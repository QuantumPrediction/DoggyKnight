extends "res://tests/line_a/combat_test_base.gd"

var readout: CombatReadout

func before_each() -> void:
	GameState.hero_class = &"archer"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.reset_run()
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	GameState.level_index = 0
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(90, 180)
	player.set_move_override(Vector2.ZERO)
	readout = CombatReadout.new()
	add_child(readout)

func after_each() -> void:
	get_tree().paused = false
	GameState.hero_class = &"knight"
	await super()

func soldier() -> ScarecrowEnemy:
	var enemy := spawn(&"scarecrow", Vector2(70, 180)) as ScarecrowEnemy
	enemy.set_physics_process(false)
	enemy.target = player
	enemy._start_telegraph(Vector2.RIGHT, false)
	return enemy

func test_scarecrow_observer_receives_frozen_geometry_before_damage_and_no_cancelled_impact() -> void:
	var enemy := spawn(&"scarecrow", Vector2(70, 180)) as ScarecrowEnemy
	enemy.set_physics_process(false)
	enemy.target = player
	var events: Array = []
	enemy.warning_committed.connect(func(mark: AttackTelegraph) -> void:
		events.append(["start", mark.global_transform, mark.direction, GameState.vigor]))
	enemy.swing_resolving.connect(func(mark: AttackTelegraph) -> void:
		events.append(["impact", mark.global_transform, mark.direction, GameState.vigor]))
	enemy._start_telegraph(Vector2.RIGHT, false)
	enemy._cancel_attack()
	assert_eq(events.size(), 1, "cancellation emits no resolution")
	enemy._start_telegraph(Vector2.RIGHT, false)
	enemy._swing()
	assert_eq(events.size(), 3)
	assert_eq(events[1][0], "start")
	assert_eq(events[2][0], "impact")
	assert_eq(events[1].slice(1), events[2].slice(1), "same committed transform, direction and pre-hit vigor")
	assert_true(GameState.vigor < int(events[2][3]), "damage follows the resolution event")

func test_committed_warning_takes_priority_without_changing_focus_or_combat() -> void:
	var enemy := soldier()
	player._focus_elapsed = player.loadout.focus_time
	var hp := enemy.hp
	var vigor := GameState.vigor
	var rng_state := enemy.rng.state
	var phase_left := enemy._phase_left
	player._publish_tactics()
	assert_eq(player.tactics_status().phase, &"ready", "readiness remains the real attack state")
	assert_eq(readout.action.text, tr("UI_TACTIC_WARNING_LOCKED"))
	assert_eq(readout.status.get("warning_count", -1), 1)
	assert_almost_eq(readout.meter, 1.0)
	assert_true(readout.detail.text.contains("1.35"))
	assert_eq(enemy.hp, hp)
	assert_eq(GameState.vigor, vigor)
	assert_eq(enemy.rng.state, rng_state)
	assert_eq(enemy._phase_left, phase_left)
	assert_almost_eq(player._focus_elapsed, player.loadout.focus_time)

func test_warning_boundary_and_cancellation_refresh_without_attack_state_change() -> void:
	var enemy := soldier()
	player._publish_tactics()
	assert_eq(readout.status.get("warning_count", -1), 1)
	player.global_position = Vector2(120, 180)
	player._publish_tactics()
	assert_eq(readout.status.get("warning_count", -1), 0)
	assert_eq(readout.action.text, tr("UI_TACTIC_READY_ARCHER"))
	player.global_position = Vector2(90, 180)
	player._publish_tactics()
	assert_eq(readout.status.get("warning_count", -1), 1)
	enemy._cancel_attack()
	player._publish_tactics()
	assert_eq(readout.status.get("warning_count", -1), 0, "queued old warning is ignored before the next frame")

func test_archer_tracking_lock_and_release_are_distinct() -> void:
	var enemy := spawn(&"scarecrow_archer", Vector2(50, 180)) as ArcherEnemy
	enemy.set_physics_process(false)
	enemy.target = player
	enemy._start_aim()
	player._publish_tactics()
	assert_eq(readout.action.text, tr("UI_TACTIC_WARNING_TRACKING"))
	enemy._ai(enemy._aim_total * 0.6)
	player._publish_tactics()
	assert_eq(readout.action.text, tr("UI_TACTIC_WARNING_LOCKED"))
	enemy._release()
	player._publish_tactics()
	assert_eq(readout.status.get("warning_count", -1), 0, "flying projectiles are not a visible ground warning")

