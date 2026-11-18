extends TestCase
## v2.7 DW3:小遊戲「接住跳跳魚」(FishMinigame)。時間用 step() 精確推進;自動試玩用 bot_step()。

const FISH_SCENE := preload("res://game/minigames/fish/fish_minigame.tscn")
const FRAME: float = 1.0 / 60.0

var _game: FishMinigame


func before_each() -> void:
	GameState.reset_run()
	GameState.chapter = 4
	_new_game(2026)


func after_each() -> void:
	if AppLifecycle.is_in_background():
		AppLifecycle.simulate_foreground()
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
	await wait_frames(1)
	GameState.chapter = 1
	GameState.reset_run()


func _new_game(seed: int) -> void:
	if _game != null and is_instance_valid(_game):
		_game.free()
	_game = FISH_SCENE.instantiate() as FishMinigame
	_game.auto_start = false
	var cfg := (_game.config as FishMinigameConfig).duplicate() as FishMinigameConfig
	cfg.rng_seed = seed
	_game.config = cfg
	add_child(_game)
	_game.set_process(false)


func _cfg() -> FishMinigameConfig:
	return _game.config as FishMinigameConfig


func _start_playing() -> void:
	_game.start()
	_game.step(_game.config.countdown_sec + 0.001)


## 像整合試玩機器人一樣每格呼叫 bot_step(),玩到 until 秒(預設玩到時間到)。
func _bot_play(until: float = INF) -> void:
	while _game.state == MinigameBase.State.PLAYING and _game.play_elapsed < until:
		_game.bot_step(FRAME)
		_game.step(FRAME)


## 一格一格推進,直到 item 被判定;每格前把金毛放在 x(測試用:直接設定位置)。
func _hold_until_judged(item: Dictionary, x: float) -> int:
	for i in 600:
		if int(item["result"]) != FishMinigame.Hit.NONE:
			break
		_game.goldie_x = x
		_game.target_x = x
		_game.step(FRAME)
	return int(item["result"])


func _good_items() -> Array[Dictionary]:
	return _game.items.filter(func(it: Dictionary) -> bool: return int(it["kind"]) != FishMinigame.Kind.BOOT)


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


# --- 時間表 ---

