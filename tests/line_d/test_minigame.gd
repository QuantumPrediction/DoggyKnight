extends TestCase
## D2、D4:小遊戲框架與「拉扯王室卷軸」。時間用 step() 精確推進(不等真實時間)。

const SCROLL_SCENE := preload("res://game/minigames/scroll/scroll_minigame.tscn")

var _game: ScrollMinigame


func before_each() -> void:
	GameState.reset_run()
	# 上一個測試的小遊戲在這裡才釋放:after_each 之後測試框架還要對它的訊號做收尾。
	if _game != null and is_instance_valid(_game):
		_game.free()
	_game = SCROLL_SCENE.instantiate() as ScrollMinigame
	_game.auto_start = false
	var cfg := (_game.config as ScrollMinigameConfig).duplicate() as ScrollMinigameConfig
	cfg.rng_seed = 1234
	_game.config = cfg
	add_child(_game)
	_game.set_process(false)


func after_each() -> void:
	if AppLifecycle.is_in_background():
		AppLifecycle.simulate_foreground()
	GameState.reset_run()


func _start_playing() -> void:
	_game.start()
	_game.step(_game.config.countdown_sec + 0.01)


func test_countdown_then_playing() -> void:
	_game.start()
	assert_eq(_game.state, MinigameBase.State.COUNTDOWN)
	assert_almost_eq(_game.time_left, 15.0, 0.0001, "15 秒")
	_game.pull(50.0)
	assert_almost_eq(_game.pulled_px, 0.0, 0.0001, "倒數時滑動不算")
	_game.step(1.0)
	assert_almost_eq(_game.time_left, 15.0, 0.0001, "倒數時不扣遊戲時間")
	_game.step(2.1)
	assert_eq(_game.state, MinigameBase.State.PLAYING)


func test_timer_runs_and_finishes() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	_start_playing()
	_game.step(5.0)
	assert_almost_eq(_game.time_left, 10.0, 0.01)
	_game.step(10.5)
	assert_eq(_game.state, MinigameBase.State.ENDING, "時間到")
	assert_eq(finished.count, 1, "發出一次 minigame_finished")
	assert_eq(finished.last_args()[0], &"scroll")


func test_timer_pauses_on_app_backgrounded() -> void:
	_start_playing()
	_game.step(2.0)
	var before := _game.time_left
	AppLifecycle.simulate_background()
	assert_eq(_game.state, MinigameBase.State.PAUSED, "切到背景就暫停")
	_game.step(5.0)
	assert_almost_eq(_game.time_left, before, 0.0001, "暫停時計時停止")
	_game.pull(40.0)
	assert_almost_eq(_game.pulled_px, 0.0, 0.0001, "暫停時滑動不算")
	AppLifecycle.simulate_foreground()
	assert_eq(_game.state, MinigameBase.State.PAUSED, "回到前景仍然暫停,等玩家點一下")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(90, 200)
	_game._unhandled_input(tap)
	assert_eq(_game.state, MinigameBase.State.PLAYING, "點一下繼續")
	_game.step(1.0)
	assert_almost_eq(_game.time_left, before - 1.0, 0.0001, "繼續後計時恢復")


func test_resume_on_foreground_option() -> void:
	_game.config.resume_on_foreground = true
	_start_playing()
	AppLifecycle.simulate_background()
	assert_true(_game.is_paused())
	AppLifecycle.simulate_foreground()
	assert_false(_game.is_paused(), "設定為回到前景自動繼續")


func test_pause_during_countdown_keeps_countdown() -> void:
	_game.start()
	_game.step(1.0)
	AppLifecycle.simulate_background()
	_game.step(10.0)
	assert_almost_eq(_game.countdown_left, _game.config.countdown_sec - 1.0, 0.0001)
	_game.resume_game()
	assert_eq(_game.state, MinigameBase.State.COUNTDOWN, "回到倒數")


func test_swiping_down_pulls_scroll_and_scores_length() -> void:
	var cfg := _game.config as ScrollMinigameConfig
	_start_playing()
	_game.pull(10.0)
	assert_almost_eq(_game.pulled_px, 10.0 * cfg.pull_ratio, 0.0001)
	_game.pull(-30.0)
	assert_almost_eq(_game.pulled_px, 10.0 * cfg.pull_ratio, 0.0001, "向上滑不算")
	_game.pull(1000.0)
	assert_almost_eq(_game.pulled_px, (10.0 + cfg.max_pull_per_event) * cfg.pull_ratio, 0.0001, "一次最多算 max_pull_per_event")
	assert_eq(_game._compute_score(), floori(_game.pulled_px / cfg.px_per_score))


