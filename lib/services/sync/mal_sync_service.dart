// 本檔案實作 MyAnimeList (MAL) 同步服務類，
// 封裝了單一條目的即時同步（如更改追番狀態、更新看完集數）和
// 帳號收藏狀態的全量雙向同步邏輯。同時負責透過 Bangumi ID 在本地與 MAL 端
// 建立及快取動漫 ID 的關聯，保證同步的一致性與防範請求限流。
import 'dart:async';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/mal/mal_collection_type.dart';
import 'package:kazumi/modules/mal/mal_sync_priority.dart';
import 'package:kazumi/modules/mal/mal_type_mapper.dart';
import 'package:kazumi/modules/collect/mal_collect_sync_merger.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/mal_api.dart';
import 'package:kazumi/services/auth/mal_auth_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';

class MalSyncService {
  String username = '';
  bool initialized = false;

  int _queuedOperationCount = 0;
  int _activeOperationCount = 0;
  Future<void> _operationQueue = Future.value();

  bool get isUsing => _queuedOperationCount > 0 || _activeOperationCount > 0;

  MalSyncService._internal();
  static final MalSyncService _instance = MalSyncService._internal();
  factory MalSyncService() => _instance;

  void reset() {
    initialized = false;
    username = '';
  }

  Future<void> init() async {
    initialized = false;
    username = '';
    
    final token = GStorage.getSetting(SettingsKeys.malAccessToken).trim();
    if (token.isEmpty) {
      throw Exception('請先填寫 MyAnimeList Access Token');
    }

    try {
      await ping();
      initialized = true;
    } catch (e) {
      KazumiLogger().e('MAL Sync: init failed', error: e);
      rethrow;
    }
  }

  Future<void> ping() async {
    if (isUsing) {
      throw Exception('MAL Sync: 當前有操作正在進行，請稍後再試');
    }
    await _runExclusive(() async {
      try {
        await MalAuthService().checkAndRefreshToken();
        final name = await MalApi.getUsername();
        if (name == null) {
          throw Exception('MAL Sync: 獲取用戶名失敗');
        } else {
          username = name;
          await GStorage.putSetting(SettingsKeys.malUsername, name);
        }
      } catch (e) {
        KazumiLogger().e('MAL Sync: ping failed', error: e);
        rethrow;
      }
    });
  }

  /// 獲取或尋找 Bangumi ID 對應的 MyAnimeList ID，若本地未快取則在線上搜尋並存入快取
  Future<int?> getOrFindMalId(int bangumiId, String name, String nameCn) async {
    final cacheKey = 'mal_map_$bangumiId';
    final cached = GStorage.getSettingRaw(cacheKey);
    if (cached is int && cached > 0) {
      return cached;
    }

    KazumiLogger().d('MAL Sync: Cache miss for Bangumi ID $bangumiId. Searching online...');
    int? malId;
    if (name.isNotEmpty) {
      malId = await MalApi.searchAnimeId(name);
    }
    if (malId == null && nameCn.isNotEmpty) {
      malId = await MalApi.searchAnimeId(nameCn);
    }

    if (malId != null) {
      await GStorage.putSettingRaw(cacheKey, malId);
      KazumiLogger().d('MAL Sync: Mapped Bangumi ID $bangumiId to MAL ID $malId');
    } else {
      KazumiLogger().w('MAL Sync: Could not map Bangumi ID $bangumiId to MAL ID');
    }
    return malId;
  }

  final Map<int, int> _lastSyncedEpisodes = {};

  /// 同步集數觀看進度到 MyAnimeList
  Future<bool> syncEpisodeProgress(int bangumiId, int episode) async {
    final syncEnable = GStorage.getSetting(SettingsKeys.malSyncEnable);
    if (!syncEnable) return false;

    // 避免重複同步相同集數
    if (_lastSyncedEpisodes[bangumiId] == episode) {
      return true;
    }

    _lastSyncedEpisodes[bangumiId] = episode;

    // 啟動非同步任務
    unawaited(() async {
      try {
        await MalAuthService().checkAndRefreshToken();

        // 取得番劇名稱，用來搜尋對應的 MAL ID
        String name = '';
        String nameCn = '';
        
        final localCollect = GStorage.collectibles.get(bangumiId);
        if (localCollect != null) {
          name = localCollect.bangumiItem.name;
          nameCn = localCollect.bangumiItem.nameCn;
        } else {
          final info = await BangumiApi.getBangumiInfoByID(bangumiId);
          if (info != null) {
            name = info.name;
            nameCn = info.nameCn;
          }
        }

        if (name.isEmpty && nameCn.isEmpty) return;

        final malId = await getOrFindMalId(bangumiId, name, nameCn);
        if (malId == null) return;

        // 更新 MAL 的集數進度，並將狀態自動設為 watching (在看)
        await MalApi.updateAnimeStatus(
          malId: malId,
          status: MalCollectionType.watching,
          watchedEpisodes: episode,
        );
        KazumiLogger().i('MAL Sync: Synced episode $episode for anime $bangumiId');
      } catch (e) {
        KazumiLogger().e('MAL Sync: syncEpisodeProgress failed', error: e);
      }
    }());

    return true;
  }

