# 開場指示(逐段貼給 Claude Code)

每一段貼給一個獨立的工作階段。次序:先 Phase 0;Phase 0 合併後才同時開 A、B、C、D;四條線到達 M1 後才開整合;擁有人決定上架後才開 M4。

---

## Phase 0(一個工作階段,先做)

```
你負責《金毛騎士》原型的 Phase 0(地基)。請先讀 CLAUDE.md、docs/DEV_PLAN.md 全文和 docs/STORE_RELEASE.md。這款遊戲最終要上架 App Store 與 Google Play。

任務:
1. 安裝或確認 Godot 4 穩定版(建議 4.7.x)。確認它能匯出 target API 36 的 Android AAB,並支援 16 KB 記憶體分頁(DEV_PLAN 第 2 節)。把版本號、算繪器與 headless 測試指令寫進 CLAUDE.md 的空格。
2. 建立 Godot 專案:直向鎖定;遊戲區 180×320;整數倍放大;stretch aspect 用 expand;像素不平滑;算繪器建議 Compatibility;返回鍵不會直接退出遊戲。按 DEV_PLAN 第 3 節建立全部目錄。
3. 實作 DEV_PLAN 第 4 節的全部合約:EventBus(含暫停與手機生命週期訊號)、GameState、core/data/ 內的資料類別、碰撞圖層名稱、輸入設定、core/app_lifecycle.gd、core/safe_area.gd(第 4.8 節)。
4. 為 goldie、bulldog、scarecrow、crow、black_knight 建立純色方塊的佔位圖與 SpriteFrames,路徑與動畫名稱完全依照 4.6。
5. 建立最小可執行的場景:佔位金毛在空場地中可以用滑鼠拖曳移動(只為證明專案能跑,A 線之後會重寫)。
6. 建立 tools/run_tests.sh:以 headless 模式執行 tests/ 下所有測試腳本,任何一個失敗就回傳非零。放一個示範測試,另加一個測試確認 app_lifecycle 會發出正確訊號。
7. 建立 docs/status/ 與 docs/requests/,各放一個說明檔;建立 docs/status/LINE_A.md 至 LINE_D.md 的空白範本;建立 docs/licenses.md,先記錄 Godot 引擎本身的授權。
8. 加上適合 Godot 的 .gitignore。必須排除 .godot/(內含匯出密碼)、金鑰與憑證(*.keystore、*.jks、*.p12、*.mobileprovision、*.cer)、匯出產生的安裝檔(*.apk、*.aab、*.ipa)。

完成條件(DEV_PLAN 第 6 節 M0):專案可以開啟並執行;run_tests.sh 通過。
完成後開 PR 到 main,並用淺白的中文告訴我:做了甚麼、怎樣開啟專案試一下、合約有沒有你認為需要補充的地方(只提出,不要自行擴充範圍)。
```

---

## A 線:戰鬥核心

```
你是《金毛騎士》原型的 A 線(戰鬥核心)。請先讀 CLAUDE.md,以及 docs/DEV_PLAN.md 的第 1 至 5 節和第 8 節。這是一款要上架的手機遊戲:只有觸控、直向單手玩。

從 main 開分支 line-a/combat。只修改 A 線擁有的目錄。
按第 8 節的任務 A1 至 A12 依序進行,優先完成 A1、A2、A4、A5,做到可以試玩就先推送並告訴我怎樣試玩,因為手感是整個原型最重要的部分。
需要 B、C、D 線的東西時,在 tests/line_a/ 做替身,不要等。
每完成一個任務就提交;收工時更新 docs/status/LINE_A.md。到達「M1 驗收」後開 PR。
```

---

## B 線:關卡流程與成長

```
你是《金毛騎士》原型的 B 線(關卡流程與成長)。請先讀 CLAUDE.md,以及 docs/DEV_PLAN.md 的第 1 至 5 節和第 9 節。這是一款要上架的手機遊戲:玩家隨時可能被來電或通知打斷,進度不可遺失。

從 main 開分支 line-b/flow。只修改 B 線擁有的目錄。
按第 9 節的任務 B1 至 B10 依序進行。A 線的戰鬥場地與敵人還沒完成,請在 tests/line_b/ 做一個實作相同方法的假場地與假敵人來開發和測試。
每完成一個任務就提交;收工時更新 docs/status/LINE_B.md。到達「M1 驗收」後開 PR。
```

