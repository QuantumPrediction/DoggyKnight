extends TestCase
## 轉場與教學提示(CP8、CP10)。

const TRANSITION := preload("res://ui/transition/transition.tscn")
const TUTORIAL := preload("res://ui/hints/tutorial.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	# 不等下一格:訊號監看要在節點真正釋放前停止。
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func test_transition_contract_and_durations() -> void:
	var tr := TRANSITION.instantiate() as CanvasLayer
	add_child(tr)
	_nodes.append(tr)
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
	_nodes.append(tr)
	var c := watch_signal(Signal(tr, "covered"))
	var r := watch_signal(Signal(tr, "revealed"))
	await tr.cover(0.01)
	await tr.reveal(0.01)
	assert_eq(c.count, 1)
	assert_eq(r.count, 1)


func _tutorial() -> Control:
	var t := TUTORIAL.instantiate() as Control
	add_child(t)
	_nodes.append(t)
	return t


func test_tutorial_never_eats_touches() -> void:
	var t := _tutorial()
	await wait_frames(1)
	assert_eq(t.mouse_filter, Control.MOUSE_FILTER_IGNORE, "根節點不攔觸控")
	for c in t.find_children("*", "Control", true, false):
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 不攔觸控" % c.name)


func test_tutorial_steps_with_real_touch_events() -> void:
	var t := _tutorial()
	assert_eq(t.get("step"), 0, "第一步:拖曳移動")
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(90, 220)
	Input.parse_input_event(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(118, 220)
	Input.parse_input_event(drag)
	await wait_frames(2)
	assert_eq(t.get("step"), 1, "拖曳 20 像素以上進入第二步:放手攻擊")
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(118, 220)
	Input.parse_input_event(release)
	await wait_frames(2)


func test_tutorial_finishes_after_attack_or_timeout() -> void:
	var t := _tutorial()
	var done := [0]
	t.connect(&"finished", func() -> void: done[0] += 1)
	t.call("simulate_drag", 30.0)
	assert_eq(t.get("step"), 1)
	t.call("simulate_release", false)
	assert_eq(t.get("step"), 1, "不在敵人附近放手:繼續提示")
	t.set("_step_time", 3.95)
	await wait_frames(6)
	assert_eq(t.get("step"), 2, "4 秒後自動完成")
	await get_tree().create_timer(1.5).timeout
	assert_eq(done[0], 1, "完成時發 finished")
	assert_false(is_instance_valid(t), "完成後自己淡出、移除")


func test_tutorial_finishes_when_an_enemy_falls() -> void:
	var t := _tutorial()
	t.call("simulate_drag", 30.0)
	EventBus.enemy_died.emit(&"scarecrow", Vector2(90, 150), 1)
	assert_eq(t.get("step"), 2, "打倒敵人就算學會了")
