class_name BreathCone
extends Node2D
## v2.7 紅龍的火焰吐息、白龍的冰霜吐息(程式畫的):從嘴巴噴出的扇形,一團團往外推、閃爍。
## 只是畫面;打中的判定在 DragonBoss(和扇形預警同一個範圍)。放在特效層,lifetime 秒後淡出。
## 在群組 combat_fx;慢動作時跟著變慢。

const FIRE_COLORS: Array[Color] = [Color("ff6a2a"), Color("ffb03a"), Color("fff0a0")]
const ICE_COLORS: Array[Color] = [Color("8fd8ff"), Color("d8f4ff"), Color("ffffff")]

var direction: Vector2 = Vector2.RIGHT
var radius: float = 70.0
var half_angle: float = 0.5
var lifetime: float = 0.5
var ice: bool = false

var _age: float = 0.0


static func blow(host: Node, at: Vector2, dir: Vector2, p_radius: float, p_half_angle: float,
		p_lifetime: float, p_ice: bool) -> BreathCone:
	if host == null or not host.is_inside_tree():
		return null
	var cone := BreathCone.new()
	cone.direction = dir.normalized()
	cone.radius = p_radius
	cone.half_angle = p_half_angle
	cone.lifetime = p_lifetime
	cone.ice = p_ice
	CombatFx.layer_for(host).add_child(cone)
	cone.global_position = at
	return cone


func _ready() -> void:
	add_to_group(&"combat_fx")


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= lifetime + 0.2:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var colors := ICE_COLORS if ice else FIRE_COLORS
	var fade := 1.0 - clampf((_age - lifetime) / 0.2, 0.0, 1.0)
	var grow := clampf(_age / 0.12, 0.0, 1.0)
	var base := direction.angle()
	var points := PackedVector2Array([Vector2.ZERO])
	for i in 11:
		var a := base - half_angle + 2.0 * half_angle * float(i) / 10.0
		points.append(Vector2.from_angle(a) * radius * grow)
	draw_colored_polygon(points, Color(colors[0], 0.28 * fade))
	# 一團團往外推的火焰(冰霧)。
	for k in 14:
		var t := fmod(_age * 2.2 + float(k) * 0.137, 1.0)
		var a := base + sin(float(k) * 2.7 + _age * 6.0) * half_angle * 0.85
		var at := Vector2.from_angle(a) * radius * grow * t
		var r := 2.0 + 5.0 * t
		draw_circle(at, r, Color(colors[k % colors.size()], (0.85 - 0.6 * t) * fade))
