# D 線(營地、小遊戲與手機建置)狀態報告

最後更新:2026-11-15(第一次收工,D1 至 D11 全部完成第一版)

## 怎樣試玩(不用寫程式)

1. 用 Godot 4.7.2 開啟專案,在左下角的「檔案系統」打開 `tests/line_d/camp_sandbox.tscn`,按右上角「執行目前場景」(或 F6)。
2. 按「進入營地」:會看到夜裡的營火、圓桌、趴著搖尾巴的金毛(目前是佔位方塊),和三個按鈕。活力先被設為 40,方便看到回復。
3. 按「拉扯王室卷軸」:倒數 3 秒時有一隻手示範「向下滑」。用滑鼠在下半部**按住往下拖**,卷軸就會被拉出來。
   墨水漬靠近金毛的嘴巴時,金毛頭上出現「!」;到達時出現紅色的手掌,**停手一下**墨水漬就會滑過去;還在滑的話金毛的臉會沾到墨水,並扣 1.5 秒。
4. 15 秒後金毛被卷軸纏住,接著顯示星星、評價與獎勵。點一下回到營地,活力條與滿意度條會增加。
5. 「同伴」顯示「即將開放」;「繼續冒險」離開營地(畫面回到測試選單,主控台會印出所有訊號)。
6. 測試選單另有「壓力測試(40 隻敵人)」與「模擬瀏海」。玩小遊戲時讓視窗失去焦點(點別的視窗)= 模擬切到背景,遊戲會暫停,回來點一下繼續。

想在 Android 手機上試:照 `export/README.md` 匯出「Android Sandbox」(App 名稱「金毛騎士(D線測試)」),開機就是上面的測試選單。

## 已完成

- **D1 營地**:`game/camp/camp.tscn`。夜空、圓桌、營火(會跳動)、金毛趴著搖尾巴、活力與滿意度條、三個入口。進入時發 `camp_entered`,按「繼續冒險」發 `camp_left`。外觀與數值都在 `game/camp/camp_config.tres`,C 線可以直接填入正式圖。各種螢幕大小都會填滿畫面並重新排版。
- **D2 拉扯王室卷軸**:`game/minigames/scroll/`。不用文字也看得懂(手勢動畫、向下箭頭、「!」、紅色手掌、停手進度圈)。滑動範圍離螢幕底邊至少 24 邏輯像素,不會誤觸「回到主畫面」手勢。音效呼叫 `scroll`、`ink`。
- **D3 評分與獎勵**:`game/minigames/scroll/scroll_grading.tres`。拉出 80 / 160 / 240 公分分別是 1 / 2 / 3 顆星。活力回復上限的 25% / 50% / 75% / 100%(不超過上限),滿意度 +5 / +10 / +20 / +30(0 至 100),下一關攻擊 +0% / 5% / 10% / 15%。先更新 GameState,再發 `minigame_finished`。
- **D4 小遊戲框架**:`game/minigames/minigame_base.gd`。倒數、計時、切到背景暫停(計時停止,點一下繼續)、結束、評價畫面。之後加「大胃王」只要繼承它(原型沒做大胃王)。
- **D5 螢幕適配**:在 16:9、19.5:9、20:9、iPhone 15、iPhone Pro Max、iPhone SE 與模擬瀏海下截圖檢查,營地與小遊戲都填滿畫面、沒有被遮住。需要的專案設定已寫成申請(見下方)。
- **D6 Android 匯出**:`export_presets.cfg`(Android、Android AAB、Android Sandbox、iOS)。已在雲端**實際做出**可安裝的除錯版 APK 與 AAB:target API 36、min API 24、不要求任何權限、64 位元程式庫支援 16 KB 分頁。步驟寫在 `export/README.md`(標明已驗證與未驗證)。建置指令:`export/build_android.sh debug|sandbox|aab|verify`。
- **D7 平台介面**:`platform/ads.gd`、`iap.gd`、`analytics.gd`,全部是只印記錄的空實作,不連網。`platform/README.md` 說明日後接真實服務時的隱私問卷、追蹤授權與家庭政策。
- **D8 遊玩記錄**:`platform/play_log.gd`,每關一行記錄(用時、勝負、把戲)存在手機本機的 `playlog.jsonl`,沒有識別碼、不上傳。需要整合工作階段註冊為 Autoload(已申請)。
- **D9 壓力測試**:`tests/line_d/stress_test.tscn`,40 隻會動、會互相推擠的敵人,左上角顯示 FPS。雲端的數字(軟體算繪,**不能代表手機**):Xvfb + llvmpipe 平均約 263 FPS(不鎖 60),腳本與物理合計每格約 1.9 毫秒(無畫面模式量到:處理 0.6 毫秒、物理 1.2 毫秒)。要在中階 Android 手機上用「Android Sandbox」實測。
- **D10 iOS**:「iOS」匯出設定(只支援 iPhone、直向、Team ID 留空)。在 Linux 上試過:填入 Team ID 後可以產生 Xcode 專案,但做不出 `.ipa`(要 Mac)。`export/IOS.md` 寫了 Mac + Xcode 26 的步驟、TestFlight、沒有 Mac 的替代方案;範例工作流程在 `export/ci/ios-testflight.yml`(未驗證,未啟用)。
- **D11 商店草稿**:`store/` 內有商店說明、隱私權政策(不收集資料)、Google Play 資料安全、Apple App 隱私、內容分級的建議答案,以及自動截圖腳本(輸出 1080×1920、1290×2796、1320×2868)。
- **沙盒與測試**:`tests/line_d/camp_sandbox.tscn`(進營地、玩、拿評價、離開)。自動化測試 45 個(評分、獎勵上下限、切到背景暫停、營地訊號、遊玩記錄、匯出設定),全部 82 個測試通過。

