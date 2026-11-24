extends SceneTree
## Runs unchanged against #31 and the candidate. Use --fixed-fps 60 and
## LOCOMOTION_DIR=/absolute/path. LOCOMOTION_VIEWPORT=1 also saves native pixels.
const ROLES: Array[String] = ["knight", "mage", "archer"]
const TICKS := 552
const START := Vector2(60, 160)
const TOUCH_ORIGIN := Vector2(28, 228)
const CROP := Rect2i(64, 184, 296, 180)
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

## Observe only after the production skin has selected its drawing in _process.
class PostPaint extends Node:
	signal sampled
	func _process(_delta: float) -> void:
		sampled.emit()

var output := OS.get_environment("LOCOMOTION_DIR")
var pictures := OS.get_environment("LOCOMOTION_VIEWPORT") == "1"
var first_picture := OS.get_environment("LOCOMOTION_FIRST_PICTURE").to_int()
var after_paint := PostPaint.new()
var physics: FileAccess
var paint: FileAccess
var label := "idle"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if output.is_empty() or (pictures and DisplayServer.get_name() == "headless"):
		printerr("Set LOCOMOTION_DIR. LOCOMOTION_VIEWPORT=1 needs a real renderer.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	root.size = Vector2i(360, 640)
	after_paint.process_priority = 1000000
	root.add_child(after_paint)
	physics = FileAccess.open(output.path_join("physics.tsv"), FileAccess.WRITE)
	paint = FileAccess.open(output.path_join("paint.tsv"), FileAccess.WRITE)
	if physics == null or paint == null:
		printerr("Could not write locomotion traces")
		quit(1)
		return
	physics.store_line("role\ttick\tleg\tinput_x\tinput_y\ttouch\tx\ty\tdx\tdy\tvx\tvy\tgame_face_x\tgame_face_y\tanimation\tframe\tprogress\tswings\ttarget_hp\tshots\trolling")
	paint.store_line("role\ttick\tleg\tsheet\tcolumn\trow\tmirror_x\tsole_x\tsole_y\trotation\tskew")
	var state := root.get_node("GameState")
	for role: String in ROLES:
		state.set("hero_class", StringName(role))
		state.call("reset_run")
		var arena: Node = load("res://game/combat/arena.tscn").instantiate()
		arena.set("spawn_telegraph_time", 0.0)
		root.add_child(arena)
		var player: Node = arena.call("get_player")
		player.rng.seed = 19
		player.global_position = START
		var sprite: AnimatedSprite2D = player.get_node("Sprite")
		await after_paint.sampled
		await after_paint.sampled
		var skin := sprite.get_node("IllustratedActor") as Node2D
		var target: Node2D
		var previous: Vector2 = player.global_position
		for tick in TICKS:
			input_step(tick, player)
			if tick == 370:
				target = arena.call("spawn_enemy", &"scarecrow", player.global_position + Vector2(-19, 0))
				target.set_physics_process(false)
			elif tick == 426 and is_instance_valid(target):
				target.free()
			await physics_frame
			await after_paint.sampled
			var position: Vector2 = player.global_position
			var input: Vector2 = player.call("get_move_input")
			var travel := position - previous
			previous = position
			var hp := int(target.get("hp")) if is_instance_valid(target) else -1
			physics.store_line("%s\t%d\t%s\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%s\t%d\t%.6f\t%d\t%d\t%d\t%d" % [
				role, tick, label, input.x, input.y, int(player.joystick.is_active()), position.x, position.y, travel.x, travel.y,
				player.velocity.x, player.velocity.y, player.facing.x, player.facing.y, sprite.animation, sprite.frame,
				sprite.frame_progress, player.swing_count, hp, get_nodes_in_group(&"hero_projectile").size(), int(player.abilities.roll.is_rolling())])
			if not log_drawing(role, tick, player, sprite, skin):
				quit(1)
				return
			if pictures and tick >= first_picture and capture_tick(tick):
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				var stem := "%s-%03d" % [role, tick]
				if image == null or image.get_size() != Vector2i(360, 640) or image.get_region(CROP).save_png(output.path_join(stem + ".png")) != OK:
					printerr("Could not save native frame " + stem)
					quit(1)
					return
				if tick in [46, 238, 284, 318, 375, 482] and image.save_png(output.path_join(stem + "-full.png")) != OK:
					quit(1)
					return
		arena.free()
		await after_paint.sampled
	physics.close()
	paint.close()
	print("Recorded %d fixed physics ticks in each of %d classes." % [TICKS, ROLES.size()])
	quit()

func input_step(tick: int, player: Node) -> void:
	match tick:
		0:
			label = "idle"
			release_actions()
		8:
			label = "run_right"
			Input.action_press(&"move_right")
		46:
			label = "reverse_left"
			release_actions()
			Input.action_press(&"move_left")
		72:
			label = "release_left"
			release_actions()
		88:
			label = "half_action"
			# Fractional action strength through the player's normal Input.get_vector().
			# Physical keys and the touch joystick normally give 0 or 1.
			var deadzone := InputMap.action_get_deadzone(&"move_right")
			Input.action_press(&"move_right", lerpf(deadzone, 1.0, 0.5))
		148:
			label = "full_action"
			Input.action_press(&"move_right")
		186:
			label = "approach_wall"
		256:
			label = "run_up"
			release_actions()
			Input.action_press(&"move_up")
		284:
			label = "reverse_down"
			release_actions()
			Input.action_press(&"move_down")
		312:
			label = "release_down"
			release_actions()
		330:
			label = "half_touch"
			screen_touch(true)
			touch_drag(player.joystick.radius * 0.5)
		350:
			label = "full_touch"
			touch_drag(player.joystick.radius)
		370:
			label = "stop_and_attack"
			screen_touch(false)
		426:
			label = "clear_target"
		436:
			label = "second_run_up"
			Input.action_press(&"move_up")
		464:
			label = "release_up"
			release_actions()
		510:
			root.get_node("EventBus").emit_signal(&"trick_chosen", &"roll")
		511:
			label = "learned_roll"
			Input.action_press(&"move_left")
		538:
			label = "release_roll"
			release_actions()

func release_actions() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)

