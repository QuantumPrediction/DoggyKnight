# 1-4 神射與遊騎存檔驗證

2026-11-22（香港）。[無提示試玩入口與紀錄表](../scene-lifetime/archer-trial.md) · [事先固定的驗收條件](../../requests/20261122-INT-archer-guard-trial.md)

接續草稿 #23 的 `a6595b21a970c1f7b7586cb7d8e7e461863b7959`。先前將兩塊底板一同調淡的實驗，遊騎兩幀都未過門檻，神射只有一幀通過。這一輪補上遊騎試玩入口，供日後分別觀察兩條路線的選擇。正式 HUD 和戰鬥來源仍與 #23 相同。[撤回候選的紀錄](../detail-recovery/README.md)

## 從正常進度擷取

Godot `4.7.2.stable.official.ed1daf0bf` 在兩個乾淨帳戶分別從第一章起步。擷取場景沿用原有 bot 的全部決策。在 1-3 的正式過關處理完成後，直接複製磁碟上已提交的存檔。該時點已可繼續 1-4，開場對白仍未播放。擷取後讓同一輪跑到原定終點。

| 路線 | 1-4 存檔 SHA-256 | 完整工程戰報 SHA-256 | 保留的結局 |
| --- | --- | --- | --- |
| 神射 | `7066f2853ad0e9daa51c631feb7f985dbead60f16672f52ef5499ef6884124b5` | `c49e74cf9fe1b388f0037b3a05838cb126e8e2fd07823e684b2d16f53909f5f9` | 1-4 倒下三次 |
| 遊騎 | `c03fdbf9a16a464f7cb75626b32c765658746c0dec225d2aba99828f33f48ebc` | `5473b13873603a7fd20a4e167ec676a9432154b5fc04ee712a98c2ec965ffb5c` | 1-4 倒下三次 |

兩份完整戰報與各自的歷史檔案逐位元組相同。神射亦逐位元組重現原有試玩存檔。遊騎保留原局 89 活力、79 零食、打滾三級及自己的成長、生成亂數狀態。神射則有 97 活力、86 零食，兩者不能當成只改一個變數的平衡實驗。兩場都依原定倒下上限退出，程序代碼均為 1，報告欄位為 `down_limit`。[神射原始戰報](../r03a/anchors/archer_route0_s19_cautious.json) · [本次神射輸出](marksman.log) · [遊騎原始戰報](../r03a/anchors/archer_route1_s19_cautious.json) · [本次遊騎輸出](outrider.log)

## 玩家接手及存檔隔離

兩個入口都透過正式 Continue 載入。無視窗的整合測試逐路核對開場對白、活力、把戲及裝備，待敵人登場後送入移動輸入與 Q 鍵，確認同伴各接受一次呼喚。光是呼喚不會完成教學。重開遊騎場景後，前次試玩私有存檔中寫入的完成旗標不會帶到新場次。[三項專項測試輸出](focused.log)

另在已合併 #22 的 `d9188279e0b4720dd35b7b7532f42a9dbb6f4b8e` 建立乾淨工作樹，只帶入共用試玩腳本、遊騎場景、遊騎存檔及專項測試。兩個版本的兩份存檔、兩個場景、共用腳本與測試逐位元組相同。#22 原版遊戲也通過相同三項操作測試，日後能以同一起點比較同一路線。[#22 專項輸出](focused-base22.log)

另在同一份有既有檔案的合成玩家帳戶，同時開啟兩個無視窗場景，各自停留 180 幀退出，再跑上述互動測試。玩家原有的 `save.json`、`save.json.bak`、`save.json.tmp` 和 `playlog.jsonl` 三次計算 SHA-256 均相同。[隔離前後指紋與退出碼](profile-isolation.json)

完整回歸於全新工作樹執行。公開實作 [9b67f1b](https://github.com/QuantumPrediction/DoggyKnight/commit/9b67f1b365e98031bc96bc042e7875ae8b59f6f8) 與本地受測提交 `8ccb3bd04d0bef0b1d0b8b040e520f5ccecf2aef` 的完整 tree 同為 `7d088aebe14c1cd3bfe79296e4f5a563f14ebf20`。952 項通過，0 失敗、0 損壞檔案，退出碼 0。完整輸出 SHA-256 為 `90f1c565e02dd10238cbfd1a83d09c88f53748dcd16a51720c430af388453deb`。退出仍列出 33 個 ObjectDB 物件、24 個資源及 RID 警告。既有外框比較工具九項通過。[完整回歸](full.log) · [外框工具檢查](contour.log)

本機 Xorg 啟動時回報 `Cannot establish any listening sockets`，退出碼 1。本輪沒有新的原生畫面或真人場次。封存的遊騎護陣按鈕約 40.3%、神射戰術面板約 17.2% 均是與指定扇形外框的幾何重合，不能直接換算成玩家看到的比例。玩家自由操作後也未必遇到同一揮擊。

## 重跑

在 Linux 的儲存庫根目錄執行。以下會使用新的暫存帳戶，並逐份比對原始位元組。

```bash
(
  set -eu
  godot --headless --editor --import --path .
  trial_dir=$(mktemp -d)
  for route in 0 1; do
    account="$trial_dir/user-$route"
    mkdir -p "$account"
    status=0
    XDG_DATA_HOME="$account" godot --headless --path . --fixed-fps 60 \
      --max-fps 0 --disable-render-loop res://tests/integration/archer_entry_capture.tscn -- \
      --speed=1 --chapter=1 --class=archer --route="$route" --build=route --seed=19 \
      --gear=common1 --element=earth --policy=cautious --guard=reactive \
      --max-downs=3 --max-sim-seconds=1200 --report="$trial_dir/$route.json" || status=$?
    test "$status" -eq 1
    cmp "$trial_dir/$route.json" "docs/validation/r03a/anchors/archer_route${route}_s19_cautious.json"
  done
  entry="godot/app_userdata/金毛騎士/archer_1_4_entry.json"
  cmp "$trial_dir/user-0/$entry" tests/fixtures/archer_1_4_checkpoint.json
  cmp "$trial_dir/user-1/$entry" tests/fixtures/archer_1_4_outrider_checkpoint.json
)
TEST_TIMEOUT=900 bash tools/run_tests.sh test_archer_trial
TEST_TIMEOUT=900 bash tools/run_tests.sh
python3 -B tests/tools/test_hud_contour.py -v
```

如需在 #22 使用相同入口，先取得本分支，再於 #22 合併提交的獨立工作樹執行以下指令。原有神射存檔及場景已在 #22。

```bash
git restore --source=7d088aebe14c1cd3bfe79296e4f5a563f14ebf20 --worktree -- \
  tests/fixtures/archer_1_4_outrider_checkpoint.json \
  tests/integration/archer_1_4_trial.gd tests/integration/archer_1_4_outrider_trial.tscn \
  tests/integration/test_archer_trial.gd
TEST_TIMEOUT=900 bash tools/run_tests.sh test_archer_trial
```
