class_name MinigameUi
extends RefCounted
## 營地與小遊戲共用的小工具:套用 C 線的介面主題、畫不需要文字的圖示(手、星星、暫停)。
## 全部用簡單的像素方塊畫,C 線日後可以換成正式圖。

const THEME_PATH: String = "res://ui/theme/main_theme.tres"

const INK := Color("1b1b2a")
const WHITE := Color("fffaf0")
const SHADOW := Color(0, 0, 0, 0.35)
const STAR_ON := Color("ffd34d")
const STAR_OFF := Color("4a4560")
const STAR_EDGE := Color("8a5a1a")

## 沒有 C 線主題時使用的字型大小(邏輯像素)。
const FALLBACK_FONT_SIZE: int = 12
## C 線的像素字(Cubic 11)在 12 的整數倍最清楚:一般 12、大字 24、特大 36。
const FONT_S: int = 12
const FONT_L: int = 24
const FONT_XL: int = 36

const HEART := Color("ff6b8a")
const HEART_EDGE := Color("a8304a")


## 有 C 線的主題就套用並傳回 true;沒有就傳回 false(呼叫端自行設定字型大小)。
static func apply_shared_theme(control: Control) -> bool:
	if ResourceLoader.exists(THEME_PATH):
		var shared := load(THEME_PATH) as Theme
		if shared != null:
			control.theme = shared
			return true
	return false


static func has_shared_theme() -> bool:
	return ResourceLoader.exists(THEME_PATH)


