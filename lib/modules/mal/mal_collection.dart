// 本檔案定義 MyAnimeList (MAL) 的用戶收藏項目數據模型，
// 用於解析 MAL API 回傳的動畫條目與用戶觀看清單狀態（如已看集數、評分、更新時間）。
import 'package:kazumi/modules/mal/mal_collection_type.dart';

class MalCollection {
  /// 動畫在 MyAnimeList 的 ID
  final int malId;

  /// 動畫標題
  final String title;

  /// 動畫封面海報網址
  final Map<String, String> images;

  /// 用戶對該動畫的收藏狀態
  final MalCollectionType type;

  /// 用戶對該動畫的評分 (1-10)
  final int score;

  /// 用戶已觀看的集數
  final int numWatchedEpisodes;

  /// 條目最後更新時間
  final DateTime updatedAt;

  MalCollection({
    required this.malId,
    required this.title,
    required this.images,
    required this.type,
    required this.score,
    required this.numWatchedEpisodes,
    required this.updatedAt,
  });

  factory MalCollection.fromJson(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>? ?? {};
    final listStatus = json['list_status'] as Map<String, dynamic>? ?? {};
    final mainPicture = node['main_picture'] as Map<String, dynamic>? ?? {};

    return MalCollection(
      malId: node['id'] as int? ?? 0,
      title: node['title'] as String? ?? '',
      images: {
        'medium': mainPicture['medium'] as String? ?? '',
        'large': mainPicture['large'] as String? ?? '',
      },
      type: MalCollectionType.fromValue(listStatus['status'] as String? ?? ''),
      score: listStatus['score'] as int? ?? 0,
      numWatchedEpisodes: listStatus['num_episodes_watched'] as int? ?? 0,
      updatedAt: DateTime.tryParse(listStatus['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
