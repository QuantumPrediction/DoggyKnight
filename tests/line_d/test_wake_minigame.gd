extends TestCase
## v2.6 DV3:小遊戲「叫醒騎士」與第二、三章營地的小遊戲輪流。時間用 step() 精確推進。

const WAKE_SCENE := preload("res://game/minigames/wake/wake_minigame.tscn")
const CAMP_SCENE := preload("res://game/camp/camp.tscn")

var _game: WakeMinigame
var _camp: Camp


func before_each() -> void:
	GameState.reset_run()
	GameState.chapter = 1
	if _game != null and is_instance_valid(_game):
		_game.free()
	_game = WAKE_SCENE.instantiate() as WakeMinigame
	_game.auto_start = false
	var cfg := (_game.config as WakeMinigameConfig).duplicate() as WakeMinigameConfig
	cfg.rng_seed = 2026
	_game.config = cfg
	add_child(_game)
	_game.set_process(false)


func after_each() -> void:
	if AppLifecycle.is_in_background():
		AppLifecycle.simulate_foreground()
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	await wait_frames(1)
	GameState.chapter = 1
	GameState.reset_run()


func _start_playing() -> void:
	_game.start()
	_game.step(_game.config.countdown_sec + 0.001)


## 每個音符都在「音符時間 + offset」點下去。傳回每一下的判定。
func _play_every_note(offset: float) -> Array[int]:
	var hits: Array[int] = []
	for i in _game.notes.size():
		var note := _game.notes[i]
		var wait := float(note["time"]) + offset - _game.play_elapsed
		if wait > 0.0:
			_game.step(wait)
		if int(note["result"]) != WakeMinigame.Hit.NONE:
			hits.append(int(note["result"]))
			continue
		hits.append(_game.tap_lane(int(note["lane"])))
	return hits


func _finish() -> void:
	_game.step(_game.time_left + 0.01)


# --- 譜面 ---

func test_chart_is_fair_and_repeatable() -> void:
	var cfg := _game.config as WakeMinigameConfig
	var a := WakeMinigame.build_chart(cfg, _rng(7))
	var b := WakeMinigame.build_chart(cfg, _rng(7))
	assert_eq(a["notes"], b["notes"], "同一個種子,同一份譜面")
	for seed in [1, 2, 3, 4, 5, 99, 2026]:
		var chart := WakeMinigame.build_chart(cfg, _rng(seed))
		var notes: Array = chart["notes"]
		assert_true(notes.size() >= 14, "種子 %d:音符夠多(%d)" % [seed, notes.size()])
		var last_time := -1.0
		var run := 0
		for i in notes.size():
			var n: Dictionary = notes[i]
			var t := float(n["time"])
			assert_true(t > last_time, "依時間排序")
			assert_true(t >= cfg.first_beat_sec - 0.001, "第一拍之後")
			assert_true(t <= cfg.duration_sec - cfg.last_note_margin_sec + 0.001, "時間到之前")
			assert_true(int(n["lane"]) >= 0 and int(n["lane"]) < cfg.lane_count)
			if i > 0 and int(n["lane"]) == int(notes[i - 1]["lane"]):
				run += 1
			else:
				run = 0
			assert_true(run < 2, "種子 %d:不會連續三下叫同一位" % seed)
			if i > 0:
				assert_true(t - last_time >= 0.2, "兩下之間至少 0.2 秒(手機上點得到)")
			last_time = t
		# 速度越來越快
		var beats: PackedFloat32Array = chart["beats"]
		assert_true(beats[1] - beats[0] > beats[beats.size() - 1] - beats[beats.size() - 2], "後面比前面快")


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


# --- 判定與分數 ---

func test_perfect_play_gets_100_and_three_stars() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	GameState.vigor = 10
	_start_playing()
	var hits := _play_every_note(0.0)
	for h in hits:
		assert_eq(h, WakeMinigame.Hit.PERFECT)
	assert_eq(_game.perfects, _game.notes.size())
	assert_eq(_game.best_combo, _game.notes.size(), "一直連擊")
	assert_eq(_game.points, _game.max_points, "拿到全部點數")
	_finish()
	assert_eq(_game.score, 100)
	assert_eq(_game.grade, 3)
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args()[0], &"wake", "minigame_finished 的 id")
	assert_eq(GameState.next_level_bonus, 0.15, "和其他小遊戲一樣影響下一關加成")
	assert_true(GameState.vigor > 10, "活力回復")
	assert_eq(_game.rewards.get("snacks", 0), 10, "零食")
	assert_true(_game.is_knight_awake(0) and _game.is_knight_awake(2), "三星:大家醒來歡呼")


func test_good_timing_is_two_stars() -> void:
	_start_playing()
	var hits := _play_every_note(0.11)
	for h in hits:
		assert_eq(h, WakeMinigame.Hit.GOOD, "慢了 0.11 秒:好!")
	_finish()
	assert_eq(_game.goods, _game.notes.size())
	assert_eq(_game.grade, 2, "全部「好!」= 兩顆星(%d 分)" % _game.score)