  /// 即時同步單個收藏狀態或觀看集數到 MyAnimeList
  Future<bool> syncCollectibleWhenIdle(
    int bangumiId,
    int localType, {
    int? watchedEpisodes,
    int? score,
  }) {
    return _runExclusive(() async {
      try {
        await MalAuthService().checkAndRefreshToken();

        // 1. 取得番劇名稱，用來搜尋對應的 MAL ID
        String name = '';
        String nameCn = '';
        
        final localCollect = GStorage.collectibles.get(bangumiId);
        if (localCollect != null) {
          name = localCollect.bangumiItem.name;
          nameCn = localCollect.bangumiItem.nameCn;
        } else {
          // 本地沒有收藏，呼叫 API 載入
          final info = await BangumiApi.getBangumiInfoByID(bangumiId);
          if (info != null) {
            name = info.name;
            nameCn = info.nameCn;
          }
        }

        if (name.isEmpty && nameCn.isEmpty) {
          KazumiLogger().w('MAL Sync: Cannot sync because anime name is empty.');
          return false;
        }

        // 2. 獲取 MAL ID
        final malId = await getOrFindMalId(bangumiId, name, nameCn);
        if (malId == null) {
          return false;
        }

        // 3. 狀態對照
        final collectType = CollectType.fromValue(localType);
        final malStatus = collectType.toMalCollectionType();

        if (malStatus == MalCollectionType.unknown) {
          // 如果是 none (未收藏)，MAL 不提供 none 狀態，只支援 DELETE 刪除
          return await MalApi.deleteAnimeFromList(malId);
        }

        return await MalApi.updateAnimeStatus(
          malId: malId,
          status: malStatus,
          watchedEpisodes: watchedEpisodes,
          score: score,
        );
      } catch (e) {
        KazumiLogger().e('MAL Sync: syncCollectibleWhenIdle failed', error: e);
        return false;
      }
    });
  }

