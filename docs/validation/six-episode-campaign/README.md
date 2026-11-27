# 六章冒險與終幕

[直接玩《黃金騎士》](https://doggy-knight-playtest.quantumprediction.chatgpt.site/)。新存檔從石中劍開始。各章有六關及兩次營地。打完章末可直接出發，也可按「回標題」，下次按「繼續冒險」接上。本章把戲、等級重新起步，所選職業、裝備、訓練及通關紀錄隨行。

| 章 | 章末戰 | 原生遊戲畫面 |
| --- | --- | --- |
| 一 · 石中劍 | 黑騎士 | [第一章開場](frames/chapter-1.webp) |
| 二 · 圓桌騎士 | 綠騎士 | [第二章開場](frames/chapter-2.webp) |
| 三 · 湖中仙女 | 摩根娜 | [第三章開場](frames/chapter-3.webp) |
| 四 · 沉沒之國 | 章魚王 | [第四章開場](frames/chapter-4.webp) |
| 五 · 紅龍與白龍 | 紅龍、白龍同場 | [第五章開場](frames/chapter-5.webp) |
| 六 · 卡姆蘭之戰 | 莫德雷德 | [第六章開場](frames/chapter-6.webp) |

4-3 海盜船可跟崔斯坦踏準船身起伏，或到船頭搶救零食。5-5 火山口可跟高文踏過熱石，或折回拿補給。6-2 影營可借鬼火照亮補給，或把火引到武器上。三個場合保留原來的出現波次和選項數值，無盡試煉沿用原來的八項抽選。各個地點的抉擇現在會顯示自己的名稱。

<details>
<summary>第六章實戰及結局畫面（含劇透）</summary>

[最終頭目](frames/mordred.webp) · [第六章戰報](frames/sixth-victory.webp) · [湖畔圓桌](frames/homecoming.webp) · [全劇終](frames/the-end.webp) · [製作名單](frames/credits.webp)

</details>

## 同種子比較

對照為 #34 的 `de04fd387e36f946f28f0f1f6bc6bc6e60710564`，tree `a3bfaf1ed5d83e9b539e471b12cec8a0dfab088b`。各用獨立空白存檔、Godot 4.7.2、每秒 60 個物理幀、360×640 直向（180×320 遊戲座標）。兩版用相同職業、種子、移動政策及各自的路線，只用正式角色和遊戲可用的操作。舊版按章末操作回到標題時，對照允許從標題另啟下一章。

| 職業與種子 | #34 可重現的停點 | 六章完成版 |
| --- | --- | --- |
| 法師 7 · 路線 0 | 第 24 次勝利（4-6）按鈕中心無法前進。12 個戰報按鈕超出安全區 | 36 關、12 營地、791 擊倒、0 倒下，完成終幕 |
| 弓手 19 · 路線 1 | 第 12 次勝利（2-6）同樣停住。6 個戰報按鈕超出安全區 | 36 關、12 營地、784 擊倒、0 倒下，完成終幕 |

舊按鈕在邏輯 y=307–333，中心 y=320 已越過可點範圍。修正後長戰報可捲動，每路 36 個主要按鈕與 6 個章末次要按鈕的完整矩形均在安全區，章末兩個熱區相距 4 個邏輯像素。每路只從標題出發一次，五次直接跨章。第五章記錄紅、白龍各自的死亡，第六章兩句謝幕依序顯示後自動打開名單。關閉、重啟引擎，重新讀取的通關檔案與先前寫入的 SHA-256 相符。上述兩路曾分別在抓取終幕前完成，更新終幕後兩路的全部戰果與按鈕幾何按 tick 重比相符。

[法師完整里程碑](runs/finale-mage7.jsonl) · [弓手完整里程碑](runs/finale-archer19.jsonl) · [配對控制、八次探索嘗試、失敗與 SHA-256](runs/verification.json)

## 中斷、繪本與網頁

頭目倒下時，遊戲把掉落、零食、解鎖和待交接的章一起存入。回到標題、重開章末、在下章序幕關閉或在製作名單中斷，均可接續。下章第一個檢查點落盤後才清交接，最終章則在關閉名單時清除。舊檔缺少新欄位時照原進度載入。回歸包含重發獎勵、手動查看名單、結算雙擊、援軍進第二章、困難模式與角色保留的檢查。

六張開場畫面來自正常解鎖到 6-6 的法師存檔，每次從獨立副本重開相應章節。最後五張來自同一份自然入場檔重新打莫德雷德，經正式戰報走到謝幕。Linux X11／OpenGL Compatibility（Mesa llvmpipe）實際渲染 360×640，網頁展示檔用無損 WebP，逐張解碼核對 RGB。終幕以 GPT Image 繪製，測試把它放回遊戲的繪本頁閱讀。 [畫面及原稿指紋](frames/index.json)

正式 Web PCK 核對六份章資料、36 份關卡及前後對白、湖畔原畫、兩句終幕、翻譯及名單相關資源。瀏覽器檔案自檢編譯 WASM 並校驗資料。這次雲端瀏覽器的正常入口回報缺少 WebGL 2，戰鬥與畫面另於 Linux 原生驗證。離場仍有資源警告；歷史原生崩潰繼續獨立追蹤。真人樣本 0，Windows、手機、手把與通關後繼續遊玩的意願仍待驗收。[網頁版本與封包指紋](web.json)

## 重跑

先用 Godot 4.7.2 匯入專案。每路指定全新的 XDG_DATA_HOME 與尚未存在的 report 路徑，結束後在同一份 profile 以另一個程序執行讀檔檢查。

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 --resolution 360x640 --path . \
  res://tests/integration/six_episode_campaign.tscn -- --speed=1 --policy=escape \
  --guard=reactive --build=route --route=0 --class=mage --seed=7 \
  --verify-epilogue --report=/absolute/new/mage7.jsonl
godot --headless --fixed-fps 60 --path . --script res://tests/integration/check_six_episode_save.gd
```

弓手改用 `--class=archer --seed=19 --route=1`。原生截圖重播使用另一個專用 profile。

```sh
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 360x640 --fixed-fps 60 res://tests/integration/six_episode_gallery.tscn -- \
  --class=mage --seed=7 --gallery=/absolute/frames \
  --earned-save=/absolute/repo/docs/validation/six-episode-campaign/runs/portrait-candidate-mage7-6-6-entry-save.json
```
