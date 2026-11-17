extends TestCase
## v2.6 DV1、DV2(DEV_PLAN 4.13、19):營地依章播對白、第三章湖中仙女代替梅林、第二章起蘭斯洛特在營地、
## 場景依章變化。

const CAMP_SCENE := preload("res://game/camp/camp.tscn")
const MAX_CJK: int = 26

var _camp: Camp


func before_each() -> void:
	GameState.reset_run()
	GameState.chapter = 1
	GameState.story_seen = {}
	Haptics.reset_for_tests()


func after_each() -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	await wait_frames(1)
	GameState.chapter = 1
	GameState.reset_run()
	GameState.story_seen = {}


func _enter(chapter: int, level_index: int, changes: Dictionary = {}) -> void:
	GameState.chapter = chapter
	GameState.level_index = level_index
	_camp = CAMP_SCENE.instantiate() as Camp
	if not changes.is_empty():
		var cfg := (_camp.config as CampConfig).duplicate() as CampConfig
		for key: String in changes:
			cfg.set(key, changes[key])
		_camp.config = cfg
	add_child(_camp)


func _wait_story_end(frames: int = 60) -> void:
	for i in frames:
		if not _camp.is_story_playing():
			return
		await wait_frames(1)


func _skip_story() -> void:
	_camp.skip_story()
	await _wait_story_end()


# --- DV1 對白依章 ---

func test_story_path_follows_the_chapter() -> void:
	var expected := {
		[1, 1]: "res://data/story/camp1.tres", [1, 3]: "res://data/story/camp2.tres",
		[2, 1]: "res://data/story/c2_camp1.tres", [2, 3]: "res://data/story/c2_camp2.tres",
		[3, 1]: "res://data/story/c3_camp1.tres", [3, 3]: "res://data/story/c3_camp2.tres",
	}
	for key: Array in expected:
		_enter(key[0], key[1])
		assert_eq(_camp.story_path(), expected[key], "第 %d 章 level_index %d" % [key[0], key[1]])
		assert_true(ResourceLoader.exists(expected[key]), "%s 存在" % expected[key])
		_camp.queue_free()
		_camp = null
		await wait_frames(1)
	_enter(2, 2)
	assert_eq(_camp.story_path(), "", "其他 level_index 沒有營地對白")
	assert_false(_camp.is_story_playing())


func test_chapter_camps_play_their_own_dialogue() -> void:
	for entry: Array in [[2, 1, &"c2_camp1"], [2, 3, &"c2_camp2"], [3, 1, &"c3_camp1"], [3, 3, &"c3_camp2"]]:
		var started := watch_signal(EventBus.dialogue_started)
		_enter(entry[0], entry[1])
		assert_true(_camp.is_story_playing(), "%s:進營地就播" % entry[2])
		assert_eq(started.last_args()[0], entry[2], "第 %d 章第 %d 次營地" % [entry[0], _camp.camp_number()])
		var script := _camp.story_script()
		var prefix := "STORY_%s_" % String(entry[2]).to_upper()
		for line: DialogueLine in script.lines:
			assert_true(line.text_key.begins_with(prefix), line.text_key)
		await _skip_story()
		assert_true(_camp.is_menu_visible(), "播完出現選單")
		_camp.queue_free()
		_camp = null
		await wait_frames(1)


func test_chapter_one_still_plays_camp1_and_camp2() -> void:
	var started := watch_signal(EventBus.dialogue_started)
	_enter(1, 1)
	assert_eq(started.last_args()[0], &"camp1")
	assert_false(_camp.is_lancelot_visible(), "第一章蘭斯洛特還沒出場")
	assert_false(_camp.is_lady_present())
	assert_eq(_camp.get_merlin().name, &"Merlin")
	assert_false(_camp.is_bulldog_visible(), "第一章第一次營地鬥牛犬還沒加入")


# --- DV1 營地的人 ---

