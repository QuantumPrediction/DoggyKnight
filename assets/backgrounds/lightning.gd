extends Node2D
## 暴風雨夜的閃電(C 線,CP2)。掛在背景場景裡:畫在背景圖層(z -100)內,永遠在角色與預警之下。
## 每隔一段時間,整個背景閃一下淡淡的白光(兩下短閃 + 淡出),不會蓋住任何戰鬥資訊。
## v2.3(CS5):閃光時城堡上空出現一道鋸齒狀的閃電,帶一圈加亮的光暈(畫在背景圖層,不在戰鬥區)。

@export var min_gap: float = 6.0
@export var max_gap: float = 12.0
@export var strength: float = 0.28
@export var area: Rect2 = Rect2(-62, -88, 304, 512)
## 閃電出現的天空範圍(世界座標;城堡上方,戰鬥區以外)。
@export var bolt_area: Rect2 = Rect2(-50, -88, 280, 70)

var _bolt: PackedVector2Array = PackedVector2Array()

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
			_make_bolt()
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


func _make_bolt() -> void:
	_bolt = PackedVector2Array()
	var x := _rng.randf_range(bolt_area.position.x, bolt_area.end.x)
	var y := bolt_area.position.y
	_bolt.append(Vector2(x, y).floor())
	while y < bolt_area.end.y:
		y += _rng.randf_range(6.0, 12.0)
		x += _rng.randf_range(-9.0, 9.0)
		_bolt.append(Vector2(x, minf(y, bolt_area.end.y)).floor())


func _draw() -> void:
	var a := flash_alpha()
	if a > 0.0:
		draw_rect(area, Color(0.86, 0.9, 1.0, a))
	if _t >= 0.0 and _t < 0.3 and _bolt.size() > 1:
		var k := 1.0 - _t / 0.3
		var tip := _bolt[_bolt.size() - 1]
		for r: float in [26.0, 16.0, 9.0]:
			draw_circle(tip, r, Color(0.75, 0.7, 1.0, 0.08 * k))
		draw_polyline(_bolt, Color(0.72, 0.63, 0.85, 0.6 * k), 3.0)
		draw_polyline(_bolt, Color(1.0, 0.98, 0.94, k), 1.0)
