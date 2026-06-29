# MyAnimeList (MAL) 同步與繁體中文介面支援 Walkthrough

我們已經成功地在 DramaS 中新增了 MyAnimeList 同步功能、繁體中文介面切換選項，並修復了 GitHub Actions 在 Release 階段因缺少簽名金鑰而發生的 CI 失敗問題。

## 實作內容概述

### 1. 新增的檔案

*   **[mal_collection_type.dart](file:///c:/Users/illus/Project/DramaS/lib/modules/mal/mal_collection_type.dart)**: 定義了 MAL 的在看、想看、擱置等收藏狀態枚舉。
*   **[mal_collection.dart](file:///c:/Users/illus/Project/DramaS/lib/modules/mal/mal_collection.dart)**: 解析 MAL `/animelist` API 返回的 JSON 資料模型。
*   **[mal_type_mapper.dart](file:///c:/Users/illus/Project/DramaS/lib/modules/mal/mal_type_mapper.dart)**: 本地 `CollectType` ↔ MAL `MalCollectionType` 的雙向映射器。
*   **[mal_sync_priority.dart](file:///c:/Users/illus/Project/DramaS/lib/modules/mal/mal_sync_priority.dart)**: MAL 同步衝突解決優先級（本地優先 vs MAL 優先）。
*   **[mal_collect_sync_merger.dart](file:///c:/Users/illus/Project/DramaS/lib/modules/collect/mal_collect_sync_merger.dart)**: 本地收藏與 MAL 收藏的雙向 Diff 與合併演算法計畫。
*   **[mal_client.dart](file:///c:/Users/illus/Project/DramaS/lib/request/clients/mal_client.dart)**: 封裝 Dio，用於向 MAL 發送請求並自動帶上 `Bearer <Access Token>` Header。
*   **[mal_api.dart](file:///c:/Users/illus/Project/DramaS/lib/request/apis/mal_api.dart)**: 提供 MAL API 呼叫（如獲取用戶名、讀取列表、更新狀態、搜尋動畫 ID 等）。
*   **[mal_auth_service.dart](file:///c:/Users/illus/Project/DramaS/lib/services/auth/mal_auth_service.dart)**: 處理 OAuth2 PKCE 流程、Token 交換、背景自動重新整理 Token 以及憑證儲存。
*   **[mal_sync_service.dart](file:///c:/Users/illus/Project/DramaS/lib/services/sync/mal_sync_service.dart)**: 核心同步服務。包含單一條目即時同步、全量雙向同步以及 **Bangumi ID ↔ MAL ID 對映快取**（快取於 `_setting` box，避免重複向 MAL 發送搜尋請求）。
*   **[mal_setting.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/mal/mal_setting.dart)**: 新的設定配置頁面，使用者可點擊網頁授權並貼回代碼以登入。
*   **[mal_module.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/mal/mal_module.dart)**: 註冊 `MalEditorPage` 路由。
*   **[translate_extension.dart](file:///c:/Users/illus/Project/DramaS/lib/utils/translate_extension.dart)**: 新增 `String` 擴充的 `.t` 語法，當介面語言切換成繁體時，在 runtime 使用 `chinese_converter` 進行簡繁體動態轉換。

---

### 2. 修改與整合的檔案

*   **[settings_keys.dart](file:///c:/Users/illus/Project/DramaS/lib/services/storage/settings_keys.dart)**: 新增了 `malSyncEnable`, `malAccessToken` 等 MAL 鍵名與 `language` 設定鍵。
*   **[storage.dart](file:///c:/Users/illus/Project/DramaS/lib/services/storage/storage.dart)**: 擴展 `GStorage` 支援動態對映快取。
*   **[webdav_setting.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/webdav_editor/webdav_setting.dart)**: 同步設置頁面整合 MyAnimeList 項目。
*   **[settings_module.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/settings/settings_module.dart)**: 註冊 `/mal` 路由。
*   **[collect_controller.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/collect/collect_controller.dart)** & **[collect_page.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/collect/collect_page.dart)**: 整合實時同步、全量同步邏輯。
*   **[init_page.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/init_page.dart)** & **[history_repository.dart](file:///c:/Users/illus/Project/DramaS/lib/repositories/history_repository.dart)**: 整合播放集數進度背景防抖同步與開機 token 刷新。
*   **[pubspec.yaml](file:///c:/Users/illus/Project/DramaS/pubspec.yaml)**: 引入 `chinese_converter` 依賴。
*   **[theme_provider.dart](file:///c:/Users/illus/Project/DramaS/lib/bean/settings/theme_provider.dart)**: 整合介面語言 `currentLanguage` 與 `setLanguage` 方法。
*   **[app_widget.dart](file:///c:/Users/illus/Project/DramaS/lib/app_widget.dart)** & **[main.dart](file:///c:/Users/illus/Project/DramaS/lib/main.dart)**: 引入 `zh_Hant` 相關的 locales 並動態適應語系。
*   **[interface_settings.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/settings/interface_settings.dart)**: 新增「語言設定」瓷磚，允許在「簡體中文」與「繁體中文」之間切換，並套用了 `.t` 簡繁字串翻譯。
*   **[menu.dart](file:///c:/Users/illus/Project/DramaS/lib/pages/menu/menu.dart)**: 底部導航欄與側邊導航欄套用 `.t` 切換語系。
*   **[.github/workflows/release.yaml](file:///c:/Users/illus/Project/DramaS/.github/workflows/release.yaml)**: 修復 Windows 與 Android 簽章在 GitHub Secrets 缺少時報錯的問題，無 secrets 時採用 fallback 複製未簽章產物直接發布。

---

## 如何驗證

### 1. 繁體中文語言介面切換
1. 開啟 **我的** -> **設置** -> **界面設置**。
2. 看到新增的 **語言設置**。
3. 點選 **繁體中文**，此時介面所有套用 `.t` 的元件（選單導航欄、設定標題與項目等）與 Flutter 系統內建對話框（長按、拷貝貼上選單等）將會自動且即時地轉為繁體。

### 2. GitHub Release CI 測試
1. 當你推送程式碼與新的 Tag（例如重新推送 2.1.8）時，Release workflow 會再次觸發。
2. 即使你的 Forked repo 沒有配置簽章金鑰的 secret，建置流程也會流暢地執行到結束，並自動建立草稿 Release 發布。
