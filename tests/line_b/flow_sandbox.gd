extends Node
## B 線沙盒:完整的遊戲流程(game/flow/main.tscn),一律使用替身場地、替身敵人與替身畫面,
## 不需要 A、C、D 線的任何東西也能從標題玩到打敗黑騎士(六關、兩次營地)。
##
## 怎樣玩:
## - 按住畫面任意位置拖曳 → 金毛移動;放手 → 停下自動攻擊。點一下敵人 → 敵人立即倒下。
## - 右上角「II」= 暫停(等同 Android 返回鍵;桌面按 Esc 也可以)。
## - 左下角「DBG」打開測試工具:
##     Kill all  場上敵人全部倒下         +5 EXP   直接加 5 點經驗(會升級)
##     BG        模擬切到背景(暫停並存檔)  Back     模擬返回鍵
##     Down      金毛直接睡著(測試失敗)     Speed    遊戲速度 1 倍 / 4 倍
##     Notch     模擬瀏海                   Android  模擬 Android(標題按返回鍵會詢問離開)
##     Reset     清除沙盒存檔(教學提示、最佳星數重新開始)
## 存檔寫在 user://flow_sandbox_save.json,不會蓋掉正式存檔。

const MAIN_SCENE: String = "res://game/flow/main.tscn"
const SAVE_PATH: String = "user://flow_sandbox_save.json"
const FONT_SIZE: int = 7

var flow: FlowMain
var _panel: VBoxContainer
var _status: Label
var _toggle: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	flow = (load(MAIN_SCENE) as PackedScene).instantiate() as FlowMain
	flow.use_stand_ins = true
	flow.save_path = SAVE_PATH
	add_child(flow)
	_build_debug_panel()


func _process(_delta: float) -> void:
	if _panel.visible:
		_status.text = _status_text()


func _status_text() -> String:
	var state_name: String = FlowMain.State.keys()[flow.state]
	var text := "%s  L%d  hero Lv%d" % [state_name, flow.get_level_index() + 1, GameState.hero_level]
	var session := flow.get_session()
	if session != null and session.spawner != null:
		text += "\nwave %d/%d  enemies %d  %.0fs" % [session.spawner.current_wave(), session.spawner.total_waves(),
				session.spawner.enemies_remaining(), session.time_sec]
	text += "\nsave: level %d  tricks %s" % [flow.get_reached_level(), ",".join(GameState.active_tricks)]
	if session != null and session.level != null:
		text += "\ndamage %d/%d  par %.0fs  best %s" % [session.damage_taken, session.level.damage_budget,
				session.level.par_time, GameState.best_stars]
	return text


func _build_debug_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	root.theme = theme
	layer.add_child(root)

	var safe := SafeArea.get_safe_rect()
	_toggle = Button.new()
	_toggle.text = "DBG"
	_toggle.custom_minimum_size = Vector2(28, 24)
	_toggle.position = Vector2(safe.position.x + 2, safe.end.y - 26)
	_toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	root.add_child(_toggle)

	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override(&"separation", 2)
	_panel.visible = false
	root.add_child(_panel)
	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	bg.add_theme_stylebox_override(&"panel", style)
	_panel.add_child(bg)
	_status = Label.new()
	bg.add_child(_status)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	_panel.add_child(grid)
	for item: Array in [
		["Kill all", _kill_all], ["+5 EXP", _add_exp],
		["BG", _background], ["Back", AppLifecycle.simulate_back],
		["Down", _down], ["Speed", _toggle_speed],
		["Notch", _toggle_notch], ["Android", _toggle_android],
		["Reset", _reset_save],
	]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(52, 24)
		button.pressed.connect(item[1])
		grid.add_child(button)
	_panel.reset_size()
	_panel.position = Vector2(safe.position.x + 2, _toggle.position.y - _panel.size.y - 4)


func _kill_all() -> void:
	var arena := flow.get_arena()
	if arena != null and arena.has_method(&"debug_kill_all"):
		arena.call(&"debug_kill_all")


func _add_exp() -> void:
	EventBus.exp_collected.emit(5)


func _background() -> void:
	AppLifecycle.simulate_background()
	AppLifecycle.simulate_foreground()


func _down() -> void:
	var arena := flow.get_arena()
	if arena != null and arena.has_method(&"debug_down_player"):
		arena.call(&"debug_down_player")


func _toggle_speed() -> void:
	Engine.time_scale = 4.0 if Engine.time_scale < 2.0 else 1.0


func _toggle_notch() -> void:
	SafeArea.simulate_notch = not SafeArea.simulate_notch


func _reset_save() -> void:
	SaveStore.new(SAVE_PATH).delete()
	GameState.tutorial_done = false
	GameState.best_stars = {}


func _toggle_android() -> void:
	flow.platform_name = "Linux" if flow.platform_name == "Android" else "Android"
