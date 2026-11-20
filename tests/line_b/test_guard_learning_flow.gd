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
	# Combat-side tests verify this event can only follow actual charge consumption.
	EventBus.companion_counter_granted.emit(.25)
	EventBus.companion_counter_resolved.emit(&"used")
	assert_true(GameState.guard_lesson_done)
	assert_true(read_save().guard_lesson_done)
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
