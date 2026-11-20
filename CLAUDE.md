# CLAUDE.md —《金毛騎士》原型

目前從 [草稿 PR #18](https://github.com/QuantumPrediction/DoggyKnight/pull/18) 的 `codex/scene-resource-lifetime` 接續。遊戲現已按場地回收特效，修正淡出期間配樂持續播放，並提供獨立存檔的弓手 1-4 真人試玩場景。最新結果與待驗收項目見 [整合狀態](docs/PROJECT_STATE.md) 及 [重現紀錄](docs/validation/scene-lifetime/README.md)。

目前接續入口為 `docs/PROJECT_STATE.md`。0.9.1 在已合併的 0.9.0 上處理戰鬥提示、弓兵預警一致性與測試生命週期；跨線整合合約為 `docs/requests/20261120-INT-combat-readability.md`。不新增下載包、不改存檔／平衡數值；原生崩潰與真人品質驗證仍是待辦。

2026-11-20 R01／R02 接續：擁有人要求持續反覆改進。當前跨線合約為 `docs/requests/20261120-INT-pressure-lifetime.md`，以計畫 PR #15 為基礎；新增壓力觀察／第二走位政策及流程生命週期診斷，修正已離開場景的護陣教學回呼仍會改狀態／寫入舊檢查點的問題。此工作未改平衡數值或存檔格式，不代表原生崩潰已修復；公開分支及實際結果以接續入口為準。

這是一款像素風手機 RPG 的原型:金毛尋回犬騎士帶著同伴打小怪、升級、打頭目。**最終目標是上架 App Store(iOS)與 Google Play(Android)。** 原型階段不公開上架,但一切按手機與商店的標準來做。完整計劃在 `docs/DEV_PLAN.md`,**動手前先讀它**;商店規定在 `docs/STORE_RELEASE.md`。

## Windows 接手補充（2026-11-18）

擁有人已要求接手本 repo 並提供 Windows `.exe`，後續研究 Steam 版本。`codex/windows-playtest` 是整合分支，可修改桌面輸入、教學、匯出及相應測試所需的跨線檔案；本輪保留觸控與手機路徑。這項授權補充早期「只做手機」的範圍，詳見 `docs/WINDOWS_HANDOVER.md`。引擎仍固定為 4.7.2。

## 繪本美術重製補充（2026-11-18）

擁有人已要求完整重新設計並整合遊戲美術。本輪以整合工作跨越美術、UI、營地與匯出，使用繪本插畫和高解析度字型；原像素限制已由這項要求補充。邏輯座標和玩法合約保留，渲染改為 `canvas_items`，詳見 `docs/ART_REDESIGN.md`。

## 職業、配樂與文字設計補充（2026-11-19）

擁有人已要求加入法師與弓箭手選角、重新設計背景音樂和字體，並測試遊戲體驗。`codex/music-classes-type` 接續美術整合分支，可修改相關跨線檔案、職業基準與存檔 v7。本輪明確不匯出新版遊戲。詳見 `docs/requests/20261119-INT-classes-score-contract.md` 及 `docs/MUSIC_CLASSES_TYPOGRAPHY.md`。

## 裝備與檢查點補充（2026-11-19）

擁有人已要求繼續開發並加入普通上限 5 級、史詩上限 9 級的武器、護甲、寶物，頭目掉落與金幣／寶石商城。此為跨線整合，早期不做商店的範圍由本次要求補充。真實付款仍未接通；採平台支付介面，不加入自行收款或授權客戶端發放付費幣。詳見 `docs/requests/20261119-INT-equipment-checkpoints.md`。

## 你是哪一條線

擁有人會在開場指示中告訴你是 Phase 0、A、B、C、D、整合還是上架(M4)。只做那一線的任務。

## 不可違反的規則

1. 只修改自己擁有的目錄(`docs/DEV_PLAN.md` 第 3 節)。
2. 除了 Phase 0 與整合工作階段,不得修改 `project.godot`、`core/`、`CLAUDE.md`、`docs/DEV_PLAN.md`、`docs/STORE_RELEASE.md`、`tools/run_tests.sh`。
3. 跨線溝通只走 `EventBus` 訊號與 `core/` 內的資料類別。
4. 需要改合約時,新增 `docs/requests/YYYYMMDD-<線>-<主題>.md`,不要自己改。
5. 不做 `docs/DEV_PLAN.md` 第 1 節「不包含」的任何東西。
6. 狗不會受傷:失敗與受擊表現一律可愛,不得有血或受傷畫面。
7. 可調的數值放在資料檔,不寫死。
8. 不安裝第三方外掛。
9. 手機優先:只用觸控、直向操作;介面避開安全區以外的地方;切到背景時要暫停並存檔(`docs/DEV_PLAN.md` 第 2、4.8 節)。
10. 不連網、不收集任何個人資料或裝置識別碼。
11. 金鑰、憑證、密碼一律不得提交到 repo。
12. 外部素材使用前核對授權,記錄在 `docs/licenses.md`。

## 工作方式

- 分支:`line-a/combat`、`line-b/flow`、`line-c/art-ui`、`line-d/camp-mobile`。
- 提交訊息以 `[A]`、`[B]`、`[C]`、`[D]`、`[P0]`、`[INT]` 開頭;小步提交並推送。
- 開 PR 前執行 `tools/run_tests.sh`,全部通過才開。
- 每次收工更新 `docs/status/LINE_X.md`:已完成 / 進行中 / 被甚麼卡住 / 下一步 / 需要擁有人決定的事。
- 擁有人不會寫程式。回報時用淺白的中文說明做了甚麼、怎樣試玩、有甚麼需要擁有人決定。

## 技術

- 平台:Android(Google Play,AAB)與 iOS(App Store,只支援 iPhone)。商店的版本要求見 `docs/STORE_RELEASE.md`。
- 引擎:**Godot 4.7.2 stable**(`4.7.2.stable.official.ed1daf0bf`)。四條線不得升級;只有整合工作階段可在擁有人同意下,為符合商店新規定而升級。已核對:此版本的 Android 建置預設 target API 36、min API 24、NDK r29(支援 16 KB 分頁)。
- 算繪器:**Compatibility**(`gl_compatibility`,桌面與手機相同)。
- GDScript,全部加型別標註。
- 直向鎖定;遊戲區 180×320,整數倍放大,向外延伸填滿螢幕,像素不平滑。座標約定見 `core/safe_area.gd` 開頭的說明。
- 測試指令:`tools/run_tests.sh`(全部);`tools/run_tests.sh line_a`(只跑路徑含 `line_a` 的測試)。測試檔命名 `test_*.gd`,`extends TestCase`,範例在 `tests/core/test_example.gd`。
- 執行遊戲:`godot --path .`(主場景是 B 線的正式流程 `game/flow/main.tscn`)。從頭到尾自動試玩:`godot --headless --path . res://tests/integration/playthrough_bot.tscn`。整合狀況見 `docs/integration_report.md`。
- 雲端工作階段沒有 Godot 時,這樣安裝:

  ```bash
  mkdir -p /opt/godot && cd /opt/godot && curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -q godot.zip && rm godot.zip && ln -sf /opt/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
  ```

- 需要建置 Android 版時:先執行 `tools/install_android_tooling.sh`(安裝匯出範本與 Android SDK,需要 dl.google.com 與 github.com 的網絡權限),再照 `export/README.md`。
- 需要截圖時:`xvfb-run -a godot --path . --rendering-driver opengl3`(雲端環境有 Xvfb 與軟體 OpenGL)。注意 Xvfb 沒有視窗管理員,改變視窗大小時要同時設定 `get_tree().root.size`。

## 0.8.0 整合接續（2026-11-20）

擁有人把主開發移回此對話，要求繼續提高完整遊戲品質。本輪接續完整 0.4–0.7 歷史，可跨戰鬥、HUD、流程、存檔、原創圖示、驗證與 Windows 匯出工作；合約為 `docs/requests/20261120-INT-guard-learning.md`。歷史 0.3 輪次的「不匯出新版」不是本輪限制。最新入口仍為 `docs/PROJECT_STATE.md`；不得從測試通過宣稱真人9/10或人氣保證。

## 0.8.1 整合接續（2026-11-20）

擁有人要求繼續既有工作；接續完整 0.8.0，處理近戰預警／命中一致性、隊長援兵上限、實際裝備打斷互動及對照驗證。合約為 `docs/requests/20261120-INT-captain-fairness.md`。沿用跨線整合與新版 Windows 試玩範圍，無新存檔或 EventBus 合約。

## 0.9.0 整合接續（2026-11-20）

擁有人在當前對話直接批准程式、素材、文件、測試及截圖公開至 QuantumPrediction/DoggyKnight 並建立草稿 PR，要求繼續品質工作。0.8.1 已公開為 PR #12。這輪合約 `docs/requests/20261120-INT-build-routes.md` 允許跨流程、進度、UI、資料及存檔整合；新增 `GameState.run_route`，存檔 v11，沿用既有 EventBus 訊號。擁有人要求除非主動索取，不再製作／上傳下載包、獨立進度報告或復原 ZIP；成果保存在儲存庫，回覆保持簡短。最新狀態仍以 `docs/PROJECT_STATE.md` 為準。
