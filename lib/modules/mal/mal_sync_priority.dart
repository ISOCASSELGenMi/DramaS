// 本檔案定義 MyAnimeList 的同步優先級枚舉，
// 當本地的收藏狀態與 MyAnimeList 遠端不一致時，決定以本地優先還是 MyAnimeList 優先。
enum MalSyncPriority {
  localFirst(0, '本地優先'),
  malFirst(1, 'MyAnimeList優先');

  const MalSyncPriority(this.value, this.label);

  final int value;
  final String label;

  static MalSyncPriority fromValue(int value) {
    return MalSyncPriority.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MalSyncPriority.localFirst,
    );
  }
}
