extends TestCase

func after_each() -> void:
	for child in get_children():
		child.queue_free()
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.music_on = true
	Music.set_ducked(false)
	Music.stop(0.0)
	await wait_frames(2)

func test_new_game_opens_class_select_before_starting_and_cancel_preserves_hero() -> void:
	GameState.chapter_cleared = false
	var title: Node = load("res://ui/screens/title.tscn").instantiate()
	add_child(title)
	var starts := [0]
	title.new_game_pressed.connect(func() -> void: starts[0] += 1)
	title.new_game_button.pressed.emit()
	var picker: HeroClassSelect = title.get_class_select()
	assert_not_null(picker)
	assert_eq(starts[0], 0)
	picker.select(&"mage")
	picker.cancel_button.pressed.emit()
	assert_eq(GameState.hero_class, &"knight")
	assert_eq(starts[0], 0)
	title.new_game_button.pressed.emit()
	picker = title.get_class_select()
	picker.select(&"archer")
	picker.confirm_button.pressed.emit()
	assert_eq(GameState.hero_class, &"archer")
	assert_eq(starts[0], 1)
	title._confirm_class(&"mage")
	assert_eq(starts[0], 1, "重複確認不能再開始一輪")

func test_class_picker_keeps_actions_visible_without_scrolling() -> void:
	var picker := HeroClassSelect.new()
	add_child(picker)
	for id in HeroClasses.IDS:
		picker.select(id)
		await wait_frames(3)
		var panel := picker.get_node("ClassPanel") as Control
		var actions := picker.cancel_button.get_global_rect()
		assert_true(panel.get_global_rect().encloses(actions), "%s 返回鈕在面板內" % id)
		assert_true(UiKit.safe_rect().encloses(panel.get_global_rect()))

func test_old_and_invalid_saves_default_to_knight_and_new_save_round_trips() -> void:
	assert_eq(SaveStore.sanitize({})["hero_class"], "knight")
	assert_eq(SaveStore.sanitize({"hero_class": []})["hero_class"], "knight")
	var store := SaveStore.new("user://class-test.json")
	assert_true(store.write_data({"hero_class": "mage", "level_index": 2}))
	assert_eq(store.read()["hero_class"], "mage")
	store.delete()

func test_class_art_and_chinese_glyphs_exist() -> void:
	var font := load("res://assets/fonts/StorySans.otf") as Font
	for id in HeroClasses.IDS:
		var data := HeroClasses.get_data(id)
		for key in [data.display_name, data.description, data.tactic, data.ultimate_name]:
			assert_ne(tr(key), key)
			for ch in tr(key):
				assert_true(font.has_char(ch.unicode_at(0)), ch)
		for pose in 8:
			assert_not_null(StoryArt.hero(id, pose))

func test_pressure_stems_match_loop_lengths_and_short_cues_stay_one_shot() -> void:
	for id in Music.LOOPS:
		var stream := Music._stream(id)
		assert_true(stream is AudioStreamOggVorbis)
		assert_true(stream.get_length() > 58.0)
		assert_true(stream.loop)
		if Music._is_battle(id):
			var stem := Music._stream(StringName(String(id) + "_pressure"))
			assert_almost_eq(stem.get_length(), stream.get_length(), 0.001)
			assert_true(stem.loop)
	for id in Music.JINGLES:
		assert_eq((Music._stream(id) as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)

func test_pressure_rises_with_crowd_and_danger_and_mute_stops_both_layers() -> void:
	var calm := Music.pressure_for(1, 1.0, false, 1)
	assert_true(Music.pressure_for(10, 1.0, false, 1) > calm)
	assert_true(Music.pressure_for(1, 0.2, true, 2) > calm)
	GameState.music_on = true
	Music.play(&"field", 0.0)
	var deck: int = Music._active
	assert_true(Music._rhythm[deck].playing)
	await wait_frames(4)
	Music.play(&"field", 0.0)
	assert_eq(Music._active, deck, "same track does not restart on a wave")
	GameState.music_on = false
	Music.refresh()
	for player in Music._players + Music._rhythm:
		assert_false(player.playing)

func test_reinforced_departure_is_available_on_a_fresh_first_chapter() -> void:
	GameState.chapter_cleared = false
	var title: Node = load("res://ui/screens/title.tscn").instantiate()
	add_child(title)
	title.new_game_button.pressed.emit()
	var picker: HeroClassSelect = title.get_class_select()
	assert_not_null(picker.reinforced_button)
	await wait_frames(2)
	assert_true(UiKit.safe_rect().encloses(picker.reinforced_button.get_global_rect()))
	assert_false(picker.reinforced_button.get_global_rect().intersects(picker.confirm_button.get_global_rect()))
	picker.select(&"mage")
	picker.reinforced_button.pressed.emit()
	assert_eq(GameState.difficulty, FlowMain.REINFORCED)
	assert_eq(GameState.hero_class, &"mage")
	GameState.difficulty = FlowMain.NORMAL
