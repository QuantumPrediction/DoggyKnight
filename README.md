# 金毛騎士 · DoggyKnight

金毛騎士帶著狗狗同伴冒險的像素動作遊戲。移動閃避、停下揮劍、升級選把戲、營地休息，再挑戰每章頭目。

目前有六章、36 關、四位同伴、12 個基本把戲與四個進化、營地小遊戲、訓練，以及通關後的困難模式與無盡試煉。內容與數值仍在試玩調整中。

## Windows 試玩

下載交付的 `DoggyKnight.exe`，雙擊即可啟動；遊戲資料已包含在執行檔內，無需安裝 Godot。這是 Windows x64 試玩版，目前保留直向畫面與原有章節解鎖流程。

| 操作 | 方法 |
| --- | --- |
| 移動 | WASD／方向鍵；也可按住滑鼠左鍵拖曳 |
| 攻擊 | 放開移動鍵或滑鼠，靠近敵人時自動揮劍 |
| 王者之劍 | 忠誠度滿時按 Space，或點右下角劍形按鈕 |
| 暫停／繼續 | Esc，或點畫面上的暫停按鈕 |
| 選技能、對白、營地小遊戲 | 使用滑鼠點選／拖曳 |

切換到其他視窗會暫停。回到遊戲後先放開移動鍵，再繼續操作。進度與設定只存在電腦本機；關卡中途退出不會保留當下敵人與位置，依原有關卡存檔流程恢復。

本次執行檔沒有數位簽章；Windows 是否顯示警告取決於系統設定。只使用專案擁有人提供的檔案，不必關閉防毒軟體。

## 開發與建置

- 引擎：**Godot 4.7.2 stable**，一般版，Compatibility renderer。
- 匯入 `project.godot`，主場景為 `game/flow/main.tscn`。
- 完整測試：`tools/run_tests.sh`；可用 `GODOT=/path/to/godot` 指定引擎。
- Windows：安裝對應版本的 export templates，執行 `export/build_windows.sh`；輸出在 `export/build/windows/DoggyKnight.exe`。也可在 Godot 的 Export 中選擇 `Windows Desktop`，匯出 Release。
- Android 與 iOS：見 [export/README.md](export/README.md)。
- 開發合約與歷史：[docs/DEV_PLAN.md](docs/DEV_PLAN.md)、[CLAUDE.md](CLAUDE.md)。
- 本輪接手紀錄：[docs/WINDOWS_HANDOVER.md](docs/WINDOWS_HANDOVER.md)。

## 授權

素材與第三方元件記錄見 [docs/licenses.md](docs/licenses.md)，遊戲內亦有製作名單與授權畫面。未另行授予整個遊戲的開源授權。
