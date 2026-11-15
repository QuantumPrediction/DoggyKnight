class_name RingFx
extends Node2D
## 程式畫的擴散圓環:重劈震波、吠叫聲波、迴旋斬、必殺技光環、敵人倒下的「噗」。

const GROUP: StringName = &"combat_fx"

var from_radius: float = 2.0
var to_radius: float = 24.0
var duration: float = 0.25
var color: Color = Color(1, 1, 1, 0.9)
var width: float = 2.0
var filled: bool = false                 ## true:畫實心的圓(用於閃光)

var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / maxf(duration, 0.001), 0.0, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var r := lerpf(from_radius, to_radius, eased)
	var c := color
	c.a *= 1.0 - t
	if filled:
		draw_circle(Vector2.ZERO, r, c)
	else:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, maxi(12, int(r * 1.5)), c, width)
