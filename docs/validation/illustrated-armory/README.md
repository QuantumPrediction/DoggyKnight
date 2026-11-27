# 選角、工坊與實戰連攜

[直接試玩《黃金騎士》](https://doggy-knight-playtest.quantumprediction.chatgpt.site/)。在標題選「開始冒險」看三職的打法，或選「裝備與商店」看試穿。工坊可以切換「目前配裝」、「試穿」和「滿級」。試穿不花遊戲幣，確認交易才會改寫裝備。

| 職業 | 選角打法示意 | 在戰場上認裝備 |
| --- | --- | --- |
| 騎士 | [貼近揮劍、橫掃近敵](frames/class_knight.webp) | [普通一級](frames/knight-common1-standing.webp) · [史詩九級](frames/knight-epic9-standing.webp) |
| 法師 | [停步施法、爆破敵群](frames/class_mage.webp) | [普通一級](frames/mage-common1-standing.webp) · [史詩九級](frames/mage-epic9-standing.webp) |
| 弓箭手 | [拉開距離、直線穿射](frames/class_archer.webp) | [普通一級](frames/archer-common1-standing.webp) · [史詩九級](frames/archer-epic9-standing.webp) |

普通商店與史詩商場各有自己的櫥窗，角色試穿與戰場採用相同配件。普通裝備在 1、3、5 級改變外觀，史詩在 1、6、9 級改變；武器與護甲分別讀取已穿上的物品。角色在本章達 4、8 級時另獲佩章。首章「挑戰更多敵人」使 1-1、1-2 各加派四隻敵方稻草人，盾犬仍會為玩家攔箭。標題省去「製作名單」入口，六章通關的謝幕及授權仍可閱讀。

[普通商店](frames/shop_01_common.webp) · [普通裝備試穿](frames/shop_02_try_lv1.webp) · [史詩商場](frames/shop_05_epic.webp) · [史詩滿級試穿](frames/shop_06_epic_max.webp) · [穿戴對照](frames/worn-comparison.webp)

## 三擊後的攻擊組合

三職都能在正常升級時選擇三項戰技，各可學三級。同一次揮劍、穿透或濺射只算一下普通命中。空揮、必殺技及附加攻擊不能替自己重新計數。

| 選擇 | 實際戰鬥行為 |
| --- | --- |
| 連雷符 | 從首先命中的敵人向另一名近敵跳雷。 |
| 彗星印 | 標記命中處，0.34 秒後打擊仍在附近的敵人，最多三個。敵人可以走開。 |
| 迴風刃 | 沿原攻擊方向穿過目標，再擊中最多兩名新敵人。 |
| 連雷符＋迴風刃 | 雷可由第二名敵人再跳一人。 |
| 連雷符＋彗星印 | 原本的星擊打中後，向另一個目標跳雷。 |
| 迴風刃＋彗星印 | 第一個被風刃擊中的新目標會留下第二顆較小的星。 |

升級卡提前顯示配搭效果。進化卡與已選路線的推薦卡保留優先位置。[實際升級卡](frames/skill-card.webp) · [跳雷](frames/skill-lightning.webp) · [風刃再落星](frames/skill-wind-star.webp)

## 驗證範圍

選角與工坊來自正常標題入口。六種姿勢的穿戴比較固定同一場地、鏡頭及角色位置，裝備是展示存檔。三張戰技畫面則來自法師 seed 7 正式遊戲的正常選卡和命中。選角插畫呈現打法，戰鬥截圖呈現遊戲實際繪製的畫面。已保存初版[卡圖過大](frames/failed-skill-card.webp)、[櫥窗文字遮住商品](frames/failed-cabinet-caption.webp)及[滿級操作越界](frames/failed-shop-safe-area.webp)的失敗樣本。[畫面指紋與尺寸](frames/index.json) · [安全區座標](frames/shop-layout.json)

[法師 seed 7 戰報](runs/mage7-techniques.jsonl)使用新戰技優先策略，[弓箭手 seed 19 戰報](runs/archer19-route.jsonl)採用既有路線優先策略。兩條均從空存檔完成 36 關，記錄所有試次。法師、弓箭手分別有 515 與 350 次以至少兩種戰技同時發動，其中三種齊備的為 476 與 209 次。這是發動次數，每次的追加傷害仍取決於敵人的位置。兩路重啟後完成狀態都正確。與先前工程版本逐行比較，兩路各只有進入、離開片尾的 tick 不同。[逐路統計與差異](runs/summary.json) · [網頁引擎與資料指紋](web.json)目標玩家仍為零，手機實玩、持續幀時間、外觀辨識率、難度、留存及市場反應待驗。

重跑使用 Godot 4.7.2，先執行 `bash tools/run_tests.sh`。完整戰役沿用[六章指令](../six-episode-campaign/README.md)，法師指定 `--build=techniques`，弓手指定 `--build=route`。繪圖驗證要用可繪製的顯示器及全新專用存檔，輸出在 `ART_CAPTURE_DIR` 或 `WORN_GEAR_DIR`。

整合全套 **1,039/1,039**，零腳本錯誤、零損壞測試檔。裝備分組 56/56、戰技 9/9、選角 10/10。先前四個測試失敗，涉及舊圖集預期、空節點判斷與翻譯鍵；後續亦發現舊瀏海測試仍嘗試讀取已移除的標題按鈕。它現在檢查玩家實際可開啟的工坊。首輪技能卡與商店畫面的失敗另存於上方。原生結束時仍報引擎資源未釋放。

圖中升級佩章的獨立比較固定武器、護甲、職業、姿勢與鏡頭，只切換本章等級。三個職業、兩種裝備、六個姿勢各在 Lv1、4、8 繪製，共 108 張，原生 PNG 的 SHA-256 已保存。工坊在空裝、普通、史詩及模擬瀏海的 8 個檢查點，櫥窗文字與人物分開，固定交易按鈕完整在安全區；普通和史詩商店首屏各有三件可點商品。
