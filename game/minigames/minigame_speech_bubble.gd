class_name MinigameSpeechBubble
extends Control
## 像素風的對話泡泡(DEV_PLAN 16 DS2、DS3):白底、墨色框、小尾巴指向說話的人。
## 營地裡的梅林與小遊戲結束時的梅林共用。全部用程式畫,不需要圖檔。
##
## 用法:把它加到一個全螢幕的 Control 之下(座標 = 畫面邏輯像素),然後
##   bubble.show_text(tr("CAMP_MERLIN_01"), 嘴巴上方的點, 秒數)
## - 泡泡出現在 anchor 的上方,尾巴指向 anchor;左右超出安全區時整個泡泡移進來(尾巴仍指向 anchor)。
## - 文字太長時自動換行,每行字數平均(不會一行很長、一行只有一個字),標點不會放在行首。
## - 出現時彈出來;duration > 0 時時間到就淡出收起;duration <= 0 時一直顯示,直到 hide_bubble()。

## 泡泡最寬多少(邏輯像素,含框)。
@export var max_width: float = 150.0
@export var font_size: int = MinigameUi.FONT_S
@export var fill_color: Color = MinigameUi.WHITE
@export var text_color: Color = MinigameUi.INK
## 泡泡上緣最高到哪裡(畫面邏輯像素);負數 = 安全區的上緣。
@export var min_top: float = -1.0

const PADDING := Vector2(5, 3)
const TAIL: float = 5.0
const POP_SEC: float = 0.14
const FADE_SEC: float = 0.2

var text: String = ""
var anchor: Vector2 = Vector2.ZERO
## 還剩多少秒收起(<= 0 而且 _forever 為 false 時已收起)。
var time_left: float = 0.0
var age: float = 0.0

var _showing: bool = false
var _forever: bool = false
var _box: Rect2 = Rect2()
var _lines: PackedStringArray = []


func _init() -> void:
	name = "SpeechBubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(delta: float) -> void:
	advance(delta)


## 顯示一句話。duration <= 0:一直顯示。
func show_text(p_text: String, p_anchor: Vector2, duration: float = 0.0) -> void:
	text = p_text
	anchor = p_anchor.round()
	age = 0.0
	_forever = duration <= 0.0
	time_left = duration
	_showing = true
	visible = true
	_layout_box()
	queue_redraw()


## 說話的人移動了(例如畫面大小改變):只移動泡泡,不重新彈出。
func move_to(p_anchor: Vector2) -> void:
	anchor = p_anchor.round()
	if _showing:
		_layout_box()
		queue_redraw()


## 立刻收起。
func hide_bubble() -> void:
	_showing = false
	visible = false
	time_left = 0.0


func is_showing() -> bool:
	return _showing


## 泡泡的框(畫面邏輯像素,不含尾巴)。測試與排版用。
func get_box() -> Rect2:
	return _box


## 推進時間(_process 每格呼叫;測試可以直接呼叫)。
func advance(delta: float) -> void:
	if not _showing:
		return
	age += delta
	if not _forever:
		time_left -= delta
		if time_left <= 0.0:
			hide_bubble()
			return
	queue_redraw()


func _font() -> Font:
	var font := get_theme_font(&"font", &"Label")
	return font if font != null else ThemeDB.fallback_font


## 不可以放在行首的標點(避頭):放不下時跟著上一行。刪節號「……」可以在行首,但兩個點不會被拆開。
const NO_LINE_START: String = "，。、！？：；）」』》〉,.!?:;)"
## 行與行之間多留的像素。
const LINE_SPACING: float = 1.0


