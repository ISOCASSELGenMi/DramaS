// 本檔案實作 MyAnimeList (MAL) 的 API HTTP 客戶端，
// 封裝了 Dio 實例，用以向 MAL 伺服器發送 GET/POST/PATCH 請求，
// 並在請求 Header 中自動附加 OAuth2 Access Token 以進行身分驗證。
import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/storage/storage.dart';

class MalClient {
  MalClient._();

  static final MalClient instance = MalClient._();

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.apiDio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(requiresAuth: requiresAuth),
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.apiDio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(requiresAuth: requiresAuth),
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<dynamic> patch(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.apiDio.patch(
        url,
        data: data,
        options: Options(
          headers: _headers(requiresAuth: requiresAuth),
          contentType: Headers.formUrlEncodedContentType,
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<dynamic> delete(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.apiDio.delete(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(requiresAuth: requiresAuth),
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Map<String, dynamic> _headers({required bool requiresAuth}) {
    final headers = <String, dynamic>{
      'User-Agent': 'Kazumi/2.1.7 (Flutter; Android/iOS/Desktop)',
    };
    final malSyncEnable = GStorage.getSetting(SettingsKeys.malSyncEnable);
    final token = GStorage.getSetting(SettingsKeys.malAccessToken).trim();
    if ((requiresAuth || malSyncEnable) && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
