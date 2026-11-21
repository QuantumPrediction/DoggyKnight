extends "res://tests/line_b/flow_test_base.gd"

func before_each() -> void:
	reset_settings()
	SaveStore.new(SAVE_PATH).delete()

func enter_stage(index: int, done: bool = false) -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": index, "guard_lesson_done": done})
	make_flow(true)
	flow.use_stand_ins = false
	await wait_frames(1)
	flow.continue_game()
	assert_true(await wait_until(in_level))
	await wait_frames(10)

func test_v9_save_migrates_without_losing_equipment_or_progress() -> void:
	var equipment := EquipmentInventory.defaults()
	equipment.owned = {"training_sword": 4, "quilted_vest": 5}
	equipment.elements = {"training_sword": "water", "quilted_vest": "water"}
	equipment.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}}
	equipment.coins = 765
	equipment.gems = 12
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 9, "level_index": 3, "snacks": 125, "equipment": equipment}))
	file.close()
	var data := SaveStore.new(SAVE_PATH).read()
	assert_false(data.guard_lesson_done)
	assert_eq(data.level_index, 3)
	assert_eq(data.snacks, 125)
	assert_eq(data.equipment, EquipmentInventory.sanitize(equipment))
	assert_false(SaveStore.sanitize({"guard_lesson_done": "yes"}).guard_lesson_done)

func test_intro_shows_optional_lesson_skip_and_pause_replay() -> void:
	await enter_stage(2)
	var coach: GuardCoach = flow._hud.guard_coach
	assert_true(coach.visible)
	assert_false(get_tree().paused)
	coach.dismiss_button.pressed.emit()
	assert_false(coach.visible)
	assert_true(GameState.guard_lesson_skipped)
	assert_false(read_save().guard_lesson_done)
	flow._on_intro_finished()
	assert_false(coach.visible, "skip survives another intro callback in this run")
	AppLifecycle.simulate_back()
	assert_true(get_tree().paused)
	assert_true(flow._pause.lesson_button.visible)
	flow._pause.lesson_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_true(coach.visible)
	assert_false(GameState.guard_lesson_skipped)

func test_completed_flag_persists_and_replay_remains_available() -> void:
	await enter_stage(3)
	var coach: GuardCoach = flow._hud.guard_coach
	assert_true(coach.visible)
	var completion := watch_signal(EventBus.guard_lesson_completed)
	var arena: CombatArena = flow.get_arena()
	var mark := AttackTelegraph.make_circle(3.0)
	arena.add_child(mark)
	mark.global_position = arena.get_player().global_position + Vector2(13, 0)
	# Combat-side tests verify this event can only follow actual charge consumption.
	EventBus.companion_counter_granted.emit(.25)
	EventBus.companion_counter_resolved.emit(&"used")
	assert_true(GameState.guard_lesson_done)
	assert_true(read_save().guard_lesson_done)
	coach._process(0.01)
	assert_false(coach.heading.is_visible_in_tree(), "persistence happens even while the card is deferred")
	var save_after_done := FileAccess.get_sha256(SAVE_PATH)
	var music_setting := GameState.music_on
	GameState.music_on = not music_setting
	EventBus.companion_counter_granted.emit(.25)
	EventBus.companion_counter_resolved.emit(&"used")
	assert_eq(completion.count, 1, "one logical completion per lesson")
	assert_eq(FileAccess.get_sha256(SAVE_PATH), save_after_done, "no duplicate save during deferral")
	GameState.music_on = music_setting
	flow.queue_free()
	await wait_frames(2)
	GameState.guard_lesson_done = false
	make_flow(true)
	flow.use_stand_ins = false
	await wait_frames(1)
	assert_true(GameState.guard_lesson_done)
	flow.continue_game()
	assert_true(await wait_until(in_level))
	await wait_frames(10)
	assert_false(flow._hud.guard_coach.visible)
	EventBus.guard_lesson_requested.emit()
	assert_true(flow._hud.guard_coach.visible)
	assert_true(GameState.guard_lesson_done, "replay does not erase earned completion")

func test_before_companion_arrives_no_lesson_or_replay_button() -> void:
	await enter_stage(1)
	assert_false(flow._hud.guard_coach.visible)
	assert_false(flow._pause.lesson_button.visible)
	EventBus.guard_lesson_requested.emit()
	assert_false(flow._hud.guard_coach.visible)

func test_detached_flow_cannot_complete_or_save_an_old_lesson() -> void:
	await enter_stage(2)
	var saved_before := FileAccess.get_file_as_string(SAVE_PATH)
	remove_child(flow)
	GameState.guard_lesson_done = false
	EventBus.guard_lesson_completed.emit()
	assert_false(GameState.guard_lesson_done, "an exited flow cannot change the active run")
	assert_eq(FileAccess.get_file_as_string(SAVE_PATH), saved_before, "an exited flow cannot overwrite a checkpoint")

func test_detached_flow_disconnects_all_guard_lesson_callbacks() -> void:
	make_flow()
	remove_child(flow)
	GameState.guard_lesson_skipped = false
	EventBus.guard_lesson_dismissed.emit()
	assert_false(GameState.guard_lesson_skipped)
	for pair in [[EventBus.guard_lesson_requested, flow._replay_guard_lesson],
		[EventBus.guard_lesson_completed, flow._on_guard_lesson_completed],
		[EventBus.guard_lesson_dismissed, flow._on_guard_lesson_dismissed]]:
		var signal_value: Signal = pair[0]
		assert_false(signal_value.is_connected(pair[1]), "guard callbacks follow the same exit boundary as pause/input callbacks")
