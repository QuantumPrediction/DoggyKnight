class_name VineLash
extends Node2D
## v2.6 綠騎士的藤鞭(程式畫的):沿著預警線很快地甩出去(extend_time 秒)、停一下,再縮回淡出。
## 只是畫面;打中的判定在 GreenKnightBoss._lash()(和預警線同一個範圍)。在群組 combat_fx。

const VINE := Color("3f7a32")
const VINE_LIGHT := Color("8fcf5a")
const LEAF := Color("5fa83a")

var direction: Vector2 = Vector2.RIGHT
var length: float = 100.0
var width: float = 10.0
var extend_time: float = 0.1
var hold_time: float = 0.12
var fade_time: float = 0.25

var _age: float = 0.0


static func lash(host: Node, from: Vector2, dir: Vector2, p_length: float, p_width: float) -> VineLash:
	if host == null or not host.is_inside_tree():
		return null
	var vine := VineLash.new()
	vine.direction = dir.normalized()
	vine.length = p_length
	vine.width = p_width
	CombatFx.layer_for(host).add_child(vine)
	vine.global_position = from
	return vine


func _ready() -> void:
	add_to_group(&"combat_fx")
	z_index = 1


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= extend_time + hold_time + fade_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var reach := length * clampf(_age / maxf(extend_time, 0.001), 0.0, 1.0)
	var fade := 1.0 - clampf((_age - extend_time - hold_time) / maxf(fade_time, 0.001), 0.0, 1.0)
	var normal := direction.orthogonal()
	var points := PackedVector2Array()
	var steps := maxi(4, int(reach / 6.0))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var wave := sin(t * 9.0 + _age * 30.0) * width * 0.18 * (1.0 - t * 0.5)
		points.append(direction * reach * t + normal * wave)
	if points.size() >= 2:
		draw_polyline(points, Color(0, 0, 0, 0.35 * fade), width * 0.55 + 2.0)
		draw_polyline(points, Color(VINE, fade), width * 0.55)
		draw_polyline(points, Color(VINE_LIGHT, 0.8 * fade), 1.0)
	# 小葉子。
	var leaves := int(reach / 14.0)
	for i in leaves:
		var at := direction * (7.0 + 14.0 * float(i)) + normal * (3.0 if i % 2 == 0 else -3.0)
		draw_circle(at, 2.0, Color(LEAF, fade))
	# 鞭梢的白光(打中的一刻)。
	if _age <= extend_time + hold_time:
		draw_circle(direction * reach, width * 0.4, Color(1, 1, 0.85, 0.7 * fade))
