# DramaS 專案系統結構與功能擴充計畫

## 1. 專案定位

DramaS 是一個基於 Flutter / Dart 的動漫播放與管理應用，核心定位是：
- 透過外部影片規則與插件抓取播放來源
- 管理動漫收藏、播放歷史與下載
- 整合 Bangumi 等元資料來源
- 提供桌面與行動裝置端使用

這個專案實際上是以 Kazumi 專案為基礎的 Flutter 應用，目錄結構已經相當清楚地拆成「頁面層」、「服務層」、「資料模型層」與「網路層」。

---

## 2. 系統結構總覽

### 2.1 啟動與應用入口

- [lib/main.dart](../lib/main.dart)  
  應用啟動入口，初始化 Flutter、MediaKit、Hive、視窗管理與權限相關服務。

- [lib/app_widget.dart](../lib/app_widget.dart)  
  定義全域 MaterialApp 與主題設定，包含主題、字體、路由與多語系基礎配置。

- [lib/app_module.dart](../lib/app_module.dart)  
  註冊全域模組與路由模組。

- [lib/core_module.dart](../lib/core_module.dart)  
  註冊跨功能共用的控制器、服務與資料倉儲。

### 2.2 路由與頁面層

- [lib/pages/](../lib/pages)  
  完整的 UI 模組集合，依據功能切分為：
  - popular：熱門/推薦頁
  - timeline：時間表頁
  - collect：收藏頁
  - history：歷史記錄頁
  - info：動漫詳情頁
  - video：播放頁
  - search：搜尋頁
  - settings：設定頁
  - my：使用者主頁與偏好設定

其中最重要的幾個頁面是：
- [lib/pages/info/info_module.dart](../lib/pages/info/info_module.dart)
- [lib/pages/collect/collect_controller.dart](../lib/pages/collect/collect_controller.dart)
- [lib/pages/history/history_controller.dart](../lib/pages/history/history_controller.dart)
- [lib/pages/my/my_controller.dart](../lib/pages/my/my_controller.dart)
- [lib/pages/settings/interface_settings.dart](../lib/pages/settings/interface_settings.dart)

### 2.3 服務層（Services）

- [lib/services/storage/](../lib/services/storage)  
  負責本機持久化與設定管理，核心是 Hive 與設定鍵值。
  - [lib/services/storage/storage.dart](../lib/services/storage/storage.dart)
  - [lib/services/storage/settings_keys.dart](../lib/services/storage/settings_keys.dart)

- [lib/services/sync/](../lib/services/sync)  
  同步服務模組，現階段已經有 Bangumi 同步邏輯。
  - [lib/services/sync/bangumi_sync_service.dart](../lib/services/sync/bangumi_sync_service.dart)
  - [lib/services/sync/history_sync_service.dart](../lib/services/sync/history_sync_service.dart)

- [lib/services/player/](../lib/services/player)  
  播放相關控制器與播放狀態邏輯。

- [lib/services/network/](../lib/services/network)  
  網路請求與代理相關邏輯。

- [lib/services/download/](../lib/services/download)  
  下載管理與下載記錄。

### 2.4 資料模型與領域模型

- [lib/modules/](../lib/modules)  
  定義核心 domain model，例如：
  - [lib/modules/bangumi/bangumi_item.dart](../lib/modules/bangumi/bangumi_item.dart)  
    番劇資料模型，包含標題、簡介、評分、圖片、標籤等。
  - [lib/modules/history/history_module.dart](../lib/modules/history/history_module.dart)  
    播放歷史與進度模型。
  - [lib/modules/collect/collect_module.dart](../lib/modules/collect/collect_module.dart)  
    收藏資料模型。

### 2.5 資料存取層（Repositories）

- [lib/repositories/](../lib/repositories)  
  提供對 Hive 與內部資料的抽象封裝：
  - [lib/repositories/history_repository.dart](../lib/repositories/history_repository.dart)
  - [lib/repositories/collect_repository.dart](../lib/repositories/collect_repository.dart)
  - [lib/repositories/collect_crud_repository.dart](../lib/repositories/collect_crud_repository.dart)

