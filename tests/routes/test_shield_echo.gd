extends "res://tests/line_b/flow_test_base.gd"

const OPENING := preload("res://data/levels/level_1_1.tres")
const SECOND := preload("res://data/levels/level_1_2.tres")
const REUNION := preload("res://data/levels/level_1_3.tres")


func _roster(wave: WaveData, reinforced: bool, borrow_shield: bool) -> Dictionary:
	var roster := {}
	for entry in wave.entries_for(reinforced, borrow_shield):
		roster[entry.enemy_id] = int(roster.get(entry.enemy_id, 0)) + entry.count
	return roster


func test_optional_shot_replaces_one_foe_and_keeps_all_other_rooms() -> void:
	for reinforced: bool in [false, true]:
		var crowd := 11 if reinforced else 9
		assert_eq(_roster(OPENING.waves[0], reinforced, false), _roster(OPENING.waves[0], reinforced, true))
		assert_eq(_roster(OPENING.waves[1], reinforced, false), {&"scarecrow": crowd})
		assert_eq(_roster(OPENING.waves[1], reinforced, true), {&"scarecrow": crowd - 1, &"scarecrow_archer": 1})
		for room: LevelData in [SECOND, REUNION]:
			for wave in room.waves:
				assert_eq(_roster(wave, reinforced, false), _roster(wave, reinforced, true))
	assert_true(OPENING.companions.is_empty() and SECOND.companions.is_empty())
	assert_eq(REUNION.companions, [&"bulldog"])


func test_checked_trial_stays_in_one_session_and_retry_opens_without_it() -> void:
	make_flow(false, 1234, false, true)
	# Use the production fork with the existing fast lifecycle fixture.
	flow.chapter.levels[0].waves[1].shield_echo_spawns.assign(OPENING.waves[1].shield_echo_spawns)
	await wait_frames(1)
	assert_true(await start_new_game())
	var first := flow.get_session()
	assert_false(first.can_borrow_shield())
	assert_true(await wait_until(func() -> bool:
		if not flow.is_event_open():
			_auto_step()
		return flow.is_event_open()))
	assert_true(first.can_borrow_shield())
	for mode: StringName in [FlowMain.HARD, FlowMain.NORMAL, FlowMain.REINFORCED]:
		first.difficulty_mode = mode
		assert_eq(first.can_borrow_shield(), mode != FlowMain.HARD)
	first.endless = true
	assert_false(first.can_borrow_shield())
	first.endless = false
	first.difficulty_mode = FlowMain.NORMAL
	first.spawner.borrow_shield = true
	flow.choose_event(0)
	assert_true(await wait_until(func() -> bool: return first.spawner.current_wave() == 2))
	assert_false(first.can_borrow_shield())
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_false(flow.get_session().spawner.borrow_shield)
	assert_true(flow.get_session().level.companions.is_empty())


func test_the_archer_starts_behind_distinct_front_guards_within_the_arena() -> void:
	var spawner := WaveSpawner.new()
	spawner.setup(OPENING, null, fast_difficulty())
	var bounds := spawner.pattern_rect()
	for from: Vector2 in [bounds.get_center(), bounds.position, bounds.end, Layout.PLAYER_START]:
		var front := spawner.shield_line_positions(2, from, 54.0)
		var rear := spawner.shield_line_positions(1, from, 144.0)[0]
		assert_true(bounds.grow(0.01).has_point(rear))
		assert_true(rear.distance_to(from) <= 145.0)
		assert_true(front[0].distance_to(front[1]) >= 14.0)
		for guard in front:
			assert_true(bounds.grow(0.01).has_point(guard))
			assert_true(from.distance_to(guard) + 50.0 < from.distance_to(rear))
	spawner.free()
