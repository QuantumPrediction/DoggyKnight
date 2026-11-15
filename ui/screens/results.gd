extends Control
## 過關結算(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(result: Dictionary);訊號 continue_pressed。
## result 的鍵(B 線提供):level_id、level_name(翻譯鍵)、victory、time_sec、kills、
## tricks(這一關新學的把戲 id)、hero_level、next_is_camp、is_final(打敗黑騎士)。
## is_final 時顯示「第一章 完」與「感謝試玩!」。顯示時播放 clear 音效。

signal continue_pressed

const PANEL_WIDTH: float = 160.0

var continue_button: Button
var title_label: Label
var level_label: Label
var time_value: Label
var kills_value: Label
var level_value: Label
var tricks_row: HBoxContainer
var footer_label: Label

var _result: Dictionary = {}
var _panel: PanelContainer
var _ribbon: PanelContainer
var _goldie: Control


func _ready() -> void:
	UiKit.setup_root(self)
	add_child(UiKit.dim(Color(PaletteColors.INK, 0.55)))
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	_panel.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)

	level_label = UiKit.label("", &"LabelSoft")
	box.add_child(level_label)
	_goldie = UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", &"idle", 2)
	var goldie_row := CenterContainer.new()
	goldie_row.custom_minimum_size = Vector2(0, 46)
	goldie_row.add_child(_goldie)
	box.add_child(goldie_row)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 0)
	box.add_child(grid)
	time_value = _stat_row(grid, tr("UI_TIME"))
	kills_value = _stat_row(grid, tr("UI_KILLS"))
	level_value = _stat_row(grid, tr("UI_LEVEL"))

	box.add_child(UiKit.label(tr("UI_TRICKS"), &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	tricks_row = HBoxContainer.new()
	tricks_row.add_theme_constant_override(&"separation", 4)
	tricks_row.custom_minimum_size = Vector2(0, 18)
	box.add_child(tricks_row)

	footer_label = UiKit.wrapped_label("", PANEL_WIDTH - 16, &"", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(footer_label)

	continue_button = UiKit.button(tr("UI_NEXT"))
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	var button_row := CenterContainer.new()
	button_row.add_child(continue_button)
	box.add_child(button_row)

	_ribbon = PanelContainer.new()
	_ribbon.theme_type_variation = &"Ribbon"
	title_label = UiKit.label("", &"LabelLight")
	_ribbon.add_child(title_label)
	add_child(_ribbon)

	_apply()
	get_viewport().size_changed.connect(_layout)


## 由 B 線呼叫,傳入這一關的結算資料。
func setup(result: Dictionary) -> void:
	_result = result
	if is_node_ready():
		_apply()
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.call(&"play", &"clear")


func _stat_row(grid: GridContainer, title: String) -> Label:
	grid.add_child(UiKit.label(title, &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	var v := UiKit.label("-", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
	return v


func _apply() -> void:
	var is_final: bool = _result.get("is_final", false)
	title_label.text = tr("UI_THE_END") if is_final else tr("UI_LEVEL_CLEAR")
	var level_name := String(_result.get("level_name", ""))
	level_label.text = tr(level_name) if not level_name.is_empty() else ""
	time_value.text = UiKit.format_time(float(_result.get("time_sec", 0.0)))
	kills_value.text = str(int(_result.get("kills", 0)))
	level_value.text = "%s %d" % [tr("UI_LEVEL_SHORT"), int(_result.get("hero_level", GameState.hero_level))]
	for c in tricks_row.get_children():
		c.queue_free()
	var tricks: Array = _result.get("tricks", [])
	if tricks.is_empty():
		tricks_row.add_child(UiKit.label(tr("UI_NONE"), &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	for id: Variant in tricks:
		tricks_row.add_child(_trick_chip(StringName(str(id))))
	if is_final:
		footer_label.text = tr("UI_THANKS")
	elif _result.get("next_is_camp", false):
		footer_label.text = tr("UI_NEXT_CAMP")
	else:
		footer_label.text = ""
	footer_label.visible = not footer_label.text.is_empty()
	_layout()


func _trick_chip(id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var path := "res://assets/icons/tricks/%s.png" % id
	if ResourceLoader.exists(path):
		row.add_child(UiKit.texture_rect(load(path) as Texture2D))
	var key := "TRICK_%s_NAME" % String(id).to_upper()
	row.add_child(UiKit.label(tr(key) if tr(key) != key else String(id), &"", HORIZONTAL_ALIGNMENT_LEFT))
	return row


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_panel.size = _panel.get_minimum_size()
	_ribbon.size = _ribbon.get_minimum_size()
	var total := Vector2(_panel.size.x, _panel.size.y + _ribbon.size.y * 0.5)
	var pos := UiKit.center_in(safe, total)
	_ribbon.position = Vector2(floorf(safe.get_center().x - _ribbon.size.x * 0.5), pos.y)
	_panel.position = Vector2(pos.x, pos.y + floorf(_ribbon.size.y * 0.5))