func test_doing_nothing_is_zero() -> void:
	_start_playing()
	_finish()
	assert_eq(_game.misses, _game.notes.size(), "全部沒叫醒")
	assert_eq(_game.points, 0)
	assert_eq(_game.grade, 0)
	assert_false(_game.is_knight_awake(1), "大家又睡著了")


func test_early_tap_is_a_miss_and_spam_breaks_combo() -> void:
	_start_playing()
	var first := _game.notes[0]
	var lane := int(first["lane"])
	_game.step(float(first["time"]) - 0.22 - _game.play_elapsed)
	assert_eq(_game.tap_lane(lane), WakeMinigame.Hit.MISS, "太早點:沒叫醒(不能亂點)")
	assert_eq(int(first["result"]), WakeMinigame.Hit.MISS)
	assert_eq(_game.misses, 1)
	# 沒有音符的時候亂點:算亂點,打斷連擊
	var second := _game.notes[1]
	_game.step(float(second["time"]) - _game.play_elapsed)
	assert_eq(_game.tap_lane(int(second["lane"])), WakeMinigame.Hit.PERFECT)
	assert_eq(_game.combo, 1)
	var other := (int(second["lane"]) + 1) % 3
	var far := _game.next_note_time(other)
	if far < 0.0 or far - _game.play_elapsed > 0.3:
		assert_eq(_game.tap_lane(other), WakeMinigame.Hit.NONE, "附近沒有音符")
		assert_eq(_game.stray_taps, 1)
		assert_eq(_game.combo, 0, "亂點打斷連擊")


func test_combo_bonus_every_five() -> void:
	_start_playing()
	var cfg := _game.config as WakeMinigameConfig
	for i in 5:
		var n := _game.notes[i]
		_game.step(float(n["time"]) - _game.play_elapsed)
		_game.tap_lane(int(n["lane"]))
	assert_eq(_game.points, 5 * cfg.perfect_points + cfg.combo_bonus, "連擊 5 下多 %d 點" % cfg.combo_bonus)
	assert_eq(WakeMinigame.max_points_for(10, cfg), 10 * cfg.perfect_points + 2 * cfg.combo_bonus)


func test_tapping_wakes_the_knight_with_feedback() -> void:
	Haptics.reset_for_tests()
	_start_playing()
	var n := _game.notes[0]
	var lane := int(n["lane"])
	assert_false(_game.is_knight_awake(lane), "打瞌睡")
	_game.step(float(n["time"]) - _game.play_elapsed)
	_game.tap_lane(lane)
	assert_true(_game.is_knight_awake(lane), "跳起來醒了")
	assert_eq(Haptics.last_kind, &"light", "輕震")
	_game.step((_game.config as WakeMinigameConfig).wake_sec + 0.01)
	assert_false(_game.is_knight_awake(lane), "又打起瞌睡")


func test_touch_in_a_column_hits_that_knight() -> void:
	_start_playing()
	var n := _game.notes[0]
	var lane := int(n["lane"])
	_game.step(float(n["time"]) - _game.play_elapsed)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = _game.pad_rect(lane).get_center()
	_game._unhandled_input(touch)
	assert_eq(int(n["result"]), WakeMinigame.Hit.PERFECT, "點按鈕墊")
	var m := _game.notes[1]
	_game.step(float(m["time"]) - _game.play_elapsed)
	touch.position = _game.knight_head(int(m["lane"]))
	_game._unhandled_input(touch)
	assert_eq(int(m["result"]), WakeMinigame.Hit.PERFECT, "點騎士本人也可以")
	for i in 3:
		assert_eq(_game.lane_at(_game.pad_rect(i).get_center().x), i)


func test_pauses_when_app_goes_to_background() -> void:
	_start_playing()
	_game.step(1.0)
	var before := _game.time_left
	var elapsed := _game.play_elapsed
	AppLifecycle.simulate_background()
	assert_eq(_game.state, MinigameBase.State.PAUSED, "切到背景就暫停")
	_game.step(5.0)
	assert_almost_eq(_game.time_left, before, 0.0001, "暫停時計時停止")
	assert_almost_eq(_game.play_elapsed, elapsed, 0.0001, "節拍也停住")
	assert_eq(_game.misses, 0, "暫停時圈圈不會過期")
	assert_eq(_game.tap_lane(0), WakeMinigame.Hit.NONE, "暫停時點不算")
	AppLifecycle.simulate_foreground()
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(90, 200)
	_game._unhandled_input(tap)
	assert_eq(_game.state, MinigameBase.State.PLAYING, "點一下繼續")