func screen_touch(press: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.pressed = press
	event.position = TOUCH_ORIGIN
	root.push_input(event, true)

func touch_drag(distance: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 3
	event.position = TOUCH_ORIGIN + Vector2.LEFT * distance
	root.push_input(event, true)

func log_drawing(role: String, tick: int, player: Node2D, sprite: AnimatedSprite2D, skin: Node2D) -> bool:
	var art := skin.get("_tex") as AtlasTexture
	if art == null or art.atlas == null:
		printerr("Missing illustrated drawing at %s/%d." % [role, tick])
		return false
	var cell := art.region.position / art.region.size
	var drawing: Rect2 = skin.get("_rect")
	# Registered position of the painted sole in player-local logical pixels.
	var sole := player.to_local(skin.to_global(drawing.position + drawing.size * Vector2(120.0 / 256.0, 176.0 / 192.0)))
	paint.store_line("%s\t%d\t%s\t%s\t%d\t%d\t%d\t%.6f\t%.6f\t%.6f\t%.6f" % [
		role, tick, label, art.atlas.resource_path.get_file().get_basename(), roundi(cell.x), roundi(cell.y),
		int(skin.transform.x.x < 0.0), sole.x, sole.y, sprite.rotation, sprite.skew])
	return true

func capture_tick(tick: int) -> bool:
	return (tick >= 6 and tick <= 86 and tick % 2 == 0) \
		or (tick >= 90 and tick <= 144 and tick % 3 == 0) \
		or (tick >= 216 and tick <= 328 and tick % 2 == 0) \
		or (tick >= 370 and tick <= 402 and tick % 5 == 0) \
		or (tick >= 458 and tick <= 494 and tick % 2 == 0) \
		or (tick >= 510 and tick <= 528 and tick % 3 == 0)
