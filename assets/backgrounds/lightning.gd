extends Node2D
## 暴風雨夜的閃電(C 線,CP2)。掛在背景場景裡:畫在背景圖層(z -100)內,永遠在角色與預警之下。
## 每隔一段時間,整個背景閃一下淡淡的白光(兩下短閃 + 淡出),不會蓋住任何戰鬥資訊。

@export var min_gap: float = 6.0
@export var max_gap: float = 12.0
@export var strength: float = 0.28
@export var area: Rect2 = Rect2(-62, -88, 304, 512)

var _rng := RandomNumberGenerator.new()
var _wait: float = 3.0
var _t: float = -1.0


func _ready() -> void:
	_rng.seed = 6
	_wait = _rng.randf_range(2.0, 4.0)


func _process(delta: float) -> void:
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
		return
	_t += delta
	queue_redraw()
	if _t > 0.7:
		_t = -1.0
		_wait = _rng.randf_range(min_gap, max_gap)
		queue_redraw()


func flash_alpha() -> float:
	if _t < 0.0:
		return 0.0
	if _t < 0.06:
		return strength
	if _t < 0.12:
		return 0.0
	if _t < 0.2:
		return strength * 0.75
	return strength * 0.75 * maxf(0.0, 1.0 - (_t - 0.2) / 0.5)


func _draw() -> void:
	var a := flash_alpha()
	if a > 0.0:
		draw_rect(area, Color(0.86, 0.9, 1.0, a))