---

## C 線:像素美術、介面與音效

```
你是《金毛騎士》原型的 C 線(像素美術、介面與音效)。請先讀 CLAUDE.md,以及 docs/DEV_PLAN.md 的第 1 至 5 節和第 10 節。這是一款要上架的手機遊戲:介面要避開瀏海與挖孔,按鈕要大得可以用拇指按。

從 main 開分支 line-c/art-ui。只修改 C 線擁有的目錄。
按第 10 節的任務 C1 至 C13 進行。先做 C1(生成工具)和 C2(金毛),完成後把金毛的動畫截圖或 GIF 給我看,我確認風格後再畫其他角色和 App 圖示(C13)。
替換佔位圖時不得改變路徑與動畫名稱。任何外部素材與字型都要先核對授權並記錄在 docs/licenses.md。
每完成一個任務就提交;收工時更新 docs/status/LINE_C.md。到達「M1 驗收」後開 PR。
```

---

## D 線:營地、小遊戲與手機建置

```
你是《金毛騎士》原型的 D 線(營地、小遊戲與手機建置)。請先讀 CLAUDE.md、docs/DEV_PLAN.md 的第 1 至 5 節和第 11 節,以及 docs/STORE_RELEASE.md。這款遊戲最終要上架 App Store 與 Google Play。

從 main 開分支 line-d/camp-mobile。只修改 D 線擁有的目錄。
按第 11 節的任務 D1 至 D11 進行。先做 D2(拉扯王室卷軸)到可以試玩,再做營地與其他項目。D6(Android 匯出)與 D10(iOS 匯出說明)請盡早開始,列出需要我在電腦上安裝或提供的東西,以及需要我在 Google Play Console 和 Apple 開發者網站上做的事。
需要修改專案設定時,寫申請到 docs/requests/,不要自己改 project.godot。
每完成一個任務就提交;收工時更新 docs/status/LINE_D.md。到達「M1 驗收」後開 PR。
```

---

## 整合(四條線都到達 M1 之後)

```
你是《金毛騎士》原型的整合工作階段。請先讀 CLAUDE.md、docs/DEV_PLAN.md 全文、docs/STORE_RELEASE.md、docs/status/ 下四條線的報告,以及 docs/requests/ 下的申請。

任務:
1. 按 DEV_PLAN 第 7 節的次序(A、B、C、D)把四條線接成完整流程:標題 → 六關 → 營地 → 黑騎士。
2. 處理我已同意的合約變更申請(我會告訴你哪些同意)。只有你可以修改 core/ 與 project.godot。
3. 接線時發現某一線的錯誤,記錄在 docs/integration_report.md 並指明由哪一線修;簡單的接縫問題可以直接修。
4. 達到 M2 後告訴我怎樣在電腦上從頭玩到尾,然後再進行 M3:做出可以上傳 Google Play 封閉測試的 AAB(有 Mac 的話也做 TestFlight 建置),一步一步告訴我怎樣上傳和邀請測試者,然後根據試玩意見調整手感與難度。
```

---

## 上架準備(M4,擁有人決定上架之後)

```
你是《金毛騎士》的上架工作階段。請先讀 CLAUDE.md、docs/DEV_PLAN.md 第 14 節、docs/STORE_RELEASE.md、docs/integration_report.md,以及 store/ 內的草稿。

任務:
1. 按 docs/STORE_RELEASE.md 第 5 節的官方連結,重新核對兩家商店的現行規定,更新該文件(含核對日期)。規定有變而需要升級 Godot 的話,先告訴我原因與影響,等我同意。
2. 我會告訴你 DEV_PLAN 第 14 節四件事的決定。依決定更新 store/ 內的隱私權政策、問卷答案與商店說明。
3. 照 docs/STORE_RELEASE.md 第 3 節的清單逐項檢查,做不到的列出來。
4. 用淺白的中文一步一步告訴我在 Play Console 和 App Store Connect 要按哪裡、填甚麼,直到送審。
```

---

## 每天繼續工作時(任何一線)

```
請讀 docs/status/LINE_X.md 與 docs/DEV_PLAN.md 中你那一線的章節,把 main 合併進你的分支,然後從「下一步」繼續。收工前更新 status 檔並推送。
```
