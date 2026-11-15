# iPhone:建置、簽署、上傳 TestFlight(D10)

最後更新:2026-11-15(D 線)。Android 的說明在 `export/README.md`。

標示:✅ = 已在雲端(Linux)實際做過;⚠️ = 未驗證(需要 Mac、Xcode 與 Apple 開發者帳號)。

**重點:iPhone 版只能在 Mac 上(或雲端 Mac)做出安裝檔。** Linux 雲端環境只能產生 Xcode 專案,不能產生 `.ipa`。
Apple 規定試玩版不可以放上 App Store,原型只用 **TestFlight** 給測試者。

---

## 1. 你需要準備的東西

| 東西 | 說明 | 費用 |
| --- | --- | --- |
| Mac(或租用的雲端 Mac) | Xcode 只能在 macOS 上執行 | — |
| **Xcode 26 或以上** | 2026-04-28 起上傳 App Store Connect 的建置必須用 Xcode 26 / iOS 26 SDK(`docs/STORE_RELEASE.md`)。Xcode 26 需要較新的 macOS,請在 Mac App Store 的 Xcode 頁面確認最低系統要求 | 免費 |
| Apple Developer Program | https://developer.apple.com/programs/ | 每年 US$99 |
| Team ID | 開發者網站 →「Account → Membership details」的 10 個字元代碼 | — |
| Godot 4.7.2(macOS 版)與匯出範本 | 與 Android 相同的版本 | 免費 |
| 一支 iPhone(測試用) | 安裝 TestFlight App | — |

---

## 2. 匯出設定(已建立)✅

`export_presets.cfg` 裡的「iOS」設定:

| 項目 | 值 | 說明 |
| --- | --- | --- |
| Bundle Identifier | `com.doggyknight.prototype` | **佔位值**,與 Android 相同。第一次上傳前要定案,之後不能改 |
| App Store Team ID | (空白) | **你要在 Mac 上填入自己的 Team ID**;不填 Godot 會拒絕匯出 |
| Targeted Device Family | iPhone | 只支援 iPhone(DEV_PLAN 第 2 節) |
| 方向 | 直向 | 讀專案設定 `display/window/handheld/orientation` |
| Short Version / Version | 0.1.0 / 1 | Version(建置號)每次上傳都要加 1 |
| Export Method | 除錯:Development;正式:App Store | |
| 簽署 | Code Sign Identity、Provisioning Profile 留空 | 交給 Xcode「自動管理簽署」 |
| 圖示 | `assets/app_icon/icon.png`(佔位) | C 線(C13)提供 1024×1024、不透明的正式圖示後,執行 `export/tools/sync_icons.gd` |

---

## 3. 在 Linux 上試匯出的結果 ✅

指令(雲端工作環境,暫時填入假的 Team ID `ABCDE12345`,試完已還原,沒有提交):

```bash
godot --headless --path . --export-debug "iOS" export/build/ios/DoggyKnight.ipa
```

結果:

- Team ID 空白時:匯出失敗,訊息「App Store Team ID not specified.」(所以你在 Mac 上一定要先填)。
- 填入 Team ID 後:**成功產生 Xcode 專案**(`DoggyKnight.xcodeproj`、`DoggyKnight.pck`、`DoggyKnight.xcframework` 等),
  並提示「.ipa can only be built on macOS」,沒有產生 `.ipa`。
- 產生的 `Info.plist` 已核對:只有直向(`UIInterfaceOrientationPortrait`)、隱藏狀態列(`UIStatusBarHidden = true`)、
  `TARGETED_DEVICE_FAMILY = 1`(iPhone)、`ITSAppUsesNonExemptEncryption = false`(上傳時不用回答加密出口問題)。
- 隱私清單 `PrivacyInfo.xcprivacy` 由 Godot 自動產生:`NSPrivacyTracking = false`,沒有收集任何資料類型,
  只列出引擎用到的「必要原因 API」(檔案時間、開機時間、磁碟空間)與其原因代碼。這符合「不收集資料」。

---

## 4. 在 Mac 上建置並上傳 TestFlight ⚠️(全部未驗證)

### 4.1 一次性準備

1. 安裝 Xcode 26(Mac App Store),開啟一次,讓它安裝 iOS 元件。
2. Xcode →「Settings → Accounts」→ 加入你的 Apple ID(開發者帳號)。
3. 安裝 Godot 4.7.2(macOS 版),「編輯器 → 管理匯出範本」下載 4.7.2 範本。
4. 開發者網站 →「Certificates, Identifiers & Profiles → Identifiers」→ 新增 App ID,
   Bundle ID 選「Explicit」,填入**已定案的**識別碼(目前佔位值 `com.doggyknight.prototype`)。
