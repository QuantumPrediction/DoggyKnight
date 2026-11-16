class_name MagicWisp
extends Node2D
## 一縷魔法火光(AS2):空盔甲兵倒下時,驅動盔甲的藍色小火光從盔甲裡飄出來、搖搖晃晃地飛走、
## 越飛越淡(呼應黑騎士:盔甲裡面是空的,是魔法在動)。程式畫的發光小圓點加一條拖尾。
## 在群組 combat_fx;慢動作時跟著變慢。用 MagicWisp.spawn() 產生(放在特效層,畫在角色之上)。

var color: Color = Color(0.45, 0.75, 1.0)
var lifetime: float = 1.3
var rise_speed: float = 34.0              ## 往上飛的速度(像素/秒)
var drift_speed: float = 14.0             ## 往旁邊飄的速度
var sway: float = 5.0                     ## 左右搖晃的幅度
var radius: float = 2.0

var _age: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _side: float = 1.0
var _trail: Array[Vector2] = []


static func spawn(host: Node, at: Vector2, tint: Color, side: float = 1.0) -> MagicWisp:
	if host == null or not host.is_inside_tree():
		return null
	var wisp := MagicWisp.new()
	wisp.color = tint
	wisp._side = signf(side) if side != 0.0 else 1.0
	CombatFx.layer_for(host).add_child(wisp)
	wisp.global_position = at
	wisp._start = at
	return wisp


func _ready() -> void:
	add_to_group(&"combat_fx")
	if _start == Vector2.ZERO:
		_start = global_position


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var t := _age
	# 先慢慢浮起,再加速往斜上方飛走,一邊左右搖晃。
	var up := rise_speed * t * (0.6 + 0.8 * t)
	var side := drift_speed * t * _side + sin(t * 9.0) * sway * minf(1.0, t * 2.0)
	_trail.push_front(global_position)
	if _trail.size() > 6:
		_trail.pop_back()
	global_position = _start + Vector2(side, -up)
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	var flicker := 0.8 + 0.2 * sin(_age * 40.0)
	for i in _trail.size():
		var p := _trail[i] - global_position
		var a := k * (1.0 - float(i + 1) / float(_trail.size() + 1)) * 0.6
		draw_circle(p, radius * (1.0 - float(i) * 0.12), Color(color, a))
	draw_circle(Vector2.ZERO, radius * 2.2, Color(color, 0.25 * k * flicker))
	draw_circle(Vector2.ZERO, radius * 1.3, Color(color, 0.7 * k))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(1, 1, 1, 0.9 * k))
