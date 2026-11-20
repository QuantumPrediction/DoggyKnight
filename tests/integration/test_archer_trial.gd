extends TestCase

const TRIAL := preload("res://tests/integration/archer_1_4_trial.tscn")
const FIXTURE := "res://tests/fixtures/archer_1_4_checkpoint.json"

func test_trial_restores_the_real_level_accepts_input_and_isolates_player_files() -> void:
	var log_path := PlayLog.log_path
	var log_digest := _digest(log_path)
	var save_digest := _digest(SaveStore.DEFAULT_PATH)
	var fixture_digest := _digest(FIXTURE)
	var trial = TRIAL.instantiate()
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
	var entered := false
	for i in 360:
		await wait_frames(1)
		if flow.is_dialogue_showing():
			flow.get_dialogue_box().call(&"skip")
		if flow.is_level_running() and not get_tree().paused:
			entered = true
			break
	assert_true(entered, "normal Continue reached playable combat")
	if entered:
		assert_true(flow.get_arena() is CombatArena)
		assert_eq(flow.get_level_index(), 3)
		assert_eq(flow.get_run_chapter(), 1)
		assert_eq(GameState.hero_class, &"archer")
		assert_eq(GameState.run_route, &"marksman")
		assert_eq(GameState.hero_level, 6)
		var player: GoldiePlayer = flow.get_arena().get_player()
		player.get_move_input()
		Input.action_press(&"move_right")
		assert_eq(player.get_move_input(), Vector2.RIGHT, "normal player input is in control")
		Input.action_release(&"move_right")
		PlayLog.append_entry({"event": "smoke"})
		assert_true(FileAccess.file_exists(PlayLog.log_path))
	trial.free()
	await wait_frames(2)
	assert_false(FileAccess.file_exists(private_path), "temporary profile removed on normal exit")
	assert_eq(PlayLog.log_path, log_path)
	assert_eq(_digest(log_path), log_digest)
	assert_eq(_digest(SaveStore.DEFAULT_PATH), save_digest)
	assert_eq(_digest(FIXTURE), fixture_digest)
	GameState.reset_run()

func _digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
