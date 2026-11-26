extends SceneTree
## Run the same file on both checkouts with --fixed-fps 60 and TOUCH_PRECISION_DIR.
## Events enter the root viewport at logical coordinates. Sample after player physics.

const ROLES := ["knight", "mage", "archer"]
const RADII := [0.0, 2.5, 3.0, 4.5, 6.0, 9.0, 12.0, 13.5, 15.0, 15.3, 16.0, 18.0, 27.0]
const TOUCH := Vector2(28, 228)
const START := Vector2(136, 160)
const STRIP := Vector2(6, 12)
const HOLD := 16
const PRIMARY := 3
const SECOND := 7

class Observer extends Node:
	signal sampled
	func _process(_delta: float) -> void:
		sampled.emit()

var observer := Observer.new()
var output := OS.get_environment("TOUCH_PRECISION_DIR")
var trace: FileAccess
var summary: FileAccess
var arena: Node
var player: Node2D
var target: Node2D
var role: String
var trial: String
var tick: int
var marker: Vector2
var damage_tick: int
var attack_tick: int
var starting_hp: int
var input_failure := false
var starting_step: int

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK or Engine.physics_ticks_per_second != 60:
		printerr("Set TOUCH_PRECISION_DIR to a writable directory and use 60 Hz.")
		quit(2)
		return
	root.size = Vector2i(360, 640)
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.process_priority = 1000000
	root.add_child(observer)
	trace = FileAccess.open(output.path_join("ticks.tsv"), FileAccess.WRITE)
	summary = FileAccess.open(output.path_join("trials.tsv"), FileAccess.WRITE)
	if trace == null or summary == null:
		quit(2)
		return
	trace.store_line("role\ttrial\ttick\tphase\towner\tin_x\tin_y\tx\ty\tvx\tvy\tswings\ttarget_x\ttarget_y\ttarget_hp\tshots\troll\tinvulnerable\tcooldown\tfacing_x\tfacing_y\tmirror\tphysics_step")
	summary.store_line("role\ttrial\thold_ticks\tdrag\tnorm\thold_dx\thold_dy\trest_dx\trest_dy\tswings_held\tfirst_swing\tfirst_damage\tstrip\tcombat_task")
	for next_role: String in ROLES:
		role = next_role
		for radius: float in RADII:
			await gesture("right_" + String.num(radius, 1), radius, Vector2.RIGHT, HOLD)
		for radius: float in [2.0, 9.0, 18.0]:
			await gesture("diagonal_" + String.num(radius, 1), radius, Vector2(0.6, -0.8), HOLD)
		await gesture("shallow_left", 6.0, Vector2(-0.08, -sqrt(1 - 0.08 ** 2)), HOLD)
		await gesture("range_half", 9.0, Vector2.RIGHT, HOLD, true)
		await gesture("range_full", 18.0, Vector2.RIGHT, HOLD, true)
		await gesture("range_short", 18.0, Vector2.RIGHT, 8, true)
		await gesture("wall_full", 18.0, Vector2.RIGHT, 32, false, Vector2(162, 160))
		await gesture("keyboard_full", 0.0, Vector2.RIGHT, HOLD)
		await gesture("roll_half", 9.0, Vector2.RIGHT, 24, false, Vector2(50, 160))
		await gesture("roll_full", 18.0, Vector2.RIGHT, 24, false, Vector2(50, 160))
		await interruptions()
	trace.close()
	summary.close()
	print("Touch precision trace complete for three classes.")
	quit(1 if input_failure else 0)

func setup_trial(name_of_trial: String, start: Vector2) -> void:
	var state := root.get_node("GameState")
	state.set("hero_class", StringName(role))
	state.call("reset_run")
	arena = load("res://game/combat/arena.tscn").instantiate()
	arena.set("spawn_telegraph_time", 0.0)
	root.add_child(arena)
	player = arena.call("get_player")
	player.get("rng").seed = 19
	player.global_position = start
	target = null
	starting_hp = -1
	damage_tick = -1
	attack_tick = -1
	trial = name_of_trial
	tick = 0
	marker = start
	# Let the new scene join normal viewport input dispatch before sending a touch.
	await observer.sampled
	await observer.sampled
	starting_step = Engine.get_physics_frames()