func test_chart_is_fair_and_repeatable() -> void:
	var cfg := _cfg()
	var width := 136.0
	var a := FishMinigame.build_chart(cfg, _rng(7), width)
	var b := FishMinigame.build_chart(cfg, _rng(7), width)
	assert_eq(a, b, "同一個種子,同一份時間表")
	var boots := 0
	var goldens := 0
	for seed in [1, 2, 3, 4, 5, 6, 7, 8, 99, 2026]:
		var chart := FishMinigame.build_chart(cfg, _rng(seed), width)
		assert_true(chart.size() >= 14 and chart.size() <= 28, "種子 %d:東西的數目合理(%d)" % [seed, chart.size()])
		var last := -1.0
		var prev_x := width * 0.5
		var prev_t := 0.0
		var good: Array[Dictionary] = []
		for item in chart:
			var land := float(item["land"])
			assert_true(land > last, "依時間排序")
			assert_true(land >= cfg.first_land_sec - 0.001, "第一條之後")
			assert_true(land <= cfg.duration_sec - cfg.last_land_margin_sec + 0.001, "時間到之前全部落地")
			assert_true(float(item["flight"]) >= cfg.flight_end_sec - 0.001 and float(item["flight"]) <= cfg.flight_start_sec + 0.001)
			assert_true(float(item["u"]) >= 0.0 and float(item["u"]) <= 1.0)
			assert_true(float(item["launch_u"]) >= 0.0 and float(item["launch_u"]) <= 1.0)
			last = land
			match int(item["kind"]):
				FishMinigame.Kind.BOOT:
					boots += 1
					assert_true(land >= cfg.boot_from_sec, "一開始沒有靴子")
				FishMinigame.Kind.GOLDEN:
					goldens += 1
			if int(item["kind"]) == FishMinigame.Kind.BOOT:
				continue
			# 每條要接的魚都走得到(金毛的速度 × 時間)
			var x := float(item["u"]) * width
			assert_true(absf(x - prev_x) <= cfg.goldie_speed * (land - prev_t) + 0.5,
				"種子 %d:%.2f 秒的魚走得到(%.1f 像素 / %.2f 秒)" % [seed, land, absf(x - prev_x), land - prev_t])
			prev_x = x
			prev_t = land
			good.append(item)
		assert_true(good.size() >= 10, "種子 %d:要接的魚夠多(%d)" % [seed, good.size()])
		# 靴子不在「上一條魚到下一條魚」的路上
		for i in chart.size():
			if int(chart[i]["kind"]) != FishMinigame.Kind.BOOT:
				continue
			var before := 0.5
			for j in range(i - 1, -1, -1):
				if int(chart[j]["kind"]) != FishMinigame.Kind.BOOT:
					before = float(chart[j]["u"])
					break
			var after := before
			for j in range(i + 1, chart.size()):
				if int(chart[j]["kind"]) != FishMinigame.Kind.BOOT:
					after = float(chart[j]["u"])
					break
			var u := float(chart[i]["u"])
			var gap := cfg.catch_half_width * 2.0 / width
			assert_true(u <= minf(before, after) - gap + 0.0001 or u >= maxf(before, after) + gap - 0.0001,
				"種子 %d:靴子不擋路" % seed)
		# 越後面越快
		var first_gap := float(chart[1]["land"]) - float(chart[0]["land"])
		var last_gap := float(chart[-1]["land"]) - float(chart[-2]["land"])
		assert_true(first_gap > last_gap - 0.15, "後面比前面密(%.2f → %.2f)" % [first_gap, last_gap])
	assert_true(boots >= 5, "十份時間表裡有靴子(%d)" % boots)
	assert_true(goldens >= 3, "十份時間表裡有金魚(%d)" % goldens)


# --- 判定與分數 ---

func test_bot_catches_everything_for_100_and_three_stars() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	GameState.vigor = 10
	_start_playing()
	_bot_play()
	var good := _good_items()
	assert_eq(_game.caught, good.size(), "每條魚都接到")
	assert_eq(_game.perfects, good.size(), "全部「完美!」")
	assert_eq(_game.misses, 0)
	assert_eq(_game.boots, 0, "機器人不會接到靴子")
	assert_eq(_game.best_combo, good.size(), "一直連續")
	assert_eq(_game.points, _game.max_points, "拿到全部點數")
	assert_eq(_game.state, MinigameBase.State.ENDING, "時間到")
	assert_eq(_game.score, 100)
	assert_eq(_game.grade, 3)
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args()[0], &"fish", "minigame_finished 的 id")
	assert_eq(finished.last_args()[1], 100)
	assert_eq(GameState.next_level_bonus, 0.15, "和其他小遊戲一樣影響下一關加成(MinigameGrading)")
	assert_true(GameState.vigor > 10, "活力回復")
	assert_eq(_game.rewards.get("snacks", 0), 10, "零食")
	assert_eq(_game.goldie_animation(), &"victory", "三星:金毛舉著碗歡呼")


func test_bot_wins_on_every_seed() -> void:
	for seed in [1, 2, 3, 11, 42]:
		_new_game(seed)
		_start_playing()
		_bot_play()
		assert_eq(_game.score, 100, "種子 %d:機器人 100 分" % seed)
		assert_eq(_game.boots, 0, "種子 %d:沒有接到靴子" % seed)


func test_standing_still_is_not_enough() -> void:
	_start_playing()
	_game.step(_game.time_left + 0.01)
	assert_true(_game.misses > 0, "站著不動會漏接")
	assert_true(_game.grade <= 1, "站著不動最多一顆星(%d 分)" % _game.score)
	assert_ne(_game.goldie_animation(), &"victory")