func test_chapter_two_has_merlin_bulldog_and_lancelot() -> void:
	_enter(2, 1)
	await _skip_story()
	assert_true(_camp.is_bulldog_visible(), "第二章 2-1 起貝德維爾就是同伴")
	assert_true(_camp.is_lancelot_visible(), "第二章第一次營地蘭斯洛特在")
	assert_true(_camp.is_merlin_visible(), "第二章梅林還在")
	assert_false(_camp.is_lady_present())
	assert_eq(_camp.get_merlin().frames, _camp.config.merlin_frames)
	var lancelot := _camp.get_lancelot()
	assert_not_null(lancelot.config.lancelot_frames, "用 C 線的 lancelot_frames")
	for anim: StringName in [&"idle", &"attack"]:
		assert_true(lancelot.config.lancelot_frames.has_animation(anim), "蘭斯洛特有 %s" % anim)
	assert_eq(lancelot.current_animation(), &"idle")
	# 畫的次序:夜空 → 梅林、蘭斯洛特 → 地面(圓桌蓋住下半身)
	var sky := _camp.find_child("Sky", true, false)
	var ground := _camp.find_child("Ground", true, false)
	assert_true(sky.get_index() < lancelot.get_index() and lancelot.get_index() < ground.get_index(), "蘭斯洛特在圓桌後面")
	assert_true(lancelot.position.x > _camp.get_merlin().position.x, "梅林在左、蘭斯洛特在右")


func test_chapter_three_lady_of_the_lake_replaces_merlin() -> void:
	_enter(3, 1)
	await _skip_story()
	assert_true(_camp.is_lady_present(), "第三章:湖中仙女")
	var host := _camp.get_merlin()
	assert_eq(host.name, &"LadyLake")
	assert_eq(host.frames, _camp.config.lady_frames, "用 assets/sprites/lady_lake/ 的圖")
	assert_ne(host.frames, _camp.config.merlin_frames, "梅林被抓走了,不在營地")
	for anim: StringName in [&"idle", &"cast"]:
		assert_true(host.frames.has_animation(anim), "湖中仙女有 %s" % anim)
	assert_true(_camp.is_merlin_visible(), "坐在梅林的位置")
	assert_true(_camp.is_lancelot_visible(), "第三章蘭斯洛特也在")
	assert_true(_camp.is_bulldog_visible())
	var said: Array[String] = []
	_camp.merlin_spoke.connect(func(key: String) -> void: said.append(key))
	var key := _camp.tap_merlin()
	assert_true(key.begins_with("CAMP_LADY_"), "點她說 CAMP_LADY_XX(%s)" % key)
	assert_true(host.is_casting(), "水光閃一下")
	assert_eq(_camp.get_merlin_bubble().text, tr(key))
	assert_eq(said, [key])


func test_lady_lines_cycle_without_repeating() -> void:
	_enter(3, 1, {"merlin_tap_cooldown_sec": 0.0})
	await _skip_story()
	var said: Array[String] = []
	for i in 8:
		said.append(_camp.tap_merlin())
	var first := said.slice(0, 4)
	first.sort()
	assert_eq(first, ["CAMP_LADY_01", "CAMP_LADY_02", "CAMP_LADY_03", "CAMP_LADY_04"] as Array[String], "四句都說過才重複")
	for i in range(1, said.size()):
		assert_ne(said[i], said[i - 1], "不會連續兩次說同一句")


