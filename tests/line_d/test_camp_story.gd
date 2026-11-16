extends TestCase
## DS1 營地故事、DS2 營地的梅林(DEV_PLAN 16)。
## 對白檔(data/story/camp1.tres、camp2.tres)由 B 線同時製作:測試用程式建立的 DialogueScript,
## 存到 user:// 再指給營地讀,這樣「依路徑讀檔」的做法也測得到。

const CAMP_SCENE := preload("res://game/camp/camp.tscn")
const DIALOGUE_BOX_SCENE := "res://ui/dialogue/dialogue_box.tscn"
const TEMP_DIR := "user://test_camp_story/"
const MAX_CJK: int = 26

var _camp: Camp


func before_each() -> void:
	GameState.reset_run()
	GameState.story_seen = {}
	Haptics.reset_for_tests()


func after_each() -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	await wait_frames(1)
	GameState.reset_run()
	GameState.story_seen = {}


static func _script(id: StringName, keys: Array) -> DialogueScript:
	var s := DialogueScript.new()
	s.id = id
	var lines: Array[DialogueLine] = []
	for entry: Array in keys:
		var line := DialogueLine.new()
		line.text_key = entry[0]
		line.speaker = entry[1]
		line.expression = entry[2]
		lines.append(line)
	s.lines = lines
	return s


## 把對白存成檔案,營地的 story_paths 指向它(和 B 線的 data/story/*.tres 一樣用路徑讀)。
func _paths_with_files() -> Dictionary[int, String]:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var camp1 := _script(&"camp1", [["STORY_CAMP1_01", &"merlin", &"proud"], ["STORY_CAMP1_04", &"goldie", &"surprised"],
			["STORY_CAMP1_05", &"merlin", &"normal"]])
	var camp2 := _script(&"camp2", [["STORY_CAMP2_01", &"bulldog", &"normal"], ["STORY_CAMP2_04", &"merlin", &"proud"]])
	ResourceSaver.save(camp1, TEMP_DIR + "camp1.tres")
	ResourceSaver.save(camp2, TEMP_DIR + "camp2.tres")
	return {1: TEMP_DIR + "camp1.tres", 3: TEMP_DIR + "camp2.tres"}


func _enter(changes: Dictionary = {}, override: DialogueScript = null) -> void:
	_camp = CAMP_SCENE.instantiate() as Camp
	var cfg := (_camp.config as CampConfig).duplicate() as CampConfig
	for key: String in changes:
		cfg.set(key, changes[key])
	_camp.config = cfg
	_camp.story_override = override
	add_child(_camp)


## 一直點對白框直到播完(對白框可能有逐字顯示:第一下先顯示整句)。
func _advance_until_done(max_taps: int = 40) -> int:
	var taps := 0
	var box := _camp.get_dialogue_box()
	while _camp.is_story_playing() and taps < max_taps:
		box.call(&"advance")
		taps += 1
		await wait_frames(1)
	return taps


func _wait_story_end(frames: int = 60) -> void:
	for i in frames:
		if not _camp.is_story_playing():
			return
		await wait_frames(1)


# --- DS1 營地故事 ---

