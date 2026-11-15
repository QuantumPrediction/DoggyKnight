extends TestCase
## HUD(C8):只聽 EventBus、數值條反應、必殺技按鈕、暫停按鈕、橫幅、安全區版面。

const HUD_SCENE := preload("res://ui/hud/hud.tscn")

var hud: Control


func before_each() -> void:
	hud = HUD_SCENE.instantiate() as Control
	add_child(hud)
	await wait_frames(1)


func after_each() -> void:
	hud.queue_free()
	SafeArea.simulate_notch = false
	await wait_frames(1)


func test_root_contract() -> void:
	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS, "HUD 暫停時也要更新")
	assert_eq(hud.anchor_right, 1.0)
	assert_eq(hud.anchor_bottom, 1.0)
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HUD 本身不可擋住搖桿")


func test_bars_react_to_signals() -> void:
	EventBus.vigor_changed.emit(40, 80)
	EventBus.exp_changed.emit(2, 5)
	EventBus.loyalty_changed.emit(30.0, 100.0)
	EventBus.leveled_up.emit(4)
	var vigor: PixelBar = hud.get("vigor_bar")
	var exp_bar: PixelBar = hud.get("exp_bar")
	var loyalty: PixelBar = hud.get("loyalty_bar")
	assert_eq(vigor.value, 40.0)
	assert_eq(vigor.max_value, 80.0)
	assert_almost_eq(exp_bar.ratio(), 0.4)
	assert_almost_eq(loyalty.ratio(), 0.3)
	assert_eq((hud.get("level_label") as Label).text, "4")


func test_ultimate_button_appears_when_loyalty_is_full() -> void:
	var button: TextureButton = hud.get("ultimate_button")
	assert_false(button.visible, "一開始不顯示")
	EventBus.loyalty_changed.emit(99.0, 100.0)
	assert_false(button.visible, "未滿不顯示")
	EventBus.loyalty_changed.emit(100.0, 100.0)
	assert_true(button.visible, "滿了就出現")
	var requested := watch_signal(EventBus.ultimate_requested)
	button.pressed.emit()
	assert_eq(requested.count, 1, "按下發出 ultimate_requested")
	button.pressed.emit()
	assert_eq(requested.count, 1, "等 ultimate_used 之前不重複發出")
	EventBus.ultimate_used.emit()
	assert_false(button.visible, "用掉後隱藏")
	EventBus.loyalty_changed.emit(100.0, 100.0)
	assert_true(button.visible, "再次滿了又出現")
	button.pressed.emit()
	assert_eq(requested.count, 2)


func test_buttons_block_the_joystick_and_are_big_enough() -> void:
	for name in ["pause_button", "ultimate_button"]:
		var b: Control = hud.get(name)
		assert_true(b.is_in_group(&"ui_touch_blocker"), "%s 在 ui_touch_blocker 群組" % name)
		assert_true(b.size.x >= 24.0 and b.size.y >= 24.0, "%s 至少 24×24(實際 %s)" % [name, b.size])


func test_pause_button_acts_like_back_key() -> void:
	var back := watch_signal(EventBus.back_requested)
	(hud.get("pause_button") as Button).pressed.emit()
	assert_eq(back.count, 1)


func test_wave_banner() -> void:
	EventBus.wave_started.emit(2, 3)
	var texts: PackedStringArray = hud.call("banner_texts")
	assert_true(texts.has(tr("UI_WAVE") % [2, 3]), "顯示「第 2/3 波」:%s" % [texts])


func test_boss_banner_on_boss_level_and_phase() -> void:
	EventBus.level_started.emit(&"1-6")
	var texts: PackedStringArray = hud.call("banner_texts")
	assert_true(texts.has(tr("UI_BOSS")), "頭目關顯示「頭目來了!」:%s" % [texts])
	EventBus.boss_phase_changed.emit(2)
	texts = hud.call("banner_texts")
	assert_true(texts.has(tr("UI_BOSS_ANGRY")), "第二階段提示")


func test_boss_banner_from_phase_signal_on_other_ids() -> void:
	EventBus.level_started.emit(&"some_level")
	EventBus.boss_phase_changed.emit(1)
	var texts: PackedStringArray = hud.call("banner_texts")
	assert_true(texts.has(tr("UI_BOSS")))


func test_layout_stays_inside_safe_area_on_many_phones() -> void:
	var cases: Array = [
		[Vector2(180, 320), Rect2(0, 0, 180, 320)],
		[Vector2(180, 320), Rect2(0, 24, 180, 286)],      # 模擬瀏海
		[Vector2(180, 400), Rect2(0, 22, 180, 367)],      # Android 挖孔 + 手勢列
		[Vector2(196, 426), Rect2(0, 10, 196, 405)],      # iPhone 15
		[Vector2(196, 426), Rect2(0, 34, 196, 382)],      # iPhone 15 + 模擬瀏海
	]
	for c: Array in cases:
		var screen: Vector2 = c[0]
		var safe: Rect2 = c[1]
		var game := Rect2(((screen - SafeArea.GAME_SIZE) * 0.5).floor(), SafeArea.GAME_SIZE)
		hud.call("apply_layout", safe, game)
		for name in ["level_badge", "vigor_bar", "exp_bar", "loyalty_bar", "pause_button", "ultimate_button"]:
			var n: Control = hud.get(name)
			var r := Rect2(n.position, n.size)
			assert_true(safe.encloses(r), "%s 在安全區內(畫面 %s,安全區 %s,元件 %s)" % [name, screen, safe, r])
		var ult: Control = hud.get("ultimate_button")
		assert_true(ult.position.y + ult.size.y <= safe.end.y - 14.0, "必殺技按鈕不貼底(%s)" % screen)
		var arena_end := game.position + Layout.ARENA_RECT.end
		assert_true(ult.position.x + ult.size.x <= arena_end.x and ult.position.y + ult.size.y <= arena_end.y,
				"必殺技按鈕在戰鬥區右下角之內")
		var pause: Control = hud.get("pause_button")
		var bar: Control = hud.get("vigor_bar")
		assert_true(pause.position.x - (bar.position.x + bar.size.x) >= 4.0, "按鈕與數值條之間至少 4 像素")


func _touch_catchers(node: Node, out: Array[Control]) -> void:
	for c in node.get_children():
		if c is Control:
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append(ctl)
		_touch_catchers(c, out)


func test_only_blocker_buttons_catch_touches() -> void:
	EventBus.loyalty_changed.emit(100.0, 100.0)
	EventBus.wave_started.emit(1, 3)
	var catchers: Array[Control] = []
	_touch_catchers(hud, catchers)
	assert_eq(catchers.size(), 2, "只有暫停與必殺技兩個按鈕會攔觸控:%s" % [catchers])
	for c in catchers:
		assert_true(c.is_in_group(&"ui_touch_blocker"), "%s 在 ui_touch_blocker 群組" % c.name)
