extends TestCase

const ArcherTrial := preload("res://tests/integration/archer_1_4_trial.gd")
const TRIAL := preload("res://tests/integration/archer_1_4_trial.tscn")
const OUTRIDER := preload("res://tests/integration/archer_1_4_outrider_trial.tscn")

func test_trial_restores_the_real_level_accepts_input_and_isolates_player_files() -> void:
	await _check_playable_entry(TRIAL, &"marksman")

func test_outrider_trial_restores_its_own_build_and_accepts_guard_input() -> void:
	await _check_playable_entry(OUTRIDER, &"outrider")

func _check_playable_entry(scene: PackedScene, route: StringName) -> void:
	var log_path := PlayLog.log_path
	var log_digest := _digest(log_path)
	var save_digest := _digest(SaveStore.DEFAULT_PATH)
	var trial := scene.instantiate() as ArcherTrial
	var fixture: String = trial.checkpoint_path
	var fixture_digest := _digest(fixture)
	var source := SaveStore.new(fixture).read()
	add_child(trial)
	var flow: FlowMain = trial.flow
	assert_not_null(flow)
	if flow == null:
		trial.free()
		return
	var private_path := flow.save_path
	assert_ne(private_path, SaveStore.DEFAULT_PATH)
	assert_ne(PlayLog.log_path, log_path)
	assert_eq(PlayLog.log_path.get_base_dir(), private_path.get_base_dir())
	assert_eq(GameState.run_route, route)
	assert_false(GameState.guard_lesson_done)
	assert_eq(GameState.vigor, int(source.checkpoint.vigor))
	assert_eq(PackedStringArray(GameState.active_tricks), PackedStringArray(source.checkpoint.tricks))
	assert_eq(GameState.run_equipment, source.checkpoint.equipment)
	var saw_opening := false
	var entered := false
	for i in 360:
		await wait_frames(1)
		if flow.is_dialogue_showing():
			saw_opening = saw_opening or flow.get_story_id() == &"l4_before"
			flow.get_dialogue_box().call(&"skip")
		if flow.is_level_running() and not get_tree().paused and not flow.get_arena().get_enemies().is_empty():
			entered = true
			break
	assert_true(saw_opening, "the normal 1-4 dialogue was available to read")
	assert_true(entered, "normal Continue reached playable combat")
	if entered:
		assert_true(flow.get_arena() is CombatArena)
		assert_eq(flow.get_level_index(), 3)
		assert_eq(flow.get_run_chapter(), 1)
		assert_eq(GameState.hero_class, &"archer")
		assert_eq(GameState.hero_level, 6)
		var player: GoldiePlayer = flow.get_arena().get_player()
		player.get_move_input()
		Input.action_press(&"move_right")
		assert_eq(player.get_move_input(), Vector2.RIGHT, "normal player input is in control")
		Input.action_release(&"move_right")
		var ally := get_tree().get_first_node_in_group(&"companion") as BulldogCompanion
		assert_not_null(ally)
		if ally != null:
			assert_eq(ally.rally_commands, 0)
			var guard_key := InputEventKey.new()
			guard_key.physical_keycode = KEY_Q
			guard_key.pressed = true
			get_viewport().push_input(guard_key)
			guard_key.pressed = false
			get_viewport().push_input(guard_key)
			assert_eq(ally.rally_commands, 1, "the companion accepts Q through the normal key binding")
			assert_false(GameState.guard_lesson_done, "calling the companion is not a used counter")
		PlayLog.append_entry({"event": "smoke"})
		assert_true(FileAccess.file_exists(PlayLog.log_path))
	await _close_trial(trial)
	assert_false(FileAccess.file_exists(private_path), "temporary profile removed on normal exit")
	assert_eq(PlayLog.log_path, log_path)
	assert_eq(_digest(log_path), log_digest)
	assert_eq(_digest(SaveStore.DEFAULT_PATH), save_digest)
	assert_eq(_digest(fixture), fixture_digest)
	GameState.reset_run()

func test_relaunch_does_not_inherit_the_previous_participants_checkpoint() -> void:
	var first := OUTRIDER.instantiate() as ArcherTrial
	add_child(first)
	var path: String = first.flow.save_path
	var store := SaveStore.new(path)
	var saved := store.read()
	saved.guard_lesson_done = true
	assert_true(store.write_data(saved))
	assert_true(store.read().guard_lesson_done)
	await _close_trial(first)
	var next_trial := OUTRIDER.instantiate() as ArcherTrial
	add_child(next_trial)
	assert_ne(next_trial.flow.save_path, path)
	assert_false(FileAccess.file_exists(path))
	assert_false(GameState.guard_lesson_done)
	assert_false(SaveStore.new(next_trial.flow.save_path).read().guard_lesson_done)
	await _close_trial(next_trial)
	GameState.reset_run()

func _close_trial(trial: ArcherTrial) -> void:
	trial.flow.show_title()
	await wait_frames(2)
	trial.free()
	await wait_frames(2)

func _digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
