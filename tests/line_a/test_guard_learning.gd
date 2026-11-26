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
	var presentation := watch_signal(EventBus.guard_success_context_observed)
	EventBus.companion_guard_status_requested.emit()
	EventBus.player_combat_status_requested.emit()
	EventBus.guard_success_context_requested.emit(6.0)
	assert_eq(coverage.count, 0, "old actors cannot overwrite the next stage HUD")
	assert_eq(readiness.count, 0)
	assert_eq(presentation.count, 0)
	player_parent.add_child(player)
	dog_parent.add_child(dog)


func _success_warning(edge_from_center: float) -> AttackTelegraph:
	var mark := AttackTelegraph.make_sector(20.0, Vector2.RIGHT, PI / 4.0)
	arena.add_child(mark)
	mark.global_position = player.global_position - Vector2(20.0 + edge_from_center, 0.0)
	return mark


func _game_control_rects() -> Array[Rect2]:
	return [hud.companion_guard.button.get_global_rect(), hud.ultimate_button.get_global_rect(),
		hud.pause_button.get_global_rect(), hud.combat_readout.get_global_rect()]


func test_success_before_nearby_warning_yields_only_the_optional_card() -> void:
	prepare(&"archer")
	var coach: GuardCoach = hud.guard_coach
	var done := watch_signal(EventBus.guard_lesson_completed)
	var skipped := watch_signal(EventBus.guard_lesson_dismissed)
	var controls := _game_control_rects()
	charge_by_block()
	player.projectile_impact_damage(1.0, false)
	coach._process(0.01)
	assert_eq(done.count, 1)
	assert_eq(coach.heading.text, tr("UI_COACH_DONE"))
	assert_true(coach.heading.is_visible_in_tree(), "success has already been presented")
	var close_center := coach.dismiss_button.get_global_rect().get_center()
	assert_true(TouchJoystick.is_blocked(get_tree(), close_center))
	var mark := _success_warning(9.0)
	assert_eq(player.tactics_status().warning_count, 0, "body still outside the real warning")
	coach._process(0.01)
	assert_false(coach.heading.is_visible_in_tree(), "nearby warning interrupts an already visible success card")
	assert_false(TouchJoystick.is_blocked(get_tree(), close_center), "no invisible dismiss touch target")
	assert_eq(_game_control_rects(), controls, "no reflow on the first danger frame")
	mark.queue_free()
	coach._process(0.19)
	assert_false(coach.heading.is_visible_in_tree(), "short glimpses of an empty arena do not flicker")
	coach._process(0.02)
	assert_true(coach.heading.is_visible_in_tree(), "remaining success presentation returns")
	assert_eq(_game_control_rects(), controls)
	assert_eq(done.count, 1)
	assert_eq(skipped.count, 0)


func test_warning_before_success_does_not_hide_the_lesson_or_tactical_warning() -> void:
	prepare()
	var coach: GuardCoach = hud.guard_coach
	var done := watch_signal(EventBus.guard_lesson_completed)
	_success_warning(3.0)
	player._publish_tactics()
	coach._process(0.01)
	assert_true(coach.heading.is_visible_in_tree(), "active lesson is unchanged")
	var controls := _game_control_rects()
	charge_by_block()
	player._swing()
	coach._process(0.01)
	assert_true(coach.completed)
	assert_eq(done.count, 1)
	assert_false(coach.heading.is_visible_in_tree())
	assert_true(hud.combat_readout.warning_active)
	assert_eq(hud.combat_readout.action.text, tr("UI_TACTIC_WARNING_LOCKED"))
	assert_eq(_game_control_rects(), controls)


func test_no_threat_success_retains_original_show_and_expiry() -> void:
	prepare()
	var coach: GuardCoach = hud.guard_coach
	var done := watch_signal(EventBus.guard_lesson_completed)
	var distant := _success_warning(30.0)
	var hidden := _success_warning(4.0)
	hidden.hide()
	var arrival := AttackTelegraph.make_arrival_circle(20.0)
	arena.add_child(arrival)
	arrival.global_position = player.global_position
	charge_by_block()
	player._swing()
	coach._process(2.19)
	assert_true(coach.heading.is_visible_in_tree(), "far, hidden and arrival marks do not defer the toast")
	assert_true(distant.is_visible_damage_warning())
	assert_eq(coach.heading.text, tr("UI_COACH_DONE"))
	coach._process(0.02)
	assert_false(coach.visible)
	assert_eq(done.count, 1)


func test_expired_success_never_moves_game_controls_during_real_drag() -> void:
	prepare()
	var coach: GuardCoach = hud.guard_coach
	var controls := _game_control_rects()
	var mark := _success_warning(9.0)
	charge_by_block()
	player._swing()
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = Vector2(20, 160)
	touch.pressed = true
	player.joystick.handle_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = touch.index
	drag.position = touch.position + Vector2(9, 0)
	player.joystick.handle_input(drag)
	assert_true(player.joystick.is_active())
	var held := player.joystick.get_vector()
	assert_almost_eq(held.x, 0.5078125, 0.00001)
	assert_eq(held.y, 0.0)
	coach._process(4.5)
	assert_false(coach.heading.is_visible_in_tree())
	assert_eq(_game_control_rects(), controls)
	mark.queue_free()
	coach._process(0.21)
	assert_true(coach.visible, "hold the reservation until the touch ends")
	assert_false(coach.heading.is_visible_in_tree(), "an expired card must not return")
	assert_eq(_game_control_rects(), controls)
	assert_eq(player.joystick.get_vector(), held, "the original drag retains both direction and speed")
	touch.pressed = false
	player.joystick.handle_input(touch)
	coach._process(0.01)
	assert_false(coach.visible)
	assert_ne(_game_control_rects(), controls, "safe release restores the actual layout")


func test_deferred_success_freezes_on_pause_and_cancels_on_down_and_reopen() -> void:
	prepare()
	var coach: GuardCoach = hud.guard_coach
	var done := watch_signal(EventBus.guard_lesson_completed)
	_success_warning(9.0)
	charge_by_block()
	player._swing()
	coach._process(0.03)
	assert_false(coach.heading.is_visible_in_tree())
	var deadline := coach._success_limit_left
	get_tree().paused = true
	await wait_frames(4)
	assert_eq(coach._success_limit_left, deadline)
	get_tree().paused = false
	player._go_down()
	assert_false(coach.visible)
	assert_eq(coach._success_limit_left, 0.0)
	coach.begin()
	assert_false(coach.completed)
	assert_true(coach.heading.is_visible_in_tree(), "a new lesson is not waiting on the old success")
	assert_ne(coach.heading.text, tr("UI_COACH_DONE"))
	assert_eq(done.count, 1)
