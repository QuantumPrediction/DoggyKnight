extends "res://tests/line_a/combat_test_base.gd"

var dog: BulldogCompanion
var target_enemy: EnemyBase
var hud: Control

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.reset_run()

func after_each() -> void:
	get_tree().paused = false
	GameState.hero_class = &"knight"
	dog = null
	target_enemy = null
	hud = null
	await super()

func prepare(hero: StringName = &"knight") -> void:
	GameState.hero_class = hero
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.set_move_override(Vector2.ZERO)
	player.global_position = Vector2(80, 200)
	player.facing = Vector2.RIGHT
	dog = arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.set_physics_process(false)
	dog.global_position = Vector2(50, 210)
	target_enemy = spawn(&"scarecrow_elite", Vector2(98, 200))
	target_enemy.set_physics_process(false)
	hud = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	hud.show_guard_lesson()

func protect() -> void:
	assert_true(dog.request_rally())
	dog.global_position = dog.rally_destination
	dog._physics_process(1.0 / 60.0)
	assert_true(dog.is_protecting(player.global_position))

func charge_by_block() -> void:
	protect()
	dog.block_projectile(null)
	assert_true(player.equipment_combat.charged_left > 0)

func test_coverage_tracks_actual_boundary_and_late_request() -> void:
	prepare()
	protect()
	assert_true(hud.companion_guard.status_label.text.contains("受保護"))
	player.global_position = dog.global_position + Vector2(dog.rally_rules.radius + .1, 0)
	dog._publish_rally_state()
	assert_true(hud.companion_guard.status_label.text.contains("圈外"))
	var coverage := watch_signal(EventBus.companion_guard_coverage)
	EventBus.companion_guard_status_requested.emit()
	assert_eq(coverage.last_args(), [false])
	player.global_position = dog.global_position + Vector2(dog.rally_rules.radius, 0)
	dog._publish_rally_state()
	assert_eq(coverage.last_args(), [true], "edge matches actual is_protecting predicate")
	dog._cancel_rally()
	assert_eq(coverage.last_args(), [false])

func test_block_then_normal_melee_hit_completes_once_without_taking_damage() -> void:
	prepare()
	var done := watch_signal(EventBus.guard_lesson_completed)
	var resolved := watch_signal(EventBus.companion_counter_resolved)
	charge_by_block()
	assert_eq(GameState.vigor, 100, "shield interception can teach this without forced damage")
	assert_eq(done.count, 0)
	var hp := target_enemy.hp
	player._swing()
	assert_eq(done.count, 1)
	assert_eq(resolved.last_args(), [&"used"])
	assert_eq(player.last_swing_damage, 13, "10 damage uses the existing 25 percent charge and integer rounding")
	assert_true(target_enemy.hp < hp, "the ordinary attack actually damages its target")
	assert_true(hud.guard_coach.completed)
	assert_false(hud.companion_guard.charge_label.visible)
	player._swing()
	assert_eq(done.count, 1)

func test_miss_preserves_charge_and_does_not_complete_lesson() -> void:
	prepare()
	charge_by_block()
	target_enemy.global_position = Vector2(160, 90)
	var done := watch_signal(EventBus.guard_lesson_completed)
	player._swing()
	assert_eq(player.last_swing_hits, 0)
	assert_true(player.equipment_combat.charged_left > 0)
	assert_eq(done.count, 0)
	assert_false(hud.guard_coach.completed)

func test_ranged_ultimate_does_not_consume_or_complete_normal_hit_does() -> void:
	prepare(&"mage")
	charge_by_block()
	var done := watch_signal(EventBus.guard_lesson_completed)
	assert_eq(player.projectile_impact_damage(1.0, true), 15)
	assert_eq(done.count, 0)
	assert_true(hud.companion_guard.charge_label.visible)
	assert_eq(player.projectile_impact_damage(1.0, false), 19)
	assert_eq(done.count, 1)
	assert_false(hud.companion_guard.charge_label.visible)

func test_expired_charge_clears_feedback_without_teaching_success() -> void:
	prepare()
	charge_by_block()
	var resolved := watch_signal(EventBus.companion_counter_resolved)
	player.equipment_combat.tick(3.1, false)
	EventBus.player_combat_status_requested.emit()
	assert_eq(resolved.last_args(), [&"expired"])
	assert_false(hud.companion_guard.charge_label.visible)
	assert_false(hud.guard_coach.completed)
	player._swing()
	assert_false(hud.guard_coach.completed)