5. App Store Connect(https://appstoreconnect.apple.com)→「我的 App → + → 新增 App」:
   平台 iOS、名稱「金毛騎士」(名稱不可與其他 App 重複)、主要語言「繁體中文」、選剛才的 Bundle ID、SKU 隨意(例如 `doggyknight`)。

### 4.2 每次建置

1. 用 Godot 開啟專案 →「專案 → 匯出 → iOS」:
   - **App Store Team ID** 填你的 Team ID(這個值存在 `export_presets.cfg`,Team ID 不是秘密,但提交前請和 D 線 / 整合工作階段確認)。
   - **Version**(建置號)比上次上傳的大(例如 1 → 2)。
2. 按「匯出專案」,存到專案資料夾以外(例如 `~/DoggyKnight-ios/DoggyKnight.ipa`)。
   Godot 會產生 Xcode 專案;在 Mac 上也可能直接做出 `.ipa`(視簽署是否已設定好)。
3. 用 Xcode 開啟 `DoggyKnight.xcodeproj`:
   - 左邊選專案 →「Signing & Capabilities」→ 勾選「Automatically manage signing」,Team 選你的帳號。
   - 上方裝置選「Any iOS Device (arm64)」。
4. 選單「Product → Archive」。完成後會開啟 Organizer。
5. Organizer →「Distribute App」→「App Store Connect」(或「TestFlight Internal Only」)→「Upload」→ 一路按下一步。
6. 等 App Store Connect 處理(通常 5 至 30 分鐘),之後會收到電郵。

### 4.3 TestFlight 邀請測試者

1. App Store Connect →「金毛騎士 → TestFlight」。
2. **內部測試**:你帳號團隊內的成員(最多 100 人),建置處理完就可以測,不用審核。
3. **外部測試**:任何人(用電郵或公開連結邀請),第一個建置要先通過 Beta App Review(通常一天內)。需要填寫測試資訊與聯絡電郵。
4. 測試者在 iPhone 安裝「TestFlight」App,接受邀請後安裝遊戲。

### 4.4 不經 TestFlight,直接裝到自己的 iPhone

iPhone 用線接 Mac,在 Xcode 上方選你的 iPhone,按「Run」(▶)。第一次要在 iPhone 的「設定 → 隱私權與安全性」開啟「開發者模式」。

---

## 5. 沒有 Mac 怎麼辦

| 方法 | 說明 | 狀態 |
| --- | --- | --- |
| 借用朋友的 Mac | 照第 4 節做;需要的時間不多(安裝 Xcode 約 1 小時,之後每次建置 10 分鐘) | ⚠️ |
| 租用雲端 Mac | 按小時或按月租用遠端 Mac,用遠端桌面照第 4 節做 | ⚠️ |
| **GitHub Actions 的 macOS 機器** | 範例在 `export/ci/ios-testflight.yml`:自動安裝 Godot、匯出 Xcode 專案、用 App Store Connect API 金鑰簽署並上傳 TestFlight。要啟用時把它複製到 `.github/workflows/`,並在 GitHub 加入 4 個 Secrets(檔案開頭有說明)。私人 repo 的 macOS 分鐘數以 10 倍計費 | ⚠️ 未驗證 |
| 延後 | DEV_PLAN 允許 iOS 延到 M4;先用 Android 試玩 | — |

用 GitHub Actions 時,你仍然要先完成第 4.1 節的第 4、5 步(在網頁上註冊 Bundle ID、建立 App),
並在 App Store Connect 產生 API 金鑰(「使用者與存取權限 → 整合 → App Store Connect API」,角色「App 管理」)。

---

## 6. 已驗證與未驗證

| 步驟 | 狀態 |
| --- | --- |
| iOS 匯出設定(只支援 iPhone、直向、佔位 Bundle ID、空白 Team ID) | ✅ |
| Linux 上產生 Xcode 專案(填 Team ID 後) | ✅ |
| `Info.plist` 與隱私清單內容核對 | ✅ |
| Mac 上用 Xcode 26 建置、簽署、Archive、上傳 | ⚠️ |
| TestFlight 內部 / 外部測試 | ⚠️ |
| GitHub Actions 工作流程 | ⚠️ |
| iPhone 實機:靜音鍵、底部橫條、瀏海、切到背景 | ⚠️(相關專案設定的申請:`docs/requests/20261115-D-mobile-project-settings.md`) |
