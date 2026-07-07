import 'package:flutter/material.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:kazumi/services/storage/storage.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  Locale _currentLocale = const Locale('zh', 'CN');

  Locale get currentLocale => _currentLocale;

  void initialize() {
    _currentLocale = resolveLocaleFromStored();
  }

  Locale resolveLocaleFromStored() {
    final storedLanguage = GStorage.getSetting(SettingsKeys.appLanguage);
    return resolveLocale(storedLanguage);
  }

  void reloadFromStorage() {
    _currentLocale = resolveLocaleFromStored();
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _currentLocale = locale;
    await GStorage.putSetting(SettingsKeys.appLanguage, serializeLocale(locale));
    notifyListeners();
  }

  static Locale resolveLocale(String? storedValue) {
    switch (storedValue) {
      case 'zh-Hant':
      case 'zh_TW':
      case 'zh-HK':
        return const Locale('zh', 'TW');
      case 'en':
      case 'en_US':
        return const Locale('en');
      case 'zh-Hans':
      case 'zh_CN':
      case 'zh':
      default:
        return const Locale('zh', 'CN');
    }
  }

  static String serializeLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.countryCode == 'TW' || locale.countryCode == 'HK') {
        return 'zh-Hant';
      }
      return 'zh-Hans';
    }
    if (locale.languageCode == 'en') {
      return 'en';
    }
    return 'zh-Hans';
  }
}

class KazumiLocalizations {
  static const Locale fallbackLocale = Locale('zh', 'CN');

  static String translate(String key, {Locale? locale}) {
    final resolvedLocale = locale ?? AppLocaleController.instance.currentLocale;
    final languageKey = _languageKey(resolvedLocale);
    return _translations[languageKey]?[key] ??
        _translations[_languageKey(fallbackLocale)]?[key] ??
        key;
  }

  static String _languageKey(Locale locale) {
    if (locale.languageCode == 'zh') {
      if (locale.countryCode == 'TW' || locale.countryCode == 'HK') {
        return 'zh_TW';
      }
      return 'zh';
    }
    return locale.languageCode;
  }

  static const Map<String, Map<String, String>> _translations = {
    'zh': {
      'interface_settings_title': '界面设置',
      'interface_settings_default_page': '启动界面设置',
      'interface_settings_default_page_description': '设置应用开启时的默认页面',
      'interface_settings_show_rating': '显示评分',
      'interface_settings_show_rating_description': '关闭后将在概览中隐藏评分信息',
      'interface_settings_show_anime_counter': '显示追番统计',
      'interface_settings_show_anime_counter_description': '启用后将在追番页面下方显示追番统计',
      'interface_settings_language': '界面语言',
      'interface_settings_language_description': '选择应用界面语言',
      'mal_settings_title': 'MyAnimeList 设置',
      'mal_settings_enable': '启用 MyAnimeList 同步',
      'mal_settings_enable_description': '将收藏状态与观看进度同步到 MyAnimeList',
      'mal_settings_token': 'MyAnimeList Access Token',
      'mal_settings_save': '保存设置',
      'common_recommended': '推荐',
      'common_popular': '热门',
      'common_timeline': '时间表',
      'common_collect': '追番',
      'common_my': '我的',
      'language_system': '跟随系统',
      'language_zh_hans': '简体中文',
      'language_zh_hant': '繁體中文',
      'language_en': 'English',
    },
    'zh_TW': {
      'interface_settings_title': '介面設定',
      'interface_settings_default_page': '啟動介面設定',
      'interface_settings_default_page_description': '設定應用啟動時的預設頁面',
      'interface_settings_show_rating': '顯示評分',
      'interface_settings_show_rating_description': '關閉後將在概覽中隱藏評分資訊',
      'interface_settings_show_anime_counter': '顯示追番統計',
      'interface_settings_show_anime_counter_description': '啟用後將在追番頁面下方顯示追番統計',
      'interface_settings_language': '介面語言',
      'interface_settings_language_description': '選擇應用介面語言',
      'mal_settings_title': 'MyAnimeList 設定',
      'mal_settings_enable': '啟用 MyAnimeList 同步',
      'mal_settings_enable_description': '將收藏狀態與觀看進度同步到 MyAnimeList',
      'mal_settings_token': 'MyAnimeList Access Token',
      'mal_settings_save': '儲存設定',
      'common_recommended': '推薦',
      'common_popular': '熱門',
      'common_timeline': '時間表',
      'common_collect': '追番',
      'common_my': '我的',
      'language_system': '跟隨系統',
      'language_zh_hans': '簡體中文',
      'language_zh_hant': '繁體中文',
      'language_en': 'English',
    },
    'en': {
      'interface_settings_title': 'Interface Settings',
      'interface_settings_default_page': 'Default Startup Page',
      'interface_settings_default_page_description': 'Choose the page shown when the app opens',
      'interface_settings_show_rating': 'Show Rating',
      'interface_settings_show_rating_description': 'Hide rating information in overview when disabled',
      'interface_settings_show_anime_counter': 'Show Anime Counter',
      'interface_settings_show_anime_counter_description': 'Display anime counting information below the collection page when enabled',
      'interface_settings_language': 'Interface Language',
      'interface_settings_language_description': 'Choose the app interface language',
      'mal_settings_title': 'MyAnimeList Settings',
      'mal_settings_enable': 'Enable MyAnimeList sync',
      'mal_settings_enable_description': 'Sync your collection and watch progress with MyAnimeList',
      'mal_settings_token': 'MyAnimeList Access Token',
      'mal_settings_save': 'Save settings',
      'common_recommended': 'Recommended',
      'common_popular': 'Popular',
      'common_timeline': 'Timeline',
      'common_collect': 'Collection',
      'common_my': 'My',
      'language_system': 'Follow system',
      'language_zh_hans': 'Simplified Chinese',
      'language_zh_hant': 'Traditional Chinese',
      'language_en': 'English',
    },
  };
}
