extends "res://tests/line_a/combat_test_base.gd"

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	GameState.level_index = 0

func after_each() -> void:
	GameState.hero_class = &"knight"
	get_tree().paused = false
	await super()

func load_class(id: StringName) -> void:
	GameState.hero_class = id
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(40, 160)

func stationary(at: Vector2) -> EnemyBase:
	var enemy := spawn(&"scarecrow", at)
	enemy.set_physics_process(false)
	return enemy

func test_all_loadouts_are_available_and_stats_do_not_mutate_resources() -> void:
	for id in HeroClasses.IDS:
		GameState.hero_class = id
		GameState.reset_run()
		var base := GameState.base_stats()
		var original := base.attack_damage
		GameState.player_stats.attack_damage += 50
		GameState.reset_run()
		assert_eq(GameState.player_stats.attack_damage, original)
		assert_ne(GameState.player_stats, base)
	assert_eq(HeroClasses.valid_id("corrupt"), &"knight")

func test_arrows_travel_before_damage_and_pierce_in_spatial_order() -> void:
	load_class(&"archer")
	# Deliberately insert the farther target first.
	var far := stationary(Vector2(110, 160))
	var near := stationary(Vector2(80, 160))
	var near_hp := near.hp
	var far_hp := far.hp
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	assert_eq(near.hp, near_hp, "launch does not deal instant hitscan damage")
	shot._physics_process(0.4)
	assert_eq(near.hp, near_hp - 9)
	assert_eq(far.hp, far_hp - 6, "second target receives reduced penetration damage")
	assert_almost_eq(player.loyalty, player.tuning.loyalty_per_hit * 2)

func test_mage_splash_hits_nearby_targets_once_and_not_distant_enemies() -> void:
	load_class(&"mage")
	var main := stationary(Vector2(80, 160))
	var splash := stationary(Vector2(80, 178))
	var outside := stationary(Vector2(125, 178))
	var hp := main.hp
	var other_hp := splash.hp
	var out_hp := outside.hp
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	shot._physics_process(0.32)
	assert_eq(main.hp, hp - 15)
	assert_eq(splash.hp, other_hp - 9)
	assert_eq(outside.hp, out_hp)
	assert_eq(shot.hit_ids.size(), 2)

func test_projectile_misses_outside_lane_and_expires_at_range() -> void:
	load_class(&"archer")
	var enemy := stationary(Vector2(100, 185))
	var hp := enemy.hp
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	shot._physics_process(1.0)
	assert_eq(enemy.hp, hp)
	assert_true(shot.is_queued_for_deletion())

func test_movement_cancels_cast_and_resets_archer_focus() -> void:
	load_class(&"archer")
	stationary(Vector2(90, 160))
	player._update_attack(0.8, false)
	assert_almost_eq(player.focus_fraction(), 1.0)
	player._update_attack(0.01, true)
	assert_almost_eq(player.focus_fraction(), 0.0)
	assert_true(player._windup_left < 0.0)
	assert_eq(get_tree().get_nodes_in_group(&"hero_projectile").size(), 0)

func test_ranged_ultimate_is_class_specific_and_does_not_refill_itself() -> void:
	load_class(&"archer")
	stationary(Vector2(90, 160))
	player._class_ultimate()
	var shots := get_tree().get_nodes_in_group(&"hero_projectile")
	assert_eq(shots.size(), 5)
	for shot in shots:
		assert_true(shot.ultimate)
		shot._physics_process(0.25)
	assert_almost_eq(player.loyalty, 0.0)

func test_pause_freezes_flying_projectile_and_clear_removes_it() -> void:
	load_class(&"mage")
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	var at := shot.global_position
	get_tree().paused = true
	await wait_frames(3)
	assert_eq(shot.global_position, at)
	get_tree().paused = false
	arena.clear()
	await wait_frames(2)
	assert_false(is_instance_valid(shot))

func test_upgrades_rebuild_from_class_base_and_do_not_offer_melee_pounce() -> void:
	load_class(&"mage")
	var progression := RunProgression.new()
	add_child(progression)
	progression.setup(load("res://game/progression/difficulty.tres"), 7)
	progression.reset_run()
	progression.apply_trick(TrickDeck.load_trick(&"fetch"))
	var damage := GameState.player_stats.attack_damage
	progression.rebuild_stats()
	assert_eq(GameState.player_stats.attack_damage, damage)
	assert_eq(GameState.player_stats.max_vigor, 75)
	assert_false(progression.get_deck().available([]).has(&"pounce"))

func test_archer_focus_changes_real_impact_damage() -> void:
	load_class(&"archer")
	var enemy := stationary(Vector2(90, 160))
	var hp := enemy.hp
	player._focus_elapsed = player.loadout.focus_time
	player._attack_target = enemy
	player._fire_projectile()
	var shot: HeroProjectile = get_tree().get_first_node_in_group(&"hero_projectile")
	shot._physics_process(0.3)
	assert_eq(enemy.hp, hp - 12, "蓄勢箭矢實際造成 1.35 倍取整傷害")

func test_mage_ultimate_centers_on_target_and_does_not_refill_itself() -> void:
	load_class(&"mage")
	var target := stationary(Vector2(110, 160))
	var beside := stationary(Vector2(130, 190))
	var outside := stationary(Vector2(40, 250))
	var hp := outside.hp
	player._class_ultimate()
	assert_false(target.is_targetable())
	assert_false(beside.is_targetable())
	assert_eq(outside.hp, hp)
	assert_almost_eq(player.loyalty, 0.0)

func test_flying_shot_expires_after_player_is_freed() -> void:
	load_class(&"mage")
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	player.free()
	player = null
	shot._physics_process(0.01)
	assert_true(shot.is_queued_for_deletion())