func test_catch_window_perfect_good_miss() -> void:
	_start_playing()
	var cfg := _cfg()
	var good := _good_items()
	var first := good[0]
	var base_points := cfg.golden_points if int(first["kind"]) == FishMinigame.Kind.GOLDEN else cfg.fish_points
	assert_eq(_hold_until_judged(first, _game.item_x(first)), FishMinigame.Hit.PERFECT, "正中間:完美!")
	assert_eq(_game.points, base_points + cfg.perfect_bonus)
	var second := good[1]
	var points_before := _game.points
	assert_eq(_hold_until_judged(second, _game.item_x(second) + cfg.perfect_half_width + 3.0), FishMinigame.Hit.GOOD, "碗邊:好!")
	var second_points := cfg.golden_points if int(second["kind"]) == FishMinigame.Kind.GOLDEN else cfg.fish_points
	assert_eq(_game.points - points_before, second_points, "好!沒有完美的加分")
	assert_eq(_game.combo, 2)
	var third := good[2]
	assert_eq(_hold_until_judged(third, _game.item_x(third) + cfg.catch_half_width + 3.0), FishMinigame.Hit.MISS, "差太遠:噗通!")
	assert_eq(_game.misses, 1)
	assert_eq(_game.combo, 0, "漏接打斷連續")
	assert_eq(_game.caught, 2)


func test_combo_bonus_every_five() -> void:
	_start_playing()
	var cfg := _cfg()
	var expected := 0
	var good := _good_items()
	for i in cfg.combo_step:
		var item := good[i]
		_hold_until_judged(item, _game.item_x(item))
		expected += (cfg.golden_points if int(item["kind"]) == FishMinigame.Kind.GOLDEN else cfg.fish_points) + cfg.perfect_bonus
	assert_eq(_game.points, expected + cfg.combo_bonus, "連續 %d 條多 %d 點" % [cfg.combo_step, cfg.combo_bonus])
	assert_true(FishMinigame.max_points_for(_game.items, cfg) >= _game.points)


func test_boot_catch_is_cute_and_breaks_combo() -> void:
	# 找一份有靴子的時間表
	var seed := 0
	for s in range(1, 60):
		var chart := FishMinigame.build_chart(_cfg(), _rng(s), 136.0)
		if chart.any(func(it: Dictionary) -> bool: return int(it["kind"]) == FishMinigame.Kind.BOOT):
			seed = s
			break
	assert_true(seed > 0, "有一份時間表有靴子")
	_new_game(seed)
	Haptics.reset_for_tests()
	_start_playing()
	var boot: Dictionary = {}
	for item in _game.items:
		if int(item["kind"]) == FishMinigame.Kind.BOOT:
			boot = item
			break
	_bot_play(float(boot["land"]) - 0.1)
	var combo_before := _game.combo
	assert_true(combo_before > 0, "靴子之前已經接到幾條魚")
	assert_eq(_hold_until_judged(boot, _game.item_x(boot)), FishMinigame.Hit.BOOT, "站在靴子下面:接到靴子")
	assert_eq(_game.boots, 1)
	assert_eq(_game.combo, 0, "呸!連續中斷")
	assert_eq(Haptics.last_kind, &"light", "輕震(不是受傷)")
	assert_eq(_game.caught + _game.misses, _good_items().filter(func(it: Dictionary) -> bool:
		return int(it["result"]) != FishMinigame.Hit.NONE).size(), "接到靴子不算魚")
	# 其他靴子機器人都躲開
	_bot_play()
	assert_eq(_game.boots, 1)
	for item in _game.items:
		if int(item["kind"]) == FishMinigame.Kind.BOOT and item != boot:
			assert_eq(int(item["result"]), FishMinigame.Hit.DODGED, "躲開的靴子")


# --- 觸控 ---

