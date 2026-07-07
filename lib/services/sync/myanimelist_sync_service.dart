import 'package:dio/dio.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class MyAnimeListSyncService {
  MyAnimeListSyncService._();

  static final MyAnimeListSyncService instance = MyAnimeListSyncService._();

  static const String _baseUrl = 'https://api.myanimelist.net/v2';

  static String? mapCollectTypeToStatus(CollectType type) {
    switch (type) {
      case CollectType.watching:
        return 'watching';
      case CollectType.planToWatch:
        return 'plan_to_watch';
      case CollectType.onHold:
        return 'on_hold';
      case CollectType.watched:
        return 'completed';
      case CollectType.abandoned:
        return 'dropped';
      case CollectType.none:
        return null;
    }
  }

  static Map<String, dynamic> buildRequestBody(
    String? status, {
    int? watchedEpisodes,
    int? score,
  }) {
    final payload = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      payload['status'] = status;
    }
    if (watchedEpisodes != null && watchedEpisodes > 0) {
      payload['num_watched_episodes'] = watchedEpisodes;
    }
    if (score != null && score > 0 && score <= 10) {
      payload['score'] = score;
    }
    return payload;
  }

  String get _configuredToken => GStorage.getSetting(SettingsKeys.malAccessToken).trim();

  bool get isEnabled => GStorage.getSetting(SettingsKeys.malEnabled);

  Future<void> validateToken() async {
    if (!isEnabled) {
      throw Exception('MyAnimeList 同步已关闭');
    }
    if (_configuredToken.isEmpty) {
      throw Exception('请先填写 MyAnimeList Access Token');
    }

    final response = await _request(
      '/users/@me',
      method: 'GET',
    );
    if (response is! Map<String, dynamic>) {
      throw Exception('MyAnimeList 验证失败');
    }
  }

  Future<bool> syncCollectible(
    CollectedBangumi collectible, {
    int? watchedEpisodes,
    int? score,
  }) async {
    if (!isEnabled) {
      return false;
    }
    final status = mapCollectTypeToStatus(CollectType.fromValue(collectible.type));
    if (status == null) {
      return true;
    }

    try {
      final resolvedWatchedEpisodes =
          watchedEpisodes ?? _resolveWatchedEpisodes(collectible);
      await _request(
        '/anime/${collectible.bangumiItem.id}/my_list_status',
        method: 'PUT',
        data: buildRequestBody(
          status,
          watchedEpisodes: resolvedWatchedEpisodes,
          score: score,
        ),
      );
      return true;
    } catch (e, stackTrace) {
      KazumiLogger().e('MyAnimeList: sync failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  int? _resolveWatchedEpisodes(CollectedBangumi collectible) {
    final matchingHistories = GStorage.histories.values.where(
      (entry) => entry.bangumiItem.id == collectible.bangumiItem.id,
    );
    if (matchingHistories.isEmpty) {
      return null;
    }

    final watchedEpisodes = matchingHistories
        .map((entry) => entry.lastWatchEpisode)
        .where((episode) => episode > 0)
        .toList();
    if (watchedEpisodes.isEmpty) {
      return null;
    }
    watchedEpisodes.sort();
    return watchedEpisodes.last;
  }

  Future<dynamic> _request(
    String path, {
    required String method,
    Object? data,
  }) async {
    final options = Options(
      headers: {
        'Authorization': 'Bearer $_configuredToken',
        'Content-Type': 'application/json',
      },
    );

    try {
      final response = await DioFactory.createForConfig(
        NetworkConfig.fromSettings(),
      ).request(
        '$_baseUrl$path',
        options: options.copyWith(method: method),
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw NetworkException(
        type: NetworkExceptionType.badResponse,
        message: 'MyAnimeList 请求失败',
        statusCode: e.response?.statusCode,
        rawError: e,
        stackTrace: e.stackTrace,
      );
    }
  }
}
