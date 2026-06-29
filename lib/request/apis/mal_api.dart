// 本檔案實作 MyAnimeList (MAL) API 的具體呼叫層，
// 封裝了包含獲取當前用戶信息、查詢用戶動漫清單、更新條目狀態與已看集數、
// 以及通過標題搜尋動漫 ID 以建立 Bangumi 與 MAL 條目關聯等 API 端點。
import 'package:kazumi/modules/mal/mal_collection.dart';
import 'package:kazumi/modules/mal/mal_collection_type.dart';
import 'package:kazumi/request/clients/mal_client.dart';
import 'package:kazumi/services/logging/logger.dart';

class MalApi {
  static final MalClient _client = MalClient.instance;

  static const String malBaseUrl = 'https://api.myanimelist.net/v2';

  /// 取得當前 Access Token 對應的用戶名
  static Future<String?> getUsername() async {
    try {
      final data = await _client.get(
        '$malBaseUrl/users/@me',
        requiresAuth: true,
      );
      if (data != null && data['name'] != null) {
        return data['name'] as String;
      }
    } catch (e) {
      KazumiLogger().e('MAL: get current user name failed', error: e);
    }
    return null;
  }

  /// 獲取用戶的 MyAnimeList 收藏清單
  static Future<List<MalCollection>> getAnimeList({
    void Function(String message, int current, int total)? onProgress,
  }) async {
    final List<MalCollection> list = [];
    String? nextUrl = '$malBaseUrl/users/@me/animelist?fields=list_status{num_episodes_watched,score,updated_at}&limit=100';

    try {
      int page = 1;
      while (nextUrl != null) {
        onProgress?.call('正在拉取 MyAnimeList 收藏 (第 $page 頁)', list.length, list.length);
        final response = await _client.get(
          nextUrl,
          requiresAuth: true,
        );
        if (response == null) break;

        final dataList = response['data'] as List<dynamic>? ?? [];
        for (var item in dataList) {
          if (item is Map<String, dynamic>) {
            try {
              list.add(MalCollection.fromJson(item));
            } catch (e) {
              KazumiLogger().e('MAL: parse animelist item failed', error: e);
            }
          }
        }

        final paging = response['paging'] as Map<String, dynamic>?;
        nextUrl = paging?['next'] as String?;
        page++;
      }
    } catch (e) {
      KazumiLogger().e('MAL: get user animelist failed', error: e);
      rethrow;
    }

    return list;
  }

  /// 更新或新增 MyAnimeList 動漫狀態與集數
  static Future<bool> updateAnimeStatus({
    required int malId,
    required MalCollectionType status,
    int? watchedEpisodes,
    int? score,
  }) async {
    final String url = '$malBaseUrl/anime/$malId/my_list_status';
    final Map<String, dynamic> body = {
      'status': status.value,
    };
    if (watchedEpisodes != null) {
      body['num_watched_episodes'] = watchedEpisodes;
    }
    if (score != null && score > 0) {
      body['score'] = score;
    }

    try {
      final response = await _client.patch(
        url,
        data: body,
        requiresAuth: true,
      );
      if (response != null && response['status'] != null) {
        KazumiLogger().d('MAL: Successfully updated anime $malId status to ${status.value}');
        return true;
      }
    } catch (e) {
      KazumiLogger().e('MAL: update anime $malId status failed', error: e);
    }
    return false;
  }

  /// 刪除 MyAnimeList 中的動漫收藏 (MAL 支援直接刪除，回傳 200)
  static Future<bool> deleteAnimeFromList(int malId) async {
    final String url = '$malBaseUrl/anime/$malId/my_list_status';
    try {
      await _client.delete(
        url,
        requiresAuth: true,
      );
      KazumiLogger().d('MAL: Successfully deleted anime $malId from list');
      return true;
    } catch (e) {
      KazumiLogger().e('MAL: delete anime $malId failed', error: e);
    }
    return false;
  }

  /// 藉由名稱搜尋 MAL ID
  static Future<int?> searchAnimeId(String name) async {
    if (name.trim().isEmpty) return null;
    final String url = '$malBaseUrl/anime';
    try {
      final response = await _client.get(
        url,
        queryParameters: {
          'q': name,
          'limit': 5,
        },
        requiresAuth: true,
      );
      if (response != null) {
        final data = response['data'] as List<dynamic>? ?? [];
        if (data.isNotEmpty) {
          final first = data.first['node'] as Map<String, dynamic>?;
          if (first != null) {
            return first['id'] as int;
          }
        }
      }
    } catch (e) {
      KazumiLogger().e('MAL: search anime id for "$name" failed', error: e);
    }
    return null;
  }
}