func test_first_camp_plays_camp1_before_the_menu() -> void:
	var started := watch_signal(EventBus.dialogue_started)
	var finished := watch_signal(EventBus.dialogue_finished)
	var left := watch_signal(EventBus.camp_left)
	GameState.level_index = 1
	_enter({"story_paths": _paths_with_files()})
	assert_true(_camp.is_story_playing(), "第一次營地:進來就播 camp1")
	assert_false(_camp.is_menu_visible(), "對白播完之前看不到選單")
	assert_eq(started.count, 1)
	assert_eq(started.last_args()[0], &"camp1")
	var box := _camp.get_dialogue_box()
	assert_not_null(box)
	assert_eq(box.scene_file_path, DIALOGUE_BOX_SCENE, "營地用 C 線對白框的實例")
	assert_true(box.is_in_group(&"dialogue_box"), "測試與機器人靠這個群組自動略過")
	assert_true(box.call(&"is_active"))
	# 對白中:選單的動作與摸頭都不會發生
	_camp.open_minigame()
	assert_null(_camp.get_minigame(), "對白中不能開小遊戲")
	_camp.leave_camp()
	assert_eq(left.count, 0, "對白中不能離開")
	assert_false(_camp.pet_goldie(), "對白中不能摸頭")
	assert_eq(_camp.tap_merlin(), "", "對白中梅林不說話")
	# 不用 watch_signal:營地在 after_each 釋放,訊號監看會在之後才停止。
	var story_done: Array = []
	_camp.story_finished.connect(func() -> void: story_done.append(true))
	await _advance_until_done()
	assert_false(_camp.is_story_playing(), "播完了")
	assert_true(_camp.is_menu_visible(), "播完才顯示選單")
	assert_eq(story_done.size(), 1)
	assert_eq(finished.count, 1)
	assert_true(GameState.story_seen.get(&"camp1", false), "對白框記下看過的段落")
	_camp.leave_camp()
	assert_eq(left.count, 1, "播完就可以離開")


func test_second_camp_plays_camp2() -> void:
	var started := watch_signal(EventBus.dialogue_started)
	GameState.level_index = 3
	_enter({"story_paths": _paths_with_files()})
	assert_true(_camp.is_story_playing())
	assert_eq(started.last_args()[0], &"camp2", "第二次營地(1-4 之後)播 camp2")
	_camp.skip_story()
	await _wait_story_end()
	assert_false(_camp.is_story_playing(), "略過")
	assert_true(_camp.is_menu_visible())
	assert_true(_camp.is_bulldog_visible(), "第二次營地鬥牛犬也在")


func test_default_paths_are_camp1_and_camp2() -> void:
	var cfg := load("res://game/camp/camp_config.tres") as CampConfig
	assert_eq(cfg.story_paths.get(1, ""), "res://data/story/camp1.tres", "1-2 之後(level_index 1)")
	assert_eq(cfg.story_paths.get(3, ""), "res://data/story/camp2.tres", "1-4 之後(level_index 3)")
	assert_eq(cfg.story_paths.size(), 2)


func test_no_story_or_missing_file_shows_menu_at_once() -> void:
	GameState.level_index = 1
	var missing: Dictionary[int, String] = {1: "res://data/story/does_not_exist.tres"}
	_enter({"story_paths": missing})
	assert_false(_camp.is_story_playing(), "對白檔不存在:安靜略過")
	assert_true(_camp.is_menu_visible())
	assert_false(_camp.story_played)
	_camp.queue_free()
	await wait_frames(1)
	GameState.level_index = 2
	_enter({"story_paths": _paths_with_files()})
	assert_false(_camp.is_story_playing(), "其他 level_index 沒有營地對白")
	assert_true(_camp.is_menu_visible())


func test_story_plays_once_per_visit() -> void:
	var started := watch_signal(EventBus.dialogue_started)
	GameState.level_index = 1
	_enter({"story_paths": _paths_with_files()})
	_camp.skip_story()
	await _wait_story_end()
	_camp.open_minigame()
	var game := _camp.get_minigame()
	assert_not_null(game)
	game.set_process(false)
	game.close()
	await wait_frames(2)
	assert_null(_camp.get_minigame())
	assert_false(_camp.is_story_playing(), "玩完小遊戲回來不會再播")
	assert_true(_camp.is_menu_visible())
	assert_eq(started.count, 1, "每次營地只播一次")


func test_story_override_from_code() -> void:
	GameState.level_index = 0
	_enter({}, _script(&"camp_test", [["STORY_CAMP1_01", &"merlin", &"proud"]]))
	assert_true(_camp.is_story_playing(), "指定的對白優先")
	assert_eq(_camp.story_script().id, &"camp_test")
	await _advance_until_done()
	assert_true(_camp.is_menu_visible())


