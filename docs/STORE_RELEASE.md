# 上架指南與清單(App Store + Google Play)

最後核對:2026-11-15。

商店規定每年都會改。**每次送審前,整合工作階段要按第 5 節的官方連結重新核對本文件,並更新上面的日期。** 本文件由 Phase 0 與整合工作階段維護,四條線只讀不改。

---

## 1. 現行硬性規定(2026-11 核對)

| 項目 | Google Play(Android) | App Store(iOS) |
| --- | --- | --- |
| 開發者帳號 | Play Console,一次性 US$25,需要身分驗證 | Apple Developer Program,每年 US$99 |
| 建置用的電腦 | Windows、macOS、Linux 都可以 | **必須是 Mac**(或雲端 Mac) |
| 上傳格式 | AAB(Android App Bundle)。APK 只用來在自己手機上測試 | 用 Xcode 建置並上傳 |
| 平台版本要求 | 新 App 與更新必須 target **API 36(Android 16)**或以上(2026-08-31 起) | 必須用 **Xcode 26** 或以上、iOS 26 SDK 建置(2026-04-28 起) |
| 其他技術要求 | 原生程式庫要支援 16 KB 記憶體分頁(Godot 4.5 起預設支援,匯出後仍要核對) | 隱私清單(privacy manifest),由 Godot 的 iOS 匯出處理,D 線核對 |
| 給測試者的管道 | 內部測試(最多 100 人,上傳後很快可用)、封閉測試、公開測試 | TestFlight(內部測試者最多 100 人;外部測試者要先經 Beta 審核) |
| 正式上架前的門檻 | 2023-11-13 之後建立的**個人**帳號:至少 **12 位測試者連續 14 天**參加封閉測試,才可申請正式版。機構帳號一般不受此限 | 送審(App Review),通常一至兩天 |
| 隱私 | 隱私權政策網址;「資料安全」表單(不收集資料也要填) | 隱私權政策網址;「App 隱私」標籤 |
| 內容分級 | IARC 內容分級問卷 | 年齡分級問卷 |
| 試玩版、測試版 | 只能放在測試管道 | 不可上架 App Store,只能用 TestFlight |

---

## 2. 擁有人要做的事(按時間)

### 現在就可以做

- [ ] 申請 Google Play Console 帳號。先決定用「個人」還是「機構」(見第 4 節)。身分驗證可能要幾天。
- [ ] 申請 Apple Developer Program。
- [ ] 決定 iOS 怎樣建置:自己的 Mac、借用的 Mac,還是雲端 Mac 服務。

### M3 之前

- [ ] 決定 App 名稱(中文名與英文名)。App Store 上的名稱不可與其他 App 重複,所以要先在兩家商店搜尋有沒有撞名,也要避開別人的商標。
- [ ] 決定套件識別碼,例如 `com.yourstudio.doggyknight`。**第一次上傳後永遠不能改。**
- [ ] 找 12 位以上願意連續 14 天保持參加測試的人。Google Play 封閉測試用他們的 Google 帳號,TestFlight 用他們的電郵。

### M3

- [ ] D 線與整合工作階段準備好 AAB 後,在 Play Console 建立 App,上傳到「封閉測試」,邀請測試者。**14 天由此開始計算**,中途有人退出可能要重新計算。
- [ ] 同時收集試玩意見。這就是 M3 的試玩。
- [ ] 有 Mac 的話,上傳 TestFlight,讓 iPhone 測試者試玩。
- [ ] 安全備份 Android 上傳金鑰與密碼(遺失了可以向 Google 申請重設,但很麻煩)。不要放進 repo。

### M4(決定上架之後)

- [ ] 回答第 4 節的決定事項。
- [ ] 準備隱私權政策網址:任何可以公開瀏覽的網頁都可以,例如 Google 協作平台,或公開的 GitHub Pages。內容用 `store/` 的草稿。
- [ ] 在兩家商店填寫商店頁面、截圖、隱私問卷、分級問卷(用 `store/` 的建議答案)。
- [ ] Play Console 申請正式版存取權(封閉測試滿 14 天後),然後送審;App Store 送審。

