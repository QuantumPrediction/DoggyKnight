class_name MoonBeam
extends Node2D
## v2.6 摩根娜第三階段的旋轉月光束(程式畫的):從摩根娜身上射出的一道月光,
## 由 MorganaBoss 每格更新方向(direction)與長度(length)。只是畫面;打中的判定在 MorganaBoss
## (和畫出來的光束同寬)。放在特效層(在角色之上,最顯眼)。在群組 combat_fx。

const CORE := Color(1.0, 1.0, 0.95)
const GLOW := Color(0.7, 0.75, 1.0)
const EDGE := Color(0.75, 0.45, 1.0)

var direction: Vector2 = Vector2.RIGHT
var length: float = 200.0
var width: float = 10.0
var fade_in: float = 0.1

var _age: float = 0.0


func _ready() -> void:
	add_to_group(&"combat_fx")


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / maxf(fade_in, 0.001), 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_age * 40.0)
	var end := direction * length
	draw_line(Vector2.ZERO, end, Color(EDGE, 0.35 * k), width + 4.0)
	draw_line(Vector2.ZERO, end, Color(GLOW, 0.7 * k * flicker), width)
	draw_line(Vector2.ZERO, end, Color(CORE, 0.95 * k), maxf(2.0, width * 0.35))
	draw_circle(Vector2.ZERO, width * 0.8, Color(CORE, 0.8 * k))
	draw_circle(end, width * 0.6, Color(GLOW, 0.6 * k * flicker))