func test_drag_moves_goldie_with_the_first_finger_only() -> void:
	_start_playing()
	var zone := _game.touch_zone()
	var range_x := _game.goldie_range()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(range_x.x + 10.0, zone.get_center().y)
	_game._unhandled_input(press)
	assert_eq(_game.target_x, range_x.x + 10.0, "按下:金毛往手指跑")
	for i in 30:
		_game.step(FRAME)
	assert_almost_eq(_game.goldie_x, range_x.x + 10.0, 0.5, "跑到手指的位置")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(zone.end.x - 1.0, zone.get_center().y)
	_game._unhandled_input(drag)
	assert_eq(_game.target_x, range_x.y, "拖到邊緣:金毛停在可以走的範圍內")
	# 第二根手指不影響
	var second := InputEventScreenTouch.new()
	second.pressed = true
	second.index = 1
	second.position = Vector2(zone.get_center().x, zone.get_center().y)
	_game._unhandled_input(second)
	var drag2 := InputEventScreenDrag.new()
	drag2.index = 1
	drag2.position = Vector2(range_x.x, zone.get_center().y)
	_game._unhandled_input(drag2)
	assert_eq(_game.target_x, range_x.y, "第二根手指不算")
	# 放開第一根之後,新的手指才算
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	_game._unhandled_input(release)
	second.position = Vector2(zone.get_center().x, zone.get_center().y)
	_game._unhandled_input(second)
	assert_eq(_game.target_x, zone.get_center().x, "放開後新的手指可以")
	# 最底的系統手勢區不算
	var low := InputEventScreenTouch.new()
	low.pressed = true
	low.index = 2
	low.position = Vector2(range_x.x + 5.0, SafeArea.get_safe_rect().end.y - 4.0)
	release.index = 1
	_game._unhandled_input(release)
	_game._unhandled_input(low)
	assert_eq(_game.target_x, zone.get_center().x, "螢幕最底(手勢區)按下不算")
	assert_true(zone.end.y <= SafeArea.get_safe_rect().end.y - _cfg().touch_bottom_margin + 0.01)


func test_pauses_when_app_goes_to_background() -> void:
	_start_playing()
	_bot_play(1.0)
	var before := _game.time_left
	var elapsed := _game.play_elapsed
	var x := _game.goldie_x
	AppLifecycle.simulate_background()
	assert_eq(_game.state, MinigameBase.State.PAUSED, "切到背景就暫停")
	_game.move_to(_game.goldie_range().y)
	_game.step(5.0)
	assert_almost_eq(_game.time_left, before, 0.0001, "暫停時計時停止")
	assert_almost_eq(_game.play_elapsed, elapsed, 0.0001, "魚也停在空中")
	assert_eq(_game.goldie_x, x, "暫停時金毛不動")
	assert_eq(_game.misses, 0, "暫停時不會漏接")
	AppLifecycle.simulate_foreground()
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(90, 200)
	_game._unhandled_input(tap)
	assert_eq(_game.state, MinigameBase.State.PLAYING, "點一下繼續")


# --- 版面與畫面 ---

func test_layout_fits_every_phone() -> void:
	var root := get_tree().root
	var original := root.size
	for phone: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2400), Vector2i(1179, 2556), Vector2i(750, 1334)]:
		for notch in [false, true]:
			SafeArea.simulate_notch = notch
			root.size = phone
			ScreenFit.call(&"_refit")
			await wait_frames(2)
			_game._relayout()
			_game.start()
			var size := SafeArea.get_screen_size()
			var safe := SafeArea.get_safe_rect()
			var cfg := _cfg()
			var range_x := _game.goldie_range()
			var label := "%s%s" % [size, " 瀏海" if notch else ""]
			assert_true(range_x.x >= safe.position.x + cfg.edge_margin - 0.5 and range_x.y <= safe.end.x - cfg.edge_margin + 0.5,
				"%s:金毛離左右邊緣夠遠(%s)" % [label, range_x])
			for x: float in [range_x.x, range_x.y]:
				_game.goldie_x = x
				var bowl := _game.bowl_center()
				assert_true(safe.grow(-2.0).has_point(bowl + Vector2(-12, 0)) and safe.grow(-2.0).has_point(bowl + Vector2(12, 0)),
					"%s:碗在安全區內" % label)
			var zone := _game.touch_zone()
			assert_true(safe.encloses(zone), "%s:拖曳範圍在安全區內" % label)
			assert_true(zone.end.y <= safe.end.y - cfg.touch_bottom_margin + 0.01, "%s:避開底部手勢區" % label)
			assert_true(_game.catch_y() > _game._time_bar_rect().end.y + 60.0, "%s:魚有足夠的高度可以落下" % label)
			for item in _game.items:
				assert_true(Rect2(Vector2.ZERO, size).has_point(Vector2(_game.item_x(item), _game.catch_y())), "%s:落點在畫面內" % label)
			var hint := _game.get_node("Hint") as Label
			assert_true(safe.encloses(Rect2(hint.position, hint.size)), "%s:提示在安全區內" % label)
	SafeArea.simulate_notch = false
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)


