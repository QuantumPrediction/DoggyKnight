extends SceneTree
## Run against each imported revision using one isolated XDG_DATA_HOME.
## -- write starts an archer game. -- read <sha256> continues its unchanged save.

func _initialize() -> void:
	run.call_deferred()


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var data_root := OS.get_environment("XDG_DATA_HOME")
	var path := ProjectSettings.globalize_path("user://save.json")
	var expected_dir := data_root.path_join("godot/app_userdata/金毛騎士")
	if OS.get_name() != "Linux" or not data_root.is_absolute_path() or OS.get_user_data_dir() != expected_dir or path != expected_dir.path_join("save.json"):
		fail("Use Linux and an isolated, absolute XDG_DATA_HOME")
		return
	if args.size() == 0:
		fail("Expected write or read <original-sha256>")
		return
	var writing := args[0] == "write"
	if writing:
		if args.size() != 1 or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp"):
			fail("Write needs an empty profile")
			return
	elif args.size() != 2 or args[0] != "read" or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != args[1]:
		fail("Read needs the original default save at the expected digest")
		return

	var state := root.get_node("GameState")
	var game: Node = load("res://game/flow/main.tscn").instantiate()
	game.rng_seed = 19
	root.add_child(game)
	var title: Node = game.get_screen()
	if writing:
		if game.has_save() or title.continue_button.visible:
			fail("New profile unexpectedly has progress")
			return
		state.set("sound_on", false)
		state.set("music_on", false)
		state.set("haptics_on", false)
		title.new_game_button.pressed.emit()
		var selection: Node = title.get_class_select()
		selection.choices[2].pressed.emit()
		selection.reinforced_button.pressed.emit()
	else:
		if not game.has_save() or not title.continue_button.visible:
			fail("Title did not offer the saved adventure")
			return
		if state.hero_class != &"archer" or game.get_run_difficulty() != &"reinforced" or state.sound_on or state.music_on or state.haptics_on:
			fail("Saved class, departure or preferences were not restored at title")
			return
		title.continue_button.pressed.emit()

	var arrived := false
	for frame in 480:
		await process_frame
		var dialogue: Node = game.get_dialogue_box()
		if dialogue != null and dialogue.is_active():
			dialogue.skip()
		if game.get_session() != null and not game.is_switching() and not game.is_dialogue_showing():
			arrived = true
			break
	if not arrived:
		fail("Did not reach a playable arena within eight seconds at 60 Hz")
		return
	var player: Node = game.get_session().get_player()
	var saved: Dictionary = game.save_store.read()
	if player == null or player.loadout.id != &"archer" or game.get_session().level.id != &"1-1" or game.get_session().difficulty_mode != &"reinforced" or saved.get("checkpoint", {}).is_empty():
		fail("Incorrect player, level, departure or checkpoint")
		return
	if state.sound_on or state.music_on or state.haptics_on:
		fail("Preferences changed on entering the arena")
		return
	print("GOLDEN_IDENTITY ", JSON.stringify({
		"action": args[0], "game": ProjectSettings.get_setting("application/config/name"),
		"path": path.trim_prefix(data_root + "/"), "v": saved.version, "level": game.get_session().level.id,
		"hero": player.loadout.id, "departure": game.get_session().difficulty_mode,
		"sound": state.sound_on, "music": state.music_on, "haptics": state.haptics_on,
		"checkpoint_sha256": JSON.stringify(saved.checkpoint).sha256_text(), "save_sha256": FileAccess.get_sha256(path)
	}))
	game.queue_free()
	for frame in 3:
		await process_frame
	quit()