func test_real_story_files_when_line_b_has_them() -> void:
	# B 線的 data/story/ 合併之後才檢查內容;還沒有時只確認營地照樣可以用。
	for entry: Array in [[1, &"camp1", "STORY_CAMP1_"], [3, &"camp2", "STORY_CAMP2_"]]:
		var path := "res://data/story/%s.tres" % entry[1]
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as DialogueScript
		assert_not_null(script, path)
		assert_eq(script.id, entry[1])
		assert_true(script.lines.size() >= 2)
		for line: DialogueLine in script.lines:
			assert_true(line.text_key.begins_with(entry[2]), "%s:%s" % [path, line.text_key])
	GameState.level_index = 1
	_enter()
	_camp.skip_story()
	await _wait_story_end()
	assert_true(_camp.is_menu_visible())


# --- DS2 營地的梅林 ---

func test_merlin_sits_behind_the_round_table() -> void:
	_enter()
	var merlin := _camp.get_merlin()
	assert_not_null(merlin)
	assert_true(_camp.is_merlin_visible(), "梅林在營地")
	var frames := _camp.config.merlin_frames
	assert_not_null(frames, "用 C 線的 merlin_frames")
	for anim: StringName in [&"idle", &"run", &"cast"]:
		assert_true(frames.has_animation(anim), "梅林有 %s 動畫" % anim)
	# 畫的次序:夜空 → 梅林 → 地面(圓桌蓋住梅林的下半身)
	var sky := _camp.find_child("Sky", true, false)
	var ground := _camp.find_child("Ground", true, false)
	assert_eq(merlin.get_parent(), sky.get_parent())
	assert_true(sky.get_index() < merlin.get_index() and merlin.get_index() < ground.get_index(), "梅林在圓桌後面")
	assert_eq(merlin.current_animation(), &"idle")


func test_tapping_merlin_says_a_camp_line() -> void:
	_enter()
	var spoke: Array = []
	_camp.merlin_spoke.connect(func(key: String) -> void: spoke.append(key))
	var key := _camp.tap_merlin()
	assert_true(key.begins_with("CAMP_MERLIN_"), "說一句 CAMP_MERLIN_XX(%s)" % key)
	assert_true(_camp.config.merlin_lines.has(key))
	var bubble := _camp.get_merlin_bubble()
	assert_true(bubble.is_showing(), "對話泡泡")
	assert_eq(bubble.text, tr(key))
	assert_true(_camp.get_merlin().is_casting(), "施法、閃光")
	assert_eq(Haptics.last_kind, &"light", "輕震")
	assert_eq(spoke, [key])
	assert_eq(_camp.merlin_taps, 1)
	# 泡泡停留一陣子後收起
	bubble.advance(_camp.config.merlin_bubble_sec + 0.05)
	assert_false(bubble.is_showing())


func test_merlin_lines_cycle_without_repeating() -> void:
	_enter({"merlin_tap_cooldown_sec": 0.0})
	var said: Array[String] = []
	for i in 12:
		said.append(_camp.tap_merlin())
	var first_round := said.slice(0, 6)
	first_round.sort()
	assert_eq(first_round, ["CAMP_MERLIN_01", "CAMP_MERLIN_02", "CAMP_MERLIN_03", "CAMP_MERLIN_04",
			"CAMP_MERLIN_05", "CAMP_MERLIN_06"] as Array[String], "六句都說過一次才重複")
	for i in range(1, said.size()):
		assert_ne(said[i], said[i - 1], "不會連續兩次說同一句")


func test_fast_taps_on_merlin_are_ignored() -> void:
	_enter({"merlin_tap_cooldown_sec": 0.6})
	assert_ne(_camp.tap_merlin(), "")
	assert_eq(_camp.tap_merlin(), "", "連點太快不算")
	assert_eq(_camp.merlin_taps, 1)


