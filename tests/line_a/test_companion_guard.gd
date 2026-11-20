extends "res://tests/line_a/combat_test_base.gd"

var dog: BulldogCompanion

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.chapter = 1
	GameState.level_index = 0
	GameState.difficulty = &"normal"
	GameState.reset_run()

func after_each() -> void:
	get_tree().paused = false
	GameState.hero_class = &"knight"
	dog = null
	await super()

func prepare(hero: StringName = &"knight") -> void:
	GameState.hero_class = hero
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(80, 200)
	player.facing = Vector2.RIGHT
	dog = arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.set_physics_process(false)
	dog.global_position = Vector2(40, 210)
	var enemy := spawn(&"scarecrow_elite", Vector2(110, 200))
	enemy.set_physics_process(false)

func arrive() -> void:
	assert_true(dog.request_rally())
	dog.global_position = dog.rally_destination
	dog._physics_process(1.0 / 60.0)
	assert_true(dog.is_protecting(player.global_position))

func test_command_runs_to_clamped_ground_point_and_never_teleports() -> void:
	prepare()
	var before := dog.global_position
	assert_true(dog.request_rally())
	assert_eq(dog.global_position, before)
	assert_false(dog.is_protecting(player.global_position), "approaching is not a shield")
	assert_eq(dog.rally_destination, Vector2(94, 200))
	assert_false(dog.request_rally(), "holding Q cannot reset cooldown")
	dog.set_physics_process(true)
	assert_true(await wait_until(func() -> bool: return dog.rally_left > 0.0, 90))
	assert_true(dog.global_position.distance_to(dog.rally_destination) <= dog.rally_rules.arrival_distance + 1)

func test_actual_incoming_damage_and_one_counter_are_bounded_by_circle() -> void:
	prepare()
	arrive()
	var counter := watch_signal(EventBus.companion_counter_granted)
	player.take_damage(20)
	assert_eq(GameState.vigor, 87, "20 becomes 13, no free invulnerability")
	assert_eq(counter.count, 1)
	assert_eq(dog.rally_prevented_damage, 7)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.25)
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(GameState.vigor, 74)
	assert_eq(counter.count, 1, "one empowered attack per command, not per hit")
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.0)
	player.global_position = dog.global_position + Vector2(0, dog.rally_rules.radius + .1)
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(GameState.vigor, 54, "outside means no mitigation")

func test_guard_is_available_for_mage_and_does_not_amplify_ultimate() -> void:
	prepare(&"mage")
	arrive()
	player.take_damage(20)
	assert_eq(GameState.vigor, 62)
	var base := player.projectile_impact_damage(1.0, true)
	assert_eq(base, 15)
	assert_almost_eq(player.equipment_combat.charge_bonus, .25, .0001, "ultimate leaves the normal-hit charge alone")
	assert_eq(player.projectile_impact_damage(1.0, false), 19)
	assert_eq(player.projectile_impact_damage(1.0, false), 15)

func test_archer_and_equipment_use_strongest_charge_without_refresh_loop() -> void:
	prepare(&"archer")
	arrive()
	player.equipment_combat.charge(.4)
	player.take_damage(20)
	assert_almost_eq(player.equipment_combat.charge_bonus, .4)
	player.equipment_combat.tick(3.1, false)
	player.invuln_left = 0
	player.take_damage(20)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.0, .0001, "same cast cannot regrant expired charge")

func test_blocked_projectile_grants_counter_only_while_player_is_inside() -> void:
	prepare()
	arrive()
	player.global_position = Vector2(160, 280)
	dog.block_projectile(null)
	assert_false(dog.rally_counter_given)
	player.global_position = dog.global_position
	dog.block_projectile(null)
	assert_true(dog.rally_counter_given)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.25)
	dog.block_projectile(null)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.0)

func test_invulnerable_hit_cannot_farm_counter_or_damage_prevention() -> void:
	prepare()
	arrive()
	player.invuln_left = 1
	player.take_damage(30)
	assert_eq(GameState.vigor, 100)
	assert_false(dog.rally_counter_given)
	assert_eq(dog.rally_prevented_damage, 0)
	player.invuln_left = 0
	player.take_damage(1)
	assert_eq(GameState.vigor, 99)
	assert_false(dog.rally_counter_given, "rounding that saves nothing cannot create a counter")

func test_daze_expiry_and_failed_arrival_end_protection_without_refund() -> void:
	prepare()
	arrive()
	dog._daze()
	assert_false(dog.is_protecting(player.global_position))
	assert_false(dog.request_rally())
	assert_true(dog.rally_cooldown_left > 0)
	dog._recover()
	dog.rally_cooldown_left = 0
	assert_true(dog.request_rally())
	dog.global_position = Vector2(20, 80)
	dog._act_rally(dog.rally_rules.approach_timeout + .1, player)
	assert_eq(dog.rally_left, 0.0)
	assert_eq(dog.rally_approach_left, 0.0)
	assert_true(dog.rally_cooldown_left > 0)
	dog.rally_cooldown_left = 0
	arrive()
	dog._act_rally(dog.rally_rules.duration + .1, player)
	assert_false(dog.is_protecting(player.global_position))

