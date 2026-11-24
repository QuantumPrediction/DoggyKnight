# 黃金騎士 · The Golden Knight 網頁試玩

[直接開始冒險](https://doggy-knight-playtest.quantumprediction.chatgpt.site/)

第一個選單可以選騎士、法師或弓箭手。「以此職業出征」按原有編隊開局。「迎戰援軍」在第一、第二關各加四隻稻草人；繼續冒險會保留這局的選擇。以 WASD、方向鍵或按住拖曳移動，停步後會自動攻擊射程內的敵人。Esc 或右上角按鈕可以暫停。關卡進度保存在同一瀏覽器的網站資料中，回來時選「繼續冒險」。清除網站資料會刪去這台裝置的存檔。

## 從原專案建置

使用 Godot 4.7.2 stable、相同版本的官方單執行緒 Web release 範本、Python 3 與 fontTools、ImageMagick 7，以及 Debian 的 `fonts-noto-cjk` 常規繁中黑體與宋體。環境變數 `GODOT` 可指定引擎路徑。在專案根目錄執行以下命令。

```sh
python3 export/build_web.py
node --test tests/web/*.test.cjs
```

把 `export/build/web/` 完整放到靜態 HTTPS 網站，入口為 `index.html`。此建置在暫存目錄重匯入美術和字體，使用遊戲原有的場景、AI、六章資料和存檔流程。大型繪本圖與庫存圖集使用 0.84 品質，近期動作圖、攻擊提示、特效及介面圖示保留無損。音樂優先沿用已有的 Ogg 版本，保留三首只有 WAV 的音軌。

引擎與遊戲資料拆成 17 個 gzip 檔，以內容指紋作檔名。在本版，全部靜態檔案合計 65,877,538 bytes，當中引擎壓縮後 10,115,449 bytes、遊戲資料 54,637,574 bytes。一般開局會直接載入標題。若要診斷公開站，可另外執行[檔案檢查](https://doggy-knight-playtest.quantumprediction.chatgpt.site/?check=1)，它會讀回全套資料、比對 SHA-256 並在該瀏覽器編譯引擎。需要支援 WebGL 2 的瀏覽器才可遊玩。

## 試玩觀察

玩家可直接開啟上述公開連結。第一輪可直接用連結觀察首次開局；指定神射／遊騎場景仍沿用[既有無提示試玩流程](../docs/validation/scene-lifetime/archer-trial.md)。兩種場次應分開記錄。首次進入可操作畫面的時間、玩家選的職業、哪一刻不明白下一步，以及是否主動再開一局，是下一輪要收集的資訊。
