// 本檔案實作 MyAnimeList 收藏狀態與本地 CollectType 之間的對應與雙向轉換，
// 方便在進行資料同步時轉換對應的枚舉狀態。
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/mal/mal_collection_type.dart';

extension MalCollectionTypeMapper on MalCollectionType {
  CollectType toCollectType() {
    return switch (this) {
      MalCollectionType.watching => CollectType.watching,
      MalCollectionType.completed => CollectType.watched,
      MalCollectionType.onHold => CollectType.onHold,
      MalCollectionType.dropped => CollectType.abandoned,
      MalCollectionType.planToWatch => CollectType.planToWatch,
      MalCollectionType.unknown => CollectType.none,
    };
  }
}

extension CollectTypeMalMapper on CollectType {
  MalCollectionType toMalCollectionType() {
    return switch (this) {
      CollectType.watching => MalCollectionType.watching,
      CollectType.planToWatch => MalCollectionType.planToWatch,
      CollectType.onHold => MalCollectionType.onHold,
      CollectType.watched => MalCollectionType.completed,
      CollectType.abandoned => MalCollectionType.dropped,
      CollectType.none => MalCollectionType.unknown,
    };
  }
}