func test_pause_stops_guard_clock_and_rejects_commands() -> void:
	prepare()
	arrive()
	dog.set_physics_process(true)
	get_tree().paused = true
	var duration := dog.rally_left
	var cooldown := dog.rally_cooldown_left
	await wait_frames(4)
	assert_almost_eq(dog.rally_left, duration)
	assert_almost_eq(dog.rally_cooldown_left, cooldown)
	assert_false(dog.request_rally())
	get_tree().paused = false
	await wait_physics(3)
	assert_true(dog.rally_left < duration)

func test_downed_and_stage_completion_cancel_field() -> void:
	prepare()
	arrive()
	GameState.vigor = 1
	player.take_damage(99)
	assert_true(player.is_downed())
	assert_false(dog.is_protecting(player.global_position))
	assert_false(dog.request_rally())
	player.revive()
	dog.rally_cooldown_left = 0
	arrive()
	EventBus.level_completed.emit(&"1-1")
	assert_false(dog.is_protecting(player.global_position))
	assert_false(dog.request_rally())

func test_melee_waits_outside_true_reach_and_is_ready_as_target_arrives() -> void:
	prepare()
	var enemy := get_tree().get_first_node_in_group(&"enemy") as EnemyBase
	enemy.global_position = player.global_position + Vector2(GameState.player_stats.attack_range + enemy.body_radius + 4, 0)
	for i in 60:
		player._update_attack(1.0 / 60.0, false)
	assert_eq(player.swing_count, 0)
	assert_eq(player._attack_cooldown, 0.0)
	enemy.global_position = player.global_position + Vector2(18, 0)
	player._update_attack(1.0 / 60.0, false)
	assert_true(player._windup_left > 0)
	var hp := enemy.hp
	player._update_attack(player.tuning.attack_windup + .01, false)
	assert_eq(enemy.hp, hp - GameState.player_stats.attack_damage)

func test_movement_can_still_cancel_attack_and_real_misses_spend_cooldown() -> void:
	prepare()
	var enemy := get_tree().get_first_node_in_group(&"enemy") as EnemyBase
	enemy.global_position = player.global_position + Vector2(18, 0)
	player._update_attack(.01, false)
	player._update_attack(.01, true)
	assert_true(player._windup_left < 0)
	assert_eq(player.swing_count, 0)
	player._update_attack(.01, false)
	enemy.global_position += Vector2(90, 0)
	player._update_attack(.2, false)
	assert_eq(player.last_swing_hits, 0)
	assert_true(player._attack_cooldown > 0)

func test_late_hud_receives_ready_state_and_button_routes_command() -> void:
	prepare()
	var hud := load("res://ui/hud/hud.tscn").instantiate() as Control
	add_child(hud)
	var control: CompanionGuardControl = hud.companion_guard
	assert_true(control.visible)
	assert_false(control.button.disabled)
	control.button.pressed.emit()
	assert_eq(dog.rally_commands, 1)
	assert_true(control.button.disabled)
	control.button.pressed.emit()
	assert_eq(dog.rally_commands, 1)
	EventBus.player_downed.emit()
	assert_false(control.visible)
	EventBus.vigor_changed.emit(50, 100)
	assert_true(control.visible, "revive restores control in the same HUD")
	for safe in [Rect2(0, 0, 180, 320), Rect2(5, 18, 170, 282)]:
		hud.apply_layout(safe, Rect2(0, 0, 180, 320))
		var rect := control.button.get_global_rect()
		assert_true(safe.encloses(rect))
		assert_false(rect.intersects(hud.ultimate_button.get_global_rect()))
	hud.queue_free()


func test_captain_cues_follow_real_attack_and_recovery_timing() -> void:
	prepare()
	var captain := spawn(&"scarecrow_captain", Vector2(80, 160)) as CaptainBoss
	captain.set_physics_process(false)
	captain.target = player
	var cues := watch_signal(EventBus.boss_intent_changed)
	captain._start_sweep()
	captain._publish_intent()
	assert_eq(cues.last_args()[1], &"sweep")
	captain._sweep()
	captain._publish_intent()
	assert_eq(cues.last_args()[1], &"opening")
	assert_almost_eq(cues.last_args()[2], captain._phase_left)
	assert_true(captain.is_targetable())
	captain._start_throw()
	captain._throw()
	captain._publish_intent()
	assert_eq(cues.last_args()[1], &"returning", "outbound/returning fork is not labelled a safe opening")
	captain._end_throw(true)
	captain._publish_intent()
	assert_eq(cues.last_args()[1], &"opening")
	captain._on_defeat_started()
	assert_eq(cues.last_args()[1], &"")

func test_boss_cue_hud_follows_signal_and_clears_at_level_end() -> void:
	prepare()
	var hud := preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	EventBus.boss_appeared.emit(&"scarecrow_captain")
	EventBus.boss_intent_changed.emit(&"scarecrow_captain", &"opening", .6)
	assert_true(hud.boss_tactic.visible)
	assert_true(hud.boss_tactic.text.contains("0.6"))
	assert_eq(hud.boss_tactic.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	EventBus.level_failed.emit(&"1-4")
	assert_false(hud.boss_tactic.visible)
	hud.queue_free()
