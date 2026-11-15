# Apple「App 隱私」標籤:建議答案

位置:App Store Connect →「你的 App → App 隱私」。
狀態:草稿,依 2026-11 的原型設計。送審前由上架工作階段按當時的問卷核對。

## 主要問題

| 問題(大意) | 建議答案 | 說明 |
| --- | --- | --- |
| 你或你的第三方合作夥伴是否會從此 App 收集資料? | **否,我們不會從此 App 收集資料** | 商店頁面會顯示「未收集資料」(Data Not Collected) |
| 隱私權政策網址 | 填入 `privacy_policy_zh-Hant.md` 放上網後的網址 | 必填 |
| 使用者隱私選擇網址 | 留空 | 選填 |

Apple 的定義:「收集」是指資料**傳送出裝置**,而且保存的時間超過即時處理所需。
本遊戲的存檔與遊玩記錄只存在 iPhone 上,所以可以選「不收集」。

## 追蹤與 App 追蹤透明度(ATT)

- 本遊戲不追蹤使用者、不讀取 IDFA,所以**不需要**「允許追蹤」的系統視窗,也不需要 `NSUserTrackingUsageDescription`。
- iOS 匯出設定中 `privacy/tracking_enabled = false`,`privacy/tracking_domains` 為空。

## 隱私清單(privacy manifest,PrivacyInfo.xcprivacy)

- Godot 4.7.2 的 iOS 匯出會自動產生(D 線已在 Linux 匯出 Xcode 專案並核對,✅):
  `NSPrivacyTracking = false`;沒有任何「收集的資料類型」;
  只列出引擎用到的「必要原因 API」:檔案時間(DDA9.1、C617.1)、開機時間(35F9.1)、磁碟空間(E174.1、85F4.1)。
- 這與上面的答案一致。之後加入任何第三方 SDK,SDK 自己的隱私清單也要一起放進 App,並重填本問卷。

## 出口合規(加密)

- Godot 產生的 `Info.plist` 已有 `ITSAppUsesNonExemptEncryption = false`(✅ 已核對),
  上傳 TestFlight 時不會再詢問加密問題。本遊戲不使用網路,也沒有自訂加密。

## 甚麼時候要重填

與 Google Play 相同:加入廣告、分析、當機回報、雲端存檔、帳號、內購或任何網路功能時(見 `platform/README.md`)。
