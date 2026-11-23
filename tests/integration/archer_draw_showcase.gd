extends Node
## Run this same fixture on both revisions, with ordinary game physics at 60 Hz.
const CASES := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "front": Vector2.DOWN,
	"back": Vector2.UP, "sidestep": Vector2.DOWN, "interrupt": Vector2.RIGHT}
const CENTER := Vector2(90, 171)
const TICKS := 100
var out := OS.get_environment("ARCHER_DRAW_DIR")
var ink_off := OS.get_environment("ARCHER_DRAW_NO_INK") == "1"
var film := OS.get_environment("ARCHER_DRAW_FILM") == "1"
var trace: FileAccess
var pictures: Dictionary = {}
var failure: String = ""

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if out.is_empty() or DirAccess.make_dir_recursive_absolute(out) != OK:
		push_error("Set ARCHER_DRAW_DIR to a writable absolute directory")
		get_tree().quit(2)
		return
	get_tree().root.size = Vector2i(360, 640)
	get_tree().node_added.connect(_seed_enemy)
	trace = FileAccess.open(out.path_join("combat.tsv"), FileAccess.WRITE)
	trace.store_line("case\ttick\tphase\tarcher_xy\tfacing\thero_xy\tvigor\taims\tshots\tanimation\tframe\tmark_xy\tmark_dir\tmark_length\tmark_width\tprogress\tlocked\tarrow_xy\tarrow_origin\tarrow_dir\ttravel\tarrow_state\thits")
	for label: String in CASES:
		await encounter(label)
		if not failure.is_empty():
			break
	trace.close()
	get_tree().node_added.disconnect(_seed_enemy)
	var meta := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	meta.store_line(JSON.stringify(pictures, "\t"))
	meta.close()
	print("Archer samples ", pictures.size(), " (", DisplayServer.get_name(), ")")
	if not failure.is_empty():
		push_error(failure)
	get_tree().quit(0 if failure.is_empty() else 1)

func _seed_enemy(node: Node) -> void:
	if node is ArcherEnemy:
		(node as ArcherEnemy).rng_seed_override = 19028

func encounter(label: String) -> void:
	seed(19028)
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	GameState.level_index = 3
	var room := Node.new()
	add_child(room)
	var arena: CombatArena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0.0
	room.add_child(arena)
	arena.set_background(preload("res://assets/backgrounds/farm_fence.tscn"))
	var player: GoldiePlayer = arena.get_player()
	player.set_physics_process(false)
	player.global_position = CENTER + Vector2(CASES[label]) * 68.0
	var archer := arena.spawn_enemy(&"scarecrow_archer", CENTER) as ArcherEnemy
	archer.target = player
	archer.set_physics_process(false)
	var hud := CanvasLayer.new()
	room.add_child(hud)
	hud.add_child(preload("res://ui/hud/hud.tscn").instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var health := GameState.vigor
	for tick in TICKS:
		if tick == 3:
			# Remove only the random wait before this single staged opportunity.
			archer._cooldown_left = 0.0
			archer.set_physics_process(true)
		if label == "sidestep" and tick == 10:
			player.global_position = CENTER + Vector2(63, 9)
		if label == "sidestep" and tick == 31:
			player.global_position = CENTER + Vector2(-15, 67)
		if label == "interrupt" and tick == 31:
			archer.stun(2.0)
		await get_tree().physics_frame
		await get_tree().process_frame
		var mark: AttackTelegraph = archer._telegraph
		if not is_instance_valid(mark) or not mark.is_visible_damage_warning():
			mark = null
		var arrow := get_tree().get_first_node_in_group(EnemyProjectile.GROUP) as EnemyProjectile
		var sprite := archer.sprite
		trace.store_csv_line(PackedStringArray([label, str(tick), str(archer.phase),
			str(archer.global_position), str(archer.facing), str(player.global_position),
			str(GameState.vigor), str(archer.aims_started), str(archer.shots_fired),
			String(sprite.animation), str(sprite.frame), str(mark.global_position) if mark else "",
			str(mark.direction) if mark else "", str(mark.length) if mark else "",
			str(mark.width) if mark else "", str(mark.progress) if mark else "",
			str(int(mark.aim_locked)) if mark else "", str(arrow.global_position) if arrow else "",
			str(arrow.origin) if arrow else "", str(arrow.direction) if arrow else "",
			str(arrow.traveled) if arrow else "", str(arrow.state) if arrow else "",
			str(arrow.hits) if arrow else ""]), "\t")
		var beat := ""
		if tick == 1 and label == "right":
			beat = "idle"
		elif label == "sidestep" and tick in [10, 31]:
			beat = "track-turn" if tick == 10 else "late-step"
		elif label == "interrupt" and tick == 31:
			beat = "cancelled"
		elif mark != null:
			beat = "tracking"
			if mark.aim_locked:
				beat = "hot" if mark.is_hot() else "locked"
		elif archer.phase == ArcherEnemy.Phase.RELEASE:
			beat = "loose" if sprite.frame == 0 else "lower"
		elif archer.shots_fired > 0 and label == "right":
			beat = "hit" if GameState.vigor < health else "move"
		var key := label + "-" + beat
		var sample := not beat.is_empty() and not pictures.has(key)
		var clip := film and label == "right" and not ink_off
		if sample or clip:
			await capture(key if sample else "", tick, archer, mark, clip)
	if archer.aims_started != 1 or archer.shots_fired != (0 if label == "interrupt" else 1):
		failure = label + " unexpected aim/shot count"
	if (GameState.vigor < health) != (label not in ["sidestep", "interrupt"]):
		failure = label + " unexpected hit or miss"
	room.free()
	await get_tree().process_frame

func capture(key: String, tick: int, archer: ArcherEnemy, mark: AttackTelegraph, clip: bool) -> void:
	var screen := get_viewport().get_stretch_transform()
	var skin := archer.sprite.get_node("IllustratedActor") as Node2D
	var draw := screen * skin.get_global_transform_with_canvas()
	var corners: Array = []
	for point: Vector2 in [Vector2(-16, -16), Vector2(16, 16)]:
		var pixel := draw * point
		corners.append([pixel.x, pixel.y])
	var lane: Array = []
	if mark != null:
		var to_pixel := screen * mark.get_global_transform_with_canvas()
		var origin := to_pixel * Vector2.ZERO
		var end := to_pixel * (mark.direction * mark.length)
		lane = [origin.x, origin.y, end.x, end.y, mark.length, mark.width, mark.aim_locked]
	if not key.is_empty():
		pictures[key] = {"tick": tick, "corners": corners, "lane": lane}
	if DisplayServer.get_name() == "headless" or (ink_off and mark == null):
		return
	if ink_off:
		await RenderingServer.frame_pre_draw
		RenderingServer.canvas_item_set_visible(mark.get_canvas_item(), false)
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	if ink_off:
		RenderingServer.canvas_item_set_visible(mark.get_canvas_item(), true)
	if frame.get_size() != Vector2i(360, 640):
		failure = key + " viewport size"
		return
	if not key.is_empty() and frame.save_png(out.path_join(key + ".png")) != OK:
		failure = key + " failed to save"
	if clip and frame.get_region(Rect2i(136, 285, 217, 112)).save_png(out.path_join("film-%03d.png" % tick)) != OK:
		failure = "Cannot save motion frames"