---

## 3. 送審前自查清單(整合工作階段執行)

- [ ] 已按第 5 節的連結重新核對第 1 節的規定,並更新本文件的日期。
- [ ] 版本號與建置號比上一次上傳的大(Android `versionCode`、iOS 建置號)。
- [ ] Android target API、iOS 使用的 Xcode 版本符合第 1 節。AAB 內的原生程式庫支援 16 KB 分頁。
- [ ] 圖示與截圖尺寸符合送審當時商店後台的要求。參考值:Google Play 要 512×512 圖示、1024×500 宣傳圖、至少 2 張手機截圖;App Store 要 6.9 吋 iPhone 的截圖。
- [ ] 隱私權政策網址可以打開,內容與遊戲的實際行為一致。
- [ ] 「資料安全」與「App 隱私」的答案與 `store/` 的草稿一致。加入任何 SDK(廣告、分析、內購)後要重填。
- [ ] 內容分級:沒有血腥(狗不會受傷),只有卡通式的輕度打鬥。
- [ ] 目標年齡若包含 13 歲以下兒童:符合 Google Play 家庭政策。
- [ ] `docs/licenses.md` 完整;遊戲內有製作名單與授權畫面。
- [ ] 遊戲畫面與商店頁面都沒有「測試版」「Demo」「Beta」之類字樣(Apple 不接受)。
- [ ] 實機檢查:Android 返回鍵、切到背景、來電、鎖螢幕、瀏海或挖孔螢幕、iPhone 底部橫條。
- [ ] 金鑰與憑證已備份,而且沒有提交到 repo。

---

## 4. 需要擁有人決定的事

| 問題 | 選項 | 建議 |
| --- | --- | --- |
| Google Play 帳號類型 | 個人:申請簡單,但正式上架前要 12 人連續 14 天封閉測試。機構:要有公司與 D-U-N-S 編號,不用 14 天測試 | 已有公司就用機構帳號;否則用個人帳號,把封閉測試併入 M3 試玩 |
| iOS 建置方法 | 自己的 Mac / 借用 / 雲端 Mac(例如 GitHub Actions 的 macOS 機器) | 先做 Android。有 Mac 最簡單;沒有的話,到 M3 再決定要不要租用 |
| 上架內容量 | 現在的 6 關 / 先補足第一章或更多 | 只有 6 關容易被玩家評為內容太少。建議原型通過後,先補足內容再正式上架 |
| 收費模式 | 付費下載 / 免費加廣告 / 免費加內購 | M3 試玩之後再決定。原型已經在 `platform/` 預留介面,不用返工 |
| 目標年齡 | 包含兒童 / 13 歲以上 | 可愛的狗會吸引兒童。若打算接廣告或分析服務,包含兒童會受到很多限制,要在 M4 開工前決定 |
| 上架地區與語言 | 原型只有繁體中文 | 第一次上架先選繁體中文地區。中國大陸 App Store 上架遊戲需要版號,手續繁複,建議先不包括。多語言要另外計劃(原型不做) |

---

## 5. 官方資料來源(每次核對用)

- Google Play target API 規定:https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play 封閉測試與正式版存取權:https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play 16 KB 分頁:https://developer.android.com/guide/practices/page-sizes
- Google Play 家庭政策:https://support.google.com/googleplay/android-developer/answer/9893335
- Apple 上傳的 SDK 最低要求:https://developer.apple.com/news/upcoming-requirements/
- Apple App 審查指南:https://developer.apple.com/app-store/review/guidelines/
- Godot 匯出 Android:https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot 匯出 iOS:https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- Godot 授權聲明要求:https://docs.godotengine.org/en/stable/about/complying_with_licenses.html
