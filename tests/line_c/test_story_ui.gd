extends TestCase
## v2.3 故事與深化(DEV_PLAN 第 16 節 CS1、CS6、CS7、CS9):正式對白框、標題難度、失敗提示、
## 困難標記、頭目血條名字。合約部分(play/advance/skip/群組/訊號)由 tests/core/test_story_contract.gd 檢查。

const BOX := "res://ui/dialogue/dialogue_box.tscn"
const STORY_SPEAKERS: Array[String] = ["goldie", "bulldog", "merlin", "black_knight", "morgana",
		"scarecrow_captain", "crow"]

var _nodes: Array[Node] = []
var _cleared_before: bool
var _difficulty_before: StringName


func before_each() -> void:
	_cleared_before = GameState.chapter_cleared
	_difficulty_before = GameState.difficulty


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	GameState.chapter_cleared = _cleared_before
	GameState.difficulty = _difficulty_before
	GameState.story_seen = {}


func _add(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n


func _line(speaker: StringName, expression: StringName, key: String, picture: String = "") -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = speaker
	l.expression = expression
	l.text_key = key
	if not picture.is_empty():
		l.illustration = load("res://assets/story/%s.png" % picture)
	return l


func _script(id: StringName, lines: Array[DialogueLine]) -> DialogueScript:
	var s := DialogueScript.new()
	s.id = id
	s.lines = lines
	return s


func _box() -> CanvasLayer:
	return _add((load(BOX) as PackedScene).instantiate()) as CanvasLayer


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# --------------------------------------------------------------------------
# 對白框(CS1)
# --------------------------------------------------------------------------

func test_first_tap_completes_the_line_second_tap_advances() -> void:
	var box := _box()
	box.play(_script(&"tap_test", [_line(&"goldie", &"happy", "STORY_L1_BEFORE_01"),
			_line(&"merlin", &"surprised", "STORY_L1_BEFORE_02")] as Array[DialogueLine]))
	await wait_frames(2)
	assert_true(box.call(&"is_typing"), "一開始逐字顯示")
	await _wait(DialogueConfig.new().tap_guard + 0.05)
	box.call(&"_on_tap")
	assert_false(box.call(&"is_typing"), "第一下:整句顯示")
	assert_eq(box.get("_index"), 0, "還在第一句")
	await _wait(0.12)
	box.call(&"_on_tap")
	assert_eq(box.get("_index"), 1, "第二下:下一句")
	box.call(&"skip")


func test_typewriter_finishes_by_itself_and_shows_the_next_arrow() -> void:
	var box := _box()
	box.play(_script(&"type_test", [_line(&"bulldog", &"normal", "STORY_L3_AFTER_01")] as Array[DialogueLine]))
	await _wait(1.6)
	assert_false(box.call(&"is_typing"), "短句一秒多就顯示完")
	assert_true((box.get("_next") as Control).visible, "顯示完時出現小箭頭")
	box.call(&"skip")


func test_portrait_sides_name_plate_and_narrator() -> void:
	var box := _box()
	box.play(_script(&"side_test", [_line(&"goldie", &"normal", "STORY_L1_AFTER_02"),
			_line(&"merlin", &"proud", "STORY_L1_AFTER_03"),
			_line(&"narrator", &"", "STORY_PROLOGUE_01", "prologue_1")] as Array[DialogueLine]))
	await wait_frames(2)
	var panel := box.get("_panel") as Control
	var portrait := box.get("_portrait_box") as Control
	var name_label := box.get("_name") as Label
	assert_true(portrait.position.x < panel.position.x + panel.size.x * 0.5, "金毛在左")
	assert_eq(name_label.text, tr("SPEAKER_GOLDIE"))
	assert_eq((box.get("_portrait") as TextureRect).texture.resource_path, "res://assets/portraits/goldie/normal.png")
	box.call(&"advance")
	await wait_frames(1)
	assert_true(portrait.position.x > panel.position.x + panel.size.x * 0.5, "梅林在右")
	assert_eq(name_label.text, tr("SPEAKER_MERLIN"))
	box.call(&"advance")
	await wait_frames(1)
	assert_false(portrait.visible, "旁白沒有頭像")
	assert_false((box.get("_plate") as Control).visible, "旁白沒有名牌")
	assert_true(box.call(&"is_storybook"), "旁白的插畫用繪本頁")
	box.call(&"skip")


func test_storybook_keeps_the_picture_and_turns_the_page() -> void:
	var box := _box()
	box.play(_script(&"book_test", [
		_line(&"narrator", &"", "STORY_L6_AFTER_01", "ending_1"),
		_line(&"merlin", &"worried", "STORY_L6_AFTER_02"),
		_line(&"morgana", &"smirk", "STORY_L6_AFTER_03", "ending_2"),
	] as Array[DialogueLine]))
	await wait_frames(2)
	var picture := box.get("_picture") as TextureRect
	assert_eq(picture.texture.resource_path, "res://assets/story/ending_1.png")
	box.call(&"advance")
	await wait_frames(1)
	assert_true(box.call(&"is_storybook"), "沒有插畫的句子沿用上一張(插畫空白 = 不換插畫)")
	assert_eq(picture.texture.resource_path, "res://assets/story/ending_1.png")
	assert_true((box.get("_portrait_box") as Control).visible, "繪本頁上角色說話時也有頭像")
	box.call(&"advance")
	await wait_frames(2)
	var book := box.get("_book") as Control
	assert_true(book.scale.x < 1.0, "換插畫時翻頁")
	await _wait(DialogueConfig.new().page_turn_time + 0.1)
	assert_eq(picture.texture.resource_path, "res://assets/story/ending_2.png")
	assert_almost_eq(book.scale.x, 1.0, 0.01, "翻完頁")
	box.call(&"skip")


func test_box_blocks_touches_and_hides_under_the_pause_menu() -> void:
	var box := _box()
	box.play(_script(&"pause_test", [_line(&"crow", &"normal", "STORY_L2_BEFORE_03")] as Array[DialogueLine]))
	await wait_frames(1)
	var root := box.get("_root") as Control
	assert_eq(root.mouse_filter, Control.MOUSE_FILTER_STOP, "顯示期間擋住觸控")
	EventBus.game_paused.emit(true)
	assert_false(root.visible, "暫停選單打開時暫時隱藏")
	EventBus.game_paused.emit(false)
	assert_true(root.visible)
	box.call(&"skip")
	await wait_frames(1)
	assert_eq(root.mouse_filter, Control.MOUSE_FILTER_IGNORE, "結束後不再擋觸控")


func test_skip_button_is_a_real_touch_target() -> void:
	var box := _box()
	box.play(_script(&"skip_btn", [_line(&"goldie", &"normal", "STORY_L1_BEFORE_01")] as Array[DialogueLine]))
	await wait_frames(2)
	var skip := box.get("_skip") as Button
	assert_true(skip.size.x >= UiKit.MIN_TOUCH and skip.size.y >= UiKit.MIN_TOUCH, "略過按鈕至少 24×24")
	assert_true(SafeArea.get_safe_rect().encloses(skip.get_global_rect()), "在安全區內")
	skip.pressed.emit()
	await wait_frames(1)
	assert_false(box.call(&"is_active"))


func test_every_speaker_has_a_voice_pitch_and_all_lines_fit() -> void:
	var cfg := load("res://ui/dialogue/dialogue_config.tres") as DialogueConfig
	for s in STORY_SPEAKERS:
		assert_true(cfg.speaker_pitch.has(s), "%s 有說話音高" % s)
	# 每句不超過 26 個中文字,三行內放得下(13 字一行)
	var file := FileAccess.open("res://i18n/story.csv", FileAccess.READ)
	while file != null and not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 2 and row[0].begins_with("STORY_") and not row[0].begins_with("STORY_TIP"):
			assert_true(row[1].length() <= 39, "%s 在對白框三行內(%d 字)" % [row[0], row[1].length()])


# --------------------------------------------------------------------------
# 標題、失敗、結算、頭目血條(CS6、CS7)
# --------------------------------------------------------------------------

func _title() -> Control:
	var t := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	_add(t)
	return t


func test_title_without_clearing_starts_normal_after_class_confirmation() -> void:
	GameState.chapter_cleared = false
	GameState.difficulty = &"hard"
	var t := _title()
	var started := watch_signal(Signal(t, &"new_game_pressed"))
	(t.get("new_game_button") as Button).pressed.emit()
	t.get_class_select().confirm_button.pressed.emit()
	assert_eq(started.count, 1, "選職業後直接開始")
	assert_eq(GameState.difficulty, &"normal")
	assert_false(t.call(&"is_difficulty_open"))
	assert_not_null(t.get_node_or_null(^"Merlin"), "標題主視覺有梅林")


func test_title_after_clearing_asks_for_difficulty() -> void:
	GameState.chapter_cleared = true
	GameState.difficulty = &"normal"
	var t := _title()
	var started := watch_signal(Signal(t, &"new_game_pressed"))
	(t.get("new_game_button") as Button).pressed.emit()
	t.get_class_select().confirm_button.pressed.emit()
	assert_true(t.call(&"is_difficulty_open"), "打完第一章:先選難度")
	assert_eq(started.count, 0)
	(t.get("back_button") as Button).pressed.emit()
	assert_false(t.call(&"is_difficulty_open"), "返回")
	(t.get("new_game_button") as Button).pressed.emit()
	t.get_class_select().confirm_button.pressed.emit()
	(t.get("hard_button") as Button).pressed.emit()
	assert_eq(GameState.difficulty, &"hard", "設定好難度才發訊號")
	assert_eq(started.count, 1)
	for b: Button in [t.get("normal_button"), t.get("hard_button"), t.get("back_button")]:
		assert_true(b.custom_minimum_size.y >= UiKit.MIN_TOUCH, "%s 夠大" % b.name)


func test_failure_shows_merlin_and_a_tip() -> void:
	var chapter_before := GameState.chapter
	GameState.chapter = 1   # v2.6:提示依章選;第一章是 1 至 8
	var f := (load("res://ui/screens/failure.tscn") as PackedScene).instantiate() as Control
	_add(f)
	f.call(&"setup", {"time_sec": 30.0, "kills": 3})
	var tip := f.get("tip_label") as Label
	var n: int = f.get("tip_index")
	assert_true(n >= 1 and n <= 8)
	assert_eq(tip.text, tr("STORY_TIP_%02d" % n))
	f.call(&"set_tip", 4)
	assert_eq(tip.text, tr("STORY_TIP_04"))
	assert_not_null(f.find_child("MerlinPortrait", true, false), "梅林的頭像")
	var last := -1
	for i in 30:
		var k: int = f.call(&"_pick_tip")
		assert_ne(k, last, "不會連續兩次同一句")
		last = k
	GameState.chapter = chapter_before


func test_results_hard_badge() -> void:
	var r := (load("res://ui/screens/results.tscn") as PackedScene).instantiate() as Control
	_add(r)
	r.call(&"setup", {"level_name": "LEVEL_1_1", "time_sec": 60.0, "kills": 10, "difficulty": &"hard"})
	assert_true((r.get("hard_badge") as Control).visible, "困難模式有標記")
	r.call(&"setup", {"level_name": "LEVEL_1_1", "time_sec": 60.0, "kills": 10, "difficulty": &"normal"})
	assert_false((r.get("hard_badge") as Control).visible)
	r.call(&"setup", {"level_name": "LEVEL_1_1", "time_sec": 60.0, "kills": 10})
	assert_false((r.get("hard_badge") as Control).visible, "舊資料沒有 difficulty")


func test_boss_bar_takes_the_name_from_boss_appeared() -> void:
	var hud := (load("res://ui/hud/hud.tscn") as PackedScene).instantiate() as Control
	_add(hud)
	await wait_frames(1)
	var bar := hud.get("boss_bar") as BossBar
	EventBus.level_started.emit(&"1-4")
	EventBus.boss_appeared.emit(&"scarecrow_captain")
	EventBus.boss_hp_changed.emit(320, 320)
	var expected := tr("ENEMY_SCARECROW_CAPTAIN")
	if expected == "ENEMY_SCARECROW_CAPTAIN":
		expected = tr("SPEAKER_SCARECROW_CAPTAIN")
	assert_eq(bar.name_label.text, expected, "中頭目的名字")
	EventBus.boss_phase_changed.emit(2)
	assert_eq(bar.bar.fill_color, PaletteColors.RED, "第二階段仍然變色")
	EventBus.level_started.emit(&"1-6")
	EventBus.boss_appeared.emit(&"black_knight")
	assert_eq(bar.name_label.text, tr("ENEMY_BLACK_KNIGHT"))
	bar.set_boss(&"no_such_boss")
	assert_eq(bar.name_label.text, tr("ENEMY_BLACK_KNIGHT"), "沒有翻譯時用黑騎士")
