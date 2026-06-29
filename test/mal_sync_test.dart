// 本檔案是 MyAnimeList (MAL) 同步功能的單元測試，
// 主要測試 CollectSyncPlan 在 MAL 啟用時的行為，以及
// MalCollectSyncMerger 在處理本地與遠端收藏狀態時的合併計算邏輯是否正確。
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/mal/mal_collection.dart';
import 'package:kazumi/modules/mal/mal_collection_type.dart';
import 'package:kazumi/modules/mal/mal_sync_priority.dart';
import 'package:kazumi/modules/collect/mal_collect_sync_merger.dart';

void main() {
  group('MalCollectSyncPlan Tests', () {
    test('enables MyAnimeList sync correctly', () {
      const plan = CollectSyncPlan(
        webDavEnabled: false,
        webDavCollectiblesEnabled: false,
        bangumiEnabled: false,
        malEnabled: true,
      );

      expect(plan.shouldSyncWebDavCollectibles, isFalse);
      expect(plan.shouldSyncBangumi, isFalse);
      expect(plan.shouldSyncMal, isTrue);
      expect(plan.canSync, isTrue);
    });

    test('ignores MyAnimeList sync when disabled', () {
      const plan = CollectSyncPlan(
        webDavEnabled: false,
        webDavCollectiblesEnabled: false,
        bangumiEnabled: false,
        malEnabled: false,
      );

      expect(plan.shouldSyncMal, isFalse);
      expect(plan.canSync, isFalse);
    });
  });

  group('MalCollectSyncMerger Tests', () {
    test('plans upload for local-only collectibles', () {
      final local = [
        _collect(1, CollectType.watching),
        _collect(2, CollectType.watched),
      ];
      final remote = <MalCollection>[];
      final mappings = {1: 101, 2: 102}; // bangumi ID -> MAL ID

      final plan = MalCollectSyncMerger.planSync(
        localCollectibles: local,
        remoteCollections: remote,
        bangumiToMalIdMap: mappings,
        priority: MalSyncPriority.localFirst,
      );

      expect(plan.localOnlyUploads.length, 2);
      expect(plan.localOnlyUploads[0].malId, 101);
      expect(plan.localOnlyUploads[0].type, CollectType.watching.value);
      expect(plan.remoteOnlyPuts.isEmpty, isTrue);
      expect(plan.conflictUploads.isEmpty, isTrue);
      expect(plan.conflictLocalUpdates.isEmpty, isTrue);
    });

    test('plans download for remote-only collectibles when mapped', () {
      final local = <CollectedBangumi>[];
      final remote = [
        _remote(101, MalCollectionType.completed),
      ];
      final mappings = {1: 101}; // bangumi ID 1 -> MAL ID 101

      final plan = MalCollectSyncMerger.planSync(
        localCollectibles: local,
        remoteCollections: remote,
        bangumiToMalIdMap: mappings,
        priority: MalSyncPriority.localFirst,
      );

      expect(plan.localOnlyUploads.isEmpty, isTrue);
      expect(plan.remoteOnlyPuts.length, 1);
      expect(plan.remoteOnlyPuts[0].collectible.bangumiItem.id, 1);
      expect(plan.remoteOnlyPuts[0].collectible.type, CollectType.watched.value);
    });

    test('resolves status conflict - localFirst priority', () {
      final local = [_collect(1, CollectType.watching)];
      final remote = [_remote(101, MalCollectionType.completed)];
      final mappings = {1: 101};

      final plan = MalCollectSyncMerger.planSync(
        localCollectibles: local,
        remoteCollections: remote,
        bangumiToMalIdMap: mappings,
        priority: MalSyncPriority.localFirst,
      );

      expect(plan.conflictUploads.length, 1);
      expect(plan.conflictUploads[0].malId, 101);
      expect(plan.conflictUploads[0].type, CollectType.watching.value);
      expect(plan.conflictLocalUpdates.isEmpty, isTrue);
    });

    test('resolves status conflict - malFirst priority', () {
      final local = [_collect(1, CollectType.watching)];
      final remote = [_remote(101, MalCollectionType.completed)];
      final mappings = {1: 101};

      final plan = MalCollectSyncMerger.planSync(
        localCollectibles: local,
        remoteCollections: remote,
        bangumiToMalIdMap: mappings,
        priority: MalSyncPriority.malFirst,
      );

      expect(plan.conflictUploads.isEmpty, isTrue);
      expect(plan.conflictLocalUpdates.length, 1);
      expect(plan.conflictLocalUpdates[0].collectible.bangumiItem.id, 1);
      expect(plan.conflictLocalUpdates[0].collectible.type, CollectType.watched.value);
    });
  });
}

CollectedBangumi _collect(int id, CollectType type) {
  return CollectedBangumi(
    BangumiItem(
      id: id,
      type: 2,
      name: 'Anime $id',
      nameCn: '動漫 $id',
      summary: '',
      airDate: '',
      airWeekday: 1,
      rank: 0,
      images: {},
      tags: [],
      alias: [],
      ratingScore: 0.0,
      votes: 0,
      votesCount: [],
      info: '',
    ),
    DateTime.now(),
    type.value,
  );
}

MalCollection _remote(int malId, MalCollectionType type) {
  return MalCollection(
    malId: malId,
    title: 'MAL Anime $malId',
    images: {},
    type: type,
    score: 0,
    numWatchedEpisodes: 0,
    updatedAt: DateTime.now(),
  );
}
