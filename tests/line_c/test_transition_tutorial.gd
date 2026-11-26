extends "res://tests/line_a/combat_test_base.gd"
## 轉場與教學提示(CP8、CP10)。

const TRANSITION := preload("res://ui/transition/transition.tscn")
const TUTORIAL := preload("res://ui/hints/tutorial.tscn")

const Hint := preload("res://ui/hints/tutorial.gd")


func after_each() -> void:
	get_tree().paused = false
	GameState.hero_class = &"knight"
	await super()


func test_transition_contract_and_durations() -> void:
	var tr := TRANSITION.instantiate() as CanvasLayer
	add_child(tr)
	assert_eq(tr.layer, 100)
	assert_eq(tr.process_mode, Node.PROCESS_MODE_ALWAYS)
	for m in [&"cover", &"reveal", &"is_covered"]:
		assert_true(tr.has_method(m), "轉場有 %s()" % m)
	var start := Time.get_ticks_msec()
	await tr.cover(0.12)
	var cover_ms := Time.get_ticks_msec() - start
	assert_true(tr.is_covered(), "cover() 之後完全蓋住")
	assert_true(cover_ms <= 260, "cover(0.12) 照時間完成(%d ms)" % cover_ms)
	var wipe := tr.get_node("Wipe") as Control
	assert_eq(wipe.mouse_filter, Control.MOUSE_FILTER_STOP, "蓋住時擋住觸控")
	start = Time.get_ticks_msec()
	await tr.reveal(0.3)
	var reveal_ms := Time.get_ticks_msec() - start
	assert_false(tr.is_covered())
	assert_true(reveal_ms <= 450, "reveal(0.3) 照時間完成(%d ms)" % reveal_ms)
	assert_eq(wipe.mouse_filter, Control.MOUSE_FILTER_IGNORE, "露出後不擋觸控")
	assert_almost_eq(float(tr.call("progress")), 0.0)


func test_transition_signals() -> void:
	var tr := TRANSITION.instantiate() as CanvasLayer
	add_child(tr)
	var c := watch_signal(Signal(tr, "covered"))
	var r := watch_signal(Signal(tr, "revealed"))
	await tr.cover(0.01)
	await tr.reveal(0.01)
	assert_eq(c.count, 1)
	assert_eq(r.count, 1)


func _tutorial() -> Hint:
	var t := TUTORIAL.instantiate() as Hint
	add_child(t)
	return t


func test_tutorial_never_eats_touches() -> void:
	var t := _tutorial()
	await wait_frames(1)
	assert_eq(t.mouse_filter, Control.MOUSE_FILTER_IGNORE, "根節點不攔觸控")
	for c in t.find_children("*", "Control", true, false):
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 不攔觸控" % c.name)


func test_tutorial_waits_for_ground_travel_from_the_controlling_finger() -> void:
	make_arena()
	var t := _tutorial()
	await wait_physics(2)
	var press := InputEventScreenTouch.new()
	press.index = 4
	press.pressed = true
	press.position = Vector2(70, 190)
	Input.parse_input_event(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = Vector2(100, 190)
	Input.parse_input_event(drag)
	drag = drag.duplicate()
	drag.index = 4
	drag.position = Vector2(72, 190)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await wait_physics(6)
	assert_eq(t.step, Hint.Step.MOVE, "第二指和死區內的移動不會完成走位")
	drag = drag.duplicate()
	drag.position = Vector2(79, 190)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await wait_physics(8)
	assert_eq(t.step, Hint.Step.ATTACK, "輕推也能實際走位")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await wait_physics(2)
	assert_eq(t.step, Hint.Step.ATTACK, "光是放手尚未出招")


func test_timeout_dismisses_once_without_claiming_a_strike() -> void:
	make_arena()
	var t := _tutorial()
	var done := watch_signal(t.finished)
	player.set_move_override(Vector2.RIGHT)
	await wait_physics(8)
	assert_eq(t.step, Hint.Step.ATTACK)
	var prompt := t.bubble_label.text
	EventBus.enemy_died.emit(&"scarecrow", Vector2(90, 150), 1)
	assert_eq(t.step, Hint.Step.ATTACK)
	player.clear_move_override()
	t._step_time = t.ATTACK_TIMEOUT - 0.02
	await wait_physics(4)
	assert_eq(t.step, Hint.Step.EXPIRED)
	assert_eq(t.bubble_label.text, prompt)
	await get_tree().create_timer(0.5).timeout
	assert_eq(done.count, 1)
	assert_false(is_instance_valid(t))


func test_pause_freezes_lesson_until_the_battle_resumes() -> void:
	make_arena()
	var t := _tutorial()
	player.set_move_override(Vector2.RIGHT)
	await wait_physics(8)
	player.clear_move_override()
	assert_eq(t.step, Hint.Step.ATTACK)
	t._step_time = t.ATTACK_TIMEOUT - 0.04
	get_tree().paused = true
	await wait_physics(8)
	assert_eq(t.step, Hint.Step.ATTACK)
	assert_almost_eq(t._step_time, t.ATTACK_TIMEOUT - 0.04, 0.00001)
	get_tree().paused = false
	await wait_physics(5)
	assert_eq(t.step, Hint.Step.EXPIRED)


func _stop_and_attack(hero: StringName) -> void:
	GameState.hero_class = hero
	GameState.reset_run()
	make_arena()
	var t := _tutorial()
	player.set_move_override(Vector2.RIGHT)
	await wait_physics(8)
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -18))
	enemy.set_physics_process(false)
	await wait_physics(4)
	assert_eq(t.step, Hint.Step.ATTACK)
	assert_eq(player.swing_count, 0)
	player.clear_move_override()
	assert_true(await wait_until(func() -> bool: return t.step == Hint.Step.DONE, 45))
	assert_true(player.swing_count > 0)
	assert_eq(t.bubble_label.text, tr("UI_TUTORIAL_DONE"))


func test_knight_finishes_tutorial_on_a_real_swing() -> void:
	await _stop_and_attack(&"knight")


func test_mage_finishes_tutorial_on_a_real_cast() -> void:
	await _stop_and_attack(&"mage")


func test_archer_finishes_tutorial_on_a_real_shot() -> void:
	await _stop_and_attack(&"archer")
