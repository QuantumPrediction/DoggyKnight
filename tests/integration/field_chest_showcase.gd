extends Node
## A fixed-camera test scene. Physics and the original animation clock run normally.
const SPAWNS := [Vector2(42, 163), Vector2(90, 163), Vector2(138, 163)]
const NAMES := ["ordinary", "elite", "boss"]
var output := OS.get_environment("CHEST_CAPTURE_DIR")
var chests: Array[TreasureChest] = []
var collected: Array[int] = []
var captures: Dictionary = {}

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set CHEST_CAPTURE_DIR to a writable directory")
		get_tree().quit(2)
		return
	var trace := FileAccess.open(output.path_join("pickup.tsv"), FileAccess.WRITE)
	trace.store_line("tick\ttier\tphase\tx\ty\tanimation\tframe\tcollected")
	get_tree().root.size = Vector2i(360, 640)
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.chapter = 1
	GameState.level_index = 3
	var arena: CombatArena = preload("res://game/combat/arena.tscn").instantiate()
	add_child(arena)
	arena.set_background(preload("res://assets/backgrounds/farm_fence.tscn"))
	var player := arena.get_player()
	player.global_position = Vector2(20, 206)
	player.set_physics_process(false)
	var foe := arena.spawn_enemy(&"scarecrow", Vector2(130, 108))
	foe.set_physics_process(false)
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	hud_layer.add_child(preload("res://ui/hud/hud.tscn").instantiate())
	# Fix the random pop trajectories, then collect each chest by real proximity.
	seed(19023)
	for tier in SPAWNS.size():
		chests.append(arena.spawn_chest(SPAWNS[tier], tier))
	EventBus.chest_collected.connect(func(tier: int) -> void: collected.append(tier))
	for tick in 138:
		if tick in [36, 62, 88]:
			var target := chests[[36, 62, 88].find(tick)]
			player.global_position = target.global_position + Vector2(10, -3)
		if tick in [39, 65, 91]:
			player.global_position = Vector2(24, 206)
		await get_tree().physics_frame
		await get_tree().process_frame
		var shot := "field" if tick == 32 else ""
		for tier in chests.size():
			var chest: TreasureChest = chests[tier]
			if not is_instance_valid(chest):
				trace.store_line("%d\t%d\tremoved\t-\t-\t-\t-\t%d" % [tick, tier, collected.count(tier)])
				continue
			var sprite := chest.get_node("Sprite") as AnimatedSprite2D
			trace.store_line("%d\t%d\t%d\t%.4f\t%.4f\t%s\t%d\t%d" % [
				tick, tier, chest.phase, chest.position.x, chest.position.y,
				sprite.animation, sprite.frame, collected.count(tier)])
			if sprite.animation == &"open" and sprite.frame in [0, 1, 2]:
				var label := "%s-%d" % [NAMES[tier], sprite.frame]
				if not captures.has(label):
					shot = label
		if not shot.is_empty():
			captures[shot] = tick
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var screenshot := get_viewport().get_texture().get_image()
				if screenshot.get_size() != Vector2i(360, 640) or screenshot.save_png(output.path_join(shot + ".png")) != OK:
					push_error("Could not save 360x640 capture " + shot)
					get_tree().quit(2)
					return
	trace.close()
	print("Chest pickups ", collected, ", observed poses ", captures)
	get_tree().quit(0 if collected == [0, 1, 2] and captures.size() == 10 else 1)
