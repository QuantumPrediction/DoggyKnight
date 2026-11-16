class_name SpeechBubble
extends Node2D
## 頭上的小對話泡泡(AP8:鬥牛犬舉盾時冒「汪!」)。用全域主題的像素字(C 線的字型,
## 經 ThemeDB 取得,不直接依賴檔案路徑),白底、深色框、下面有小尾巴。
## 出現時彈一下,lifetime 秒後淡出並自己刪除。掛在說話的角色身上,跟著角色走。

const GROUP: StringName = &"combat_fx"
const FILL := Color(1.0, 0.98, 0.92)
const BORDER := Color(0.18, 0.12, 0.14)
const TEXT := Color(0.35, 0.16, 0.12)

var text: String = ""
var lifetime: float = 0.9
var font_size: int = 12

var _age: float = 0.0
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	z_as_relative = false
	z_index = 9
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		_font = theme.default_font
		if theme.default_font_size > 0:
			font_size = theme.default_font_size
	else:
		_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _font == null or text.is_empty():
		return
	var alpha := clampf((lifetime - _age) / 0.2, 0.0, 1.0)
	var rise := -roundf(minf(_age / 0.12, 1.0) * 2.0)
	var pop := 1.0 if _age < 0.06 else 0.0
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var w := ceilf(text_size.x) + 6.0 + pop * 2.0
	var h := float(font_size) + 2.0 + pop * 2.0
	var box := Rect2(Vector2(-roundf(w * 0.5), rise - h - 3.0), Vector2(w, h))
	# 框:四角留空,看起來圓圓的。
	var border := Color(BORDER, alpha)
	draw_rect(Rect2(box.position.x, box.position.y - 1.0, box.size.x, 1.0), border)
	draw_rect(Rect2(box.position.x, box.end.y, box.size.x, 1.0), border)
	draw_rect(Rect2(box.position.x - 1.0, box.position.y, 1.0, box.size.y), border)
	draw_rect(Rect2(box.end.x, box.position.y, 1.0, box.size.y), border)
	draw_rect(box, Color(FILL, alpha))
	# 尾巴(指向說話的角色)。
	var fill := Color(FILL, alpha)
	var y := box.end.y
	draw_rect(Rect2(-1, y, 3, 1), fill)
	draw_rect(Rect2(-1, y + 1, 1, 1), border)
	draw_rect(Rect2(0, y + 1, 1, 1), fill)
	draw_rect(Rect2(1, y + 1, 1, 1), border)
	draw_rect(Rect2(0, y + 2, 1, 1), border)
	var baseline := Vector2(box.position.x + 3.0 + pop, box.position.y + _font.get_ascent(font_size) + 1.0 + pop)
	draw_string(_font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(TEXT, alpha))