## 手動換行(平均每行字數 + 避頭),結果在 _lines。
func _layout_box() -> void:
	var font := _font()
	var inner_max := maxf(24.0, max_width - PADDING.x * 2.0)
	var full := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var target := inner_max
	if full > inner_max:
		# 平均分行:先算要幾行,再用平均寬度換行(多留半個字,避免最後一行只剩一兩個字)。
		var count := ceili(full / inner_max)
		target = minf(inner_max, ceilf(full / count) + font_size * 0.5)
	_lines = _break_lines(font, target, inner_max)
	var width := 0.0
	for line in _lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_height := _line_height(font)
	var text_size := Vector2(ceilf(width), line_height * _lines.size() - LINE_SPACING)
	var size_px := (text_size + PADDING * 2.0).ceil()
	var safe := SafeArea.get_safe_rect()
	var top_limit := safe.position.y + 2.0 if min_top < 0.0 else min_top
	var x := clampf(anchor.x - roundf(size_px.x * 0.5), safe.position.x + 2.0, safe.end.x - 2.0 - size_px.x)
	var y := maxf(anchor.y - TAIL - size_px.y, top_limit)
	_box = Rect2(Vector2(x, y).round(), size_px)


## 換好的行(測試用)。
func get_lines() -> PackedStringArray:
	return _lines


func _line_height(font: Font) -> float:
	return ceilf(font.get_height(font_size)) + LINE_SPACING


func _break_lines(font: Font, target: float, hard_max: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var current := ""
	var current_w := 0.0
	for i in text.length():
		var ch := text[i]
		if ch == "\n":
			lines.append(current)
			current = ""
			current_w = 0.0
			continue
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if current != "" and current_w + w > target:
			if NO_LINE_START.contains(ch) and current_w + w <= hard_max:
				pass        # 標點跟著上一行(稍微超出平均寬度沒關係)
			elif (NO_LINE_START.contains(ch) or (ch == "…" and current.ends_with("…"))) and current.length() > 1:
				# 放不下:把上一行最後一個字帶到下一行,標點就不會在行首(「……」也不會被拆開)
				var carry := current[current.length() - 1]
				lines.append(current.substr(0, current.length() - 1))
				current = carry
				current_w = font.get_string_size(carry, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			else:
				lines.append(current)
				current = ""
				current_w = 0.0
		current += ch
		current_w += w
	if current != "" or lines.is_empty():
		lines.append(current)
	return lines


func _draw() -> void:
	if not _showing:
		return
	var pop := clampf(age / POP_SEC, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - pop, 3.0)
	var alpha := 1.0
	if not _forever:
		alpha = clampf(time_left / FADE_SEC, 0.0, 1.0)
	# 從尾巴的尖端彈出來
	var pivot := anchor
	var s := 0.55 + 0.45 * grow + 0.08 * sin(pop * PI)
	draw_set_transform(pivot - pivot * s, 0.0, Vector2(s, s))
	var ink := Color(MinigameUi.INK, alpha)
	var fill := Color(fill_color, alpha)
	var box := _box
	draw_rect(Rect2(box.position + Vector2(1, 2), box.size), Color(0, 0, 0, 0.3 * alpha))
	draw_rect(box.grow(1.0), ink)
	draw_rect(box, fill)
	# 尾巴:從框的下緣指向 anchor(框被推開時尾巴盡量貼近 anchor)
	var tail_x := clampf(anchor.x, box.position.x + 4.0, box.end.x - 5.0)
	var base_y := box.end.y
	if anchor.y > base_y + 1.0:
		var tip := Vector2(clampf(anchor.x, tail_x - 4.0, tail_x + 4.0), minf(anchor.y, base_y + TAIL))
		draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 3.0, base_y), Vector2(tail_x + 4.0, base_y), tip + Vector2(0.5, 1.0)]), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 2.0, base_y - 1.0), Vector2(tail_x + 3.0, base_y - 1.0), tip + Vector2(0.5, -0.5)]), fill)
	# 文字(每行置中)。彈出途中不畫字:縮放中的像素字會糊掉。
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if pop < 1.0:
		return
	var font := _font()
	var line_height := _line_height(font)
	var inner_w := box.size.x - PADDING.x * 2.0
	for i in _lines.size():
		var baseline := box.position + PADDING + Vector2(0, font.get_ascent(font_size) + i * line_height)
		draw_string(font, baseline.round(), _lines[i], HORIZONTAL_ALIGNMENT_CENTER, inner_w, font_size, Color(text_color, alpha))