func test_layout_fits_every_phone() -> void:
	var root := get_tree().root
	var original := root.size
	for phone: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2400), Vector2i(1179, 2556), Vector2i(750, 1334)]:
		root.size = phone
		ScreenFit.call(&"_refit")
		await wait_frames(2)
		_game._relayout()
		var size := SafeArea.get_screen_size()
		var safe := SafeArea.get_safe_rect()
		var cfg := _game.config as WakeMinigameConfig
		for i in 3:
			var pad := _game.pad_rect(i)
			assert_true(safe.encloses(pad), "%s:按鈕墊 %d 在安全區內" % [size, i])
			assert_true(pad.end.y <= safe.end.y - cfg.pad_bottom_margin + 0.01, "%s:避開底部手勢區" % size)
			assert_true(pad.size.x >= 44.0 and pad.size.y >= 24.0, "%s:按鈕墊夠大(%s)" % [size, pad.size])
			var head := _game.knight_head(i)
			assert_true(Rect2(Vector2.ZERO, size).has_point(head + Vector2(0, -40)), "%s:騎士的羽飾在畫面內" % size)
			assert_true(head.y < pad.position.y - 40.0, "%s:騎士在按鈕墊上面" % size)
		var time_bar := _game._time_bar_rect()
		assert_true(_game.knight_head(1).y - 44.0 > time_bar.end.y, "%s:騎士不蓋住計時條" % size)
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)


func test_draws_every_state_without_errors() -> void:
	_game.start()
	_game.step(1.0)
	_game.queue_redraw()
	await wait_frames(1)
	_game.step(_game.config.countdown_sec)
	_play_every_note(0.0)
	_game.queue_redraw()
	await wait_frames(1)
	_finish()
	_game.step(_game.config.results_delay_sec + 0.1)
	assert_eq(_game.state, MinigameBase.State.RESULTS)
	_game.queue_redraw()
	await wait_frames(1)
	assert_true(_game._result_extra_lines()[0].contains(str(_game.perfects)), "評價畫面顯示完美次數")


func test_strings_exist_and_are_short() -> void:
	for key: String in ["UI_CAMP_MINIGAME_WAKE", "MINIGAME_WAKE_GO", "MINIGAME_WAKE_HINT", "MINIGAME_WAKE_SCORE",
			"MINIGAME_WAKE_RESULT", "MINIGAME_WAKE_COMBO", "MINIGAME_WAKE_SNORE", "MINIGAME_WAKE_CHEER"]:
		var text := tr(key)
		assert_ne(text, key, "%s 有文字" % key)
		assert_true(text.length() <= 26, key)
		assert_false(text.contains(","), "%s 用全形逗號" % key)
	var font := (_game.get_node("Hint") as Label).get_theme_font(&"font")
	var width := font.get_string_size(tr("MINIGAME_WAKE_HINT"), HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S).x
	assert_true(width <= 172.0, "提示一行放得下(%d)" % width)
	assert_true(tr("UI_CAMP_MINIGAME_WAKE").length() <= 10, "營地按鈕放得下")


# --- 營地輪流 ---

func _enter_camp(chapter: int, level_index: int) -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
		await wait_frames(1)
	GameState.chapter = chapter
	GameState.level_index = level_index
	_camp = CAMP_SCENE.instantiate() as Camp
	add_child(_camp)
	_camp.skip_story()
	for i in 60:
		if not _camp.is_story_playing():
			break
		await wait_frames(1)


func test_camp_alternates_minigames_from_chapter_two() -> void:
	var wake_path := "res://game/minigames/wake/wake_minigame.tscn"
	var scroll_path := "res://game/minigames/scroll/scroll_minigame.tscn"
	var expected := {[1, 1]: scroll_path, [1, 3]: scroll_path, [2, 1]: wake_path, [2, 3]: scroll_path,
		[3, 1]: scroll_path, [3, 3]: wake_path}
	for key: Array in expected:
		await _enter_camp(key[0], key[1])
		assert_eq(_camp.current_minigame_scene().resource_path, expected[key], "第 %d 章第 %d 次營地" % [key[0], _camp.camp_number()])
		var button := _camp.find_child("MinigameButton", true, false) as Button
		var want := tr("UI_CAMP_MINIGAME_WAKE") if expected[key] == wake_path else tr("UI_CAMP_MINIGAME")
		assert_eq(button.text, want, "按鈕文字跟著小遊戲")


func test_wake_round_trip_in_a_chapter_two_camp() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	await _enter_camp(2, 1)
	GameState.vigor = 20
	_camp.open_minigame()
	var game := _camp.get_minigame() as WakeMinigame
	assert_not_null(game, "第二章第一次營地:叫醒騎士")
	game.set_process(false)
	game.step(game.config.countdown_sec + 0.001)
	for n: Dictionary in game.notes:
		var wait := float(n["time"]) - game.play_elapsed
		if wait > 0.0:
			game.step(wait)
		game.tap_lane(int(n["lane"]))
	game.step(game.time_left + 0.01)
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args()[0], &"wake")
	assert_eq(GameState.next_level_bonus, 0.15, "下一關攻擊 +15%")
	assert_true(GameState.vigor > 20)
	game.step(game.config.results_delay_sec + game.config.results_min_sec + 0.1)
	game.close()
	await wait_frames(1)
	assert_null(_camp.get_minigame(), "回到營地")
	assert_eq(_camp.last_grade, 3)
	_camp.open_minigame()
	assert_null(_camp.get_minigame(), "今晚玩過了")