這一層是目前最適合掛接「MyAnimeList 同步」與「本地觀看進度匯出」的介面。

### 2.6 請求與 API 層

- [lib/request/](../lib/request)  
  包含 API client、端點設定與資料解析。
  - [lib/request/config/api_endpoints.dart](../lib/request/config/api_endpoints.dart)
  - [lib/request/apis/bangumi_api.dart](../lib/request/apis/bangumi_api.dart)
  - [lib/request/clients/bangumi_client.dart](../lib/request/clients/bangumi_client.dart)

目前已經具備 Bangumi API 的整合，這對新增 MyAnimeList 同步來說非常有利，因為架構上可以直接沿用同樣的「service → api → repository → UI」模式。

### 2.7 插件與來源系統

- [lib/plugins/](../lib/plugins)  
  提供規則式插件系統。這是專案的核心能力之一：
  - 支援配置播放源、搜尋規則與解析邏輯
  - 支援影片來源與元資料來源的擴充

這部分對「繁體中文化」而言，雖然不直接負責 UI 文案，但會影響來源內容與標題顯示的多語資料取得。

---

## 3. 主要資料流

### 3.1 番劇瀏覽與詳情

1. 使用者進入動漫列表或搜尋頁。
2. 控制器呼叫 API / plugin 取得資料。
3. 資料解析為 BangumiItem 等 model。
4. 頁面渲染成卡片或詳情資訊。

### 3.2 收藏與歷史

1. 播放完畢或切換集數時，HistoryRepository 記錄觀看進度。
2. 進度資訊存入 Hive。
3. 若啟用同步服務，會新增同步事件或呼叫同步服務。

### 3.3 設定與偏好

1. 設定頁修改設定。
2. 資料寫入 GStorage / Hive。
3. 相關 UI 與服務根據設定動態切換。

---

## 4. 適合擴展的新功能接點

### 4.1 MyAnimeList 同步的最適合接點

最適合接入的地方有三個：
1. 觀看歷史與播放進度更新流程  
   這是最自然的同步入口，因為專案已經有完整的 HistoryRepository 與 HistoryController。

2. 收藏與評分狀態管理流程  
   這裡已經有 CollectController 與 collect model，適合建立與 MAL 狀態的對應。

3. 動漫詳情頁  
   可以在詳情頁提供「同步到 MyAnimeList」或「標記評分」的操作入口。

### 4.2 繁體中文化的最適合接點

最適合接入的地方有兩個：
1. UI 文案層  
   目前頁面中存在大量硬編碼字串，這需要逐步改造成多語系資源。

2. 動畫資料顯示層  
   例如 BangumiItem 的 title / summary / info，應該在顯示前依照目前語系做格式化或轉換。

---

## 5. 功能擴充執行計畫 A：與 MyAnimeList 同步個人觀看進度與評分

### 5.1 目標

新增一套 MyAnimeList 同步流程，支援：
- 使用者登入與授權
- 同步觀看進度（watching / completed / dropped 等）
- 同步個人評分
- 將本地收藏狀態與 MAL 狀態對齊

### 5.2 建議實作策略

建議先採用「單向同步」版本：
- 本地資料更新時，推送到 MyAnimeList
- 先不做複雜的雙向衝突合併

這樣可以先把流程打通，再逐步升級為雙向同步。

### 5.3 詳細步驟

#### Step 1：新增 MyAnimeList 認證與設定

需求：
- 使用者需註冊 MyAnimeList 開發者應用
- 取得 Client ID 與 Redirect URI
- 以 OAuth 2.0 或 Access Token 方式做登入

實作內容：
- 在 [lib/services/storage/settings_keys.dart](../lib/services/storage/settings_keys.dart) 新增設定鍵：
  - malAccessToken
  - malRefreshToken
  - malUsername
  - malEnabled
  - malAutoSyncEnabled
