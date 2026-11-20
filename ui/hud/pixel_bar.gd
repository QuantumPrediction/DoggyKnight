class_name PixelBar
extends Control
## HUD 用的像素數值條(C8):深色外框、底色、填色與一列亮邊。
## 數值變少時留下一段白色「殘影」慢慢縮短,讓玩家看得出剛才少了多少。

@export var fill_color: Color = PaletteColors.RED
@export var fill_light: Color = PaletteColors.PINK
## 填色底下那一列的陰影色(高度 4 像素以上才畫)。
@export var fill_dark: Color = PaletteColors.RED_D
@export var empty_color: Color = Color("132b2b")
@export var trail_color: Color = PaletteColors.WHITE
## 填滿時閃爍(忠誠度條用)。
@export var flash_when_full: bool = false
## 刻度:把條分成幾格(0 = 不畫刻度)。
@export var segments: int = 0
## 低於這個比例時填色閃爍(活力條的心跳;0 = 不閃)。
@export var low_ratio: float = 0.0
## 數值增加時,新增的那一段先亮一下(回復活力時)。
@export var gain_color: Color = PaletteColors.WHITE

const FILL_SPEED: float = 4.0     # 每秒追上的比例
const TRAIL_DELAY: float = 0.35
const TRAIL_SPEED: float = 1.2

var value: float = 1.0
var max_value: float = 1.0

var _shown: float = 1.0
var _trail: float = 1.0
var _trail_wait: float = 0.0
var _time: float = 0.0
var _gain_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 0.0001)
	value = clampf(current, 0.0, max_value)
	var r := ratio()
	if r < _shown:
		_trail = maxf(_trail, _shown)
		_trail_wait = TRAIL_DELAY
	elif r > _shown + 0.001:
		_gain_flash = 0.25
	queue_redraw()


## 目前畫面上顯示的比例(動畫中會慢慢追上 ratio())。測試用。
func shown_ratio() -> float:
	return _shown


## 受擊殘影(白色那一段)目前的比例。測試用。
func trail_ratio() -> float:
	return _trail


func is_low() -> bool:
	return low_ratio > 0.0 and ratio() <= low_ratio and value > 0.0


## 立刻顯示目前數值(不播動畫),例如剛進場時。
func snap_to_value() -> void:
	_shown = ratio()
	_trail = _shown
	queue_redraw()


func ratio() -> float:
	return value / max_value


func is_full() -> bool:
	return value >= max_value


func _process(delta: float) -> void:
	_time += delta
	var target := ratio()
	var changed := false
	if not is_equal_approx(_shown, target):
		_shown = move_toward(_shown, target, maxf(FILL_SPEED * delta * absf(target - _shown), delta * 0.5))
		changed = true
	if _trail_wait > 0.0:
		_trail_wait -= delta
	elif _trail > _shown:
		_trail = move_toward(_trail, _shown, TRAIL_SPEED * delta)
		changed = true
	if flash_when_full and is_full():
		changed = true
	if is_low():
		changed = true
	if _gain_flash > 0.0:
		_gain_flash -= delta
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	if w < 3 or h < 3:
		return
	# frame with clipped corners
	draw_rect(Rect2(1, 0, w - 2, h), PaletteColors.INK)
	draw_rect(Rect2(0, 1, w, h - 2), PaletteColors.INK)
	var inner := Rect2(1, 1, w - 2, h - 2)
	draw_rect(inner, empty_color)
	var trail_w := floorf(inner.size.x * _trail)
	if trail_w > 0.0 and _trail > _shown:
		draw_rect(Rect2(inner.position, Vector2(trail_w, inner.size.y)), trail_color)
	var fill_w := floorf(inner.size.x * _shown)
	if fill_w > 0.0:
		var col := fill_color
		var light := fill_light
		if flash_when_full and is_full() and fmod(_time, 0.5) < 0.25:
			col = PaletteColors.YELLOW
			light = PaletteColors.WHITE
		if is_low() and fmod(_time, 0.62) < 0.18:
			col = light
			light = PaletteColors.WHITE
		if _gain_flash > 0.0 and fmod(_gain_flash, 0.1) > 0.05:
			col = gain_color
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), col)
		draw_rect(Rect2(inner.position, Vector2(fill_w, 1)), light)
		if inner.size.y >= 4:
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fill_w, 1)), fill_dark)
		# v2.5 (CR3):亮面的小反光(左上兩格)與填色前端的一條亮邊,像一管有光澤的液體
		if fill_w >= 4.0:
			draw_rect(Rect2(inner.position + Vector2(1, 0), Vector2(2, 1)), PaletteColors.WHITE)
		if fill_w >= 2.0 and fill_w < inner.size.x:
			draw_rect(Rect2(inner.position.x + fill_w - 1, inner.position.y, 1, inner.size.y - 1), light)
	# v2.5 (CR3):空槽上緣一列內陰影,看起來是凹進去的槽
	if fill_w < inner.size.x:
		draw_rect(Rect2(inner.position.x + fill_w, inner.position.y, inner.size.x - fill_w, 1), Color(PaletteColors.INK, 0.5))
	if segments > 1:
		for i in range(1, segments):
			var x := floorf(inner.position.x + inner.size.x * i / segments)
			draw_rect(Rect2(x, inner.position.y + 1, 1, inner.size.y - 1), Color(PaletteColors.INK, 0.45))