## 進行中

- (無)

## 被甚麼卡住

- **核心的小問題(已申請,不影響 D 線)**:視窗縮小但邏輯畫面不變時,`ScreenFit` 不會重新計算,可能出現大片黑邊(摺疊手機、分割畫面)。申請:`docs/requests/20261115-D-screenfit-shrink.md`。
- **給 B 線的提醒**(不是錯誤,接線時注意):
  - 營地畫在第 15 層 CanvasLayer,會蓋住 HUD(第 10 層),不會蓋住暫停選單(第 20 層)。B 線不需要特別隱藏 HUD。
  - 在營地與小遊戲中按返回鍵時,建議 B 線照樣打開暫停選單(`get_tree().paused`),營地與小遊戲會一起停住。
  - 營地不會自己消失,收到 `camp_left` 後由 B 線移除。
- 雲端環境沒有手機、沒有 Mac、沒有 Play Console 帳號,所以實機安裝、TestFlight、上傳都還沒驗證。
- 共用的 Godot 編輯器設定檔會被同時執行的其他 Godot 覆寫,所以建置腳本改用一份臨時的設定;不影響你。

## 下一步

- 請你(或整合工作階段)在 Android 手機上裝「Android Sandbox」APK,試小遊戲的手感、看 40 隻敵人的 FPS。
- C 線放入正式 App 圖示後,執行 `godot --headless --path . --script res://export/tools/sync_icons.gd` 更新匯出設定。
- 整合時:營地接上 B 線的流程,處理三個申請。

## 需要擁有人決定的事

1. **套件識別碼(最重要)**:現在用的是佔位值 `com.doggyknight.prototype`。**第一次上傳 Google Play 或 App Store 之後就永遠不能改。** 請在第一次上傳前決定,例如 `com.你的工作室名稱.doggyknight`。
2. **免費還是付費**:Google Play 上「免費」的 App 以後不能改成付費。第一次建立 App 時就要選。
3. **三個申請要不要接受**(建議全部接受):
   - `docs/requests/20261115-D-mobile-project-settings.md`:鎖 60 FPS 省電、iPhone 開靜音時不發聲、隱藏狀態列。
   - `docs/requests/20261115-D-playlog-autoload.md`:開啟本機遊玩記錄。
   - `docs/requests/20261115-D-screenfit-shrink.md`:修正改變視窗大小時的黑邊。
4. **每次進營地只能玩一次小遊戲**(我先這樣決定,避免無限刷獎勵)。想改成可以重玩:把 `game/camp/camp_config.tres` 的 `minigame_plays_per_visit` 改為 0。
5. **小遊戲的難度**:門檻 80 / 160 / 240 公分是估計值(自動試玩約拿到 170 至 185 公分,2 顆星)。試玩後告訴我太難或太易,只要改 `scroll_grading.tres`。
6. **切到背景後回來**:目前小遊戲停在暫停畫面,要點一下才繼續(較安全)。想要回來就自動繼續,把 `scroll_config.tres` 的 `resume_on_foreground` 改為開。

## 建議(只記錄,未實作)

- 在暫停選單或製作名單加一個「複製遊玩記錄」按鈕:把記錄放進剪貼簿,讓經 Google Play 測試安裝的測試者貼給你(不需要網路與外掛)。目前正式版的記錄只能在手機上讀,開發者拿不到。
- 32 位元(armeabi-v7a)的程式庫讓安裝檔大了約一半。若統計顯示測試者都用 64 位元手機,可以在匯出設定關掉它,AAB 會小很多(Google Play 會依手機只下載需要的部分,所以影響主要是 APK)。
- 營地的「同伴」入口將來可以做成和鬥牛犬互動(餵零食、摸摸頭),同樣用 `MinigameBase` 框架。
