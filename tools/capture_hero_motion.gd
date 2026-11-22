extends SceneTree
## A contact sheet of the actual selected actor drawings. Uses source pixels so it
## also works with a headless display. This is not a framebuffer capture.
const TICKS := 160
const SAMPLE_EVERY := 4
const SCALE := 4.0
var output := OS.get_environment("MOTION_CAPTURE_DIR")
var sheets := {}

func _initialize() -> void:
	run.call_deferred()

func paint(skin: Node2D, sprite: AnimatedSprite2D, file: String) -> void:
	skin.call("_update")
	var atlas := skin.get("_tex") as AtlasTexture
	var path := atlas.atlas.resource_path
	if not sheets.has(path):
		sheets[path] = Image.load_from_file(path)
	var source: Image = sheets[path]
	var region := Rect2i(atlas.region)
	var drawing := source.get_region(region)
	var original := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
	var rect := Rect2(sprite.offset - original * 0.5, original)
	if "_rect" in skin:
		rect = skin.get("_rect")
	var size := Vector2i((rect.size * SCALE).round())
	drawing.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	if sprite.flip_h:
		drawing.flip_x()
		rect.position.x = -rect.end.x
	var canvas := Image.create_empty(208, 156, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var offset := Vector2(100, 80) + (rect.position + sprite.position) * SCALE
	canvas.blend_rect(drawing, Rect2i(Vector2i.ZERO, size), Vector2i(offset.round()))
	canvas.save_png(file)

func run() -> void:
	if output.is_empty():
		printerr("Set MOTION_CAPTURE_DIR to a new output directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var track := FileAccess.open(output.path_join("events.tsv"), FileAccess.WRITE)
	track.store_line("hero\ttick\tswings\thp\tshots")
	var state := root.get_node("GameState")
	for id: String in ["knight", "mage", "archer"]:
		state.set("hero_class", StringName(id))
		state.call("reset_run")
		var arena: Node = load("res://game/combat/arena.tscn").instantiate()
		arena.set("spawn_telegraph_time", 0.0)
		root.add_child(arena)
		var player: Node = arena.call("get_player")
		player.rng.seed = 19
		player.global_position = Vector2(35, 150)
		player.invuln_left = 30
		player.call("set_move_override", Vector2.ZERO)
		await process_frame
		await process_frame
		var target: Node2D
		for tick in TICKS:
			if tick == 12:
				player.call("set_move_override", Vector2.RIGHT)
			if tick == 78:
				player.call("set_move_override", Vector2.ZERO)
				target = arena.call("spawn_enemy", &"scarecrow", player.global_position + Vector2(19, 0))
				target.set_physics_process(false)
			if tick == 124 and is_instance_valid(target):
				target.free()
			await physics_frame
			await process_frame
			var hp := int(target.get("hp")) if is_instance_valid(target) else -1
			track.store_line("%s\t%d\t%d\t%d\t%d" % [id, tick, player.swing_count, hp, get_nodes_in_group(&"hero_projectile").size()])
			if tick % SAMPLE_EVERY == 0:
				var sprite: AnimatedSprite2D = player.get_node("Sprite")
				paint(sprite.get_node("IllustratedActor"), sprite, output.path_join("%s-%02d.png" % [id, tick / SAMPLE_EVERY]))
		arena.free()
		await process_frame
		await process_frame
	track.close()
	print("Sampled 40 drawings for each of three classes. Source pixels, fixed framing, 60 Hz input.")
	quit()
