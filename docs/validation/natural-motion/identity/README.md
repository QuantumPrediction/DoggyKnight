# 黃金騎士 · The Golden Knight

Linux X11 上以 Godot 4.7.2、GL Compatibility、Mesa llvmpipe、固定 60 Hz 和相同鏡頭擷取 360×640 畫面。對照組是 [#31](https://github.com/QuantumPrediction/DoggyKnight/pull/31) 的 `9b7ed6c449087ae8a89daea997fcecde707b085e`。下圖依序為舊版、撤回的初稿和定稿，裁切自相同位置。

![三版遊戲封面題字，由上至下為原版、英文超出緞帶的初稿與定稿](ribbons.webp)

初稿逐字加距後寬 83.2 個邏輯像素，緞帶兩個凹口之間只有 74，英文末端落在淺色背景。定稿改用 8 號襯線字整行置中，文字寬 74，凹口間寬 88。全畫面逐像素比較，舊版與定稿有 5,467 個像素不同，全部在左上 (84, 85)、右下 (276, 148) 的題字範圍內。按鈕與其餘畫面完全吻合。此為單一固定畫格的渲染檢查。[完整定稿畫面](cover.webp) · [原圖、檔案與區域指紋](checks.json)

繪本封面、製作名單、結局、視窗、網頁頁籤與載入畫面的名稱已一致。標題插畫本身沒有文字。兩個備援像素標誌、早期啟動畫面、商店橫幅各有烙入的舊字樣，四檔均以原生成器先逐位元組重現，再重繪前兩個字。主角的名字仍叫「金毛」。平台顯示名稱與商店文字是專案草稿。

## 續玩

在 Linux 開兩份獨立空白資料夾。一份用 #31 的正式出征流程建立弓箭手 1-1 援軍局，關掉音效、音樂、震動，再從候選版標題按「繼續冒險」。另一份用候選版新開同一局，再啟動候選版讀回。四次均讀到弓箭手在 1-1、同一個援軍選項、三項設定與 1,487 bytes 的 v11 存檔。檔案 SHA-256 均為 `358723af4eeb6a076d7832f6646a814a1e1045872248c570d0fc5652958b378d`。原版新開局檢查曾報 4 個 ObjectDB 物件與 2 個資源的退出警告。

桌面的 `user://` 續用原名資料夾。Linux 實際呼叫 `OS.get_user_data_dir()` 和 `ProjectSettings.globalize_path("user://save.json")`，讀寫的都是 `$XDG_DATA_HOME/godot/app_userdata/金毛騎士/save.json`。Windows、macOS 設定保留原來的大寫 `Godot/app_userdata/金毛騎士`。行動版保留套件與 bundle ID，網頁版沿用同一網址。這輪的原生跨版讀檔驗證環境是 Linux；Windows、macOS、Android、iOS 的實際升級仍待實機檢查。[Godot 各平台的資料路徑](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

## 重現

兩份工程先以相同的 Godot 4.7.2 匯入。下列指令在候選版專案根目錄執行，`control` 指向 #31 的本地 checkout。使用新的空資料夾，腳本會核對真實預設路徑和原存檔指紋。

```sh
candidate="$PWD"
control="/path/to/pr-31"
probe="$candidate/tools/check_title_save.gd"
profile_root=$(mktemp -d)
for writer in "$control" "$candidate"; do
  export XDG_DATA_HOME
  XDG_DATA_HOME=$(mktemp -d "$profile_root/profile.XXXXXX")
  godot --headless --path "$writer" --fixed-fps 60 --script "$probe" -- write
  sha=$(sha256sum "$XDG_DATA_HOME/godot/app_userdata/金毛騎士/save.json" | cut -d' ' -f1)
  godot --headless --path "$candidate" --fixed-fps 60 --script "$probe" -- read "$sha"
done
```

畫面沿用上一輪 [正式標題的擷取條件](../../playfeel/lettering/README.md)，依同一腳本的 `title.png` 在畫格 75 比對。專案設定 11/11、匯出設定 11/11、正式畫面 7/7、翻譯與音效 5/5 在本機通過。