func test_tapping_lancelot_says_a_line() -> void:
	_enter(2, 3, {"merlin_tap_cooldown_sec": 0.0})
	await _skip_story()
	var spoke: Array = []
	_camp.lancelot_spoke.connect(func(key: String) -> void: spoke.append(key))
	var key := _camp.tap_lancelot()
	assert_true(key.begins_with("CAMP_LANCELOT_"), "說 CAMP_LANCELOT_XX(%s)" % key)
	var lancelot := _camp.get_lancelot()
	assert_true(lancelot.is_poking(), "轉一下長槍")
	assert_eq(lancelot.current_animation(), &"attack")
	assert_eq(Haptics.last_kind, &"light")
	var bubble := _camp.get_merlin_bubble()
	assert_true(bubble.is_showing())
	assert_eq(bubble.text, tr(key))
	assert_eq(spoke, [key])
	lancelot.advance(_camp.config.lancelot_tap_sec + 0.05)
	assert_false(lancelot.is_poking())
	assert_eq(lancelot.current_animation(), &"idle", "回到平常")
	var said: Array[String] = [key]
	for i in 7:
		said.append(_camp.tap_lancelot())
	var first := said.slice(0, 4)
	first.sort()
	assert_eq(first, ["CAMP_LANCELOT_01", "CAMP_LANCELOT_02", "CAMP_LANCELOT_03", "CAMP_LANCELOT_04"] as Array[String])
	for i in range(1, said.size()):
		assert_ne(said[i], said[i - 1])
	# 梅林說話不會打亂蘭斯洛特的抽籤袋(各自的)
	assert_true(_camp.tap_merlin().begins_with("CAMP_MERLIN_"))


func test_lancelot_on_screen_and_silent_when_busy() -> void:
	_enter(2, 1)
	assert_eq(_camp.tap_lancelot(), "", "對白中不說話")
	await _skip_story()
	var zone := _camp.find_child("LancelotZone", true, false) as Control
	assert_true(zone.visible)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	zone.gui_input.emit(tap)
	assert_eq(_camp.lancelot_taps, 1, "點蘭斯洛特 = 說一句話")
	_camp.open_minigame()
	assert_false(_camp.is_lancelot_visible(), "小遊戲中看不到")
	assert_false(zone.visible)
	assert_eq(_camp.tap_lancelot(), "")
	var game := _camp.get_minigame()
	game.set_process(false)
	game.close()
	await wait_frames(1)
	assert_true(_camp.is_lancelot_visible(), "回到營地還在")


func test_no_lancelot_in_chapter_one() -> void:
	_enter(1, 3)
	await _skip_story()
	assert_false(_camp.is_lancelot_visible())
	assert_eq(_camp.tap_lancelot(), "")
	assert_false((_camp.find_child("LancelotZone", true, false) as Control).visible)


func test_zones_and_bubbles_fit_every_phone() -> void:
	for chapter in [2, 3]:
		_enter(chapter, 1, {"merlin_tap_cooldown_sec": 0.0})
		await _skip_story()
		_camp.finish_intro()
		var root := get_tree().root
		var original := root.size
		for phone: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2400), Vector2i(1179, 2556), Vector2i(750, 1334)]:
			root.size = phone
			ScreenFit.call(&"_refit")
			await wait_frames(2)
			_camp.finish_intro()
			var size := SafeArea.get_screen_size()
			var safe := SafeArea.get_safe_rect()
			var zones := {}
			for zone_name: String in ["LancelotZone", "MerlinZone", "PetZone", "BulldogZone", "Menu"]:
				var node := _camp.find_child(zone_name, true, false) as Control
				zones[zone_name] = Rect2(node.global_position, node.size)
			var lz: Rect2 = zones["LancelotZone"]
			assert_true(lz.size.x >= 24.0 and lz.size.y >= 24.0, "%s:蘭斯洛特夠大好點(%s)" % [size, lz.size])
			assert_true(Rect2(Vector2.ZERO, size).encloses(lz), "%s:蘭斯洛特在畫面內" % size)
			for other: String in ["MerlinZone", "PetZone", "BulldogZone", "Menu"]:
				assert_false(lz.intersects(zones[other]), "%s 第 %d 章:蘭斯洛特不和 %s 重疊" % [size, chapter, other])
			var mz: Rect2 = zones["MerlinZone"]
			assert_true(mz.size.x >= 24.0 and mz.size.y >= 24.0, "%s:梅林(仙女)夠大好點" % size)
			var bubble := _camp.get_merlin_bubble()
			for key: String in _camp.config.lancelot_lines:
				bubble.show_text(tr(key), _camp.get_lancelot().speech_anchor(), 1.0)
				assert_true(safe.encloses(bubble.get_box()), "%s:%s 的泡泡在安全區內" % [size, key])
				assert_true(bubble.get_lines().size() <= 2, "%s:最多兩行" % key)
			for key: String in _camp.host_lines():
				bubble.show_text(tr(key), _camp.get_merlin().speech_anchor(), 1.0)
				assert_true(safe.encloses(bubble.get_box()), "%s:%s 的泡泡在安全區內" % [size, key])
				assert_true(bubble.get_lines().size() <= 2, "%s:最多兩行" % key)
		root.size = original
		ScreenFit.call(&"_refit")
		await wait_frames(1)
		_camp.queue_free()
		_camp = null
		await wait_frames(1)