func test_arrivals_are_not_attacks_and_tint_is_not_a_classifier() -> void:
	var enemy := spawn(&"scarecrow", player.global_position)
	enemy.set_physics_process(false)
	enemy.begin_spawn(1.0)
	assert_eq(player.tactics_status().get("warning_count", -1), 0)
	var captain := spawn(&"scarecrow_captain", Vector2(90, 120)) as CaptainBoss
	captain.set_physics_process(false)
	captain.target = player
	captain._start_rally()
	assert_true(not captain._rally_marks.is_empty())
	player.global_position = captain._rally_marks[0].global_position
	assert_eq(player.tactics_status().get("warning_count", -1), 0)
	var damage_mark := AttackTelegraph.make_circle(12.0, AttackTelegraph.DUST)
	arena.add_child(damage_mark)
	damage_mark.global_position = player.global_position
	assert_eq(player.tactics_status().get("warning_count", -1), 1, "damage warnings may have the same tint as an arrival")

func test_transformed_shapes_hidden_and_detached_marks_use_current_visible_body() -> void:
	var mark := AttackTelegraph.make_sector(24, Vector2.RIGHT, PI / 4.0)
	arena.add_child(mark)
	mark.position = Vector2(90, 160)
	mark.rotation = PI / 2.0
	assert_eq(player.tactics_status().get("warning_count", -1), 1)
	mark.hide()
	assert_eq(player.tactics_status().get("warning_count", -1), 0)
	mark.show()
	arena.remove_child(mark)
	assert_eq(player.tactics_status().get("warning_count", -1), 0)
	mark.free()
	mark = AttackTelegraph.make_circle(10)
	arena.add_child(mark)
	mark.position = Vector2(65, 180)
	mark.scale = Vector2(2, 2)
	assert_eq(player.tactics_status().get("warning_count", -1), 1)
	player.position.x = 93
	assert_eq(player.tactics_status().get("warning_count", -1), 0)
	mark.queue_free()
	mark = AttackTelegraph.make_line(Vector2.RIGHT, 40, 6)
	arena.add_child(mark)
	mark.position = Vector2(85, 160)
	mark.rotation = PI / 2.0
	assert_eq(player.tactics_status().get("warning_count", -1), 1)
	player.position.x = 96
	assert_eq(player.tactics_status().get("warning_count", -1), 0)

func test_overlap_priority_fits_and_pause_cannot_advance_warning_or_focus() -> void:
	var enemy := soldier()
	var second := AttackTelegraph.make_circle(12)
	arena.add_child(second)
	second.global_position = player.global_position
	player._publish_tactics()
	assert_eq(readout.action.text, tr("UI_TACTIC_WARNING_OVERLAP"))
	assert_eq(readout.status.get("warning_count", -1), 2)
	assert_true(readout.action.get_minimum_size().x <= readout.action.size.x)
	assert_eq(readout.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var before := player.tactics_status()
	var clock := enemy._phase_left
	get_tree().paused = true
	await wait_frames(3)
	EventBus.player_combat_status_requested.emit()
	assert_eq(readout.status, before)
	assert_eq(enemy._phase_left, clock)

func test_warning_readout_contains_every_text_row_above_the_panel_border() -> void:
	soldier()
	EventBus.trick_chosen.emit(&"roll")
	player._publish_tactics()
	await wait_frames(2)
	var inside := Rect2(Vector2(3, 2), readout.size - Vector2(6, 4))
	for label in [readout.action, readout.detail, readout.dodge]:
		assert_true(inside.encloses(label.get_rect()), "%s rect %s inside %s" % [label.text, label.get_rect(), inside])
		assert_true(label.get_minimum_size().y <= label.size.y, label.text)
	assert_true(readout.action.get_rect().end.y <= readout.detail.position.y)
	assert_true(readout.detail.get_rect().end.y <= 27.0, "detail must not overlap the focus meter")
	assert_true(readout.dodge.position.y >= 29.0, "roll text stays below the meter")


func test_roll_ready_instruction_uses_glyphs_in_the_bundled_face() -> void:
	var font := load("res://assets/fonts/StorySans.otf") as FontFile
	var bundled := font.get_supported_chars()
	for ch: String in tr("UI_TACTIC_ROLL_READY"):
		assert_true(bundled.contains(ch), "Roll-ready glyph must ship with the game: " + ch)
