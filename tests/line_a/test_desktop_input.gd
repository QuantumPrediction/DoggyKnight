extends "res://tests/line_a/combat_test_base.gd"
## Windows controls exercise actual InputMap events and the production player.

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func after_each() -> void:
	get_tree().paused = false
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SPACE]:
		key(code, false)
	await super.after_each()


func test_keyboard_movement_is_normalized_and_release_stops() -> void:
	make_arena()
	key(KEY_W, true)
	key(KEY_D, true)
	assert_almost_eq(player.get_move_input().length(), 1.0)
	assert_true(player.get_move_input().dot(Vector2(1, -1).normalized()) > 0.99)
	await wait_physics(8)
	assert_true(player.velocity.length() > 0.0)
	key(KEY_W, false)
	key(KEY_D, false)
	await wait_physics(4)
	assert_eq(player.velocity, Vector2.ZERO)


func test_arrows_and_opposite_directions() -> void:
	make_arena()
	key(KEY_LEFT, true)
	assert_eq(player.get_move_input(), Vector2.LEFT)
	key(KEY_RIGHT, true)
	assert_eq(player.get_move_input(), Vector2.ZERO)
	key(KEY_LEFT, false)
	assert_eq(player.get_move_input(), Vector2.RIGHT)
	key(KEY_RIGHT, false)
	key(KEY_UP, true)
	assert_eq(player.get_move_input(), Vector2.UP)
	key(KEY_UP, false)
	key(KEY_DOWN, true)
	assert_eq(player.get_move_input(), Vector2.DOWN)


func test_keyboard_release_restores_auto_attack() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -20))
	enemy.set_physics_process(false)
	key(KEY_D, true)
	await wait_physics(4)
	assert_eq(player.swing_count, 0)
	key(KEY_D, false)
	assert_true(await wait_until(func() -> bool: return player.swing_count > 0, 30))


func test_space_uses_ultimate_only_with_full_loyalty_and_not_while_paused() -> void:
	make_arena()
	var used := watch_signal(EventBus.ultimate_used)
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	assert_eq(used.count, 0)
	player.add_loyalty(500.0)
	get_tree().paused = true
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	assert_eq(used.count, 0)
	get_tree().paused = false
	key(KEY_SPACE, true, true)
	assert_eq(used.count, 0, "key repeat must not trigger an ultimate")
	key(KEY_SPACE, false)
	key(KEY_SPACE, true)
	assert_eq(used.count, 1)
	key(KEY_SPACE, false)


func test_pause_requires_release_before_keyboard_movement_resumes() -> void:
	make_arena()
	key(KEY_D, true)
	assert_eq(player.get_move_input(), Vector2.RIGHT)
	get_tree().paused = true
	get_tree().paused = false
	assert_eq(player.get_move_input(), Vector2.ZERO)
	key(KEY_D, false)
	assert_eq(player.get_move_input(), Vector2.ZERO)
	key(KEY_D, true)
	assert_eq(player.get_move_input(), Vector2.RIGHT)


func test_keyboard_tutorial_progresses_without_touch() -> void:
	make_arena()
	var tutorial := preload("res://ui/hints/tutorial.tscn").instantiate()
	add_child(tutorial)
	assert_eq(tutorial.step, 0)
	key(KEY_W, true)
	assert_eq(tutorial.step, 1)
	key(KEY_W, false)
	tutorial._step_time = tutorial.ATTACK_TIMEOUT
	await wait_frames(2)
	assert_eq(tutorial.step, 2)
