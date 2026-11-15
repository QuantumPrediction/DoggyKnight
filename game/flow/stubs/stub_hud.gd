extends Control
## HUD 的替身。正式版:ui/hud/hud.tscn(C 線)。只聽 EventBus,不讀任何戰鬥節點。
##
## 顯示:等級、活力條、經驗條、波次;右上角一個暫停鈕(發 back_requested,等同返回鍵,
## 讓沒有返回鍵的 iPhone 也能暫停);忠誠度滿時出現必殺技按鈕(發 ultimate_requested)。

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")
const BAR_W: float = 80.0
const BAR_H: float = 4.0

var _vigor: Vector2i = Vector2i(0, 1)
var _exp: Vector2i = Vector2i(0, 1)
var _level: int = 1
var _wave_text: String = ""
var _level_label: Label
var _wave_label: Label
var _pause_button: Button
var _ultimate_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = GameState.hero_level
	_level_label = Label.new()
	_wave_label = Label.new()
	for label in [_level_label, _wave_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.custom_minimum_size = Vector2(24, 24)
	_pause_button.pressed.connect(EventBus.back_requested.emit)
	add_child(_pause_button)
	_ultimate_button = Button.new()
	_ultimate_button.text = "ULT"
	_ultimate_button.custom_minimum_size = Vector2(32, 32)
	_ultimate_button.visible = false
	_ultimate_button.pressed.connect(func() -> void:
		_ultimate_button.visible = false
		EventBus.ultimate_requested.emit())
	add_child(_ultimate_button)

	EventBus.vigor_changed.connect(_on_vigor_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	EventBus.leveled_up.connect(_on_leveled_up)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.loyalty_changed.connect(_on_loyalty_changed)
	EventBus.level_completed.connect(_on_level_completed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.vigor_changed, _on_vigor_changed],
		[EventBus.exp_changed, _on_exp_changed],
		[EventBus.leveled_up, _on_leveled_up],
		[EventBus.wave_started, _on_wave_started],
		[EventBus.loyalty_changed, _on_loyalty_changed],
		[EventBus.level_completed, _on_level_completed],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _layout() -> void:
	var safe := SafeArea.get_safe_rect()
	var game := SafeArea.get_game_rect()
	var area := safe.intersection(game) if safe.intersects(game) else safe
	_level_label.position = area.position + Vector2(4, 2)
	_wave_label.position = area.position + Vector2(4, 26)
	_pause_button.position = Vector2(area.end.x - 28, area.position.y + 4)
	var arena_bottom_right := game.position + Layout.ARENA_RECT.end
	_ultimate_button.position = Vector2(minf(arena_bottom_right.x, safe.end.x) - 36,
			minf(arena_bottom_right.y, safe.end.y) - 36)
	_refresh()


func _refresh() -> void:
	_level_label.text = "Lv %d" % _level
	_wave_label.text = _wave_text
	queue_redraw()


func _draw() -> void:
	var safe := SafeArea.get_safe_rect()
	var origin := safe.position + Vector2(34, 6)
	_draw_bar(origin, _vigor, Color("ff7a8a"))
	_draw_bar(origin + Vector2(0, 8), _exp, Color("f2c14e"))


func _draw_bar(at: Vector2, value: Vector2i, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.5))
	var ratio := clampf(float(value.x) / maxf(1.0, float(value.y)), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(BAR_W * ratio, BAR_H)), color)


func _set_wave_text(text: String) -> void:
	_wave_text = text
	_refresh()


func _on_vigor_changed(current: int, maximum: int) -> void:
	_vigor = Vector2i(current, maximum)
	queue_redraw()


func _on_exp_changed(current: int, needed: int) -> void:
	_exp = Vector2i(current, needed)
	queue_redraw()


func _on_leveled_up(new_level: int) -> void:
	_level = new_level
	_refresh()


func _on_wave_started(index: int, total: int) -> void:
	_set_wave_text("Wave %d/%d" % [index, total])


func _on_loyalty_changed(current: float, maximum: float) -> void:
	_ultimate_button.visible = maximum > 0.0 and current >= maximum


func _on_level_completed(_level_id: StringName) -> void:
	_set_wave_text("CLEAR!")
