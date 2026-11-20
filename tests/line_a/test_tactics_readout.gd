extends "res://tests/line_a/combat_test_base.gd"

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.reset_run()
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	GameState.level_index = 0

func after_each() -> void:
	get_tree().paused = false
	SafeArea.simulate_notch = false
	GameState.hero_class = &"knight"
	await super()

func prepare(hero: StringName) -> void:
	GameState.hero_class = hero
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(40, 180)
	player.set_move_override(Vector2.ZERO)

func test_focus_feedback_uses_the_bonus_clock_and_resets_on_movement() -> void:
	prepare(&"archer")
	player._update_attack(0.35, false)
	assert_almost_eq(float(player.tactics_status().focus), 0.5)
	player._update_attack(0.36, false)
	assert_almost_eq(float(player.tactics_status().focus), 1.0)
	assert_almost_eq(float(player.tactics_status().focus_bonus), player.loadout.focus_mult)
	player.set_move_override(Vector2.RIGHT)
	player._physics_process(0.016)
	assert_almost_eq(float(player.tactics_status().focus), 0.0)
	assert_eq(player.tactics_status().phase, &"moving")

func test_exact_focus_threshold_emits_even_after_quantized_near_full_state() -> void:
	prepare(&"archer")
	var readout := CombatReadout.new()
	add_child(readout)
	player._update_attack(player.loadout.focus_time * 0.99, false)
	player._publish_tactics()
	assert_true(readout.meter < 1.0)
	player._update_attack(player.loadout.focus_time * 0.02, false)
	player._publish_tactics()
	assert_almost_eq(readout.meter, 1.0)
	assert_true(readout.detail.text.contains("1.35"))
	readout.queue_free()

func test_roll_feedback_tracks_actual_protection_cooldown_and_restart_requirement() -> void:
	prepare(&"mage")
	assert_eq(player.tactics_status().roll, &"absent")
	EventBus.trick_chosen.emit(&"roll")
	assert_eq(player.tactics_status().roll, &"ready")
	player.set_move_override(Vector2.RIGHT)
	player._physics_process(0.016)
	assert_eq(player.tactics_status().roll, &"rolling")
	var vigor := GameState.vigor
	player.take_damage(10)
	assert_eq(GameState.vigor, vigor, "indicator refers to actual invulnerability")
	player.abilities.update(0.5)
	assert_eq(player.tactics_status().roll, &"cooldown")
	assert_almost_eq(float(player.tactics_status().roll_left), player.abilities.roll.cooldown_left)
	player.abilities.update(4.0)
	assert_eq(player.tactics_status().roll, &"moving", "holding movement does not trigger another roll")
	player.set_move_override(Vector2.ZERO)
	assert_eq(player.tactics_status().roll, &"ready")

func test_melee_status_requires_real_target_reach() -> void:
	prepare(&"knight")
	var enemy := spawn(&"scarecrow", Vector2(150, 180))
	enemy.set_physics_process(false)
	assert_eq(player.tactics_status().phase, &"out_of_range")
	enemy.global_position = player.global_position + Vector2(15, 0)
	assert_eq(player.tactics_status().phase, &"ready")
	player._update_attack(0.01, false)
	assert_eq(player.tactics_status().phase, &"windup")
	player._update_attack(1.0, false)
	assert_eq(player.tactics_status().phase, &"busy", "real impact hitstop precedes recovery")
	player._physics_process(player._hitstop_left + 0.001)
	assert_eq(player.tactics_status().phase, &"recovering")

func test_pause_and_status_requests_cannot_tick_focus_or_roll() -> void:
	prepare(&"archer")
	EventBus.trick_chosen.emit(&"roll")
	player.abilities.roll.try_roll()
	player._update_attack(0.3, false)
	player.set_physics_process(true)
	get_tree().paused = true
	var before := player.tactics_status()
	var readout := CombatReadout.new()
	readout.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(readout)
	await wait_frames(5)
	EventBus.player_combat_status_requested.emit()
	assert_eq(player.tactics_status(), before)
	assert_eq(readout.status, before)
	readout.queue_free()

func test_detached_old_player_cannot_answer_a_new_hud_request() -> void:
	prepare(&"mage")
	var watched := watch_signal(EventBus.player_tactics_changed)
	var old := player
	old.get_parent().remove_child(old)
	EventBus.player_combat_status_requested.emit()
	assert_eq(watched.count, 0)
	old.queue_free()
	player = null

func test_readout_is_touch_transparent_and_survives_small_notched_layouts() -> void:
	prepare(&"archer")
	EventBus.trick_chosen.emit(&"roll")
	var hud := preload("res://ui/hud/hud.tscn").instantiate() as Control
	add_child(hud)
	var readout := hud.get("combat_readout") as CombatReadout
	for safe in [Rect2(0, 0, 180, 320), Rect2(5, 14, 170, 292), Rect2(-8, -30, 196, 402)]:
		hud.call(&"apply_layout", safe, Rect2(0, 0, 180, 320))
		assert_true(safe.encloses(readout.get_global_rect()))
		assert_false(readout.get_global_rect().intersects((hud.get("companion_guard") as Control).get_global_rect()))
	assert_eq(readout.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for label in [readout.action, readout.detail, readout.dodge]:
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_true(label.get_minimum_size().x <= label.size.x, label.text)
	assert_eq(readout.status.hero, &"archer")
	EventBus.level_completed.emit(&"1-1")
	assert_false(readout.visible)
	hud.queue_free()

func test_downed_actor_never_reports_a_ready_panel() -> void:
	prepare(&"mage")
	var readout := CombatReadout.new()
	add_child(readout)
	player.take_damage(100000)
	player._publish_tactics()
	assert_eq(player.tactics_status().phase, &"unavailable")
	assert_false(readout.visible)
	readout.queue_free()
