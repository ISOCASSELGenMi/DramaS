import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/sync/myanimelist_sync_service.dart';

void main() {
  group('MyAnimeList sync mapping', () {
    test('maps collect types to MAL statuses', () {
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.watching), 'watching');
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.planToWatch), 'plan_to_watch');
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.onHold), 'on_hold');
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.watched), 'completed');
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.abandoned), 'dropped');
      expect(MyAnimeListSyncService.mapCollectTypeToStatus(CollectType.none), null);
    });

    test('builds a request body with watched episode info', () {
      final body = MyAnimeListSyncService.buildRequestBody('watching', watchedEpisodes: 12);
      expect(body, {'status': 'watching', 'num_watched_episodes': 12});
    });

    test('builds a request body with score info', () {
      final body = MyAnimeListSyncService.buildRequestBody('completed', watchedEpisodes: 24, score: 8);
      expect(body, {
        'status': 'completed',
        'num_watched_episodes': 24,
        'score': 8,
      });
    });
  });
}
