extends TestCase
## 暫停選單(C10):聽 game_paused;按鈕發出 resume_requested / quit_to_title_requested;
## 音效開關直接切換 GameState.sound_on。

const SCENE := preload("res://ui/pause/pause.tscn")

var ui: Control
var _sound_before: bool


func before_each() -> void:
	_sound_before = GameState.sound_on
	ui = SCENE.instantiate() as Control
	add_child(ui)
	await wait_frames(1)


func after_each() -> void:
	GameState.sound_on = _sound_before
	ui.queue_free()
	await wait_frames(1)


func test_root_contract() -> void:
	assert_eq(ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(ui.anchor_right, 1.0)
	assert_eq(ui.anchor_bottom, 1.0)
	assert_eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "根節點不攔觸控(隱藏時不擋 A 線搖桿)")
	assert_false(ui.visible)


func test_follows_game_paused() -> void:
	EventBus.game_paused.emit(true)
	assert_true(ui.visible)
	EventBus.game_paused.emit(false)
	assert_false(ui.visible)


func test_buttons_emit_requests() -> void:
	EventBus.game_paused.emit(true)
	var resume := watch_signal(EventBus.resume_requested)
	var quit := watch_signal(EventBus.quit_to_title_requested)
	(ui.get("resume_button") as Button).pressed.emit()
	(ui.get("title_button") as Button).pressed.emit()
	assert_eq(resume.count, 1)
	assert_eq(quit.count, 1)


func test_keyboard_can_resume_immediately_and_reopening_returns_to_resume() -> void:
	if not OS.has_feature("pc"):
		return
	EventBus.game_paused.emit(true)
	await wait_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), ui.resume_button,
		"Opening pause must offer a safe immediate keyboard action")
	var resumed := watch_signal(EventBus.resume_requested)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	get_viewport().push_input(accept)
	accept = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = false
	get_viewport().push_input(accept)
	await wait_frames(1)
	assert_eq(resumed.count, 1, "Enter/accept resumes without a mouse click")
	ui.title_button.grab_focus()
	EventBus.game_paused.emit(false)
	assert_null(get_viewport().gui_get_focus_owner(), "Hidden pause controls release keyboard focus")
	EventBus.game_paused.emit(true)
	await wait_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), ui.resume_button,
		"Reopening must not leave the previous back-to-title action focused")


func test_sound_toggle_flips_game_state() -> void:
	GameState.sound_on = true
	EventBus.game_paused.emit(true)
	var button: Button = ui.get("sound_button")
	assert_eq(button.text, tr("UI_SOUND_ON"))
	button.pressed.emit()
	assert_false(GameState.sound_on, "關掉音效")
	assert_eq(button.text, tr("UI_SOUND_OFF"))
	button.pressed.emit()
	assert_true(GameState.sound_on, "再按一次打開")
	assert_eq(button.text, tr("UI_SOUND_ON"))


func test_buttons_are_touch_friendly() -> void:
	EventBus.game_paused.emit(true)
	await get_tree().create_timer(0.2).timeout     # 等彈出動畫(放大到原尺寸)播完
	var safe := SafeArea.get_safe_rect()
	var rects: Array[Rect2] = []
	for name in ["resume_button", "sound_button", "title_button"]:
		var b: Button = ui.get(name)
		var r := b.get_global_rect()
		assert_true(r.size.x >= 24.0 and r.size.y >= 24.0, "%s 至少 24×24" % name)
		assert_true(safe.encloses(r), "%s 在安全區內" % name)
		rects.append(r)
	for i in range(1, rects.size()):
		assert_true(rects[i].position.y - rects[i - 1].end.y >= 4.0, "按鈕之間至少 4 像素")
