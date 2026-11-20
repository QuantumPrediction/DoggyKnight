extends Node
## Staged captures of production collision/tell code. No human-play claim.
var out := OS.get_environment("ART_CAPTURE_DIR")
var arena: CombatArena
var player: GoldiePlayer
var captain: CaptainBoss
var hud: Control
var evidence: Array[Dictionary] = []

func _ready() -> void:
	run.call_deferred()

func frames(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func shot(label: String, details: Dictionary) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	details["capture"] = label
	details["vigor"] = GameState.vigor
	details["safe_area"] = SafeArea.get_safe_rect().encloses(hud.boss_tactic.get_global_rect())
	evidence.append(details)
	print("CAPTURE ", label)

func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(540, 960)
	GameState.hero_class = &"knight"
	GameState.equipment = preload("res://tests/integration/equipment_profiles.gd").make("knight", "common1")
	GameState.meta_upgrades = {}
	GameState.chapter = 1
	GameState.level_index = 3
	GameState.reset_run()
	arena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0
	add_child(arena)
	arena.set_background(load("res://assets/backgrounds/farm_fence.tscn"))
	player = arena.get_player()
	player.set_physics_process(false)
	player.global_position = Vector2(125, 178)
	player.facing = Vector2.LEFT
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.set_physics_process(false)
	dog.global_position = Vector2(75, 230)
	captain = arena.spawn_enemy(&"scarecrow_captain", Vector2(85, 156))
	captain.set_physics_process(false)
	captain.target = player
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = preload("res://ui/hud/hud.tscn").instantiate()
	layer.add_child(hud)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)
	EventBus.boss_appeared.emit(&"scarecrow_captain")
	EventBus.boss_hp_changed.emit(captain.hp, captain.max_hp)
	await frames(150)
	captain._start_sweep()
	captain._telegraph.progress = 0.65
	captain._publish_intent()
	var shown := captain._telegraph.global_position
	var direction := captain._sweep_dir
	player.global_position = shown + direction * (captain.sweep_radius + EnemyBase.radius_of(player) + 2)
	await shot("01_committed_sweep", {"body_outside": not captain._telegraph.intersects_sector_body(player.global_position, EnemyBase.radius_of(player))})
	var vigor := GameState.vigor
	captain._sweep()
	captain._publish_intent()
	await shot("02_dodge_and_opening", {"no_damage": GameState.vigor == vigor, "same_origin": captain.global_position == shown})
	# Three already living summons leave one visibly announced reinforcement.
	captain._start_rally()
	captain._rally()
	for i in captain._summons.size():
		var soldier := captain._summons[i] as EnemyBase
		soldier.set_physics_process(false)
		soldier.global_position = [Vector2(44, 206), Vector2(130, 216), Vector2(47, 129)][i]
	captain._start_rally()
	captain._publish_intent()
	for mark in captain._rally_marks:
		mark.progress = 0.6
	await shot("03_one_remaining_reinforcement", {"living_summons": captain.alive_summons(), "warnings": captain._rally_marks.size()})
	captain._rally()
	for soldier in captain._summons:
		soldier.set_physics_process(false)
	captain._publish_intent()
	await shot("04_four_summon_limit", {"living_summons": captain.alive_summons(), "cap": captain.max_summons_alive})
	get_tree().root.size = Vector2i(360, 640)
	captain._start_sweep()
	captain._publish_intent()
	await shot("05_small_warning", {"warning": true})
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await shot("06_notched_warning", {"warning": true})
	SafeArea.simulate_notch = false
	var file := FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()
	var passed := bool(evidence[0].body_outside) and bool(evidence[1].no_damage) and bool(evidence[1].same_origin)
	passed = passed and evidence[2].warnings == 1 and evidence[3].living_summons == 4
	passed = passed and evidence.all(func(row: Dictionary) -> bool: return row.safe_area)
	get_tree().quit(0 if passed else 1)
