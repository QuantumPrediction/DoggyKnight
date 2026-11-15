extends Control
## 失敗結算(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(result: Dictionary);訊號 retry_pressed、title_pressed。
## 金毛只是累得睡著了(可愛,不受傷):睡覺動畫 + Zzz。顯示時播放 fail 音效。
## 「再試一次」是最大的主要按鈕,讓玩家 2 秒內回到戰鬥。

signal retry_pressed
signal title_pressed

const PANEL_WIDTH: float = 156.0

var retry_button: Button
var title_button: Button
var title_label: Label
var time_value: Label
var kills_value: Label

var _result: Dictionary = {}
var _panel: PanelContainer


func _ready() -> void:
	UiKit.setup_root(self)
	add_child(UiKit.dim(Color(PaletteColors.WATER_D, 0.72)))
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_panel.add_child(box)

	title_label = UiKit.label(tr("UI_LEVEL_FAILED"), &"")
	box.add_child(title_label)
	var goldie := UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", &"sleep", 2)
	goldie.name = "SleepingGoldie"
	var goldie_row := CenterContainer.new()
	goldie_row.add_child(goldie)
	box.add_child(goldie_row)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	box.add_child(grid)
	time_value = _stat_row(grid, tr("UI_TIME"))
	kills_value = _stat_row(grid, tr("UI_KILLS"))

	retry_button = UiKit.button(tr("UI_RETRY"), &"", Vector2(124, 30))
	retry_button.name = "RetryButton"
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	title_button = UiKit.button(tr("UI_BACK_TO_TITLE"), &"ButtonAlt", Vector2(124, 26))
	title_button.name = "TitleButton"
	title_button.pressed.connect(func() -> void: title_pressed.emit())
	for b: Button in [retry_button, title_button]:
		var row := CenterContainer.new()
		row.add_child(b)
		box.add_child(row)

	_apply()
	get_viewport().size_changed.connect(_layout)


## 由 B 線呼叫,傳入這一關的結算資料(鍵同過關結算)。
func setup(result: Dictionary) -> void:
	_result = result
	if is_node_ready():
		_apply()
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.call(&"play", &"fail")


func _stat_row(grid: GridContainer, title: String) -> Label:
	grid.add_child(UiKit.label(title, &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	var v := UiKit.label("-", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
	return v


func _apply() -> void:
	time_value.text = UiKit.format_time(float(_result.get("time_sec", 0.0)))
	kills_value.text = str(int(_result.get("kills", 0)))
	_layout()


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	_panel.size = _panel.get_minimum_size()
	_panel.position = UiKit.center_in(SafeArea.get_safe_rect(), _panel.size)
