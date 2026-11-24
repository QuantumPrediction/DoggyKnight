extends Control
## 製作名單與授權(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 訊號 closed(按「關閉」)。內容會自動慢慢往上捲(CP5);玩家一碰就停,放手 3 秒後再繼續。
## 內容可上下拖曳捲動:
## 1. 製作名單;2. 授權條目(照抄 docs/licenses.md,見 LICENSE_ENTRIES);
## 3. 俐方體11號的 SIL OFL 授權全文;4. Godot 引擎本身與內含第三方元件的授權聲明
##    (Engine.get_license_text()、get_copyright_info()、get_license_info())。

signal closed

const OFL := preload("res://ui/screens/ofl_text.gd")

## docs/licenses.md 的條目(更新該文件時一併更新這裡;tests/line_c 會核對名稱)。
const LICENSE_ENTRIES: Array[Dictionary] = [
	{
		"name": "Godot Engine 4.7.2",
		"use": "整個遊戲",
		"source": "https://godotengine.org",
		"license": "MIT License",
	},
	{
		"name": "俐方體11號 Cubic 11 (1.500)",
		"use": "保留的像素介面與後備字型",
		"source": "https://github.com/ACh-K/Cubic-11",
		"license": "SIL Open Font License 1.1。Copyright (c) ACh-K;衍生自 M+ BITMAP FONTS, Copyright (C) 2002-2004 COZ,及 JF Dot M+H 12, Copyright (c) 2005 M+ FONTS PROJECT",
	},
	{
		"name": "像素圖、介面圖、App 圖示",
		"use": "角色、特效、場地、介面",
		"source": "本專案原創(tools/pixel 程式生成)",
		"license": "本專案原創",
	},
	{
		"name": "音效",
		"use": "全部音效",
		"source": "本專案原創(tools/pixel 程式合成)",
		"license": "本專案原創",
	},
	{
		"name": "背景音樂",
		"use": "標題、關卡、頭目戰、營地、過關、失敗、第一章完",
		"source": "本專案原創(tools/pixel/music_gen.py 程式作曲與合成)",
		"license": "本專案原創",
	},
]

var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer

## 自動捲動速度(每秒幾個像素)與玩家碰過之後的等待秒數。
const AUTO_SCROLL_SPEED: float = 14.0
const AUTO_SCROLL_RESUME: float = 3.0

var _bg: ColorRect
var _panel: PanelContainer
var _built_width: float = -1.0
var _scroll_pos: float = 0.0
var _hold: float = 1.2


func _ready() -> void:
	UiKit.setup_root(self)
	_bg = UiKit.dim(PaletteColors.PLUM)
	add_child(_bg)
	_panel = PanelContainer.new()
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 4)
	_panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UiKit.label(tr("UI_CREDITS"), &"", HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = UiKit.button(tr("UI_CLOSE"), &"ButtonAlt", Vector2(52, 26))
	close_button.name = "CloseButton"
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 4
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override(&"separation", 2)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_layout()
	_auto_scroll(delta)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		_hold = AUTO_SCROLL_RESUME


func _auto_scroll(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
		_scroll_pos = float(scroll.scroll_vertical)
		return
	var bar := scroll.get_v_scroll_bar()
	var max_pos := maxf(0.0, bar.max_value - bar.page)
	if _scroll_pos >= max_pos:
		return
	_scroll_pos = minf(max_pos, _scroll_pos + AUTO_SCROLL_SPEED * delta)
	scroll.scroll_vertical = int(_scroll_pos)


## 自動捲動目前的位置(測試用)。
func auto_scroll_position() -> float:
	return _scroll_pos


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	var rect := safe.grow(-4.0)
	_panel.position = rect.position.floor()
	_panel.size = rect.size.floor()
	var text_width := floorf(rect.size.x - 16.0 - 8.0)
	if not is_equal_approx(text_width, _built_width):
		_built_width = text_width
		_fill(text_width)


## 全部文字(測試用:檢查授權內容有放進來)。
func get_all_text() -> String:
	var parts: PackedStringArray = []
	for child in content.get_children():
		if child is Label:
			parts.append((child as Label).text)
	return "\n".join(parts)


func _fill(width: float) -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var logo := UiKit.texture_rect(preload("res://assets/ui/logo_2x.png"))
	logo.accessibility_name = tr("GAME_TITLE")
	var logo_row := CenterContainer.new()
	logo_row.add_child(logo)
	content.add_child(logo_row)
	_heading(tr("UI_CREDITS_TEAM"), width)
	for key in ["UI_CREDITS_GAME", "UI_CREDITS_ART", "UI_CREDITS_ENGINE", "UI_CREDITS_FONT"]:
		_text(tr(key), width)
	_text(tr("UI_CREDITS_THANKS"), width, &"LabelSoft")

	_heading(tr("UI_LICENSES"), width)
	for e: Dictionary in LICENSE_ENTRIES:
		_text(String(e["name"]), width)
		_text("%s\n%s\n%s" % [e["use"], e["source"], e["license"]], width, &"LabelSoft")

	_heading("Cubic 11 — SIL OFL 1.1", width)
	for para in OFL.TEXT.split("\n\n"):
		_text(para, width, &"LabelSoft")

	_heading("StorySans / StorySerif — Noto CJK", width)
	_text("Noto Sans CJK TC 與 Noto Serif CJK TC 子集；SIL Open Font License 1.1。", width)
	for para in preload("res://ui/screens/noto_license.gd").TEXT.split("\n\n"):
		_text(para, width, &"LabelSoft")
	_heading("繪本美術", width)
	_text("OpenAI image generation 輔助製作；提示、來源與整合紀錄見專案 docs/ART_REDESIGN.md。", width)
	_heading(tr("UI_THIRD_PARTY"), width)
	_text("Godot Engine", width)
	for para in Engine.get_license_text().split("\n\n"):
		_text(para, width, &"LabelSoft")
	for info: Dictionary in Engine.get_copyright_info():
		_text(String(info.get("name", "")), width)
		for part: Dictionary in info.get("parts", []):
			var lines: PackedStringArray = []
			for c: String in part.get("copyright", []):
				lines.append("© " + c)
			lines.append("License: " + String(part.get("license", "")))
			_text("\n".join(lines), width, &"LabelSoft")
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		_text(license_name, width)
		for para in String(licenses[license_name]).split("\n\n"):
			_text(para, width, &"LabelSoft")


func _heading(text: String, width: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	content.add_child(spacer)
	var ribbon := PanelContainer.new()
	ribbon.theme_type_variation = &"Ribbon"
	var l := UiKit.label(text, &"LabelLight")
	if l.get_minimum_size().x > width - 24.0:
		l = UiKit.wrapped_label(text, width - 24.0, &"LabelLight", HORIZONTAL_ALIGNMENT_CENTER)
	ribbon.add_child(l)
	var row := CenterContainer.new()
	row.add_child(ribbon)
	content.add_child(row)


func _text(text: String, width: float, variation: StringName = &"") -> void:
	var t := text.strip_edges()
	if t.is_empty():
		return
	var l := UiKit.wrapped_label(t, width, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
