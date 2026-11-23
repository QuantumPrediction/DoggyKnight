extends Node
## The same staged production encounter runs on both revisions at fixed 60 Hz.
const DIRECTIONS := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "front": Vector2.DOWN,
	"back": Vector2.UP, "cancel": Vector2.RIGHT, "elite": Vector2.RIGHT}
var output := OS.get_environment("SCARECROW_CAPTURE_DIR")
var no_ink := OS.get_environment("SCARECROW_WITHOUT_INK") == "1"
var film := OS.get_environment("SCARECROW_FILM") == "1"
var trace: FileAccess
var shots := {}
var resolves := 0
var warning: AttackTelegraph
var failure := ""

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set SCARECROW_CAPTURE_DIR to a writable directory")
		get_tree().quit(2)
		return
	get_tree().root.size = Vector2i(360, 640)
	trace = FileAccess.open(output.path_join("combat.tsv"), FileAccess.WRITE)
	trace.store_line("case\ttick\tphase\tenemy_x\tenemy_y\tface_x\tface_y\tplayer_x\tplayer_y\tvigor\tstarts\tresolves\tanim\tframe\tmark_x\tmark_y\tradius\tangle\tprogress\toverlaps")
	for label: String in DIRECTIONS:
		await encounter(label)
		if not failure.is_empty():
			break
	trace.close()
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_line(JSON.stringify(shots, "\t"))
	file.close()
	if not failure.is_empty():
		push_error(failure)
	print("Recorded ", shots.size(), " scarecrow samples, ", DisplayServer.get_name())
	get_tree().quit(0 if failure.is_empty() else 1)

func encounter(label: String) -> void:
	seed(19027)
	resolves = 0
	warning = null
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.chapter = 1
	GameState.level_index = 3
	var room := Node.new()
	add_child(room)
	var arena: CombatArena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0.0
	room.add_child(arena)
	arena.set_background(preload("res://assets/backgrounds/farm_fence.tscn"))
	var player := arena.get_player()
	var center := Vector2(90, 166)
	player.global_position = center + Vector2(DIRECTIONS[label]) * 27.0
	player.set_physics_process(false)
	var id := &"scarecrow_elite" if label == "elite" else &"scarecrow"
	var enemy := arena.spawn_enemy(id, center) as ScarecrowEnemy
	enemy.target = player
	enemy.set_physics_process(false)
	enemy.warning_committed.connect(func(mark: AttackTelegraph) -> void: warning = mark)
	enemy.swing_resolving.connect(func(_mark: AttackTelegraph) -> void: resolves += 1)
	var layer := CanvasLayer.new()
	room.add_child(layer)
	layer.add_child(preload("res://ui/hud/hud.tscn").instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var initial_hp := GameState.vigor
	for tick in 55:
		if tick == 3:
			enemy.set_physics_process(true)
		if label == "cancel" and tick == 14:
			enemy.stun(1.0)
		await get_tree().physics_frame
		await get_tree().process_frame
		var live := is_instance_valid(warning) and warning.is_visible_damage_warning()
		var origin := warning.global_position if live else Vector2.ZERO
		var sprite := enemy.sprite
		trace.store_csv_line(PackedStringArray([label, str(tick), str(enemy.phase),
			str(enemy.position.x), str(enemy.position.y), str(enemy.facing.x), str(enemy.facing.y),
			str(player.position.x), str(player.position.y), str(GameState.vigor),
			str(enemy.attacks_started), str(resolves), String(sprite.animation), str(sprite.frame),
			str(origin.x), str(origin.y), str(warning.radius if live else 0.0),
			str(warning.half_angle if live else 0.0), str(warning.progress if live else 0.0),
			str(int(live and warning.intersects_sector_body(player.position, player.tuning.body_radius)))]), "\t")
		var beat := ""
		if tick == 1 and label == "right":
			beat = "idle"
		elif label == "cancel" and tick == 15:
			beat = "interrupted"
		elif live:
			beat = "hot" if warning.is_hot() else "raise"
		elif enemy.phase == ScarecrowEnemy.Phase.SWING:
			beat = "release" if sprite.frame == 0 else "follow"
		elif label == "right" and enemy.phase == ScarecrowEnemy.Phase.RECOVER:
			beat = "rest"
		var key := label + "-" + beat
		var sample := not beat.is_empty() and not shots.has(key)
		var film_frame := film and label == "right" and not no_ink
		if sample or film_frame:
			await photograph(key if sample else "", tick, enemy, live, film_frame)
	if enemy.attacks_started != 1 or resolves != (0 if label == "cancel" else 1):
		failure = label + " unexpected commit or resolve count"
	if (GameState.vigor < initial_hp) != (label != "cancel"):
		failure = label + " unexpected damage"
	room.free()
	await get_tree().process_frame

func photograph(key: String, tick: int, enemy: ScarecrowEnemy, live: bool, film_frame: bool) -> void:
	var to_screen := get_viewport().get_stretch_transform()
	var skin := enemy.sprite.get_node("IllustratedActor") as Node2D
	var to_pixel := to_screen * skin.get_global_transform_with_canvas()
	var corners: Array = []
	for p: Vector2 in [Vector2(-16, -16), Vector2(16, 16)]:
		var point: Vector2 = to_pixel * p
		corners.append([point.x, point.y])
	var arc: Array = []
	if live:
		var transform := to_screen * warning.get_global_transform_with_canvas()
		var polygon := warning._sector_points(warning.radius)
		for i in range(1, polygon.size()):
			var p := transform * polygon[i]
			arc.append([p.x, p.y])
	if not key.is_empty():
		shots[key] = {"tick": tick, "sprite_corners": corners, "outer_arc": arc}
	if DisplayServer.get_name() == "headless" or (no_ink and not live):
		return
	if no_ink:
		# Change only this draw. Gameplay continues to read the real visible node.
		await RenderingServer.frame_pre_draw
		RenderingServer.canvas_item_set_visible(warning.get_canvas_item(), false)
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	if no_ink:
		RenderingServer.canvas_item_set_visible(warning.get_canvas_item(), true)
	if frame.get_size() != Vector2i(360, 640):
		failure = key + " viewport capture failed"
		return
	if not key.is_empty() and frame.save_png(output.path_join(key + ".png")) != OK:
		failure = key + " PNG save failed"
	if film_frame:
		var clip := frame.get_region(Rect2i(119, 245, 172, 138))
		if clip.save_png(output.path_join("film-%02d.png" % tick)) != OK:
			failure = "Film frame save failed"