- 在設定頁新增「MyAnimeList 設定」入口
- 建議使用安全儲存（如 Flutter Secure Storage）或至少加密後寫入本機

#### Step 2：建立 MAL API 服務層

新增檔案建議：
- [lib/request/apis/mal_api.dart](../lib/request/apis/mal_api.dart)
- [lib/request/clients/mal_client.dart](../lib/request/clients/mal_client.dart)
- [lib/services/sync/mal_sync_service.dart](../lib/services/sync/mal_sync_service.dart)

功能包含：
- 取得目前使用者資訊
- 更新動畫狀態
- 更新評分
- 取得動畫詳細資訊
- 取得使用者觀看列表

#### Step 3：建立本地對應模型

目前專案的核心資料是 [lib/modules/bangumi/bangumi_item.dart](../lib/modules/bangumi/bangumi_item.dart)。
MAL 需要獨立的 anime ID，因此需要新增一層對應：
- 本地動畫項目 → MAL anime ID 的映射
- 建議做法：
  - 在 BangumiItem 中增加可選欄位 `malId`
  - 或建立單獨的 mapping table / Hive box

建議優先使用：
- `malId` 欄位（最簡單，最容易與現有資料流接上）

#### Step 4：接到播放歷史流程

這是最重要的一步：
- 當使用者播放進度更新時，HistoryRepository 會寫入進度
- 在這個寫入點後，觸發 MAL 同步

建議條件：
- 進度大於 80% 時，標記為 completed
- 進度大於 0 且小於 80%，標記為 watching
- 進度為 0 或清除歷史時，移除/重設同步

#### Step 5：接到收藏與評分流程

在收藏狀態變更時：
- 將本地收藏類型映射為 MAL 狀態：
  - 想看 → plan_to_watch
  - 在看 → watching
  - 完結 → completed
  - 拋棄 → dropped

在評分入口上：
- 在詳情頁或收藏頁新增「評分」按鈕
- 評分值映射到 MAL 的 `score` 欄位（通常為 1–10）

#### Step 6：增加排程與重試機制

需求：
- 避免 API 限流
- 避免重複同步
- 讓離線或失敗時能重試

建議：
- 使用本地 queue / pending job 機制
- 失敗後延遲重試
- 針對 429 或 5xx 做退避策略

#### Step 7：新增 UI 與使用者回饋

在設定頁與詳情頁新增：
- 啟用/停用 MAL 同步
- 登入狀態顯示
- 手動同步按鈕
- 同步成功/失敗 Toast

### 5.4 需求與風險

必要需求：
- MyAnimeList 開發者帳戶與 OAuth 配置
- 需要穩定的網路與 API 存取
- 需要安全儲存 token
- 需要明確的動畫 ID 對應規則

風險：
- 標題比對不準，導致錯配動畫
- MAL API 限流造成同步失敗
- 需要處理不同版本的 anime 名稱與別名

建議的第一版範圍：
- 只支援「從本地狀態同步到 MAL」
- 不做完整雙向衝突解決

---

## 6. 功能擴充執行計畫 B：繁體中文化界面與動畫資料內容

### 6.1 目標

支援繁體中文介面，並讓動畫標題、簡介、資訊等內容在使用者選擇繁體中文語系時顯示為繁體。

### 6.2 建議實作策略

建議分兩層做：
1. 介面層本地化（UI 文案）
2. 內容層本地化（動畫標題與資料內容）

這兩層可以分階段完成，先把 UI 先做好，再做資料內容。

### 6.3 詳細步驟

#### Step 1：啟用多語系支援

目前 [lib/app_widget.dart](../lib/app_widget.dart) 和 [lib/main.dart](../lib/main.dart) 只設定了簡體中文語系，這是第一個需要改的點。

實作內容：
- 新增 `zh_TW` / `zh_Hant` 語系支援
- 啟用 Flutter localization 生成流程
- 建立 ARB 檔案，例如：
  - `lib/l10n/app_zh.arb`
  - `lib/l10n/app_zh_Hant.arb`

#### Step 2：將硬編碼字串改為多語系資源

