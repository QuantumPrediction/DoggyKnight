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

func test_each_portrait_opens_its_own_combat_illustration_and_stable_departures() -> void:
	var picker := HeroClassSelect.new()
	picker.offer_reinforcements = true
	add_child(picker)
	var previous_notch := SafeArea.simulate_notch
	var illustrations: Array[Texture2D] = []
	var notes := picker.find_child("FieldNotes", true, false) as ScrollContainer
	var hint := picker.find_child("ReinforcementRule", true, false) as Label
	assert_not_null(hint)
	assert_eq(hint.text, tr("UI_REINFORCED_HINT"))
	var font := load("res://assets/fonts/StorySans.otf") as Font
	for glyph in hint.text + picker.reinforced_button.text:
		assert_true(font.has_char(glyph.unicode_at(0)), glyph)
	for notched in [false, true]:
		SafeArea.simulate_notch = notched
		picker._layout()
		await wait_frames(4)
		var depart := picker.reinforced_button.get_global_rect()
		for i in HeroClasses.IDS.size():
			var id := HeroClasses.IDS[i]
			var tab := picker.choices[i]
			var icon := (tab.get_node("Portrait") as TextureRect).texture as AtlasTexture
			assert_not_null(icon)
			assert_eq(tab.accessibility_name, tr(HeroClasses.get_data(id).display_name))
			assert_true(tab.size.x >= UiKit.MIN_TOUCH and tab.size.y >= UiKit.MIN_TOUCH)
			assert_true(UiKit.safe_rect().encloses(tab.get_global_rect()))
			tab.pressed.emit()
			await wait_frames(2)
			assert_eq(picker.selected, id)
			assert_true(tab.button_pressed)
			assert_eq(picker._portrait.texture, icon.atlas)
			assert_true(Rect2(Vector2.ZERO, icon.atlas.get_size()).encloses(icon.region))
			var data := HeroClasses.get_data(id)
			assert_eq(picker._description.text, tr(data.description))
			assert_eq(picker._vigor.text, str(data.stats.max_vigor))
			assert_eq(picker._range.text, str(int(data.stats.attack_range)))
			assert_eq(picker._ultimate.text, tr(data.ultimate_name))
			if not notched:
				assert_false(illustrations.has(picker._portrait.texture))
				illustrations.append(picker._portrait.texture)
			assert_true(UiKit.safe_rect().encloses(picker._portrait.get_global_rect()))
			assert_false(notes.get_v_scroll_bar().visible, "%s 的首屏可讀完職業說明" % id)
			assert_true(notes.get_global_rect().encloses(picker._ultimate.get_global_rect()))
			assert_true(UiKit.safe_rect().encloses(hint.get_global_rect()))
			assert_true(hint.get_global_rect().end.y <= depart.position.y)
			assert_eq(picker.reinforced_button.get_global_rect(), depart)
			assert_true(UiKit.safe_rect().encloses(picker.cancel_button.get_global_rect()))
	SafeArea.simulate_notch = previous_notch

func test_ordinary_picker_shows_no_first_chapter_challenge_rule() -> void:
	var picker := HeroClassSelect.new()
	add_child(picker)
	assert_null(picker.reinforced_button)
	assert_null(picker.find_child("ReinforcementRule", true, false))

func test_class_art_accepts_pointer_touch_and_keyboard_selection() -> void:
	var picker := HeroClassSelect.new()
	add_child(picker)
	await wait_frames(4)
	var portrait := picker.choices[1].get_node("Portrait") as Control
	var point := portrait.get_global_transform_with_canvas() * (portrait.size / 2.0)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		get_viewport().push_input(click, true)
	assert_eq(picker.selected, &"mage", "按法師縮圖便能選職")
	var caption := picker.choices[2].get_node("Caption") as Control
	point = caption.get_screen_transform() * (caption.size / 2.0)
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await wait_frames(1)
	assert_eq(picker.selected, &"archer", "點弓箭手圖下的職名也能選職")
	picker.choices[0].grab_focus()
	for pressed in [true, false]:
		var key := InputEventAction.new()
		key.action = &"ui_accept"
		key.pressed = pressed
		get_viewport().push_input(key)
	assert_eq(picker.selected, &"knight", "聚焦後確認能選職")
