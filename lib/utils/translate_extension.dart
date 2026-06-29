import 'package:pinyin/pinyin.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

extension TranslateExtension on String {
  String get t {
    try {
      final lang = GStorage.getSetting(SettingsKeys.language);
      if (lang == 'zh_TW') {
        return ChineseHelper.convertToTraditionalChinese(this);
      }
    } catch (_) {
      // 防禦性處理：避免在 GStorage 尚未初始化完成前調用出錯
    }
    return this;
  }
}
