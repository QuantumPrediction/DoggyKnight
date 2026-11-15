# Android:做出安裝檔、裝到手機、上傳 Google Play(D6)

最後更新:2026-11-15(D 線)。iPhone 的說明在 `export/IOS.md`。

**先記住兩種檔案:**

| 檔案 | 用途 | 匯出設定(Godot「專案 → 匯出」裡的名稱) |
| --- | --- | --- |
| APK(`.apk`) | 直接裝到**自己的** Android 手機測試 | `Android`(正式遊戲)、`Android Sandbox`(D 線測試選單) |
| AAB(`.aab`) | 上傳到 **Google Play**(內部測試、封閉測試、正式版都用它) | `Android AAB` |

標示:✅ = 已在雲端工作環境實際做過並成功;⚠️ = 未驗證(雲端環境沒有手機、沒有 Play Console 帳號,或要在你的電腦上做)。

---

## 1. 你需要準備的東西

| 東西 | 用途 | 去哪裡拿 | 費用 |
| --- | --- | --- | --- |
| 一台電腦(Windows、macOS 或 Linux 都可以) | 建置 | — | — |
| Godot 4.7.2 編輯器(**一定要這個版本**) | 開專案、匯出 | https://godotengine.org/download/archive/4.7.2-stable/ | 免費 |
| Godot 4.7.2 匯出範本 | 匯出時需要 | Godot 編輯器:「編輯器 → 管理匯出範本 → 下載並安裝」 | 免費 |
| JDK 17 或 21(Java) | Android 建置工具需要 | 建議 Eclipse Temurin:https://adoptium.net/ | 免費 |
| Android SDK | Android 建置工具 | 最簡單:安裝 Android Studio(https://developer.android.com/studio),第一次開啟時會自動下載 SDK | 免費 |
| SDK 內要有的套件 | — | Android Studio →「SDK Manager」勾選:**Android SDK Platform 36**、**Android SDK Build-Tools 36.x**、**Android SDK Platform-Tools**、**NDK 29.0.14206865**(只有做 AAB 需要) | 免費 |
| 一支 Android 手機(Android 7.0 或以上)與 USB 線 | 實機測試 | — | — |
| Google Play Console 帳號 | 上傳 AAB、邀請測試者 | https://play.google.com/console | 一次性 US$25 |
| 上傳金鑰(upload key) | 證明 AAB 是你上傳的 | 你自己產生(第 4 節) | 免費 |

雲端環境實際用過的版本(✅):Godot 4.7.2、OpenJDK 21、Android SDK build-tools 36.1.0、platform android-36、NDK 29.0.14206865。

---

## 2. 第一次設定 Godot(只做一次)⚠️

1. 開啟 Godot 4.7.2,匯入專案資料夾(有 `project.godot` 的那個)。
2. 選單「編輯器 → 編輯器設定 → 匯出 → Android」:
   - **Java SDK Path**:JDK 的資料夾。Windows 例:`C:\Program Files\Eclipse Adoptium\jdk-21...`;macOS 例:`/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`。
   - **Android SDK Path**:Android Studio →「SDK Manager」視窗上方顯示的路徑。Windows 例:`C:\Users\你的名字\AppData\Local\Android\Sdk`;macOS 例:`~/Library/Android/sdk`。
   - **Debug Keystore**:留空即可,Godot 會自動產生除錯用的金鑰。
3. 選單「編輯器 → 管理匯出範本」,下載並安裝 4.7.2 的範本。

---

## 3. 做出除錯版 APK,裝到手機

### 3.1 匯出 ⚠️(在你的電腦上);✅(雲端用指令做過,見第 7 節)

1. Godot 選單「專案 → 匯出」。
2. 左邊選 **Android**(想試 D 線的營地與壓力測試就選 **Android Sandbox**)。
3. 按下方「匯出專案」,**勾選「使用除錯匯出」**,存成例如 `doggyknight-debug.apk`。
   請存到專案資料夾以外,或專案內的 `export/build/`(這個資料夾不會被提交)。

`Android Sandbox` 做出來的 App 名稱是「金毛騎士(D線測試)」,開啟後是 D 線的測試選單:進入營地、玩小遊戲、壓力測試(40 隻敵人,左上角顯示 FPS)。它的套件名稱不同,可以和正式的除錯版同時裝在手機上。

### 3.2 裝到手機(擇一)⚠️

**方法 A:傳檔案(不用裝任何工具)**

1. 把 APK 傳到手機:USB 線(手機選「檔案傳輸」)、Google 雲端硬碟,或寄給自己。
2. 在手機的「檔案」App 點那個 APK。
3. 手機會說「基於安全考量,你的手機目前無法安裝這個來源的不明應用程式」→ 點「設定」→ 開啟「允許這個來源的應用程式」→ 返回 → 安裝。
4. 若出現 Play 安全防護的警告,點「仍要安裝」(這是你自己做的 App)。

**方法 B:用 adb(較快,適合常常重裝)**

1. 手機:「設定 → 關於手機 → 版本號碼」連點 7 下,開啟開發人員選項;再到「開發人員選項」開啟「USB 偵錯」。
2. 用 USB 線接電腦,手機上允許這台電腦偵錯。
3. 電腦上(Android SDK 的 `platform-tools` 資料夾內有 `adb`):

   ```
   adb install -r doggyknight-debug.apk
   ```

**方法 C:Godot 一鍵部署**:手機用 USB 接好並開啟 USB 偵錯後,Godot 編輯器右上角會出現 Android 圖示,按下就會建置並安裝。

**裝不上去?** 「應用程式未安裝」通常是因為手機上已經有一個用不同金鑰簽署的同名 App(例如之前從 Play 測試裝的版本)。先把舊的解除安裝再試。

---

## 4. 上傳金鑰(upload key)與 Play 應用程式簽署

### 這是甚麼

- Google Play 現在一律使用「**Play 應用程式簽署**」:真正發給玩家的 App,由 **Google 保管的金鑰**簽署。
- 你只需要一把「**上傳金鑰**」:每次上傳 AAB 時用它簽署,讓 Google 確認是你上傳的。
- 上傳金鑰遺失了,可以在 Play Console 申請重設(要等 Google 處理,幾天時間),遊戲本身不受影響。但還是要好好備份。

### 產生上傳金鑰 ⚠️(指令本身 ✅ 在雲端用來產生測試用金鑰)

在電腦的終端機(Windows:命令提示字元)執行。`keytool` 在 JDK 的 `bin` 資料夾內:

```
keytool -genkeypair -v -keystore doggyknight-upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

它會問密碼(輸入兩次)和姓名、機構等資料(可以隨意填,玩家看不到)。完成後得到 `doggyknight-upload.keystore` 檔案。

### 備份(很重要)

- 金鑰檔、**別名**(上面的 `upload`)、**密碼**三樣一起記錄。
- 至少放兩個地方:例如密碼管理器(1Password、Bitwarden 等)一份,加一個離線的 USB 隨身碟一份。
- **絕對不要**放進 GitHub repo、不要寄電郵、不要放在專案資料夾內。repo 的 `.gitignore` 已經排除 `*.keystore`、`*.jks`,但最安全是放在專案以外的地方。

### 在 Godot 裡使用

「專案 → 匯出 → Android AAB → Keystore」:
**Release** 填金鑰檔的完整路徑、**Release User** 填別名、**Release Password** 填密碼。
Godot 會把密碼存在 `.godot/export_credentials.cfg`(已被 `.gitignore` 排除),**不會**寫進 `export_presets.cfg`。
D 線的測試(`tests/line_d/test_export_presets.gd`)會檢查 `export_presets.cfg` 裡沒有任何金鑰或密碼。

---

## 5. 做出 AAB ⚠️(在你的電腦上);✅(雲端用指令做過)

1. 第一次:Godot 選單「專案 → 安裝 Android 建置範本」。會在專案內建立 `android/` 資料夾(不會被提交)。
2. 「專案 → 匯出」→ 選 **Android AAB** → 確認第 4 節的 Release 金鑰已填好。
3. 按「匯出專案」,**取消勾選「使用除錯匯出」**,存成 `doggyknight-release.aab`。
4. 第一次建置要連網下載 Gradle 與 Android 程式庫(幾百 MB),需要幾分鐘。之後會快很多。

**每次上傳新版本之前**:把「Android AAB」(和「Android」)的 **Version → Code** 加 1(例如 1 → 2)。Google Play 不接受相同或較小的版本號。
**Version → Name**(例如 0.1.0)是給人看的,可以自己決定。

這個 AAB 已經符合 Google Play 2026 年的要求(✅ 已檢查):target API 36、min API 24、arm64-v8a 的原生程式庫支援 16 KB 記憶體分頁、不要求任何權限。

---

## 6. Play Console:建立 App、上傳到「內部測試」⚠️(全部未驗證,畫面以 Play Console 當時為準)

### 6.1 第一次上傳前一定要決定:套件名稱

目前用的是佔位值 **`com.doggyknight.prototype`**。**第一次上傳到 Play Console 之後就永遠不能改。**
請在第一次上傳前決定正式的名稱(例如 `com.你的工作室.doggyknight`),告訴 D 線或整合工作階段,
他們會同時改 `export_presets.cfg` 內的三個 Android 設定與 iOS 的 Bundle Identifier,以及對應的測試。

### 6.2 建立 App

1. 登入 https://play.google.com/console →「建立應用程式」。
2. 名稱:金毛騎士;預設語言:中文(台灣)– zh-TW;類型:**遊戲**;**免費**或付費。
   注意:**免費的 App 以後不能改成付費**(付費可以改免費)。還沒決定收費模式的話,這是要先想清楚的事(`docs/STORE_RELEASE.md` 第 4 節)。
3. 勾選同意政策後建立。

### 6.3 Play 應用程式簽署

新的 App 預設就會使用 Play 應用程式簽署(Google 產生並保管簽署金鑰)。第一次上傳 AAB 時,Play Console 會請你確認;選預設(由 Google 產生)即可。
你上傳時用的那把金鑰,就會被登記成這個 App 的「上傳金鑰」。

> **不要上傳雲端環境做出來的 AAB。** 它是用一把標明「THROWAWAY NOT FOR STORE」的測試金鑰簽署的(第 7 節),
> 一旦上傳,那把金鑰就會變成這個 App 的上傳金鑰。請用你自己在第 4 節產生的金鑰重新匯出。

### 6.4 上傳到內部測試

1. 左邊選單「測試 → 內部測試」→「建立新版本」。
2. 把 `doggyknight-release.aab` 拖進去。版本名稱會自動帶入(0.1.0)。
3. 「儲存」→「檢查版本」→ 看有沒有錯誤 →「開始推出到內部測試」。
4. 「測試人員」分頁:建立電郵名單,加入測試者的 Google 帳號電郵(最多 100 人)。
5. 複製「加入測試的連結」,傳給測試者。他們在手機上打開連結、按「接受」,再從 Play 商店安裝。
6. 內部測試通常幾分鐘內就可以安裝。

### 6.5 之後:封閉測試(12 人連續 14 天)

個人帳號在申請正式版之前,要有至少 12 位測試者連續 14 天參加**封閉測試**(`docs/STORE_RELEASE.md`)。
做法和內部測試類似:「測試 → 封閉測試」建立測試群組、上傳同一個 AAB、邀請測試者。封閉測試要先填好商店資訊、內容分級、資料安全等(草稿在 `store/`)。

---

## 7. 給 Claude 工作階段的建置指令(✅ 已在雲端執行成功)

環境:Linux、Godot 4.7.2、`/opt/android-sdk`、`/usr/lib/jvm/java-21-openjdk-amd64`、匯出範本在 `~/.local/share/godot/export_templates/4.7.2.stable/`。

```bash
# 除錯版 APK → export/build/doggyknight-debug.apk
export/build_android.sh debug

# D 線測試選單 APK → export/build/doggyknight-sandbox-debug.apk
export/build_android.sh sandbox

# AAB → export/build/doggyknight-release.aab(上傳金鑰只用環境變數傳入,不寫進任何檔案)
UPLOAD_KEYSTORE=/path/outside/repo/upload.keystore UPLOAD_KEY_ALIAS=upload UPLOAD_KEY_PASSWORD=... \
  export/build_android.sh aab

# 檢查:套件名稱、SDK 版本、權限、zipalign 16 KB、原生程式庫 16 KB 分頁、AAB 簽署
export/build_android.sh verify
```

腳本在 Linux 上用一份臨時的 Godot 編輯器設定(`XDG_CONFIG_HOME`),所以不會改到、也不會被其他同時執行的 Godot 改到;
除錯金鑰在 `~/.android/debug.keystore`(不存在時自動產生,密碼 `android`)。

等同的原始指令(腳本內部做的事):

```bash
XDG_CONFIG_HOME=<只含 Android 設定的臨時資料夾> godot --headless --path . --export-debug "Android" export/build/doggyknight-debug.apk
XDG_CONFIG_HOME=... GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... GODOT_ANDROID_KEYSTORE_RELEASE_USER=... GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
  godot --headless --path . --install-android-build-template --export-release "Android AAB" export/build/doggyknight-release.aab
```

2026-11-15 的實際結果:

| 項目 | 結果 |
| --- | --- |
| 除錯版 APK | 約 58 MB;`package: com.doggyknight.prototype`、`versionCode 1`、`versionName 0.1.0`、`minSdkVersion 24`、`targetSdkVersion 36`、App 名稱「金毛騎士」、`native-code: arm64-v8a armeabi-v7a`、**沒有任何 uses-permission** |
| `zipalign -c -P 16 -v 4` | 通過(Verification successful) |
| 原生程式庫 16 KB 分頁 | arm64-v8a 的 `libgodot_android.so`、`libc++_shared.so` LOAD 對齊 16384 ✅;armeabi-v7a 為 4096(32 位元手機只用 4 KB 分頁,不受規定限制) |
| AAB(Gradle) | 約 53 MB,建置約 2 分鐘(第一次含下載);Gradle 產生的 AndroidManifest:minSdk 24、targetSdk 36、沒有權限;以**測試用的拋棄式金鑰**簽署(`CN=THROWAWAY NOT FOR STORE`),`jarsigner -verify` 通過 |
| iOS | 見 `export/IOS.md` |

拋棄式金鑰放在雲端環境的 `~/.android/THROWAWAY-not-for-store-release.keystore`(repo 以外),只用來證明 AAB 建置流程可行。

---

## 8. 已驗證與未驗證

| 步驟 | 狀態 |
| --- | --- |
| 匯出設定 `export_presets.cfg`(Android、Android AAB、Android Sandbox、iOS) | ✅ |
| 指令列匯出除錯版 APK、沙盒 APK | ✅ |
| 安裝 Android 建置範本、Gradle 建置 AAB | ✅ |
| APK / AAB 檢查(SDK 版本、權限、16 KB) | ✅ |
| 在 Godot 編輯器的圖形介面匯出(第 2、3.1、5 節) | ⚠️ 未在你的電腦上驗證,但設定與指令列用的是同一份 |
| 裝到實體手機、在手機上試玩 | ⚠️ 雲端沒有手機 |
| 沙盒 APK 開機直接進 D 線測試選單(用 `command_line/extra_args`) | ⚠️ 已確認參數有寫進 APK,未在手機上確認 |
| Play Console 建立 App、上傳、內部測試、封閉測試 | ⚠️ 需要你的帳號 |
| 上傳金鑰遺失時的重設流程 | ⚠️ 依 Google 說明,未實際操作 |

## 9. App 圖示

目前用的是 Phase 0 的佔位圖示 `assets/app_icon/icon.png`。C 線(C13)放入正式圖示(例如 `android_foreground.png`、`android_background.png`、`android_monochrome.png`、`ios_1024.png`)之後,執行:

```bash
godot --headless --path . --script res://export/tools/sync_icons.gd
```

它會把找到的圖示填進 `export_presets.cfg`。之後提交 `export_presets.cfg`。
沒有單色(monochrome)圖示時,建置工具會出現一行 `themed_icon` 的警告,不影響安裝。
