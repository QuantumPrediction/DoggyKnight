extends "res://tests/integration/playthrough_bot.gd"
## Render the game's six opening pages from an already-earned save, then replay Mordred and the ending.
## Each chapter opens a disposable copy. The supplied checkpoint is never written to.

var earned_save := ""
var gallery := ""
var captured: Dictionary = {}


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--earned-save="):
			earned_save = arg.trim_prefix("--earned-save=")
		elif arg.begins_with("--gallery="):
			gallery = arg.trim_prefix("--gallery=")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(earned_save)) if FileAccess.file_exists(earned_save) else null
	var data := SaveStore.sanitize(raw) if raw is Dictionary else {}
	if DisplayServer.get_name() == "headless" or gallery.is_empty() or data.get("chapter") != 6 or data.get("chapters_cleared") != 5 or data.get("level_index") != 5 or data.checkpoint.is_empty():
		push_error("Use a rendering display, a gallery directory and an earned 6-6 entry save.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(gallery)
	get_tree().root.size = Vector2i(360, 640)
	Engine.time_scale = 1
	seed(rng_seed)
	Loot.seed_rng(rng_seed + 200)
	get_tree().node_added.connect(_seed_added_node)
	for n in range(1, 7):
		await _load_copy()
		GameState.chapter = n
		flow.start_new_game()
		await _frames(125)
		if not flow.is_story_playing() or flow.get_story_id() != (&"prologue" if n == 1 else StringName("c%d_prologue" % n)):
			push_error("Expected chapter opening %d" % n)
			get_tree().quit(2)
			return
		await _capture("chapter-%d" % n)
		await _close_copy()
	await _load_copy()
	flow.continue_game()
	var first_tick := Engine.get_physics_frames()
	while Engine.get_physics_frames() - first_tick < 42000:
		await get_tree().process_frame
		if flow.is_switching():
			continue
		if flow.is_story_playing():
			var box := flow.get_dialogue_box()
			if flow.get_story_id() == &"c6_teaser":
				await _frames(120)
				if tr("STORY_C6_TEASER_02") != "《黃金騎士》全劇終。謝謝你和金毛一起走到這裡。":
					push_error("Reimport the final story translations before rendering")
					get_tree().quit(2)
					return
				await _capture("homecoming")
				box.call(&"advance")
				await _frames(140)
				await _capture("the-end")
			box.call(&"skip")
			continue
		if flow.get_credits() != null:
			await _frames(85)
			await _capture("credits")
			print("GALLERY_OK ", captured.size(), " native frames from ", FileAccess.get_sha256(earned_save))
			get_tree().quit(0)
			return
		match flow.state:
			FlowMain.State.LEVEL:
				_level_clock += get_process_delta_time()
				if flow.is_level_running() and flow.get_session().time_sec > 8 and not captured.has("mordred"):
					await _capture("mordred")
				await _play_level()
			FlowMain.State.RESULTS:
				await _frames(90)
				await _capture("sixth-victory")
				flow.get_screen().emit_signal(&"continue_pressed")
			FlowMain.State.FAILURE:
				push_warning("The live finale replay was downed, preserving the failure.")
				await _capture("finale-downed")
				get_tree().quit(1)
				return
	push_error("Finale replay timed out")
	get_tree().quit(1)


func _load_copy() -> void:
	var copy_path := "user://six_episode_gallery.json"
	var output := FileAccess.open(copy_path, FileAccess.WRITE)
	output.store_buffer(FileAccess.get_file_as_bytes(earned_save))
	output.close()
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = copy_path
	flow.rng_seed = rng_seed
	add_child(flow)
	await _frames(6)


func _close_copy() -> void:
	flow.queue_free()
	await _frames(3)


func _capture(label: String) -> void:
	if captured.has(label):
		return
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if picture.get_size() != Vector2i(360, 640) or picture.save_png(gallery.path_join(label + ".png")) != OK:
		push_error("Failed to capture native portrait " + label)
		get_tree().quit(2)
		return
	captured[label] = true
	print("FRAME ", label)