func gesture(name_of_trial: String, distance: float, direction: Vector2, hold: int, with_target := false, start := START) -> void:
	await setup_trial(name_of_trial, start)
	var with_roll := name_of_trial.begins_with("roll_")
	if with_target:
		var attack_range := float(root.get_node("GameState").get("player_stats").get("attack_range"))
		target = arena.call("spawn_enemy", &"scarecrow", start + Vector2.LEFT * attack_range)
		# Place the center once. The real player's acquisition, projectile and hit tests remain active.
		var combat_reach := attack_range + float(target.get("body_radius"))
		target.global_position = start + Vector2.LEFT * (combat_reach - STRIP.y)
		target.set_physics_process(false)
		starting_hp = int(target.get("hp"))
	if name_of_trial == "keyboard_full":
		Input.action_press(&"move_right")
	else:
		if with_roll:
			root.get_node("EventBus").emit_signal(&"trick_chosen", &"roll")
		touch(PRIMARY, TOUCH, true)
		drag(PRIMARY, TOUCH + direction * distance)
		if int(player.get("joystick").call("get_touch_index")) != PRIMARY:
			printerr("Viewport failed to deliver primary touch: ", role, "/", trial)
			input_failure = true
	var input: Vector2 = player.call("get_move_input")
	await sample("hold", hold)
	var hold_delta := player.global_position - marker
	var held_swings := int(player.get("swing_count"))
	if name_of_trial == "keyboard_full":
		Input.action_release(&"move_right")
	else:
		touch(PRIMARY, TOUCH + direction * distance, false)
	var rest_ticks := 188 - hold if with_roll else (60 if with_target else 6)
	await sample("release", rest_ticks)
	var rest := player.global_position - marker
	var in_strip := int(rest.x >= STRIP.x and rest.x <= STRIP.y and absf(rest.y) < 0.001)
	var success := int(in_strip == 1 and held_swings == 0 and damage_tick >= hold)
	summary.store_line("%s\t%s\t%d\t%.3f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t%d\t%d\t%d" % [
		role, trial, hold, distance, input.length(), hold_delta.x, hold_delta.y, rest.x, rest.y, held_swings,
		attack_tick, damage_tick, in_strip if with_target else -1, success if with_target else -1])
	if with_roll:
		touch(PRIMARY, TOUCH, true)
		drag(PRIMARY, TOUCH + direction * distance)
		await sample("reroll", 3)
		touch(PRIMARY, TOUCH + direction * distance, false)
		await sample("second_release", 6)
	arena.free()

func interruptions() -> void:
	await setup_trial("ownership", START)
	touch(PRIMARY, TOUCH, true)
	drag(PRIMARY, TOUCH + Vector2.RIGHT * 9)
	await sample("primary", 6)
	var other := TOUCH + Vector2(24, 12)
	touch(SECOND, other, true)
	drag(SECOND, other + Vector2.UP * 18)
	await sample("secondary_drag", 3)
	touch(SECOND, other + Vector2.UP * 18, false)
	await sample("secondary_release", 2)
	drag(PRIMARY, TOUCH)
	await sample("recenter", 6)
	drag(PRIMARY, TOUCH + Vector2.UP * 18)
	await sample("resume", 3)
	touch(PRIMARY, TOUCH + Vector2.UP * 18, false, true)
	await sample("cancel", 6)
	touch(PRIMARY, TOUCH, true)
	drag(PRIMARY, TOUCH + Vector2.RIGHT * 18)
	await sample("before_pause", 4)
	paused = true
	await sample("paused", 3)
	paused = false
	await sample("unpaused", 6)
	# Start on the game's actual pause button and drag out. A HUD gesture must never own the stick.
	var hud: Control = load("res://ui/hud/hud.tscn").instantiate()
	root.add_child(hud)
	await observer.sampled
	await observer.sampled
	var button: Button = hud.get("pause_button")
	var inside := button.get_global_rect().get_center()
	touch(PRIMARY, inside, true)
	drag(PRIMARY, inside + Vector2.DOWN * 40)
	await sample("hud_blocked", 4)
	touch(PRIMARY, inside + Vector2.DOWN * 40, false, true)
	hud.free()
	# _go_down is reached by the normal production damage path and releases/disables the stick.
	player.call("take_damage", 10000)
	touch(SECOND, other, true)
	drag(SECOND, other + Vector2.RIGHT * 18)
	await sample("downed", 6)
	touch(SECOND, other, false)
	arena.free()

func touch(index: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	root.push_input(event, true)

func vector_columns(vector: Vector2) -> String:
	return "%.6f\t%.6f" % [vector.x, vector.y]

func sample(phase: String, ticks: int) -> void:
	for _i in ticks:
		await physics_frame
		await observer.sampled
		var input: Vector2 = player.call("get_move_input")
		var velocity: Vector2 = player.get("velocity")
		var stick: Node = player.get("joystick")
		var swings := int(player.get("swing_count"))
		var hp := int(target.get("hp")) if is_instance_valid(target) else -1
		var where := target.global_position if is_instance_valid(target) else Vector2(-1, -1)
		if attack_tick < 0 and swings > 0:
			attack_tick = tick
		if damage_tick < 0 and starting_hp > 0 and hp >= 0 and hp < starting_hp:
			damage_tick = tick
		var abilities: RefCounted = player.get("abilities")
		var roll: RefCounted = abilities.get("roll")
		var facing: Vector2 = player.get("facing")
		trace.store_line("\t".join([
			role, trial, str(tick), phase, str(stick.call("get_touch_index")),
			vector_columns(input), vector_columns(player.global_position), vector_columns(velocity),
			str(swings), vector_columns(where), str(hp), str(get_nodes_in_group(&"hero_projectile").size()),
			str(int(roll.call("is_rolling"))), str(int(abilities.call("is_invulnerable"))),
			"%.6f" % float(roll.get("cooldown_left")), vector_columns(facing),
			str(int(player.get_node("Sprite").get("flip_h"))), str(Engine.get_physics_frames() - starting_step)]))
		tick += 1
