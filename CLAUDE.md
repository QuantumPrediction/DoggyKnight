# CLAUDE.md —《金毛騎士》原型

這是一款像素風手機 RPG 的原型:金毛尋回犬騎士帶著同伴打小怪、升級、打頭目。**最終目標是上架 App Store(iOS)與 Google Play(Android)。** 原型階段不公開上架,但一切按手機與商店的標準來做。完整計劃在 `docs/DEV_PLAN.md`,**動手前先讀它**;商店規定在 `docs/STORE_RELEASE.md`。

## Windows 接手補充（2026-11-18）

擁有人已要求接手本 repo 並提供 Windows `.exe`，後續研究 Steam 版本。`codex/windows-playtest` 是整合分支，可修改桌面輸入、教學、匯出及相應測試所需的跨線檔案；本輪保留觸控與手機路徑。這項授權補充早期「只做手機」的範圍，詳見 `docs/WINDOWS_HANDOVER.md`。引擎仍固定為 4.7.2。

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
