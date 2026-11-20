# 整合進度：繪本美術重製

更新：2026-11-18。分支 `codex/storybook-art-overhaul`，接續 Windows PR #9。

| 欄位 | 狀態 |
| --- | --- |
| 已完成 | 原遊戲整合 28 個新圖集／圖片：36 戰場、30 角色、38 劇情頁、六章營地、技能／特效／HUD、三種小遊戲；新增美術巡覽；Windows EXE／ZIP |
| 回歸 | Godot 4.7.2 完整 782 項測試：0 失敗、0 損壞檔案。另以真實 renderer 檢查 23 張遊戲畫面（含 EXE 資料包正式啟動與第一關） |
| 打包 | Windows x64 Release 191,347,408 bytes；資料包的 36 關、四位同伴、28 張新 PNG 及正式 UI 均可載入，測試場景排除；ZIP 123,555,620 bytes，CRC 與內含 EXE SHA-256 核對通過 |
| 重要修正 | 空白 ScrollContainer 樣式保持原尺寸、底板不遮對白、技能說明與標記不重疊、阿瓦隆圖集不漏出下一列羽飾、休息金毛與營火分開 |
| 進行中 | 真人美術／操作試玩回饋 |
| 被甚麼卡住 | 沒有 Windows 實機人工試玩；沒有手機效能檢查。Linux renderer 已可使用，上一輪遠端畫面障礙已繞過 |
| 下一步 | 依試玩回饋精修動作連貫度、敵人可讀性及螢幕比例，再進行 Steam 玩法切片 |
| 需要擁有人決定的事 | 本輪沒有額外決定；可直接下載試玩 |

EXE SHA-256：`aa1604fd9a6bc69a32bf48d11feb2b80020d835542eec89ac9bd450f16867319`。

完整測試命令：`GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=900 tools/run_tests.sh`。

圖形驗證：`tools/capture_illustrated.gd`；Xorg + Mesa llvmpipe，540×960。最後額外針對營地／技能修正重拍 UI。另以相同 Linux Godot 的 `--main-pack` 讀取 Windows EXE，從 `game/flow/main.tscn` 啟動正式標題、新遊戲、劇情略過和第一關，得到 `PACK_RENDER_OK`。這不等同原生 Windows 執行。

自動測試與快速結束時仍有既有的資源釋放警告；本輪沒有宣稱消除這些問題。沒有重跑六章全通關機器人；上一輪的六章完成紀錄與 6-5 重試資料只作歷史參考，不能冒充本輪新結果。

詳細範圍與剩餘限制見 [ART_REDESIGN.md](../ART_REDESIGN.md)。