func test_tapping_merlin_on_screen() -> void:
	_enter()
	var zone := _camp.find_child("MerlinZone", true, false) as Control
	assert_not_null(zone)
	assert_eq(zone.mouse_filter, Control.MOUSE_FILTER_STOP)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	zone.gui_input.emit(tap)
	assert_eq(_camp.merlin_taps, 1, "點梅林 = 說一句話")


func test_merlin_casts_now_and_then() -> void:
	_enter({"merlin_cast_every_min": 1.0, "merlin_cast_every_max": 1.0, "merlin_cast_sec": 0.5})
	var merlin := _camp.get_merlin()
	merlin.set_process(false)
	var before := merlin.cast_count
	merlin.advance(1.05)
	assert_eq(merlin.cast_count, before + 1, "偶爾施法")
	assert_eq(merlin.current_animation(), &"cast")
	merlin.advance(0.55)
	assert_false(merlin.is_casting())
	assert_eq(merlin.current_animation(), &"idle", "施法完回到平常")


func test_merlin_hidden_and_silent_during_minigame() -> void:
	_enter({"merlin_tap_cooldown_sec": 0.0})
	_camp.tap_merlin()
	_camp.open_minigame()
	assert_false(_camp.is_merlin_visible(), "小遊戲中看不到營地的梅林")
	assert_false(_camp.get_merlin_bubble().is_showing(), "泡泡收起")
	assert_eq(_camp.tap_merlin(), "")
	var game := _camp.get_minigame()
	game.set_process(false)
	game.close()
	await wait_frames(1)
	assert_true(_camp.is_merlin_visible(), "回到營地,梅林還在")


func test_camp_merlin_lines_are_short_and_well_formed() -> void:
	for i in range(1, 7):
		var key := "CAMP_MERLIN_%02d" % i
		var text := tr(key)
		assert_ne(text, key, "%s 有文字" % key)
		assert_true(text.length() <= MAX_CJK, "%s 不超過 %d 字(%d)" % [key, MAX_CJK, text.length()])
		assert_false(text.contains(","), "%s 用全形逗號" % key)
	assert_eq(tr("MINIGAME_MERLIN_ASK").length() <= MAX_CJK, true)


func test_merlin_zone_and_bubble_fit_every_phone() -> void:
	_enter({"merlin_tap_cooldown_sec": 0.0})
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
		var zone := _camp.find_child("MerlinZone", true, false) as Control
		var zone_rect := Rect2(zone.global_position, zone.size)
		assert_true(zone_rect.size.x >= 24.0 and zone_rect.size.y >= 24.0, "%s:梅林夠大好點" % size)
		assert_true(Rect2(Vector2.ZERO, size).encloses(zone_rect), "%s:梅林在畫面內" % size)
		var menu := _camp.find_child("Menu", true, false) as Control
		assert_false(zone_rect.intersects(Rect2(menu.global_position, menu.size)), "%s:不蓋住選單" % size)
		var pet := _camp.find_child("PetZone", true, false) as Control
		assert_false(zone_rect.intersects(Rect2(pet.global_position, pet.size)), "%s:不和摸金毛的範圍重疊" % size)
		var bulldog := _camp.find_child("BulldogZone", true, false) as Control
		assert_false(zone_rect.intersects(Rect2(bulldog.global_position, bulldog.size)), "%s:不和鬥牛犬重疊" % size)
		for key: String in _camp.config.merlin_lines:
			var bubble := _camp.get_merlin_bubble()
			bubble.show_text(tr(key), _camp.get_merlin().speech_anchor(), 1.0)
			assert_true(safe.encloses(bubble.get_box()), "%s:%s 的泡泡在安全區內" % [size, key])
			for line: String in bubble.get_lines():
				assert_false(line.is_empty(), key)
				assert_false(MinigameSpeechBubble.NO_LINE_START.contains(line[0]), "%s:標點不在行首(%s)" % [key, line])
				assert_false(line.begins_with("…") and not line.begins_with("……"), "%s:刪節號不被拆開(%s)" % [key, line])
			assert_true(bubble.get_lines().size() <= 2, "%s:最多兩行" % key)
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)
