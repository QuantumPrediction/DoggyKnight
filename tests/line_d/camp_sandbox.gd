extends Node
## D 線沙盒(DEV_PLAN 11 M1 驗收):進營地、玩小遊戲、拿到評價、離開。
## 這個場景同時是 B 線流程的替身:它把營地加到自己底下,收到 camp_left 後移除營地。
##
## 操作(只用觸控;桌面用滑鼠):
## - 「進入營地」:活力先設為 40,方便看到小遊戲的回復效果。
## - 「壓力測試」:開啟 tests/line_d/stress_test.tscn(40 隻敵人與 FPS)。
## - 「模擬瀏海」:切換 SafeArea.simulate_notch。
## 視窗失去焦點 = 切到背景(小遊戲會暫停);回來後點一下繼續。
##
## 自動試玩(無畫面的檢查用):
##   godot --headless --path . res://tests/line_d/camp_sandbox.tscn --fixed-fps 60 --quit-after 1500 -- --autoplay
## 加上 --fast 時以 4 倍速執行。無畫面(headless)時自動開啟自動試玩。

const CAMP_SCENE: PackedScene = preload("res://game/camp/camp.tscn")
const STRESS_SCENE_PATH: String = "res://tests/line_d/stress_test.tscn"

var autoplay: bool = false
var _camp: Camp
var _menu_layer: CanvasLayer
var _menu: VBoxContainer
var _status: Label
var _log: PackedStringArray = []
var _bot_time: float = 0.0
var _bot_step: int = 0
var _bot_swipe_timer: float = 0.0
var _bot_mistake_done: bool = false
var _bot_pause_done: bool = false
var _timer_at_pause: float = 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay") or DisplayServer.get_name() == "headless"
	if args.has("--fast"):
		Engine.time_scale = 4.0
	EventBus.camp_entered.connect(func() -> void: _note("EventBus.camp_entered"))
	EventBus.camp_left.connect(_on_camp_left)
	EventBus.minigame_finished.connect(func(id: StringName, score: int, grade: int) -> void:
		_note("EventBus.minigame_finished(%s, score=%d, grade=%d) → vigor=%d satisfaction=%d next_level_bonus=%.2f" % [
			id, score, grade, GameState.vigor, GameState.satisfaction, GameState.next_level_bonus]))
	EventBus.app_backgrounded.connect(func() -> void: _note("EventBus.app_backgrounded"))
	EventBus.app_foregrounded.connect(func() -> void: _note("EventBus.app_foregrounded"))
	_build_menu()
	if autoplay:
		_note("autoplay on")
		enter_camp()


func enter_camp() -> void:
	if _camp != null:
		return
	GameState.reset_run()
	GameState.vigor = 40
	_menu_layer.visible = false
	_camp = CAMP_SCENE.instantiate() as Camp
	_camp.minigame_opened.connect(func(m: MinigameBase) -> void:
		_note("minigame opened: %s" % m.config.minigame_id)
		m.state_changed.connect(func(s: MinigameBase.State) -> void:
			_note("  minigame state → %s (time_left=%.2f)" % [MinigameBase.State.keys()[s], m.time_left])))
	_camp.minigame_closed.connect(func(score: int, grade: int) -> void:
		_note("minigame closed, back at camp menu (score=%d grade=%d)" % [score, grade]))
	add_child(_camp)


func _on_camp_left() -> void:
	_note("EventBus.camp_left → sandbox (B 線替身) removes the camp")
	if _camp != null:
		_camp.queue_free()
		_camp = null
	_menu_layer.visible = true
	_status.text = "\n".join(_log.slice(maxi(0, _log.size() - 6)))
	if autoplay:
		_note("SANDBOX DONE")


func _process(delta: float) -> void:
	if autoplay:
		_run_bot(delta)


# 自動試玩:像一個普通玩家那樣滑動,遇到墨水漬就停手(故意犯錯一次),中途模擬切到背景。
func _run_bot(delta: float) -> void:
	if _camp == null:
		return
	_bot_time += delta
	var minigame := _camp.get_minigame()
	match _bot_step:
		0:
			if _bot_time > 0.5:
				_camp.open_minigame()
				_bot_step = 1
		1:
			if minigame == null:
				return
			if minigame.state == MinigameBase.State.PLAYING:
				var scroll := minigame as ScrollMinigame
				if not _bot_pause_done and minigame.play_elapsed > 5.0:
					_bot_pause_done = true
					_timer_at_pause = minigame.time_left
					AppLifecycle.simulate_background()
					_bot_time = 0.0
					_bot_step = 2
					return
				_bot_swipe_timer -= delta
				if _bot_swipe_timer <= 0.0:
					_bot_swipe_timer = 0.22
					if scroll.ink_state == ScrollMinigame.Ink.STOP:
						if not _bot_mistake_done:
							_bot_mistake_done = true
							scroll.simulate_swipe(40.0)
							_note("  bot swiped on an ink blot on purpose (mistakes=%d, time_left=%.2f)" % [scroll.mistakes, minigame.time_left])
					elif scroll.ink_state == ScrollMinigame.Ink.NONE:
						scroll.simulate_swipe(70.0)
			elif minigame.state == MinigameBase.State.RESULTS and minigame.get_state_time() > 1.3:
				minigame.close()
				_bot_time = 0.0
				_bot_step = 3
		2:
			# 在背景裡等一秒:計時不應該減少。
			if _bot_time > 1.0 and minigame != null:
				_note("  paused for 1 s: time_left %.2f → %.2f (should be equal)" % [_timer_at_pause, minigame.time_left])
				AppLifecycle.simulate_foreground()
				minigame.resume_game()   # 等同玩家點一下畫面
				_bot_step = 1
		3:
			if _bot_time > 0.5:
				_camp.open_companion()
				_bot_step = 4
		4:
			if _bot_time > 1.2:
				_camp.leave_camp()
				_bot_step = 5
		_:
			pass


func _note(text: String) -> void:
	_log.append(text)
	print("[camp_sandbox] ", text)


func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 1
	add_child(_menu_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	MinigameUi.apply_shared_theme(root)
	_menu_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("221a33")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 6)
	root.add_child(_menu)
	_menu.add_child(MinigameUi.make_label(tr("CAMP_SANDBOX_TITLE"), 14, Color("ffe9a8")))
	var size := Vector2(150, 26)
	var camp_button := MinigameUi.make_button(tr("CAMP_SANDBOX_CAMP"), size, 11, Color("c0603a"), Color("3a1a10"))
	camp_button.pressed.connect(enter_camp)
	_menu.add_child(camp_button)
	var stress_button := MinigameUi.make_button(tr("CAMP_SANDBOX_STRESS"), size, 11, Color("5a5670"), Color("24203a"))
	stress_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(STRESS_SCENE_PATH))
	_menu.add_child(stress_button)
	var notch_button := MinigameUi.make_button(tr("CAMP_SANDBOX_NOTCH"), size, 11, Color("3a5a8a"), Color("12243a"))
	notch_button.pressed.connect(func() -> void:
		SafeArea.simulate_notch = not SafeArea.simulate_notch
		_layout_menu())
	_menu.add_child(notch_button)
	_status = MinigameUi.make_label("", 8)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(150, 60)
	_menu.add_child(_status)
	root.resized.connect(_layout_menu)
	_layout_menu()


func _layout_menu() -> void:
	var safe := SafeArea.get_safe_rect()
	_menu.size = Vector2(150, 0)
	_menu.position = Vector2(roundf(safe.get_center().x - 75.0), safe.position.y + 40.0)