func test_snapshot_explains_movement_range_and_recovery_from_actor_state() -> void:
	prepare()
	charge_by_block()
	var status := watch_signal(EventBus.player_combat_readiness)
	player.set_move_override(Vector2.UP)
	EventBus.player_combat_status_requested.emit()
	assert_eq(status.last_args()[0], &"moving")
	assert_true(hud.guard_coach.instruction.text.contains("停下"))
	player.set_move_override(Vector2.ZERO)
	target_enemy.global_position = Vector2(160, 90)
	EventBus.player_combat_status_requested.emit()
	assert_eq(status.last_args()[0], &"out_of_range")
	player._attack_cooldown = .2
	EventBus.player_combat_status_requested.emit()
	assert_eq(status.last_args()[0], &"recovering")
	assert_almost_eq(status.last_args()[1], player.equipment_combat.charged_left)
	player._attack_cooldown = 0
	target_enemy.global_position = Vector2(98, 200)
	EventBus.player_combat_status_requested.emit()
	assert_eq(status.last_args()[0], &"ready")

func test_pause_freezes_actual_charge_and_ui_then_death_cancels_lesson() -> void:
	prepare()
	charge_by_block()
	player.set_physics_process(true)
	get_tree().paused = true
	var remaining := player.equipment_combat.charged_left
	var caption: String = hud.companion_guard.charge_label.text
	await wait_frames(4)
	assert_almost_eq(player.equipment_combat.charged_left, remaining)
	assert_eq(hud.companion_guard.charge_label.text, caption)
	get_tree().paused = false
	player.set_physics_process(false)
	var resolved := watch_signal(EventBus.companion_counter_resolved)
	player._go_down()
	assert_eq(resolved.last_args(), [&"cancelled"])
	assert_false(hud.guard_coach.visible)
	assert_false(hud.companion_guard.charge_label.visible)

func test_danger_priority_and_skip_never_pause_or_block_movement() -> void:
	prepare()
	charge_by_block()
	EventBus.boss_intent_changed.emit(&"scarecrow_captain", &"returning", 1.0)
	assert_true(hud.guard_coach.instruction.text.contains("回旋叉"))
	assert_eq(hud.guard_coach.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(hud.guard_coach.dismiss_button.is_in_group(&"ui_touch_blocker"))
	var dismissed := watch_signal(EventBus.guard_lesson_dismissed)
	hud.guard_coach.dismiss_button.pressed.emit()
	assert_eq(dismissed.count, 1)
	assert_false(hud.guard_coach.visible)
	assert_false(get_tree().paused)
	player._swing()
	assert_false(hud.guard_coach.completed, "hidden lesson cannot mark itself completed")

func test_coach_and_charge_are_in_safe_area_without_control_overlap() -> void:
	prepare()
	charge_by_block()
	for safe in [Rect2(0, 0, 180, 320), Rect2(5, 18, 170, 282)]:
		hud.apply_layout(safe, Rect2(0, 0, 180, 320))
		var lesson := hud.guard_coach.get_global_rect() as Rect2
		assert_true(safe.encloses(lesson))
		assert_true(safe.encloses(hud.companion_guard.charge_label.get_global_rect()))
		assert_false(lesson.intersects(hud.companion_guard.get_global_rect()))
		assert_false(lesson.intersects(hud.ultimate_button.get_global_rect()))
		assert_true(lesson.encloses(hud.guard_coach.dismiss_button.get_global_rect()), "close %s inside coach %s" % [hud.guard_coach.dismiss_button.get_global_rect(), lesson])


func test_detached_previous_stage_actors_do_not_answer_new_hud_requests() -> void:
	prepare()
	charge_by_block()
	var player_parent := player.get_parent()
	var dog_parent := dog.get_parent()
	player_parent.remove_child(player)
	dog_parent.remove_child(dog)
	var coverage := watch_signal(EventBus.companion_guard_coverage)
	var readiness := watch_signal(EventBus.player_combat_readiness)
	EventBus.companion_guard_status_requested.emit()
	EventBus.player_combat_status_requested.emit()
	assert_eq(coverage.count, 0, "old actors cannot overwrite the next stage HUD")
	assert_eq(readiness.count, 0)
	player_parent.add_child(player)
	dog_parent.add_child(dog)