func test_ink_blot_stops_pulling_until_player_waits() -> void:
	var cfg := _game.config as ScrollMinigameConfig
	_start_playing()
	var stop_at := _game.next_ink_stop_at()
	while _game.ink_state == ScrollMinigame.Ink.NONE:
		_game.simulate_swipe(40.0)
	assert_eq(_game.ink_state, ScrollMinigame.Ink.STOP, "墨水漬到達咬住的位置")
	assert_almost_eq(_game.pulled_px, stop_at, 0.0001, "停在墨水漬前")
	assert_eq(_game.mistakes, 0, "把墨水漬拉到位置的那一下不算犯錯")
	_game.simulate_swipe(40.0)
	assert_almost_eq(_game.pulled_px, stop_at, 0.0001, "停住時拉不動")
	_game.step(cfg.ink_still_sec + 0.01)
	assert_eq(_game.ink_state, ScrollMinigame.Ink.PASSING, "停手夠久,墨水漬滑過去")
	_game.step(cfg.ink_pass_sec + 0.01)
	assert_eq(_game.ink_state, ScrollMinigame.Ink.NONE)
	assert_eq(_game.blots_passed, 1)
	assert_true(_game.pulled_px > stop_at)


func test_swiping_on_ink_costs_time_once_per_swipe() -> void:
	var cfg := _game.config as ScrollMinigameConfig
	_start_playing()
	while _game.ink_state == ScrollMinigame.Ink.NONE:
		_game.simulate_swipe(40.0)
	var before := _game.time_left
	_game.simulate_swipe(60.0, 10)
	assert_eq(_game.mistakes, 1, "一次滑動只罰一次")
	assert_almost_eq(_game.time_left, before - cfg.ink_penalty_sec, 0.0001, "扣時間")
	_game.simulate_swipe(60.0)
	assert_eq(_game.mistakes, 2, "再滑一次再罰")
	assert_eq(_game.ink_state, ScrollMinigame.Ink.STOP, "還是要停手")
	_game.simulate_swipe(3.0, 3)
	assert_eq(_game.mistakes, 2, "新的手勢但只是輕微抖動(少於 ink_swipe_tolerance_px)不算")


func test_finish_applies_rewards_and_emits() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	var local := watch_signal(_game.finished)
	GameState.vigor = 30
	GameState.satisfaction = 0
	_start_playing()
	_game.pulled_px = 245.0 * (_game.config as ScrollMinigameConfig).px_per_score
	_game.step(_game.config.duration_sec + 0.1)
	assert_eq(_game.score, 245)
	assert_eq(_game.grade, 3, "245 ≥ 240 是 3 級")
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args(), [&"scroll", 245, 3])
	assert_eq(local.count, 1)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "3 級回復 100%")
	assert_eq(GameState.satisfaction, 30)
	assert_almost_eq(GameState.next_level_bonus, 0.15)


func test_results_then_close() -> void:
	var closed := watch_signal(_game.closed)
	_start_playing()
	_game.step(_game.config.duration_sec + 0.1)
	_game.step(_game.config.results_delay_sec + 0.01)
	assert_eq(_game.state, MinigameBase.State.RESULTS, "結束動畫後顯示評價")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	_game._unhandled_input(tap)
	assert_eq(closed.count, 0, "評價剛出現時點一下不會跳過")
	_game.step(_game.config.results_min_sec + 0.01)
	_game._unhandled_input(tap)
	assert_eq(closed.count, 1, "看過評價後點一下關閉")


func test_swipe_zone_avoids_bottom_gesture_area() -> void:
	var cfg := _game.config as ScrollMinigameConfig
	var safe := SafeArea.get_safe_rect()
	assert_true(_game._swipe_zone.end.y <= safe.end.y - cfg.swipe_zone_bottom_margin + 0.01, "滑動範圍離底邊至少 %d" % cfg.swipe_zone_bottom_margin)
	assert_true(_game._swipe_zone.size.y >= 120.0, "滑動範圍夠長")
	_start_playing()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(safe.get_center().x, safe.end.y - 4.0)
	_game._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(0, 2)
	drag.relative = Vector2(0, 20)
	_game._unhandled_input(drag)
	assert_almost_eq(_game.pulled_px, 0.0, 0.0001, "從最底邊開始的手勢不算")
