import 'package:card_settings_ui/list/settings_list.dart';
import 'package:card_settings_ui/section/settings_section.dart';
import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/app_localizations.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  late bool showRating;
  late bool showAnimeCounter;
  late String defaultPage;
  late String appLanguage;
  final MenuController defaultPageMenuController = MenuController();
  final MenuController languageMenuController = MenuController();

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': 'popular',
    '/tab/timeline/': 'timeline',
    '/tab/collect/': 'collect',
    '/tab/my/': 'my',
  };

  static const Map<String, String> languageMap = {
    'zh-Hans': 'language_zh_hans',
    'zh-Hant': 'language_zh_hant',
    'en': 'language_en',
  };

  @override
  void initState() {
    super.initState();
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    showAnimeCounter = GStorage.getSetting(SettingsKeys.showAnimeCounter);
    defaultPage = GStorage.getSetting(SettingsKeys.defaultStartupPage);
    appLanguage = GStorage.getSetting(SettingsKeys.appLanguage);
    AppLocaleController.instance.initialize();
  }

  void updateDefaultPage(String page) {
    GStorage.putSetting(SettingsKeys.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  Future<void> updateAppLanguage(String language) async {
    await GStorage.putSetting(SettingsKeys.appLanguage, language);
    await AppLocaleController.instance.setLocale(AppLocaleController.resolveLocale(language));
    if (!mounted) return;
    setState(() {
      appLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    final localizedTitle = KazumiLocalizations.translate('interface_settings_title', locale: AppLocaleController.instance.currentLocale);
    final defaultPageLabel = KazumiLocalizations.translate('common_${defaultPageMap[defaultPage] ?? 'recommended'}', locale: AppLocaleController.instance.currentLocale);

    return Scaffold(
      appBar: SysAppBar(
        title: Text(localizedTitle),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(tiles: [
            SettingsTile.navigation(
              onPressed: (_) async {
                if (defaultPageMenuController.isOpen) {
                  defaultPageMenuController.close();
                } else {
                  defaultPageMenuController.open();
                }
              },
              title: Text(KazumiLocalizations.translate('interface_settings_default_page', locale: AppLocaleController.instance.currentLocale), style: TextStyle(fontFamily: fontFamily)),
              description: Text(KazumiLocalizations.translate('interface_settings_default_page_description', locale: AppLocaleController.instance.currentLocale),
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: defaultPageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    KazumiLocalizations.translate('common_${defaultPageMap[defaultPage] ?? 'recommended'}', locale: AppLocaleController.instance.currentLocale),
                    style: TextStyle(fontFamily: fontFamily),
                  );
                },
                menuChildren: [
                  for (final entry in defaultPageMap.entries)
                    MenuItemButton(
                      requestFocusOnHover: false,
                      onPressed: () => updateDefaultPage(entry.key),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            KazumiLocalizations.translate('common_${entry.value}', locale: AppLocaleController.instance.currentLocale),
                            style: TextStyle(
                              color: entry.key == defaultPage
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                showRating = value ?? !showRating;
                await GStorage.putSetting(SettingsKeys.showRating, showRating);
                setState(() {});
              },
              title: Text(KazumiLocalizations.translate('interface_settings_show_rating', locale: AppLocaleController.instance.currentLocale), style: TextStyle(fontFamily: fontFamily)),
              description: Text(KazumiLocalizations.translate('interface_settings_show_rating_description', locale: AppLocaleController.instance.currentLocale),
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showRating,
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                showAnimeCounter = value ?? !showAnimeCounter;
                await GStorage.putSetting(SettingsKeys.showAnimeCounter, showAnimeCounter);
                setState(() {});
              },
              title: Text(KazumiLocalizations.translate('interface_settings_show_anime_counter', locale: AppLocaleController.instance.currentLocale), style: TextStyle(fontFamily: fontFamily)),
              description: Text(KazumiLocalizations.translate('interface_settings_show_anime_counter_description', locale: AppLocaleController.instance.currentLocale),
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showAnimeCounter,
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.navigation(
              onPressed: (_) async {
                if (languageMenuController.isOpen) {
                  languageMenuController.close();
                } else {
                  languageMenuController.open();
                }
              },
              title: Text(KazumiLocalizations.translate('interface_settings_language', locale: AppLocaleController.instance.currentLocale), style: TextStyle(fontFamily: fontFamily)),
              description: Text(KazumiLocalizations.translate('interface_settings_language_description', locale: AppLocaleController.instance.currentLocale), style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: languageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    KazumiLocalizations.translate(languageMap[appLanguage] ?? 'language_zh_hans', locale: AppLocaleController.instance.currentLocale),
                    style: TextStyle(fontFamily: fontFamily),
                  );
                },
                menuChildren: [
                  for (final entry in languageMap.entries)
                    MenuItemButton(
                      requestFocusOnHover: false,
                      onPressed: () async => updateAppLanguage(entry.key),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            KazumiLocalizations.translate(entry.value, locale: AppLocaleController.instance.currentLocale),
                            style: TextStyle(
                              color: entry.key == appLanguage
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
