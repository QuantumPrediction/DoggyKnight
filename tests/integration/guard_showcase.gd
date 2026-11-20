extends Node
## Staged production-engine capture, not a natural playthrough or balance test.
var out: String = OS.get_environment("ART_CAPTURE_DIR")
var arena: CombatArena
var player: GoldiePlayer
var dog: BulldogCompanion
var boss: CaptainBoss
var hud: Control
var pause: Control
var checks: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func frames(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func shot(label: String) -> void:
	await frames()
	var safe := SafeArea.get_safe_rect()
	var control: CompanionGuardControl = hud.companion_guard
	var button_rect := control.button.get_global_rect()
	checks.append({"name": label, "safe": safe.encloses(button_rect),
		"no_overlap": not button_rect.intersects(hud.ultimate_button.get_global_rect()),
		"caption_safe": safe.encloses(control.status_label.get_global_rect()),
		"boss_cue_safe": not hud.boss_tactic.visible or safe.encloses(hud.boss_tactic.get_global_rect()),
		"pause_safe": pause == null or not pause.visible or safe.encloses(pause._panel.get_global_rect()),
		"state": control.state, "caption": control.status_label.text,
		"boss_tactic": hud.boss_tactic.text, "vigor": GameState.vigor,
		"actual_protection": dog.is_protecting(player.global_position)})
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURE ", label)

func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("A real rendering display and ART_CAPTURE_DIR are required; no placeholder screenshots.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(540, 960)
	GameState.hero_class = &"knight"
	GameState.equipment = preload("res://tests/integration/equipment_profiles.gd").make("knight", "common1")
	GameState.meta_upgrades = {}
	GameState.reset_run()
	GameState.chapter = 1
	GameState.level_index = 3
	arena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0
	add_child(arena)
	arena.set_background(load("res://assets/backgrounds/farm_fence.tscn"))
	player = arena.get_player()
	player.global_position = Vector2(90, 224)
	player.facing = Vector2.UP
	player.set_physics_process(false)
	dog = arena.spawn_companion(&"bulldog")
	dog.global_position = Vector2(70, 230)
	# Freeze incidental attacks only in this staged composition; guard still approaches.
	dog.bump_interval = 100000
	boss = arena.spawn_enemy(&"scarecrow_captain", Vector2(94, 139))
	boss.set_physics_process(false)
	boss.phase = CaptainBoss.Phase.IDLE
	boss.target = player
	for entry in [[&"scarecrow", Vector2(55, 197)], [&"scarecrow", Vector2(127, 206)], [&"scarecrow_archer", Vector2(45, 151)]]:
		var enemy := arena.spawn_enemy(entry[0], entry[1])
		enemy.set_physics_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = preload("res://ui/hud/hud.tscn").instantiate()
	layer.add_child(hud)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)
	EventBus.boss_appeared.emit(&"scarecrow_captain")
	EventBus.boss_hp_changed.emit(boss.hp, boss.max_hp)
	await frames(150)
	await shot("01_guard_ready")
	hud.companion_guard.button.pressed.emit()
	for i in 100:
		await get_tree().physics_frame
		if dog.rally_left > 0:
			break
	dog.set_physics_process(false)
	assert(dog.is_protecting(player.global_position))
	boss._start_throw()
	boss._publish_intent()
	await shot("02_guard_and_telegraph")
	player.take_damage(20)
	boss._end_throw(true)
	boss._publish_intent()
	await shot("03_counter_opening")
	get_tree().root.size = Vector2i(360, 640)
	await shot("04_small_guard")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await shot("05_notch_guard")
	SafeArea.simulate_notch = false
	get_tree().root.size = Vector2i(540, 960)
	pause = preload("res://ui/pause/pause.tscn").instantiate()
	layer.add_child(pause)
	EventBus.game_paused.emit(true)
	await shot("06_pause_controls")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await shot("07_notch_pause")
	pause.queue_free()
	var file := FileAccess.open(out.path_join("layout_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(checks, "\t"))
	file.close()
	get_tree().quit(0 if checks.all(func(c: Dictionary) -> bool: return c.safe and c.no_overlap and c.caption_safe and c.boss_cue_safe and c.pause_safe) else 1)
