extends SceneTree
## The same script runs against #30 or the candidate. Captures use the real arena camera.
const INPUTS := [Vector2.DOWN, Vector2.UP, Vector2(-1, 1), Vector2(1, -1), Vector2.ZERO]
const TICKS_PER_INPUT := 36

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_environment("VERTICAL_RUN_DIR")
	var pictures := OS.get_environment("VERTICAL_VIEWPORT") == "1"
	if output.is_empty() or (pictures and DisplayServer.get_name() == "headless"):
		printerr("Set VERTICAL_RUN_DIR. VERTICAL_VIEWPORT=1 requires a rendering display.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(360, 640)
	var track := FileAccess.open(output.path_join("physics.tsv"), FileAccess.WRITE)
	if track == null:
		printerr("Cannot write the physics record")
		quit(1)
		return
	track.store_line("hero\tleg\ttick\tx\ty\tvx\tvy\tface_x\tface_y\tanimation\tframe\tprogress\tswings")
	var state := root.get_node("GameState")
	for role: String in ["knight", "mage", "archer"]:
		state.set("hero_class", StringName(role))
		state.call("reset_run")
		var arena: Node = load("res://game/combat/arena.tscn").instantiate()
		root.add_child(arena)
		var player: Node = arena.call("get_player")
		player.rng.seed = 19
		player.global_position = Vector2(90, 160)
		player.call("set_move_override", Vector2.ZERO)
		var sprite := player.get_node("Sprite") as AnimatedSprite2D
		await process_frame
		await process_frame
		for leg in INPUTS.size():
			player.call("set_move_override", INPUTS[leg])
			var captured := {}
			for tick in TICKS_PER_INPUT:
				await physics_frame
				await process_frame
				track.store_line("%s\t%d\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%s\t%d\t%.6f\t%d" % [
					role, leg, tick, player.global_position.x, player.global_position.y, player.velocity.x,
					player.velocity.y, player.facing.x, player.facing.y, sprite.animation, sprite.frame,
					sprite.frame_progress, player.swing_count])
				if pictures and leg < 2 and sprite.animation == &"run":
					var cycle := (sprite.frame + sprite.frame_progress) / sprite.sprite_frames.get_frame_count(&"run")
					var beat := clampi(floori(cycle * 4.0), 0, 3)
					if not captured.has(beat):
						captured[beat] = true
						await RenderingServer.frame_post_draw
						var frame := root.get_texture().get_image()
						var path := output.path_join("%s-%s-%d.png" % [role, "front" if leg == 0 else "back", beat])
						if frame == null or frame.get_size() != Vector2i(360, 640) or frame.save_png(path) != OK:
							printerr("Could not capture " + path)
							quit(1)
							return
		arena.free()
		await process_frame
		await process_frame
	track.close()
	print("Recorded 540 live movement ticks across three classes.")
	quit()
