extends "res://tests/integration/guard_showcase.gd"
## Staged real-engine UI/actor validation. No image compositing or fake gameplay result.

func shot(label: String) -> void:
	await super(label)
	var safe := SafeArea.get_safe_rect()
	var coach: GuardCoach = hud.guard_coach
	var rect := coach.get_global_rect()
	var entry: Dictionary = checks.back()
	entry["coach_safe"] = not coach.visible or safe.encloses(rect)
	entry["coach_controls_clear"] = not coach.visible or (not rect.intersects(hud.companion_guard.get_global_rect()) and not rect.intersects(hud.ultimate_button.get_global_rect()))
	entry["coach_text_fits"] = not coach.visible or (coach.instruction.get_line_count() <= 2 and rect.encloses(coach.instruction.get_global_rect()) and rect.encloses(coach.heading.get_global_rect()))
	entry["coach_heading"] = coach.heading.text
	entry["coach_body"] = coach.instruction.text
	entry["charge"] = hud.companion_guard.charge_label.text
	entry["charge_visible"] = hud.companion_guard.charge_label.visible
	entry["lesson_completed"] = coach.completed


func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
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
	player.set_move_override(Vector2.ZERO)
	player.set_physics_process(false)
	dog = arena.spawn_companion(&"bulldog")
	dog.global_position = Vector2(70, 230)
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
	hud.show_guard_lesson()
	await shot("01_optional_lesson")
	hud.companion_guard.button.pressed.emit()
	for i in 100:
		await get_tree().physics_frame
		if dog.rally_left > 0:
			break
	dog.set_physics_process(false)
	assert(dog.is_protecting(player.global_position))
	await shot("02_inside_protection")
	player.global_position = Vector2(142, 244)
	dog._publish_rally_state()
	assert(not dog.is_protecting(player.global_position))
	await shot("03_outside_protection")
	player.global_position = Vector2(90, 224)
	dog._publish_rally_state()
	dog.block_projectile(null)
	player.set_move_override(Vector2.LEFT)
	player._refresh_combat_readiness()
	await shot("04_counter_ready")
	get_tree().root.size = Vector2i(360, 640)
	await shot("05_small_counter")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await shot("06_notched_counter")
	SafeArea.simulate_notch = false
	get_tree().root.size = Vector2i(540, 960)
	boss._start_throw()
	boss._publish_intent()
	await shot("07_danger_before_counter")
	boss._sweep()
	boss._publish_intent()
	player.set_move_override(Vector2.ZERO)
	var enemy := get_tree().get_nodes_in_group(&"enemy")[1] as EnemyBase
	player.global_position = enemy.global_position + Vector2(0, 18)
	player.facing = Vector2.UP
	player._swing()
	assert(hud.guard_coach.completed)
	await shot("08_counter_used")
	pause = preload("res://ui/pause/pause.tscn").instantiate()
	layer.add_child(pause)
	EventBus.game_paused.emit(true)
	get_tree().paused = true
	await frames(20)
	await shot("09_pause_replay")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await shot("10_notched_pause")
	get_tree().paused = false
	var file := FileAccess.open(out.path_join("layout_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(checks, "\t"))
	file.close()
	get_tree().quit(0 if checks.all(func(c: Dictionary) -> bool: return c.safe and c.no_overlap and c.caption_safe and c.boss_cue_safe and c.pause_safe and c.coach_safe and c.coach_controls_clear and c.coach_text_fits) else 1)
