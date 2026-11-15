# platform/:平台服務的介面(D 線)

這個資料夾放「遊戲以外的服務」的介面:廣告、內購、分析,以及本機遊玩記錄。
DEV_PLAN 第 1 節規定原型**不做**廣告、內購與分析,所以前三個都是「空實作」:
方法存在、可以呼叫,但甚麼都不做,只在除錯版的主控台印一行記錄。**不連網、不載入任何 SDK、不讀取任何識別碼。**

| 檔案 | 類別 | 原型的行為 |
| --- | --- | --- |
| `ads.gd` | `PlatformAds` | `show_rewarded()` 之後發出 `rewarded_finished(placement, false)`(沒有獎勵);插頁、橫幅都不顯示 |
| `iap.gd` | `PlatformIap` | `purchase()` 之後發出 `purchase_finished(id, false)`;`get_products()` 傳回空陣列 |
| `analytics.gd` | `PlatformAnalytics` | `log_event()` 只印出,不儲存、不上傳 |
| `play_log.gd` | (Autoload `PlayLog`) | 每關結束在手機本機寫一行記錄,見下面「遊玩記錄」 |
| `platform_log.gd` | `PlatformLog` | 上面三個共用的「只在除錯版印出」工具 |

## 給程式的用法

遊戲程式**只能**經這裡呼叫平台服務(DEV_PLAN 4.8),不可直接呼叫任何廣告或付款外掛。
日後要接真實服務時,只改這幾個檔案的內容,方法名稱與訊號不變,遊戲程式不用改。

```gdscript
var ads := PlatformAds.new()      # 日後可改為 Autoload
add_child(ads)
ads.rewarded_finished.connect(func(placement: StringName, rewarded: bool) -> void:
	if rewarded:
		GameState.snacks += 1)
ads.show_rewarded(&"continue")
```

原型沒有任何地方呼叫廣告與內購,所以不需要把它們註冊為 Autoload。

## 接真實服務之前一定要做的事(給擁有人與上架工作階段)

接上任何廣告、內購或分析 SDK,**兩家商店的隱私問卷都要重填**,而且有些決定一旦做了很難回頭:

1. **隱私問卷**:Google Play 的「資料安全」與 Apple 的「App 隱私」標籤,現在可以填「不收集資料」(見 `store/`)。
   加入廣告或分析 SDK 後,通常要申報「裝置或其他 ID」「使用情形資料」「當機記錄」等,並說明用途(廣告、分析)。
2. **Apple 的追蹤授權(ATT)**:廣告 SDK 若使用 IDFA(廣告識別碼)做個人化廣告,必須先彈出系統的「允許追蹤」視窗,
   並在 iOS 匯出設定填寫追蹤用途說明;SDK 的隱私清單(privacy manifest)也要一併放進 App。
3. **Android 的廣告 ID 權限**:使用廣告 ID 要加 `com.google.android.gms.permission.AD_ID` 權限,並在 Play Console 申報。
   目前 `export_presets.cfg` 沒有任何權限。
4. **兒童與家庭政策**:金毛很可愛,很可能吸引兒童。如果目標年齡包含 13 歲以下:
   - Google Play「家庭政策」:只能使用通過 Google「家庭自我認證」的廣告 SDK;不可傳送兒童的廣告 ID;廣告內容要適合兒童。
   - Apple「兒童類別」:基本上不可以有第三方分析與第三方廣告(除非符合特定條件),不可追蹤。
   - 美國 COPPA、歐盟 GDPR 等法律對兒童資料有額外要求。
   建議在 M4 開工前先決定目標年齡(DEV_PLAN 第 14 節、`docs/STORE_RELEASE.md` 第 4 節)。
5. **同意畫面**:在歐盟、英國等地區顯示個人化廣告或做分析之前,要先取得玩家同意(例如 Google 的 UMP)。
   `PlatformAnalytics.set_consent()` 已預留這個開關。
6. **內購**:Apple 規定非消耗性商品要有「恢復購買」按鈕(`PlatformIap.restore_purchases()` 已預留)。
   價格、退款與稅務在 Play Console 和 App Store Connect 設定。
7. **外掛**:原型規定不裝第三方外掛(CLAUDE.md 規則 8)。接真實服務時要用 Godot 的 Android 外掛(AAR)與 iOS 外掛,
   先核對授權並記錄在 `docs/licenses.md`,也要確認外掛支援目前的 Godot 版本與商店要求(target API、16 KB 分頁、Xcode 版本)。

## 遊玩記錄(play_log.gd,D8)

用途:M3 試玩時了解每關打多久、輸贏、選了甚麼把戲,用來調整難度。

- 檔案:手機上 App 自己的資料夾內的 `playlog.jsonl`(Godot 的 `user://`)。一行一筆,格式說明在 `play_log.gd` 開頭。
- 內容:時間、關卡 id、過關或失敗、戰鬥秒數(不含暫停)、經過秒數、所選把戲、等級;營地小遊戲的分數與評價。
- **不含**任何裝置識別碼、帳號、位置或個人資料,**不上傳**。所以兩家商店的隱私問卷仍然可以填「不收集資料」
  (資料只留在使用者自己的手機,開發者收不到,不算「收集」)。
- 超過 512 KB 時,舊記錄改名為 `playlog.old.jsonl`,只留一份舊檔。
- 需要整合工作階段把它註冊為 Autoload「PlayLog」:`docs/requests/20261115-D-playlog-autoload.md`。

擁有人怎樣拿到記錄:

| 情況 | 方法 | 已驗證? |
| --- | --- | --- |
| 桌面試玩(Godot 編輯器) | Windows:`%APPDATA%\Godot\app_userdata\金毛騎士\playlog.jsonl`;macOS:`~/Library/Application Support/Godot/app_userdata/金毛騎士/`;Linux:`~/.local/share/godot/app_userdata/金毛騎士/` | Linux 已驗證 |
| Android 除錯版 APK(用 USB 線接電腦) | `adb shell run-as com.doggyknight.prototype cat files/playlog.jsonl > playlog.jsonl` | 未在實機驗證 |
| 經 Google Play 測試安裝的正式版 | 無法直接讀取(系統保護 App 的資料)。建議日後加一個「複製遊玩記錄」按鈕,把內容放進剪貼簿讓測試者貼給你(不需要網路與外掛) | 尚未實作 |
| iPhone(Xcode 安裝的開發版) | Xcode →「Window → Devices and Simulators」→ 選 App →「Download Container」 | 未驗證(需要 Mac) |
