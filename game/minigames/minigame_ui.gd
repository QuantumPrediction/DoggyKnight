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
const FALLBACK_FONT_SIZE: int = 10


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
	label.add_theme_constant_override(&"outline_size", 2)
	if not has_shared_theme():
		label.add_theme_font_size_override(&"font_size", font_size)
	return label


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


## 一隻指著下方的手(手指尖在 tip)。pressed:按下時手指稍微壓扁。
static func draw_hand(ci: CanvasItem, tip: Vector2, pressed: bool, alpha: float = 1.0) -> void:
	var white := Color(WHITE, alpha)
	var edge := Color(INK, alpha)
	var p := tip.round()
	var finger_h := 5.0 if pressed else 7.0
	# 食指
	ci.draw_rect(Rect2(p + Vector2(-2, -finger_h - 1), Vector2(5, finger_h + 2)), edge)
	ci.draw_rect(Rect2(p + Vector2(-1, -finger_h), Vector2(3, finger_h)), white)
	# 手掌
	var palm := Rect2(p + Vector2(-4, -finger_h - 9), Vector2(10, 10))
	ci.draw_rect(palm.grow(1), edge)
	ci.draw_rect(palm, white)
	# 其他指節
	for i in 3:
		ci.draw_rect(Rect2(palm.position + Vector2(2 + i * 3, 9), Vector2(1, 1)), edge)
	if pressed:
		ci.draw_arc(p + Vector2(0.5, 1), 4.0, 0.0, TAU, 12, Color(WHITE, alpha * 0.8), 1.0)


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
