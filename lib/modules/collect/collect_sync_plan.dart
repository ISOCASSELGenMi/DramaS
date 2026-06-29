// 本檔案定義收藏狀態同步計劃（CollectSyncPlan）數據模型，
// 新增了 MyAnimeList 同步狀態的開關屬性，以配合 WebDAV 與 Bangumi 的同步邏輯判斷。
class CollectSyncPlan {
  const CollectSyncPlan({
    required this.webDavEnabled,
    required this.webDavCollectiblesEnabled,
    required this.bangumiEnabled,
    required this.malEnabled,
  });

  final bool webDavEnabled;
  final bool webDavCollectiblesEnabled;
  final bool bangumiEnabled;
  final bool malEnabled;

  bool get shouldSyncWebDavCollectibles =>
      webDavEnabled && webDavCollectiblesEnabled;

  bool get shouldSyncBangumi => bangumiEnabled;

  bool get shouldSyncMal => malEnabled;

  bool get canSync =>
      shouldSyncWebDavCollectibles || shouldSyncBangumi || shouldSyncMal;

  bool shouldUploadWebDavAfterBangumi({
    required bool webDavSynced,
    required bool bangumiSynced,
  }) {
    return shouldSyncWebDavCollectibles &&
        shouldSyncBangumi &&
        webDavSynced &&
        bangumiSynced;
  }
}
