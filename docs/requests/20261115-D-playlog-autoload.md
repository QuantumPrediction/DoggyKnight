# 註冊遊玩記錄 Autoload「PlayLog」

- 提出:D 線,2026-11-15
- 狀態:已完成

## 要改甚麼

在 `project.godot` 的 `[autoload]` 加一行(放在 `Sfx` 之後,必須在 `EventBus` 與 `GameState` 之後):

```
PlayLog="*res://platform/play_log.gd"
```

並在 `tests/core/test_project_settings.gd` 的 `test_autoloads()` 清單加入 `"PlayLog"`。

`platform/play_log.gd` 沒有 `class_name`(與 Autoload 同名會衝突),不需要任何設定,加入後就會開始記錄。
它只聽 EventBus 的 `level_started`、`trick_chosen`、`level_completed`、`level_failed`、`minigame_finished`,
不呼叫任何一線的程式。

## 為甚麼

DEV_PLAN 11 D8:每關的用時、勝負、所選把戲寫到本機記錄檔,供 M3 調整難度。
記錄要在整個遊戲期間持續聽訊號,所以必須是 Autoload;B 線的流程換場景時也不會中斷。

替代做法:由 B 線在 `game/flow/main.tscn` 加一個子節點。但這樣 B 線要依賴 D 線的檔案,而且沙盒場景都要各自加,較容易漏。

## 影響哪些線

- 只改 `project.godot` 與合約測試,四條線都不用改程式。
- 記錄檔 `user://playlog.jsonl` 不含識別碼、不上傳,隱私問卷仍可填「不收集資料」(見 `platform/README.md`)。

## 給擁有人的一句話說明

試玩時自動記下每關打了多久、輸贏、選了甚麼把戲,只存在手機上,方便之後調整難度。

## 結果

已完成(2026-11-15,整合):已註冊 Autoload `PlayLog`,`test_autoloads` 已加入檢查。