func test_new_camp_lines_are_short_and_well_formed() -> void:
	var keys: Array[String] = []
	for i in range(1, 5):
		keys.append("CAMP_LANCELOT_%02d" % i)
		keys.append("CAMP_LADY_%02d" % i)
	for key in keys:
		var text := tr(key)
		assert_ne(text, key, "%s 有文字" % key)
		assert_true(text.length() <= MAX_CJK, "%s 不超過 %d 字(%d)" % [key, MAX_CJK, text.length()])
		assert_false(text.contains(","), "%s 用全形逗號" % key)
		assert_false(text.contains("!") or text.contains("?"), "%s 用全形標點" % key)


# --- DV2 場景依章 ---

func test_scenery_follows_the_chapter() -> void:
	var tops: Array[Color] = []
	for chapter in [1, 2, 3]:
		_enter(chapter, 1)
		await _skip_story()
		var parts := _scenery_parts()
		assert_eq(parts.size(), 3, "夜空、地面、光暈")
		for part: CampScenery in parts:
			assert_eq(part.chapter, chapter, "%s 用第 %d 章的場景" % [part.name, chapter])
			# 畫一格不出錯(含城牆、湖、洞口)
			part.advance(0.5)
		tops.append(_camp.config.sky_top_color)
		var sky := parts[0]
		await wait_frames(1)
		if chapter == 2:
			assert_true(sky.wall_top() < sky.horizon_y - 30.0, "城牆夠高")
			assert_true(sky.wall_top() >= sky.top_y - 30.0, "城牆不蓋到標題")
			assert_eq(sky.torch_spots().size(), 2, "牆上兩支火把")
		if chapter == 3:
			assert_true(sky.lake_top() < sky.horizon_y - 20.0, "看得到湖面")
		_camp.queue_free()
		_camp = null
		await wait_frames(1)
	assert_ne(tops[0], tops[1], "第二章換顏色")
	assert_ne(tops[1], tops[2], "第三章換顏色")
	var cfg := load("res://game/camp/camp_config.tres") as CampConfig
	assert_eq(cfg.sky_top_color, tops[0], "共用的 camp_config.tres 沒有被改到")


func _scenery_parts() -> Array[CampScenery]:
	var parts: Array[CampScenery] = []
	var sky := _camp.find_child("Sky", true, false)
	for child in sky.get_parent().get_children():
		if child is CampScenery:
			parts.append(child as CampScenery)
	return parts


func test_chapter_palettes_are_data() -> void:
	var cfg := load("res://game/camp/camp_config.tres") as CampConfig
	for chapter in [2, 3]:
		var palette: Dictionary = cfg.chapter_palettes.get(chapter, {})
		assert_false(palette.is_empty(), "第 %d 章的顏色在 camp_config.tres" % chapter)
		for key: String in palette:
			assert_true(palette[key] is Color, "%s 是顏色" % key)