func test_draws_every_state_and_chapter_without_errors() -> void:
	for chapter in [4, 5, 6]:
		GameState.chapter = chapter
		_new_game(chapter)
		_game.start()
		_game.step(1.0)
		_game.queue_redraw()
		await wait_frames(1)
		_game.step(_game.config.countdown_sec)
		_bot_play(6.0)
		_game.queue_redraw()
		await wait_frames(1)
		AppLifecycle.simulate_background()
		_game.queue_redraw()
		await wait_frames(1)
		AppLifecycle.simulate_foreground()
		_game.resume_game()
		_bot_play()
		_game.step(_game.config.results_delay_sec + 0.1)
		assert_eq(_game.state, MinigameBase.State.RESULTS, "第 %d 章:評價畫面" % chapter)
		_game.queue_redraw()
		await wait_frames(1)
		assert_true(_game._result_extra_lines()[0].contains(str(_game.caught)), "評價畫面顯示接到幾條")


func test_strings_exist_and_fit() -> void:
	var font := (_game.get_node("Hint") as Label).get_theme_font(&"font")
	for key: String in ["UI_CAMP_MINIGAME_FISH", "MINIGAME_FISH_GO", "MINIGAME_FISH_HINT", "MINIGAME_FISH_SCORE",
			"MINIGAME_FISH_COMBO", "MINIGAME_FISH_RESULT", "MINIGAME_FISH_BOOT", "MINIGAME_FISH_MISS", "MINIGAME_FISH_CHEER"]:
		var text := tr(key)
		assert_ne(text, key, "%s 有文字" % key)
		assert_true(text.length() <= 26, key)
		assert_false(text.contains(",") or text.contains("!") or text.contains("?"), "%s 用全形標點" % key)
		for c in text:
			assert_true(font.has_char(c.unicode_at(0)), "%s:字型有「%s」" % [key, c])
	var width := font.get_string_size(tr("MINIGAME_FISH_HINT"), HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S).x
	assert_true(width <= 172.0, "提示一行放得下(%d)" % width)
	assert_true(tr("UI_CAMP_MINIGAME_FISH").length() <= 10, "營地按鈕放得下")


# --- 自動試玩(整合機器人用的 bot_step) ---

func test_every_minigame_can_play_itself_with_bot_step() -> void:
	var expected := {
		"res://game/minigames/scroll/scroll_minigame.tscn": 1,
		"res://game/minigames/wake/wake_minigame.tscn": 3,
		"res://game/minigames/fish/fish_minigame.tscn": 3,
	}
	for path: String in expected:
		var game := (load(path) as PackedScene).instantiate() as MinigameBase
		game.auto_start = false
		game.config = game.config.duplicate() as MinigameConfig
		if "rng_seed" in game.config:
			game.config.set(&"rng_seed", 5)
		add_child(game)
		game.set_process(false)
		game.start()
		var frames := 0
		while game.state != MinigameBase.State.ENDING and frames < 60 * 30:
			game.bot_step(FRAME)
			game.step(FRAME)
			frames += 1
		assert_eq(game.state, MinigameBase.State.ENDING, "%s:玩到時間到" % path.get_file())
		assert_true(game.grade >= int(expected[path]), "%s:bot_step 至少 %d 顆星(%d 顆、%d 分)" % [path.get_file(), expected[path], game.grade, game.score])
		game.queue_free()
		await wait_frames(1)
