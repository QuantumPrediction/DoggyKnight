extends Control
## 失敗結算(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(result: Dictionary);訊號 retry_pressed、title_pressed。
## 金毛只是累得睡著了(可愛,不受傷):睡覺動畫 + Zzz、「呼嚕…呼嚕…」、夜空的小星星一閃一閃。
## 顯示時播放 fail 音效(B 線已經在播失敗短曲時就不重複)。
## 「再試一次」是最大的主要按鈕,會輕輕跳動,讓玩家 2 秒內回到戰鬥。
## v2.3(CS7):梅林的小頭像與一句隨機提示 tr("STORY_TIP_%02d" % n)(不會連續兩次相同)。
## v2.6(CW6,docs/STORY.md 第 13 節):提示依 GameState.chapter 選:第一章 1 至 8;第二章 1 至 10 與 13;
## 第三章 1 至 14。
## v2.7(CW10,docs/STORY.md 第 18 節):提示 1 至 20,每章只抽用得上的(TIPS_BY_CHAPTER):第四章 1 至 7
## 與 15、16(螃蟹、水母);第五章 1 至 7 與 9、11、17、18(石像鬼、狐火、雪人、火蜥蜴);第六章 1 至 8 與
## 12、13、19、20(影狼、舊頭目的幻影、影子騎士、提燈鬼火)。無盡試煉抽已開啟各章的提示。
## v2.4(CV5,DEV_PLAN 4.12):結果字典的 can_revive 為 true 時,最上面多一個金色的
## 「用 N 個零食復活」按鈕(N = revive_cost,按鈕上有零食圖示),按下播 revive 音效並發 revive_pressed;
## 這時「再試一次」改為藍色次要按鈕,梅林的小提示換成「金毛吃了零食就會醒來!」。can_revive 為 false 或沒有這個鍵時完全不顯示。

signal retry_pressed
signal title_pressed
signal revive_pressed

const PANEL_WIDTH: float = 160.0
const TIP_COUNT: int = 20
## 每章可以抽的提示編號(docs/STORY.md 第 6、13、18 節);沒有列出的章用全部 1 至 TIP_COUNT。
const TIPS_BY_CHAPTER: Dictionary = {
	1: [1, 2, 3, 4, 5, 6, 7, 8],
	2: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13],
	3: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
	4: [1, 2, 3, 4, 5, 6, 7, 15, 16],
	5: [1, 2, 3, 4, 5, 6, 7, 9, 11, 17, 18],
	6: [1, 2, 3, 4, 5, 6, 7, 8, 12, 13, 19, 20],
}
const PORTRAIT_FRAME: Texture2D = preload("res://assets/ui/portrait_frame.png")

static var _last_tip: int = 0

var revive_button: Button
var revive_hint: Label
var retry_button: Button
var title_button: Button
var title_label: Label
var time_value: Label
var kills_value: Label
var tip_label: Label
var tip_index: int = 0

var _result: Dictionary = {}
var _panel: PanelContainer
var _tip: Control
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
	_tip = _tip_row()
	box.add_child(_tip)

	revive_button = UiKit.button(tr("UI_REVIVE") % 0, &"", Vector2(140, 30))
	revive_button.name = "ReviveButton"
	revive_button.icon = preload("res://assets/ui/icon_snack.png")
	revive_button.pressed.connect(_on_revive)
	revive_button.visible = false
	var revive_row := CenterContainer.new()
	revive_row.name = "ReviveRow"
	revive_row.add_child(revive_button)
	box.add_child(revive_row)
	revive_hint = UiKit.label(tr("UI_REVIVE_HINT"), &"LabelSoft")
	revive_hint.name = "ReviveHint"
	revive_hint.visible = false
	box.add_child(revive_hint)

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


## 這一章可以抽的提示編號。
static func tips_for_chapter(chapter: int) -> Array[int]:
	var out: Array[int] = []
	if TIPS_BY_CHAPTER.has(chapter):
		out.assign(TIPS_BY_CHAPTER[chapter])
	else:
		for i in range(1, TIP_COUNT + 1):
			out.append(i)
	return out


## 這次失敗可以抽的提示:故事模式看這一章;無盡試煉合併已開啟各章(1 至 已打完的章數)的提示。
static func tip_pool() -> Array[int]:
	if GameState.mode != &"endless":
		return tips_for_chapter(GameState.chapter)
	var out: Array[int] = []
	for n in range(1, clampi(GameState.chapters_cleared, 1, GameState.CHAPTER_COUNT) + 1):
		for k: int in tips_for_chapter(n):
			if not out.has(k):
				out.append(k)
	out.sort()
	return out


static func _pick_tip() -> int:
	var pool := tip_pool()
	var n := pool[randi_range(0, pool.size() - 1)]
	if n == _last_tip:
		n = pool[(pool.find(n) + 1) % pool.size()]
	_last_tip = n
	return n


## 顯示第 n 句提示(1 至 TIP_COUNT;測試也用這個)。
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
	var can_revive := bool(_result.get("can_revive", false))
	revive_button.visible = can_revive
	revive_hint.visible = can_revive
	_tip.visible = not can_revive        # 小螢幕放得下:可以復活時,復活提示代替梅林的小提示
	revive_button.text = tr("UI_REVIVE") % int(_result.get("revive_cost", 0))
	revive_button.disabled = false
	# 可以復活時,復活是主要按鈕(金色),再試一次改為次要(藍色)
	retry_button.theme_type_variation = &"ButtonAlt" if can_revive else &""
	_layout()


func _on_revive() -> void:
	if not revive_button.visible or revive_button.disabled:
		return
	revive_button.disabled = true      # 防止連按扣兩次零食
	UiKit.play_sfx(&"revive")
	revive_pressed.emit()


func _process(delta: float) -> void:
	_time += delta
	_layout()
	# 主要按鈕(可以復活時是「復活」,否則「再試一次」)輕輕跳動
	var main := revive_button if revive_button.visible else retry_button
	main.pivot_offset = main.size * 0.5
	if main.scale.y > 0.95 and main.scale.y < 1.08:
		var s := 1.0 + 0.04 * maxf(0.0, sin(_time * 4.0))
		main.scale = Vector2(s, s)


func _layout() -> void:
	if not is_inside_tree():
		return
	_panel.size = _panel.get_minimum_size()
	_panel.position = UiKit.center_in(SafeArea.get_safe_rect(), _panel.size)
	_stars.position = SafeArea.get_safe_rect().get_center()