  /// 執行全量收藏狀態同步
  Future<bool> syncCollectibles({
    void Function(String message, int current, int total)? onProgress,
  }) async {
    final syncEnable = GStorage.getSetting(SettingsKeys.malSyncEnable);
    if (!syncEnable) {
      KazumiDialog.showToast(message: 'MAL 同步已關閉');
      return false;
    }
    if (isUsing) {
      throw Exception('MyAnimeList 同步正在進行中');
    }

    return _runExclusive(() async {
      try {
        onProgress?.call('開始同步 MyAnimeList 狀態', 0, 0);

        // 1. 刷新 Token 並拉取 MAL 遠端狀態
        await MalAuthService().checkAndRefreshToken();
        final remoteCollection = await MalApi.getAnimeList(onProgress: onProgress);

        // 2. 載入本地所有收藏
        final localCollectibles = GStorage.collectibles.values.toList();

        // 3. 建立本地所有收藏的 MAL ID 對應表
        onProgress?.call('正在比對條目對應關係...', 0, localCollectibles.length);
        final Map<int, int> bangumiToMalIdMap = {};
        
        int matchCount = 0;
        for (final local in localCollectibles) {
          final bId = local.bangumiItem.id;
          final cachedMalId = GStorage.getSettingRaw('mal_map_$bId');
          
          if (cachedMalId is int && cachedMalId > 0) {
            bangumiToMalIdMap[bId] = cachedMalId;
          } else {
            // 沒有快取則進行線上查詢，每次請求延遲 250ms 避免被 MAL 限流
            onProgress?.call('正在為 ${local.bangumiItem.nameCn} 建立 MAL 關聯...', matchCount, localCollectibles.length);
            final malId = await getOrFindMalId(bId, local.bangumiItem.name, local.bangumiItem.nameCn);
            if (malId != null) {
              bangumiToMalIdMap[bId] = malId;
            }
            await Future.delayed(const Duration(milliseconds: 250));
          }
          matchCount++;
        }

        final priority = MalSyncPriority.fromValue(
          GStorage.getSetting(SettingsKeys.malSyncPriority),
        );

        // 4. 計算合併計畫
        final mergePlan = MalCollectSyncMerger.planSync(
          localCollectibles: localCollectibles,
          remoteCollections: remoteCollection,
          bangumiToMalIdMap: bangumiToMalIdMap,
          priority: priority,
        );

        final totalOps = mergePlan.totalOperations;
        if (totalOps == 0) {
          onProgress?.call('未發現狀態差異，無需同步', 1, 1);
          return false;
        }

        int syncedCount = 0;

        // 5. 處理本地新增上傳
        if (mergePlan.localOnlyUploads.isNotEmpty) {
          onProgress?.call('正在上傳本地新增狀態...', syncedCount, totalOps);
          for (final upload in mergePlan.localOnlyUploads) {
            final status = CollectType.fromValue(upload.type).toMalCollectionType();
            final success = await MalApi.updateAnimeStatus(
              malId: upload.malId,
              status: status,
            );
            if (!success) {
              throw Exception('同步失敗：MAL ID ${upload.malId} 上傳失敗');
            }
            syncedCount++;
            onProgress?.call('正在上傳本地新增狀態...', syncedCount, totalOps);
            await Future.delayed(const Duration(milliseconds: 250));
          }
        }

        // 6. 處理本地缺失補全 (從遠端下載)
        if (mergePlan.remoteOnlyPuts.isNotEmpty) {
          onProgress?.call('正在下載遠端缺失狀態...', syncedCount, totalOps);
          for (final put in mergePlan.remoteOnlyPuts) {
            final bangumiId = put.collectible.bangumiItem.id;
            // 必須先呼叫 Bangumi API 下載完整番劇資訊，不可用 stub
            final fullItem = await BangumiApi.getBangumiInfoByID(bangumiId);
            if (fullItem != null) {
              final finalCollectible = CollectedBangumi(
                fullItem,
                put.collectible.time,
                put.collectible.type,
              );
              await GStorage.putCollectible(finalCollectible);
              await GStorage.appendCollectChange(
                bangumiId: bangumiId,
                action: put.changeAction,
                type: put.collectible.type,
              );
            }
            syncedCount++;
            onProgress?.call('正在下載遠端狀態...', syncedCount, totalOps);
            await Future.delayed(const Duration(milliseconds: 250));
          }
        }

        // 7. 處理衝突
        if (priority == MalSyncPriority.localFirst) {
          onProgress?.call('本地優先：正在解決狀態衝突...', syncedCount, totalOps);
          for (final upload in mergePlan.conflictUploads) {
            final status = CollectType.fromValue(upload.type).toMalCollectionType();
            final success = await MalApi.updateAnimeStatus(
              malId: upload.malId,
              status: status,
            );
            if (!success) {
              throw Exception('同步失敗：MAL ID ${upload.malId} 衝突解決上傳失敗');
            }
            syncedCount++;
            onProgress?.call('本地優先：正在解決狀態衝突...', syncedCount, totalOps);
            await Future.delayed(const Duration(milliseconds: 250));
          }
        } else {
          onProgress?.call('MAL優先：正在解決狀態衝突...', syncedCount, totalOps);
          for (final update in mergePlan.conflictLocalUpdates) {
            // 本地需要更新為遠端狀態
            await GStorage.putCollectible(update.collectible);
            await GStorage.appendCollectChange(
              bangumiId: update.collectible.bangumiItem.id,
              action: update.changeAction,
              type: update.collectible.type,
            );
            syncedCount++;
            onProgress?.call('MAL優先：正在解決狀態衝突...', syncedCount, totalOps);
          }
        }

        onProgress?.call('MyAnimeList 同步完成', 1, 1);
        return true;
      } catch (e) {
        KazumiLogger().e('MAL Sync: full sync failed', error: e);
        rethrow;
      }
    });
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previousOperation = _operationQueue;
    _queuedOperationCount++;

    _operationQueue = (() async {
      try {
        await previousOperation;
      } catch (_) {}

      _queuedOperationCount--;
      _activeOperationCount++;
      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      } finally {
        _activeOperationCount--;
      }
    })();

    return completer.future;
  }
}
