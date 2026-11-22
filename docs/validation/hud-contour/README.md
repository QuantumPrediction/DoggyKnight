# 本輪接續狀態

2026-11-22：曾在原生 Linux 完成四路比較，單一 0.60-alpha 候選三個關鍵畫面未過，已撤回。發布前執行環境重置，原始捕捉檔案遺失；以下「沒有新渲染」描述僅屬最初診斷階段。現況、歷史觀察與保存限制見 [本輪記錄](../detail-recovery/README.md)。正式 HUD 與公開基準相同，既有比較器保留；沒有將遺失的原始圖像視作此 PR 中可覆核的證據。

---

## 初始診斷階段

# 固定戰鬥介面的預警外框量測

已核對預設分支 `claude/sleepy-hawking-8cvkvl` 的 #22 合併提交 `d9188279e0b4720dd35b7b7532f42a9dbb6f4b8e`、tree `13415a50ebb70983e623f42c2aeabc79e3a3eec0`。本包只加驗證工具。神射戰術面板與遊騎護陣按鈕分別與所選外框幾何重合 17.2346% 與 40.3241%。岩石、角色、特效及介面仍可能遮擋；沒有測得玩家的觀看或反應。[固定比較與失敗條件](../../requests/20261122-INT-hud-contour.md) · [原版畫面指紋](../guard-success-toast/frame-hashes.csv) · [舊重播的實際幾何](../scarecrow-render-cues/observations.json)

| 場景 | 從已封存多邊形算出的可抽樣邊點 | 本輪新渲染／真人 |
| --- | --- | --- |
| 神射 t4989、4990 | 每幀 27 個不同中心畫素 | 0／0 |
| 遊騎 t374、375 | 每幀 61 個不同中心畫素 | 0／0 |

每幀用兩遍完整重播。正常畫面保留全部圖層，另一次只在繪圖前收起選定攻擊的 CanvasItem RID，畫完即還原；節點的正式可見狀態、攻擊判定和控件維持原狀。正常與移除版的差會消去兩者共有的前景裝飾。外框中央再與兩側經相同處理的樣本比較，減少把單純底色或填色當作外框的可能。每個路線的起手另以先前記錄的露出畫素驗證移除有效，扇形加三畫素以外不得出現任何差異。門檻通過時仍須審閱正常原畫的文字、按鈕及危險警示。

本機 Godot 4.7.2 匯入通過，9 個合成／封存／缺欄位防護檢查、8 個正式預警回歸及完整 936 項回歸通過。完整回歸退出仍報 33 個物件、24 個資源及 RID 警告。70 個封存 PNG 指紋索引、兩組完整戰報及 5,723／6,422 行逐幀記錄已核對。獨立覆核發現早期比較器可能讓四份同時缺欄位的 manifest 通過；最終版要求完整且非 null 的 frame、HUD、前景 schema，並逐一核對 #22 留存的十個 HUD／持久化錨點。執行環境沒有可連接的 X11 顯示，啟動虛擬 Xorg 時本地 socket 被拒絕。沒有產生新的原畫、改動 HUD、驗收像素增益或觀察到玩家。兩路原有三次倒下仍保留。

## 重跑

先在本工作提交的獨立工作樹執行以下檢查（Python 3.11+、Pillow、NumPy）。

```sh
python3 -B tests/tools/test_hud_contour.py -v
python3 -B tools/check_hud_contour.py --check-archive
TEST_TIMEOUT=900 bash tools/run_tests.sh warning_readout
```

有相同 X11、llvmpipe LLVM 19.1.7、360×640 環境後，基線使用本包的測量工具及 #22 的全套正式來源。候選由該工作樹另開，只嘗試調整兩塊底板的填色透明度。兩份來源各跑下列兩條命令，指定四個全新的輸出路徑。兩份來源之間須使用完全相同的測量工具。次序如下，先以基線工作樹執行前兩條，切到候選工作樹才執行後三條。

```sh
python3 -B tools/capture_scarecrow_cues.py --out /tmp/contour-base
python3 -B tools/capture_scarecrow_cues.py --without-selected-ink --out /tmp/contour-base-muted
python3 -B tools/capture_scarecrow_cues.py --out /tmp/contour-candidate
python3 -B tools/capture_scarecrow_cues.py --without-selected-ink --out /tmp/contour-candidate-muted
python3 -B tools/check_hud_contour.py /tmp/contour-base /tmp/contour-base-muted /tmp/contour-candidate /tmp/contour-candidate-muted
```

退出 2 表示證據缺漏或不能配對，退出 1 表示像素門檻失敗，退出 0 只表示像素門檻通過。保存四個輸出目錄、所有失敗及 JSON 判定。另覆核候選 diff 是否只改底板填色、保留原前景與操作條件，再並排檢視前景、觸控及遮擋。兩個案例不能推論真人可讀性；可沿用[五分鐘無提示試玩](../scene-lifetime/archer-trial.md)觀察。
