// 本檔案定義 MyAnimeList (MAL) 的收藏/觀看狀態類型枚舉，
// 用於表示和映射 MAL 端的在看、看完、擱置、拋棄、想看等狀態。
enum MalCollectionType {
  watching('watching', '在看'),
  completed('completed', '看過'),
  onHold('on_hold', '擱置'),
  dropped('dropped', '拋棄'),
  planToWatch('plan_to_watch', '想看'),
  unknown('', '未知');

  const MalCollectionType(this.value, this.label);

  final String value;
  final String label;

  static MalCollectionType fromValue(String value) {
    return MalCollectionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MalCollectionType.unknown,
    );
  }
}
