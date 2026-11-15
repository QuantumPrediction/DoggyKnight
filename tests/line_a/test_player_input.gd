extends "res://tests/line_a/combat_test_base.gd"
## A1、A2:觸控搖桿、只認第一根手指、介面按鈕擋住搖桿、俐落的加減速、移動中不攻擊。


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	return event


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	return event


func test_drag_moves_and_release_stops_without_sliding() -> void:
	make_arena()
	var joystick := player.joystick
	joystick.handle_input(_touch(0, Vector2(90, 200), true))
	joystick.handle_input(_drag(0, Vector2(110, 200)))
	assert_eq(joystick.get_vector(), Vector2.RIGHT)
	await wait_physics(8)
	var speed := GameState.player_stats.move_speed
	assert_almost_eq(player.velocity.x, speed, 0.5, "很快到達全速")
	var x_before := player.global_position.x
	joystick.handle_input(_touch(0, Vector2(110, 200), false))
	await wait_physics(4)
	assert_eq(player.velocity, Vector2.ZERO, "放手後幾格內完全停下")
	assert_true(player.global_position.x - x_before < 3.0, "不會滑行")
	assert_false(joystick.is_active())


func test_only_the_first_finger_controls_movement() -> void:
	make_arena()
	var joystick := player.joystick
	joystick.handle_input(_touch(0, Vector2(60, 200), true))
	joystick.handle_input(_drag(0, Vector2(60, 180)))
	joystick.handle_input(_touch(1, Vector2(120, 250), true))
	joystick.handle_input(_drag(1, Vector2(150, 250)))
	assert_eq(joystick.get_touch_index(), 0)
	assert_eq(joystick.get_vector(), Vector2.UP, "第二根手指不影響方向")
	joystick.handle_input(_touch(1, Vector2(150, 250), false))
	assert_true(joystick.is_active(), "第二根手指放開不影響")
	joystick.handle_input(_touch(0, Vector2(60, 180), false))
	assert_false(joystick.is_active())


func test_touch_starting_on_ui_blocker_is_ignored() -> void:
	make_arena()
	var layer := CanvasLayer.new()
	add_child(layer)
	var button := Control.new()
	button.position = Vector2(140, 260)
	button.size = Vector2(28, 28)
	button.add_to_group(TouchJoystick.BLOCKER_GROUP)
	layer.add_child(button)
	var joystick := player.joystick
	joystick.handle_input(_touch(0, Vector2(150, 270), true))
	assert_false(joystick.is_active(), "按在必殺技按鈕上不出現搖桿")
	joystick.handle_input(_touch(0, Vector2(150, 270), false))
	joystick.handle_input(_touch(1, Vector2(60, 200), true))
	assert_true(joystick.is_active(), "按在其他地方正常出現")
	joystick.handle_input(_touch(1, Vector2(60, 200), false))
	button.visible = false
	joystick.handle_input(_touch(0, Vector2(150, 270), true))
	assert_true(joystick.is_active(), "看不見的按鈕不擋")


func test_pause_releases_the_joystick() -> void:
	make_arena()
	var joystick := player.joystick
	joystick.handle_input(_touch(0, Vector2(60, 200), true))
	joystick.notification(Node.NOTIFICATION_PAUSED)
	assert_false(joystick.is_active(), "暫停時放開搖桿,恢復後不會自己走")


func test_player_attacks_only_when_stopped() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -20))
	enemy.set_physics_process(false)
	player.set_move_override(Vector2.DOWN)
	await wait_physics(20)
	player.set_move_override(Vector2.UP)
	await wait_physics(20)
	assert_eq(player.swing_count, 0, "移動中不攻擊")
	player.clear_move_override()
	var swung := await wait_until(func() -> bool: return player.swing_count > 0, 30)
	assert_true(swung, "停下後自動揮劍")
	assert_true(player.facing.dot(Vector2.UP) > 0.9, "朝最近的敵人揮")


func test_no_swing_without_enemies() -> void:
	make_arena()
	await wait_physics(40)
	assert_eq(player.swing_count, 0, "場上沒有敵人時安靜站著")


func test_windup_comes_before_the_hit() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(18, 0))
	enemy.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(enemy.hp, 75, "前搖期間還沒打中")
	var landed := await wait_until(func() -> bool: return enemy.hp < 75, 20)
	assert_true(landed)


func test_ultimate_needs_full_loyalty() -> void:
	make_arena()
	var used := watch_signal(EventBus.ultimate_used)
	var died := watch_signal(EventBus.enemy_died)
	var loyalty := watch_signal(EventBus.loyalty_changed)
	var near := spawn(&"scarecrow", player.global_position + Vector2(40, -30))
	var far := spawn(&"scarecrow", Vector2(20, 80))
	player.add_loyalty(50.0)
	EventBus.ultimate_requested.emit()
	assert_eq(used.count, 0, "忠誠度未滿時不放")
	player.add_loyalty(500.0)
	assert_eq(loyalty.last_args(), [100.0, 100.0], "最多到上限")
	EventBus.ultimate_requested.emit()
	assert_eq(used.count, 1)
	assert_eq(player.loyalty, 0.0, "放完歸零")
	assert_eq(loyalty.last_args(), [0.0, 100.0])
	assert_eq(died.count, 1, "範圍內的稻草人被打倒")
	assert_true(near.is_dead())
	assert_false(far.is_dead(), "範圍外的不受影響")
	EventBus.ultimate_requested.emit()
	assert_eq(used.count, 1, "不能連放")