目前專案在頁面中存在多個硬編碼字串，例如：
- 設定頁標題
- 按鈕文字
- Toast 訊息
- 錯誤提示

建議把這些逐步替換為 `AppLocalizations` 文字鍵。

#### Step 3：建立內容翻譯/轉換層

對於動畫標題與資訊，建議不要直接把所有內容散落在各個頁面裡做轉換，而是建立一層「顯示前轉換」邏輯：
- 在顯示前，根據目前語系選擇適當欄位
- 若資料來源提供了繁體欄位，優先使用
- 否則使用簡體/原始欄位，並做簡化繁簡轉換

建議實作位置：
- [lib/modules/bangumi/bangumi_item.dart](../lib/modules/bangumi/bangumi_item.dart)
- 或在 UI 層新增一個 `LocalizedBangumiDisplay` helper

#### Step 4：資料來源層補上繁體內容來源

如果 API 提供了不同語系欄位：
- 優先使用 `name_cn` / `nameCN` / 繁體欄位
- 若沒有，則使用 fallback

若資料來源本身沒有繁體內容，則有兩種可選策略：
1. 內建繁簡轉換字典（較快、可離線）
2. 外部翻譯服務（更準確，但需要 API 與額外成本）

建議第一版優先採用 1，第二版再加上 2。

#### Step 5：在 UI 上提供語系切換

建議在設定頁新增：
- 語言選單（中文簡體 / 中文繁體 / English）
- 立即生效，不需重啟應用

#### Step 6：補上測試與回退邏輯

每個頁面都要確認：
- 語系切換後標題與說明正確顯示
- 缺少繁體內容時能優雅 fallback
- 無法取得資料時不會造成 UI 崩潰

### 6.4 需求與風險

必要需求：
- 需要建立本地化資源檔
- 需要整理所有硬編碼字串
- 需要決定繁簡轉換策略

風險：
- 目前許多 UI 文案仍是硬編碼，改造工作量較大
- 某些動畫資訊來源本身沒有繁體資料
- 需要避免讓本地化流程破壞既有資料模型

建議的第一版範圍：
- 先完成 UI 文案繁體化
- 再完成動畫標題與簡介的繁體化顯示

---

## 7. 建議的實作順序

### Phase 1：基礎整理（1–2 週）
- 建立多語系框架
- 讓設定頁與主要頁面支援繁體中文
- 補上預設的語系切換與 fallback

### Phase 2：動畫資料本地化（1–2 週）
- 建立內容顯示轉換層
- 為 BangumiItem / metadata 顯示增補繁體內容
- 加上簡繁轉換與 fallback

### Phase 3：MyAnimeList 同步基礎（2–3 週）
- 建立 MAL 認證與 API client
- 新增本地映射與設定
- 接到收藏與評分流程

### Phase 4：進度同步與排程（1–2 週）
- 接到播放歷史流程
- 支援排程重試與失敗回退
- 完成使用者回饋與錯誤處理

---

## 8. 建議的最小可行版本（MVP）

如果你想先快速上線，建議 MVP 先做：

### MyAnimeList MVP
- 使用者登入
- 同步收藏狀態與評分
- 同步觀看進度（簡化版）
- 不做完整雙向合併

### 繁體中文化 MVP
- 先把主要設定頁、收藏頁、詳情頁的文案改成繁體
- 先讓動畫標題、簡介、資訊的顯示支援繁體內容優先

---

## 9. 結論

這個專案目前已經具備相當好的擴充基礎：
- 有清楚的頁面與服務分層
- 已有 Bangumi 同步與歷史進度模型
- 已有 Hive 持久化與設定系統
- 已有插件型資料來源架構

因此，新增「MyAnimeList 同步」與「繁體中文化」是可行的，而且可以沿用現有架構模式，避免從零重建。

如果要執行，最好的思路是：
- 先完成繁體中文化基礎，因為它屬於較穩定且可分階段落地的改造
- 再完成 MyAnimeList 同步，因為它需要更多 API、認證與映射邏輯
