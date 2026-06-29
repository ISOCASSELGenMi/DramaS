// 本檔案實作 MyAnimeList 設置配置介面。
// 提供使用者點擊開啟瀏覽器進行登入授權、複製貼上驗證碼進行綁定、
// 登出帳號、配置同步優先級、以及手動觸發全量雙向同步狀態等功能。
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/mal/mal_sync_priority.dart';
import 'package:kazumi/services/auth/mal_auth_service.dart';
import 'package:kazumi/services/sync/mal_sync_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/utils/translate_extension.dart';

class MalEditorPage extends StatefulWidget {
  const MalEditorPage({super.key});

  @override
  State<MalEditorPage> createState() => _MalEditorPageState();
}

class _MalEditorPageState extends State<MalEditorPage> {
  final TextEditingController malClientIdController = TextEditingController();
  final TextEditingController authCodeController = TextEditingController();
  bool isVerifying = false;
  late bool malImmediateSyncToastEnable;
  late int syncPriority;
  bool syncCollectiblesing = false;
  final MenuController syncPriorityMenuController = MenuController();

  String currentUsername = '';
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    malClientIdController.text = GStorage.getSetting(SettingsKeys.malClientId);
    malImmediateSyncToastEnable = GStorage.getSetting(SettingsKeys.malImmediateSyncToastEnable);
    syncPriority = GStorage.getSetting(SettingsKeys.malSyncPriority);
    
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    final token = GStorage.getSetting(SettingsKeys.malAccessToken).trim();
    final name = GStorage.getSetting(SettingsKeys.malUsername).trim();
    if (token.isNotEmpty) {
      isLoggedIn = true;
      currentUsername = name.isNotEmpty ? name : '已授權用戶';
    } else {
      isLoggedIn = false;
      currentUsername = '';
    }
  }

  @override
  void dispose() {
    malClientIdController.dispose();
    authCodeController.dispose();
    super.dispose();
  }

  Future<void> updateSyncPriority(int value) async {
    await GStorage.putSetting(SettingsKeys.malSyncPriority, value);
    if (!mounted) return;
    setState(() {
      syncPriority = value;
    });
  }

  Future<void> syncWithProgress() async {
    final syncEnable = GStorage.getSetting(SettingsKeys.malSyncEnable);
    if (!syncEnable) {
      KazumiDialog.showToast(message: '請先開啟 MyAnimeList 同步');
      return;
    }

    final progressDialogKey = GlobalKey<_MalSyncProgressDialogState>();

    try {
      setState(() {
        syncCollectiblesing = true;
      });

      KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) => _MalSyncProgressDialog(key: progressDialogKey),
      );

      final malSync = MalSyncService();
      await malSync.ping();
      await malSync.syncCollectibles(
        onProgress: (message, current, total) {
          progressDialogKey.currentState?.update(
            total > 0 ? '$message ($current/$total)' : message,
            total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null,
          );
        },
      );
    } catch (e) {
      KazumiDialog.showToast(message: 'MAL 同步失敗: $e');
    } finally {
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
      if (mounted) {
        setState(() {
          syncCollectiblesing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: !syncCollectiblesing,
      child: Scaffold(
        appBar: SysAppBar(title: Text('MyAnimeList 配置'.t)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLoggedIn) ...[
                  Text(
                    '授權步驟：'.t,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: malClientIdController,
                    decoration: InputDecoration(
                      labelText: '自訂 Client ID (可空，留空將使用預設 ID)'.t,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) async {
                      await GStorage.putSetting(SettingsKeys.malClientId, val.trim());
                    },
                  ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(MalAuthService().getAuthorizationUrl());
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          KazumiDialog.showToast(message: '無法開啟授權連結'.t);
                        }
                      },
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: Text('1. 前往 MyAnimeList 進行網頁授權'.t),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '授權同意後，瀏覽器將轉跳至本地頁面（顯示無法連線是正常的）。請複製網址列中 `code=` 後方的代碼貼在下方輸入框：'.t,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authCodeController,
                    decoration: InputDecoration(
                      labelText: '2. 輸入網址中的 Authorization Code'.t,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final code = authCodeController.text.trim();
                                if (code.isEmpty) {
                                  KazumiDialog.showToast(message: '授權碼不能為空'.t);
                                  return;
                                }
                                setState(() {
                                  isVerifying = true;
                                });
                                KazumiDialog.showToast(message: '正在向 MAL 交換 Token...'.t);
                                try {
                                  final success = await MalAuthService().exchangeCodeForToken(code);
                                  if (success) {
                                    final malSync = MalSyncService();
                                    await malSync.init();
                                    await GStorage.putSetting(SettingsKeys.malSyncEnable, true);
                                    
                                    KazumiDialog.showToast(message: '${'授權成功，用戶名：'.t}${malSync.username}');
                                    if (mounted) {
                                      setState(() {
                                        _checkLoginStatus();
                                      });
                                    }
                                  } else {
                                    KazumiDialog.showToast(message: '授權失敗，請確認代碼無誤'.t);
                                  }
                                } catch (e) {
                                  KazumiDialog.showToast(message: '${'授權出錯: '.t}${e.toString()}');
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      isVerifying = false;
                                    });
                                  }
                                }
                              },
                        child: Text('3. 驗證並登入'.t),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_rounded),
                        ),
                        title: Text('${'當前登入用戶：'.t}$currentUsername'),
                        subtitle: Text('MyAnimeList 同步已啟用'.t),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await MalAuthService().clearAuth();
                            setState(() {
                              _checkLoginStatus();
                            });
                            KazumiDialog.showToast(message: '已登出 MyAnimeList 帳號'.t);
                          },
                          child: Text('登出'.t),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SettingsSection(
                      margin: EdgeInsetsDirectional.zero,
                      tiles: [
                        SettingsTile.switchTile(
                          onToggle: (value) async {
                            malImmediateSyncToastEnable = value ?? !malImmediateSyncToastEnable;
                            await GStorage.putSetting(
                              SettingsKeys.malImmediateSyncToastEnable,
                              malImmediateSyncToastEnable,
                            );
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          title: Text('即時同步提示'.t, style: TextStyle(fontFamily: fontFamily)),
                          description: Text('追番或觀看進度變更觸發即時同步時顯示提示框'.t,
                              style: TextStyle(fontFamily: fontFamily)),
                          initialValue: malImmediateSyncToastEnable,
                        ),
                        SettingsTile.navigation(
                          onPressed: (_) async {
                            if (syncPriorityMenuController.isOpen) {
                              syncPriorityMenuController.close();
                            } else {
                              syncPriorityMenuController.open();
                            }
                          },
                          title: Text('同步優先級'.t, style: TextStyle(fontFamily: fontFamily)),
                          description: Text('當本地與 MyAnimeList 狀態不一致時優先使用哪個狀態'.t,
                              style: TextStyle(fontFamily: fontFamily)),
                          value: MenuAnchor(
                            consumeOutsideTap: true,
                            controller: syncPriorityMenuController,
                            builder: (context, controller, child) => Text(
                              MalSyncPriority.fromValue(syncPriority).label.t,
                              style: TextStyle(fontFamily: fontFamily),
                            ),
                            menuChildren: [
                              for (final entry in MalSyncPriority.values)
                                MenuItemButton(
                                  requestFocusOnHover: false,
                                  onPressed: () => updateSyncPriority(entry.value),
                                  child: Container(
                                    height: 48,
                                    constraints: const BoxConstraints(minWidth: 112),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        entry.label.t,
                                        style: TextStyle(
                                          color: entry.value == syncPriority
                                              ? Theme.of(context).colorScheme.primary
                                              : null,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                        SettingsTile(
                          trailing: syncCollectiblesing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded),
                          onPressed: (_) async {
                            await syncWithProgress();
                          },
                          title: Text("立即同步狀態".t, style: TextStyle(fontFamily: fontFamily)),
                          description: Text('同步狀態不一致或僅存在於本地/遠端的動漫狀態'.t,
                              style: TextStyle(fontFamily: fontFamily)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MalSyncProgressDialog extends StatefulWidget {
  const _MalSyncProgressDialog({super.key});

  @override
  State<_MalSyncProgressDialog> createState() => _MalSyncProgressDialogState();
}

class _MalSyncProgressDialogState extends State<_MalSyncProgressDialog> {
  String _progressText = '準備同步 MyAnimeList 狀態...';
  double? _progressValue;

  void update(String text, double? value) {
    if (!mounted) return;
    setState(() {
      _progressText = text.t;
      _progressValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MyAnimeList 同步進行中'.t,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_progressText),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progressValue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