## 一般的文字標籤。沒有共用主題時加上描邊,讓文字在任何背景上都看得清楚。
static func make_label(text: String, font_size: int, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", 2 if font_size <= FONT_S else 4)
	label.add_theme_font_size_override(&"font_size", crisp_size(font_size))
	return label


## 大標題(C 線主題的 LabelTitle:金色、粗描邊、影子)。
static func make_title(text: String) -> Label:
	var label := make_label(text, FONT_L, Color("ffe066"))
	if has_shared_theme():
		label.theme_type_variation = &"LabelTitle"
		label.remove_theme_color_override(&"font_color")
		label.remove_theme_color_override(&"font_outline_color")
		label.remove_theme_constant_override(&"outline_size")
	return label


## 把字型大小調到 12 的整數倍(像素字才不會糊)。
static func crisp_size(font_size: int) -> int:
	return maxi(FONT_S, roundi(font_size / float(FONT_S)) * FONT_S)


## 像素風按鈕。有共用主題時只設定最小尺寸,外觀交給主題。
static func make_button(text: String, min_size: Vector2, font_size: int, fill: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	if not has_shared_theme():
		button.add_theme_font_size_override(&"font_size", font_size)
		button.add_theme_color_override(&"font_color", WHITE)
		button.add_theme_color_override(&"font_pressed_color", WHITE)
		button.add_theme_color_override(&"font_hover_color", WHITE)
		button.add_theme_color_override(&"font_disabled_color", Color(1, 1, 1, 0.55))
		button.add_theme_color_override(&"font_outline_color", INK)
		button.add_theme_constant_override(&"outline_size", 2)
		button.add_theme_stylebox_override(&"normal", _box(fill, border))
		button.add_theme_stylebox_override(&"hover", _box(fill.lightened(0.08), border))
		button.add_theme_stylebox_override(&"pressed", _box(fill.darkened(0.2), border, 1))
		button.add_theme_stylebox_override(&"disabled", _box(fill.darkened(0.45), border.darkened(0.3)))
		button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	return button


static func _box(fill: Color, border: Color, shift: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_bottom = 3 - shift
	box.content_margin_top = 2 + shift
	box.content_margin_bottom = 2
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.anti_aliasing = false
	return box


## 一隻指著下方的手(手指尖在 tip)。pressed:按下時手指稍微壓扁。scale:整數倍放大。
static func draw_hand(ci: CanvasItem, tip: Vector2, pressed: bool, alpha: float = 1.0, scale: float = 2.0) -> void:
	var white := Color(WHITE, alpha)
	var edge := Color(INK, alpha)
	ci.draw_set_transform(tip.round(), 0.0, Vector2(scale, scale))
	var finger_h := 4.0 if pressed else 6.0
	# 食指
	ci.draw_rect(Rect2(Vector2(-2, -finger_h - 1), Vector2(4, finger_h + 2)), edge)
	ci.draw_rect(Rect2(Vector2(-1, -finger_h), Vector2(2, finger_h)), white)
	# 手掌與其他手指(握起來)
	var palm := Rect2(Vector2(-3, -finger_h - 7), Vector2(8, 7))
	ci.draw_rect(palm.grow(1), edge)
	ci.draw_rect(palm, white)
	for i in 2:
		ci.draw_rect(Rect2(palm.position + Vector2(3 + i * 2, 6), Vector2(1, 1)), edge)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if pressed:
		ci.draw_arc(tip.round() + Vector2(0, 1), 3.0 * scale, 0.0, TAU, 16, Color(WHITE, alpha * 0.8), 1.0)


## 向下的箭頭(提示滑動方向)。
static func draw_down_chevron(ci: CanvasItem, center: Vector2, half_width: float, color: Color) -> void:
	var c := center.round()
	for i in int(half_width):
		ci.draw_rect(Rect2(c + Vector2(-half_width + i, i - half_width * 0.5), Vector2(2, 2)), color)
		ci.draw_rect(Rect2(c + Vector2(half_width - i - 2, i - half_width * 0.5), Vector2(2, 2)), color)


## 五角星。
static func draw_star(ci: CanvasItem, center: Vector2, radius: float, filled: bool) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	var outline := PackedVector2Array()
	for i in 10:
		var r := (radius + 1.5) if i % 2 == 0 else (radius + 1.5) * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		outline.append(center + Vector2(cos(angle), sin(angle)) * r)
	ci.draw_colored_polygon(outline, STAR_EDGE if filled else INK)
	ci.draw_colored_polygon(points, STAR_ON if filled else STAR_OFF)


## 像素愛心(7×6 格,scale 整數倍)。
static func draw_heart(ci: CanvasItem, center: Vector2, scale: float = 1.0, alpha: float = 1.0, color: Color = HEART) -> void:
	const ROWS: Array[String] = [".xx.xx.", "xooxoox", "xooooox", ".xooox.", "..xox..", "...x..."]
	var fill := Color(color, alpha)
	var edge := Color(HEART_EDGE, alpha)
	var shine := Color(1, 1, 1, alpha * 0.85)
	var origin := (center - Vector2(3.5, 3.0) * scale).round()
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var c := edge if ch == "x" else fill
			if y == 1 and x == 1:
				c = shine
			ci.draw_rect(Rect2(origin + Vector2(x, y) * scale, Vector2(scale, scale)), c)


## 暫停圖示(兩條直線)。
static func draw_pause_icon(ci: CanvasItem, center: Vector2, color: Color) -> void:
	var c := center.round()
	ci.draw_rect(Rect2(c + Vector2(-8, -10), Vector2(6, 20)), color)
	ci.draw_rect(Rect2(c + Vector2(2, -10), Vector2(6, 20)), color)


## 「停!」的手掌(張開的手)。
static func draw_stop_palm(ci: CanvasItem, center: Vector2, color: Color) -> void:
	var c := center.round()
	ci.draw_circle(c, 11.0, Color(INK, color.a))
	ci.draw_circle(c, 10.0, color)
	var white := Color(WHITE, color.a)
	ci.draw_rect(Rect2(c + Vector2(-4, -2), Vector2(8, 7)), white)
	for i in 4:
		ci.draw_rect(Rect2(c + Vector2(-4 + i * 2, -7 + absi(i - 1) % 2), Vector2(1, 6)), white)
	ci.draw_rect(Rect2(c + Vector2(4, 0), Vector2(2, 3)), white)
