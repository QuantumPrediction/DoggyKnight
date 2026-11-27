extends Node
## Paired, staged poses in the real arena. Save PNGs at native 360 × 640 on a graphical run.
## WORN_GEAR_DIR=/absolute/path godot --resolution 360x640 --fixed-fps 60 res://tests/integration/worn_gear_showcase.tscn
## WORN_GEAR_LEVEL=4 or 8 adds the chapter insignia at the same camera and poses.
const ARENA := preload("res://game/combat/arena.tscn")
const PROFILES := preload("res://tests/integration/equipment_profiles.gd")
const BEATS: Array[String] = ["standing", "side_left", "front", "rear", "windup", "release"]
const PRESETS: Array[String] = ["common1", "epic9"]
const AT := Vector2(90, 162)

func _ready() -> void:
	var output := OS.get_environment("WORN_GEAR_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set WORN_GEAR_DIR to a writable output directory.")
		get_tree().quit(2)
		return
	get_window().size = Vector2i(360, 640)
	var rendered := DisplayServer.get_name() != "headless"
	var chapter_level := maxi(1, OS.get_environment("WORN_GEAR_LEVEL").to_int())
	var trace := FileAccess.open(output.path_join("poses.tsv"), FileAccess.WRITE)
	if trace == null:
		get_tree().quit(2)
		return
	trace.store_line("role\tloadout\tpose\torigin\tsheet\tregion\tmirror\tshoulder_and_weapon\tchapter_level")
	for role: StringName in HeroClasses.IDS:
		for preset in PRESETS:
			GameState.hero_class = role
			GameState.equipment = PROFILES.make(String(role), preset)
			GameState.reset_run()
			GameState.hero_level = chapter_level
			var arena := ARENA.instantiate()
			add_child(arena)
			var player := arena.call("get_player") as GoldiePlayer
			player.set_physics_process(false)
			player.position = AT
			await get_tree().process_frame
			await get_tree().process_frame
			var skin := player.sprite.get_node("IllustratedActor")
			for beat in BEATS:
				pose(player, beat)
				skin.call("_update")
				var image: AtlasTexture = skin.get("_tex")
				var pins := WornGear.SOCKETS.locate(String(role), image)
				if pins.is_empty():
					push_error("Unregistered pose " + beat)
					get_tree().quit(1)
					return
				trace.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d" % [role, preset, beat,
					player.position, image.atlas.resource_path.get_file(), image.region, skin.scale.x, pins, chapter_level])
				if rendered:
					await RenderingServer.frame_post_draw
					var pixels := get_viewport().get_texture().get_image()
					var name := "%s-%s-%s.png" % [role, preset, beat]
					if pixels == null or pixels.get_size() != Vector2i(360, 640) or pixels.save_png(output.path_join(name)) != OK:
						push_error("Failed to save 360 × 640 viewport " + name)
						get_tree().quit(1)
						return
			arena.free()
			await get_tree().process_frame
	trace.close()
	print("Recorded 36 staged arena poses. Rendered 360 × 640 PNGs: ", rendered)
	get_tree().quit()

func pose(player: GoldiePlayer, beat: String) -> void:
	var sprite := player.sprite
	player.stride_direction = Vector2.ZERO
	player.stride_moving = false
	player.facing = Vector2.RIGHT
	sprite.flip_h = false
	if beat in ["side_left", "front", "rear"]:
		var direction := Vector2.LEFT
		if beat == "front":
			direction = Vector2.DOWN
		elif beat == "rear":
			direction = Vector2.UP
		player.stride_direction = direction
		player.stride_moving = true
		player.stride_cycle = 0.25
		sprite.play(&"run")
	elif beat in ["windup", "release"]:
		sprite.play(&"attack")
	else:
		sprite.play(&"idle")
	sprite.set_frame_and_progress(2 if beat == "release" else 0, 0.0)
	sprite.pause()
