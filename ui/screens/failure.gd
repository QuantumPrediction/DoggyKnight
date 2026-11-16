extends Control
## 失敗結算(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(result: Dictionary);訊號 retry_pressed、title_pressed。
## 金毛只是累得睡著了(可愛,不受傷):睡覺動畫 + Zzz、「呼嚕…呼嚕…」、夜空的小星星一閃一閃。
## 顯示時播放 fail 音效(B 線已經在播失敗短曲時就不重複)。
## 「再試一次」是最大的主要按鈕,會輕輕跳動,讓玩家 2 秒內回到戰鬥。
## v2.3(CS7):梅林的小頭像與一句隨機提示 tr("STORY_TIP_%02d" % n)(n = 1 至 8,不會連續兩次相同)。

signal retry_pressed
signal title_pressed

const PANEL_WIDTH: float = 160.0
const TIP_COUNT: int = 8
const PORTRAIT_FRAME: Texture2D = preload("res://assets/ui/portrait_frame.png")

static var _last_tip: int = 0

var retry_button: Button
var title_button: Button
var title_label: Label
var time_value: Label
var kills_value: Label
var tip_label: Label
var tip_index: int = 0

var _result: Dictionary = {}
var _panel: PanelContainer
var _stars: CPUParticles2D
var _time: float = 0.0


func _ready() -> void:
	UiKit.setup_root(self)
	add_child(UiKit.dim(Color(PaletteColors.NIGHT_D, 0.78)))
	_stars = _make_stars()
	add_child(_stars)
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
	box.add_child(UiKit.label(tr("UI_SLEEPING"), &"LabelSoft"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	box.add_child(grid)
	time_value = _stat_row(grid, tr("UI_TIME"))
	kills_value = _stat_row(grid, tr("UI_KILLS"))
	box.add_child(_tip_row())

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
	var music := get_node_or_null("/root/Music")
	var jingle: StringName = music.call(&"playing_track") if music != null and music.has_method(&"playing_track") else &""
	if jingle != &"fail":
		UiKit.play_sfx(&"fail")


## 梅林的頭像(左)與一句提示(右,像對話泡泡)。
func _tip_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "MerlinTip"
	row.add_theme_constant_override(&"separation", 4)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	var face := UiKit.texture_rect(load("res://assets/portraits/merlin/normal.png") as Texture2D)
	face.name = "MerlinPortrait"
	face.position = Vector2(2, 2)
	holder.add_child(face)
	holder.add_child(UiKit.texture_rect(PORTRAIT_FRAME))
	row.add_child(holder)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.add_child(UiKit.label(tr("UI_MERLIN_TIP"), &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	tip_label = UiKit.wrapped_label("", PANEL_WIDTH - 72.0)
	tip_label.name = "Tip"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	col.add_child(tip_label)
	row.add_child(col)
	set_tip(_pick_tip())
	return row


static func _pick_tip() -> int:
	var n := randi_range(1, TIP_COUNT)
	if n == _last_tip:
		n = n % TIP_COUNT + 1
	_last_tip = n
	return n


## 顯示第 n 句提示(1 至 8;測試也用這個)。
func set_tip(n: int) -> void:
	tip_index = clampi(n, 1, TIP_COUNT)
	if tip_label != null:
		tip_label.text = tr("STORY_TIP_%02d" % tip_index)


func _make_stars() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "NightStars"
	p.texture = load("res://assets/fx/particles/tex/plus.png")
	p.amount = 14
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(96, 160)
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 2.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.5, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 0.8, 0), Color(1, 1, 0.8, 0.9), Color(1, 1, 0.8, 0.3),
			Color(1, 1, 0.8, 0.9), Color(1, 1, 0.8, 0)])
	p.color_ramp = g
	return p


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


func _process(delta: float) -> void:
	_time += delta
	_layout()
	# 「再試一次」輕輕跳動
	retry_button.pivot_offset = retry_button.size * 0.5
	if retry_button.scale.y > 0.95 and retry_button.scale.y < 1.08:
		var s := 1.0 + 0.04 * maxf(0.0, sin(_time * 4.0))
		retry_button.scale = Vector2(s, s)


func _layout() -> void:
	if not is_inside_tree():
		return
	_panel.size = _panel.get_minimum_size()
	_panel.position = UiKit.center_in(SafeArea.get_safe_rect(), _panel.size)
	_stars.position = SafeArea.get_safe_rect().get_center()
