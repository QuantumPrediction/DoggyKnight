extends Node
## Staged production rendering. Does not claim human playtest or balance evidence.
var out := OS.get_environment("ART_CAPTURE_DIR")
var arena: CombatArena
var hud: Control
var layer: CanvasLayer
var archer: ArcherEnemy
var evidence: Array[Dictionary] = []

func _ready() -> void:
	run.call_deferred()

func frames(count: int = 8) -> void:
	for i in count:
		await get_tree().process_frame

func world(hero: StringName) -> void:
	for node in [arena, layer]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	await frames(2)
	GameState.hero_class = hero
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.reset_run()
	GameState.active_tricks.append(&"roll")
	arena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0.0
	add_child(arena)
	arena.set_background(load("res://assets/backgrounds/farm_fence.tscn"))
	var player := arena.get_player() as GoldiePlayer
	player.set_physics_process(false)
	player.global_position = Vector2(104, 222)
	player.set_move_override(Vector2.ZERO)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.set_physics_process(false)
	dog.global_position = Vector2(127, 230)
	archer = arena.spawn_enemy(&"scarecrow_archer", Vector2(55, 160)) as ArcherEnemy
	archer.set_physics_process(false)
	archer.target = player
	archer._start_aim()
	for point in [Vector2(135, 150), Vector2(70, 205)]:
		var enemy := arena.spawn_enemy(&"scarecrow", point) as EnemyBase
		enemy.set_physics_process(false)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = preload("res://ui/hud/hud.tscn").instantiate()
	layer.add_child(hud)
	await frames()

func shot(name: String) -> void:
	var player := arena.get_player() as GoldiePlayer
	player._refresh_combat_readiness()
	hud.call(&"relayout")
	await frames(12)
	await RenderingServer.frame_post_draw
	var readout := hud.get("combat_readout") as CombatReadout
	var safe := SafeArea.get_safe_rect()
	var text_fits := true
	for label in [readout.action, readout.detail, readout.dodge]:
		text_fits = text_fits and label.get_minimum_size().x <= label.size.x + 0.1
	var guard := hud.get("companion_guard") as Control
	var fits := safe.encloses(readout.get_global_rect()) and not readout.get_global_rect().intersects(guard.get_global_rect())
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	evidence.append({"capture": name, "safe": fits, "text_fits": text_fits,
		"status": readout.status, "lane_locked": archer._telegraph.aim_locked})
	print("CAPTURE ", name, " safe=", fits, " text=", text_fits)

func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(540, 960)
	await world(&"archer")
	var player := arena.get_player() as GoldiePlayer
	player._focus_elapsed = 0.35
	archer._ai(archer._aim_total * 0.2)
	await shot("archer_tracking")
	player._focus_elapsed = player.loadout.focus_time
	archer._ai(archer._aim_total * 0.4)
	await shot("archer_locked_focus_ready")
	await world(&"mage")
	player = arena.get_player() as GoldiePlayer
	player.abilities.roll.try_roll()
	player.abilities.update(0.6)
	player.set_move_override(Vector2.RIGHT)
	await shot("mage_roll_cooldown")
	get_tree().root.size = Vector2i(360, 640)
	await world(&"knight")
	await shot("knight_small")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await world(&"archer")
	player = arena.get_player() as GoldiePlayer
	player._focus_elapsed = player.loadout.focus_time
	archer._ai(archer._aim_total * 0.6)
	await shot("archer_notched")
	SafeArea.simulate_notch = false
	var file := FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()
	get_tree().quit(0 if evidence.all(func(row: Dictionary) -> bool: return row.safe and row.text_fits) else 1)
