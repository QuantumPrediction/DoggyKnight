class_name InkPuddle
extends Node2D
## v2.7 章魚王的墨汁落地後留下的一小片暗區(程式畫的):淡入、停留 lifetime 秒、淡出後自己刪除。
## 只是畫面(不傷人、不擋路),放在地面層(在預警圈與角色之下,不會蓋住危險訊號)。在群組 combat_fx。

const INK := Color(0.12, 0.08, 0.2)
const SHINE := Color(0.45, 0.4, 0.7)

var radius: float = 14.0
var lifetime: float = 4.0
var fade_time: float = 0.5

var _age: float = 0.0
var _blobs: Array[Vector3] = []          ## x、y = 偏移;z = 半徑


static func spill(host: Node, at: Vector2, p_radius: float, p_lifetime: float) -> InkPuddle:
	if host == null or not host.is_inside_tree():
		return null
	var puddle := InkPuddle.new()
	puddle.radius = p_radius
	puddle.lifetime = p_lifetime
	CombatFx.layer_for(host, true).add_child(puddle)
	puddle.global_position = at
	return puddle


func _ready() -> void:
	add_to_group(&"combat_fx")
	z_index = -2
	_blobs.append(Vector3(0, 0, radius * 0.75))
	for i in 5:
		var dir := Vector2.from_angle(TAU * float(i) / 5.0 + randf_range(-0.3, 0.3))
		var r := radius * randf_range(0.3, 0.45)
		var at := dir * (radius - r) * randf_range(0.7, 1.0)
		_blobs.append(Vector3(at.x, at.y, r))


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func is_fading() -> bool:
	return _age >= lifetime - fade_time


func _draw() -> void:
	var a := minf(clampf(_age / 0.15, 0.0, 1.0), clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	for b in _blobs:
		draw_circle(Vector2(b.x, b.y), b.z, Color(INK, 0.72 * a))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.25), radius * 0.16, Color(SHINE, 0.5 * a))
	draw_set_transform(Vector2.ZERO)
