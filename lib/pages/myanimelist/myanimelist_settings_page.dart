import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/myanimelist_sync_service.dart';
import 'package:kazumi/utils/app_localizations.dart';

class MyAnimeListSettingsPage extends StatefulWidget {
  const MyAnimeListSettingsPage({super.key});

  @override
  State<MyAnimeListSettingsPage> createState() => _MyAnimeListSettingsPageState();
}

class _MyAnimeListSettingsPageState extends State<MyAnimeListSettingsPage> {
  final TextEditingController _tokenController = TextEditingController();
  bool _enabled = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _tokenController.text = GStorage.getSetting(SettingsKeys.malAccessToken);
    _enabled = GStorage.getSetting(SettingsKeys.malEnabled);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final token = _tokenController.text.trim();
    await GStorage.putSetting(SettingsKeys.malEnabled, _enabled);
    await GStorage.putSetting(SettingsKeys.malAccessToken, token);

    if (!mounted) return;

    if (!_enabled || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MyAnimeList 設定已保存')),
      );
      return;
    }

    try {
      await MyAnimeListSyncService.instance.validateToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MyAnimeList 驗證成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MyAnimeList 驗證失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleController.instance.currentLocale;
    return Scaffold(
      appBar: SysAppBar(title: Text(KazumiLocalizations.translate('mal_settings_title', locale: locale))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: Text(KazumiLocalizations.translate('mal_settings_enable', locale: locale)),
              subtitle: Text(KazumiLocalizations.translate('mal_settings_enable_description', locale: locale)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: KazumiLocalizations.translate('mal_settings_token', locale: locale),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: Text(KazumiLocalizations.translate('mal_settings_save', locale: locale)),
            ),
          ],
        ),
      ),
    );
  }
}
