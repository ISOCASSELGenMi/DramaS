// 本檔案實作 MyAnimeList 同步合併算法，
// 通過比對本地收藏項目與 MyAnimeList 遠端收藏項目的差異，
// 產生對應的同步計畫，包含僅本地有的上傳、僅遠端有的補全、以及狀態不一致時的衝突解決。
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/mal/mal_collection.dart';
import 'package:kazumi/modules/mal/mal_sync_priority.dart';
import 'package:kazumi/modules/mal/mal_type_mapper.dart';

class MalUploadMutation {
  final int malId;
  final int type;

  const MalUploadMutation({
    required this.malId,
    required this.type,
  });
}

class MalLocalMutation {
  final CollectedBangumi collectible;
  final int changeAction; // 1: 新增, 2: 修改

  const MalLocalMutation({
    required this.collectible,
    required this.changeAction,
  });
}

class MalCollectiblesMergePlan {
  final List<MalUploadMutation> localOnlyUploads;
  final List<MalLocalMutation> remoteOnlyPuts;
  final List<MalUploadMutation> conflictUploads;
  final List<MalLocalMutation> conflictLocalUpdates;

  const MalCollectiblesMergePlan({
    required this.localOnlyUploads,
    required this.remoteOnlyPuts,
    required this.conflictUploads,
    required this.conflictLocalUpdates,
  });

  int get totalOperations =>
      localOnlyUploads.length +
      remoteOnlyPuts.length +
      conflictUploads.length +
      conflictLocalUpdates.length;
}

class MalCollectSyncMerger {
  static MalCollectiblesMergePlan planSync({
    required List<CollectedBangumi> localCollectibles,
    required List<MalCollection> remoteCollections,
    required Map<int, int> bangumiToMalIdMap,
    required MalSyncPriority priority,
  }) {
    final localMap = {
      for (final item in localCollectibles) item.bangumiItem.id: item,
    };
    
    final remoteMap = {
      for (final item in remoteCollections) item.malId: item,
    };

    final malToBangumiIdMap = {
      for (final entry in bangumiToMalIdMap.entries) entry.value: entry.key,
    };

    final List<MalUploadMutation> localOnlyUploads = [];
    final List<MalLocalMutation> remoteOnlyPuts = [];
    final List<MalUploadMutation> conflictUploads = [];
    final List<MalLocalMutation> conflictLocalUpdates = [];

    // 1. 本地有對應 MAL ID 的項目
    for (final localItem in localCollectibles) {
      final bangumiId = localItem.bangumiItem.id;
      final malId = bangumiToMalIdMap[bangumiId];
      if (malId == null) {
        // 沒有快取的 MAL ID，跳過全量合併，留待即時同步再尋找
        continue;
      }

      final remoteItem = remoteMap[malId];
      if (remoteItem == null) {
        // 僅本地有：上傳到 MyAnimeList
        if (localItem.type > 0) {
          localOnlyUploads.add(MalUploadMutation(malId: malId, type: localItem.type));
        }
      } else {
        // 雙方都有：比對狀態
        final localType = localItem.type;
        final remoteType = remoteItem.type.toCollectType().value;

        if (localType != remoteType) {
          if (priority == MalSyncPriority.localFirst) {
            conflictUploads.add(MalUploadMutation(malId: malId, type: localType));
          } else {
            // MyAnimeList 優先：更新本地
            conflictLocalUpdates.add(
              MalLocalMutation(
                collectible: CollectedBangumi(
                  localItem.bangumiItem,
                  remoteItem.updatedAt,
                  remoteType,
                ),
                changeAction: 2,
              ),
            );
          }
        }
      }
    }

    // 2. 僅 MyAnimeList 遠端有，且本地可以對應到 Bangumi ID 的項目
    for (final remoteItem in remoteCollections) {
      final bangumiId = malToBangumiIdMap[remoteItem.malId];
      if (bangumiId == null) {
        // 遠端有但無法與本地 Bangumi 對應，暫時跳過
        continue;
      }

      final localItem = localMap[bangumiId];
      if (localItem == null) {
        // 僅遠端有：在本地新增，但需注意：在外部執行同步時，若本地沒有該 BangumiItem 實體，
        // 必須動態獲取 BangumiItem 以建構 CollectedBangumi。
        // 此處我們提供一個 placeholder collectible，外部再依照此 collectible.bangumiItem.id 填入真正的 BangumiItem
        final tempCollectible = CollectedBangumi(
          // 外部會透過 BangumiApi 將此 stub 替換為真正的物件
          stubBangumiItem(bangumiId),
          remoteItem.updatedAt,
          remoteItem.type.toCollectType().value,
        );
        remoteOnlyPuts.add(
          MalLocalMutation(
            collectible: tempCollectible,
            changeAction: 1,
          ),
        );
      }
    }

    return MalCollectiblesMergePlan(
      localOnlyUploads: localOnlyUploads,
      remoteOnlyPuts: remoteOnlyPuts,
      conflictUploads: conflictUploads,
      conflictLocalUpdates: conflictLocalUpdates,
    );
  }

  // 建立一個 Stub 的 BangumiItem 用於傳遞 ID，外部會自動呼叫 API 換成真實項目。
  static CollectedBangumi stubCollectible(int bangumiId, DateTime updatedAt, int type) {
    return CollectedBangumi(
      stubBangumiItem(bangumiId),
      updatedAt,
      type,
    );
  }

  static BangumiItem stubBangumiItem(int id) {
    return BangumiItem(
      id: id,
      type: 2,
      name: '',
      nameCn: '',
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
    );
  }
}
