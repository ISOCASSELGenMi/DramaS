import 'package:card_settings_ui/list/settings_list.dart';
import 'package:card_settings_ui/section/settings_section.dart';
import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/utils/translate_extension.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  late bool showRating;
  late bool showAnimeCounter;
  late String defaultPage;
  late String currentLanguage;
  final MenuController defaultPageMenuController = MenuController();
  final MenuController languageMenuController = MenuController();

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': '推荐',
    '/tab/timeline/': '时间表',
    '/tab/collect/': '追番',
    '/tab/my/': '我的',
  };

  static const Map<String, String> languageMap = {
    'zh_CN': '简体中文',
    'zh_TW': '繁體中文',
  };

  @override
  void initState() {
    super.initState();
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    showAnimeCounter = GStorage.getSetting(SettingsKeys.showAnimeCounter);
    defaultPage = GStorage.getSetting(SettingsKeys.defaultStartupPage);
    currentLanguage = GStorage.getSetting(SettingsKeys.language);
  }

  void updateDefaultPage(String page) {
    GStorage.putSetting(SettingsKeys.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  void updateLanguage(String lang) {
    GStorage.putSetting(SettingsKeys.language, lang);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setLanguage(lang);
    setState(() {
      currentLanguage = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Scaffold(
      appBar: SysAppBar(
        title: Text('界面设置'.t),
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
              title: Text('启动界面设置'.t, style: TextStyle(fontFamily: fontFamily)),
              description: Text('设置应用开启时的默认页面'.t,
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: defaultPageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    (defaultPageMap[defaultPage] ?? '推荐').t,
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
                            entry.value.t,
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
            SettingsTile.navigation(
              onPressed: (_) async {
                if (languageMenuController.isOpen) {
                  languageMenuController.close();
                } else {
                  languageMenuController.open();
                }
              },
              title: Text('语言设置'.t, style: TextStyle(fontFamily: fontFamily)),
              description: Text('选择应用的介面显示语言'.t,
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: languageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    (languageMap[currentLanguage] ?? '简体中文').t,
                    style: TextStyle(fontFamily: fontFamily),
                  );
                },
                menuChildren: [
                  for (final entry in languageMap.entries)
                    MenuItemButton(
                      requestFocusOnHover: false,
                      onPressed: () => updateLanguage(entry.key),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.value.t,
                            style: TextStyle(
                              color: entry.key == currentLanguage
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
              title: Text('显示评分'.t, style: TextStyle(fontFamily: fontFamily)),
              description: Text('关闭后将在概览中隐藏评分信息'.t,
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
              title: Text('显示追番统计'.t, style: TextStyle(fontFamily: fontFamily)),
              description: Text('启用后将在追番页面下方显示追番统计'.t,
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showAnimeCounter,
            ),
          ]),
        ],
      ),
    );
  }
}
