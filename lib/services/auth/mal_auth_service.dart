// 本檔案實作 MyAnimeList (MAL) 的 OAuth2 認證服務，
// 負責處理 PKCE（Proof Key for Code Exchange）流程、
// 使用授權碼（Authorization Code）交換 Access/Refresh Token、
// 儲存 Token 憑證、以及在 Access Token 過期時自動利用 Refresh Token 進行刷新。
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class MalAuthService {
  MalAuthService._internal();
  static final MalAuthService _instance = MalAuthService._internal();
  factory MalAuthService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// 預設的 MyAnimeList Client ID。
  /// 使用者如果想使用自定義的 API Client，可以在設置頁面修改此值。
  static const String defaultClientId = '5b30691e847c94c965fb6de634351a02';
  static const String defaultRedirectUri = 'http://localhost';

  /// 當前使用的 Client ID
  String get clientId {
    final configured = GStorage.getSetting(SettingsKeys.malClientId).trim();
    return configured.isNotEmpty ? configured : defaultClientId;
  }

  /// 當前使用的 Redirect URI
  String get redirectUri => defaultRedirectUri;

  /// 本地暫存的 code_verifier，用於在授權回傳後與 MAL 交換 token
  String? _pendingCodeVerifier;

  /// 產生 PKCE 的 Code Verifier（隨機 128 字元字串）
  String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// 獲取引導使用者在瀏覽器中開啟的授權網址，並在本地記錄對應的 code_verifier
  String getAuthorizationUrl() {
    final verifier = _generateCodeVerifier();
    _pendingCodeVerifier = verifier;
    
    // 將 code_verifier 存入持久化，防範 App 重啟等狀況
    GStorage.putStringListSettingByName('mal_pending_verifier', [verifier]);

    return 'https://myanimelist.net/v1/oauth2/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&code_challenge=$verifier'
        '&code_challenge_method=plain';
  }

  /// 使用授權碼（Authorization Code）向 MAL 交換 Access Token 和 Refresh Token
  Future<bool> exchangeCodeForToken(String authCode) async {
    // 優先從記憶體中拿 verifier，若無則從持久化中載入
    String? verifier = _pendingCodeVerifier;
    if (verifier == null || verifier.isEmpty) {
      final saved = GStorage.getStringListSettingByName('mal_pending_verifier');
      if (saved.isNotEmpty) {
        verifier = saved.first;
      }
    }

    if (verifier == null || verifier.isEmpty) {
      KazumiLogger().e('MAL Auth: Missing code verifier for token exchange.');
      throw Exception('缺少驗證碼 (Code Verifier)，請重新發起授權');
    }

    try {
      final response = await _dio.post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': authCode.trim(),
          'code_verifier': verifier,
          'redirect_uri': redirectUri,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        await _saveTokenData(data);
        // 清理暫存的 verifier
        _pendingCodeVerifier = null;
        await GStorage.putStringListSettingByName('mal_pending_verifier', []);
        return true;
      }
    } catch (e) {
      KazumiLogger().e('MAL Auth: Token exchange failed', error: e);
      rethrow;
    }
    return false;
  }

  /// 使用 Refresh Token 刷新 Access Token
  Future<bool> refreshToken() async {
    final rToken = GStorage.getSetting(SettingsKeys.malRefreshToken).trim();
    if (rToken.isEmpty) {
      KazumiLogger().w('MAL Auth: Refresh token is empty.');
      return false;
    }

    try {
      KazumiLogger().i('MAL Auth: Refreshing access token...');
      final response = await _dio.post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': rToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        await _saveTokenData(data);
        KazumiLogger().i('MAL Auth: Access token refreshed successfully.');
        return true;
      }
    } catch (e) {
      KazumiLogger().e('MAL Auth: Token refresh failed', error: e);
      // 若更新失敗（例如 refresh token 已失效），清除授權狀態
      await clearAuth();
    }
    return false;
  }

  /// 檢查 Token 是否即將過期，若是則自動執行 Refresh。
  /// 會在每次進行 MAL API 請求前呼叫。
  Future<void> checkAndRefreshToken() async {
    final token = GStorage.getSetting(SettingsKeys.malAccessToken).trim();
    if (token.isEmpty) return;

    final expiry = GStorage.getSetting(SettingsKeys.malTokenExpiry);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 如果過期時間剩不到 10 分鐘，或者是已經過期，則刷新 Token
    if (expiry == 0 || (expiry - nowMs) < 600000) {
      final success = await refreshToken();
      if (!success) {
        throw Exception('MyAnimeList 登入已過期，請重新登入授權');
      }
    }
  }

  /// 清除本地的所有 MAL 登入授權狀態
  Future<void> clearAuth() async {
    await GStorage.putSetting(SettingsKeys.malAccessToken, '');
    await GStorage.putSetting(SettingsKeys.malRefreshToken, '');
    await GStorage.putSetting(SettingsKeys.malTokenExpiry, 0);
    await GStorage.putSetting(SettingsKeys.malUsername, '');
    await GStorage.putSetting(SettingsKeys.malSyncEnable, false);
    KazumiLogger().i('MAL Auth: Cleared authentication data.');
  }

  /// 輔助方法：儲存 Token 資料並計算過期時間
  Future<void> _saveTokenData(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String? ?? '';
    final refreshToken = data['refresh_token'] as String? ?? '';
    final expiresIn = data['expires_in'] as int? ?? 0;

    // 計算過期的毫秒時間戳
    final expiryTimeMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

    await GStorage.putSetting(SettingsKeys.malAccessToken, accessToken);
    await GStorage.putSetting(SettingsKeys.malRefreshToken, refreshToken);
    await GStorage.putSetting(SettingsKeys.malTokenExpiry, expiryTimeMs);
  }
}
