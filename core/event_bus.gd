extends Node
## 全域事件匯流排(Autoload 名稱:EventBus)。DEV_PLAN 4.1。
##
## 所有跨線通訊只走這裡的訊號。這是凍結的合約:四條線不得修改,
## 要改請在 docs/requests/ 提出申請。tests/core/test_event_bus.gd 會核對每個訊號的參數。

@warning_ignore_start("unused_signal")

# 戰鬥(A 線發出)
signal enemy_died(enemy_id: StringName, position: Vector2, exp_value: int)
signal player_damaged(amount: int)
signal vigor_changed(current: int, maximum: int)
signal loyalty_changed(current: float, maximum: float)
signal ultimate_used()
signal player_downed()                      # 活力歸零,金毛趴下睡著
signal boss_phase_changed(phase: int)
signal exp_collected(amount: int)          # 拾取經驗珠(原始值;exp_mult 由 B 線套用)

# 流程與成長(B 線發出)
signal level_started(level_id: StringName)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal level_completed(level_id: StringName)
signal level_failed(level_id: StringName)
signal exp_changed(current: int, needed: int)
signal leveled_up(new_level: int)
signal trick_offered(options: Array)        # Array[TrickData]
signal trick_chosen(trick_id: StringName)   # 由 C 線的選擇介面發出
signal game_paused(paused: bool)            # B 線發出;C 線暫停畫面聽這個

# 介面(C 線發出)
signal ultimate_requested()                 # HUD 的必殺技按鈕被按下;A 線執行後發 ultimate_used
signal resume_requested()                   # 暫停畫面的「繼續」
signal quit_to_title_requested()            # 暫停畫面的「回標題」

# 營地與小遊戲(D 線發出)
signal camp_entered()
signal minigame_finished(minigame_id: StringName, score: int, grade: int)  # grade 0 至 3
signal camp_left()

# 手機生命週期(core/app_lifecycle.gd 發出)
signal app_backgrounded()                   # 切到背景、來電、鎖螢幕
signal app_foregrounded()
signal back_requested()                     # Android 返回鍵或返回手勢(桌面:Esc)

@warning_ignore_restore("unused_signal")
