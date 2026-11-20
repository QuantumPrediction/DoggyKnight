# 0.4.0 裝備與續玩驗證

日期：2026-11-19（香港）。引擎：Godot 4.7.2 stable Linux。

## 接續驗證：關卡重試配裝

本次找回上輪原始程式、美術和五張介面截圖，原驗證清單的 10 個檔案 SHA-256 全部吻合。新分支以 PR #11 的實際遠端提交為基礎，恢復後的來源樹與上輪本地樹完全一致。

新增情境：以 Lv.1 武器開始一關 → 回標題升至 Lv.5 → 續玩 → 倒下重試。修正前續玩使用 Lv.1，但重試錯誤使用 Lv.5；修正後兩者均保留關卡配裝，下一關才使用 Lv.5。

- 修正前：21 項定向測試、1 項失敗；日誌 `retry_equipment_before_fix.log` 保留重現證據。
- 修正後：21 項定向測試、0 失敗、0 損壞檔案，退出碼 0；日誌 `retry_equipment_after_fix.log`。
- 修正後完整回歸：**823 項、0 失敗、0 損壞檔案，退出碼 0**；完整日誌 `final_regression_823.log`。本次全部測試使用 `4.7.2.stable.official.ed1daf0bf`。被測程式／測試提交為 `ce576caae211cbfe5111fccfdebade8cf19c87f5`，之後僅補文件和證據。
- 下方原 820／20 項紀錄及五張截圖保留為上輪歷史。接續環境的 Xvfb 無法建立 Unix 顯示連線，因此本輪沒有重新擷取介面；UI 與素材未修改。下方截圖均為上輪同一套 UI 的實際 Godot 渲染，非新拍攝。

## 上輪自動檢查（歷史）

| 檢查 | 結果 | 紀錄 |
|---|---|---|
| 完整回歸 | 820 tests、0 failed、0 broken files、退出碼 0 | `regression_820.log` |
| 最終裝備定向檢查 | 20 tests、0 failed、0 broken files、退出碼 0 | `equipment_20.log` |
| 實際 OpenGL 介面擷取 | 5 張，540×960 與 360×640；無腳本錯誤 | `render.log`、`screenshots/` |
| 差異格式檢查 | `git diff --check` 通過 | 提交前執行 |

完整回歸完成後修正「從檢查點續玩進營地，換裝後出發」的旗標和 UI 錨點；最終定向檢查包含這個回歸案例，並另外測試長弓 Lv.9 的實際投射物貫穿。因此本輪有 20 個新增案例，但沒有宣稱最終版本 822 個案例在同一次完整執行中全過。

定向覆蓋：普通／史詩等級上限、金幣／寶石分開扣款、失敗交易不扣款、存檔寫入失敗回滾、職業和欄位限制、唯一寶物、損壞資料清理、1,000 次頭目結算的保底與重複品、套裝只算一次、數值重建不複利、觸發冷卻、真實法球與箭矢、同伴擋彈事件、護盾與清波治療、第一關續玩、當局技能／亂數還原、未結算零食回滾、重複結算拒絕、舊檔升級、營地換裝、UI 確認與返回、停用支付不發幣。

重現命令（`GODOT` 設為本機執行檔）：

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=900 tools/run_tests.sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=180 tools/run_tests.sh equipment
ART_CAPTURE_DIR=/absolute/output/path godot --path . --audio-driver Dummy --rendering-driver opengl3 --script res://tools/capture_equipment.gd
```

封存日誌僅移除行尾空白，保留所有警告、錯誤與測試結果。

`run_tests.sh` 使用獨立的 user data 目錄，不覆蓋真實玩家存檔。擷取需可用的圖形顯示器；本輪使用 Xvfb 和 llvmpipe。

## 截圖說明

截圖來自 Godot 實際介面，不是概念圖。為展示功能，擷取腳本注入金幣 2,600、寶石 120、星鐵 18、已收藏裝備與章節解鎖資料；這些不是真人遊玩所得或付款證據。

- `equipment_loadout.png`：騎士收藏與已裝備標記。
- `equipment_detail.png`：Lv.3 日誓之刃、目前效果、升級成本；下方可捲動到下一級及裝備按鈕。
- `equipment_arcade.png`：史詩商場收藏列表。
- `equipment_confirm.png`：指定物品的寶石確認視窗；確認畫面本身不扣款。
- `equipment_small.png`：360×640 下的相同確認畫面，確認與取消均可見。

## 已知限制

完整回歸仍含既有故事測試的 Lambda／訊號清理錯誤，以及退出時資源未釋放訊息；820 個斷言案例通過不等於日誌完全無錯誤。舊版本同類警告的對照保存在 `../0.3.0/`。初次完整回歸亦含新軍械庫的錨點警告，已在最後修正；最終 20 項定向日誌無這項警告。最終圖形擷取只有虛擬顯示器不支援 V-Sync 的警告。

沒有真人長期平衡、付費轉換或留存資料。沒有 Windows EXE 匯出、Steam／App Store 上架、真實付款、伺服器付費錢包、手機實機或完整手把驗證。本地寶石可用於測試，不能充當正式付費帳本。沒有把裝備美術替換到角色逐幀動作。

完整設計和數值見 [EQUIPMENT_SYSTEM_ZH.md](../../EQUIPMENT_SYSTEM_ZH.md)。檔案校驗見 `manifest.json`。
