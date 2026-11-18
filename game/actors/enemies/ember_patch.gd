class_name EmberPatch
extends Node2D
## v2.7 火蜥蜴衝刺時身後留下的小火苗(程式畫的)。放在地面層(角色之下)。
## - 剛落下的 arm_time 秒只是小火星(不燙),之後變成小火苗,lifetime 秒後縮小熄掉。
## - 金毛或同伴踩到(角色中心離火苗 radius 以內)會被燙一下(每個火苗對每個角色只燙一次):
##   冒一縷白煙與小火星,可愛表現,不是受傷畫面。
## 在群組 combat_fx(場地 clear() 時一起移除);慢動作時跟著變慢。

const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const FLAME := Color(1.0, 0.55, 0.2)
const FLAME_CORE := Color(1.0, 0.9, 0.45)

var damage: int = 4
var radius: float = 5.0
var arm_time: float = 0.25
var lifetime: float = 1.6
var hits: int = 0

var _age: float = 0.0
var _burned: Array[int] = []
var _seed: float = 0.0


static func drop(host: Node, at: Vector2, p_damage: int, p_radius: float, p_lifetime: float, p_arm: float) -> EmberPatch:
	if host == null or not host.is_inside_tree():
		return null
	var e := EmberPatch.new()
	e.damage = maxi(1, p_damage)
	e.radius = p_radius
	e.lifetime = p_lifetime
	e.arm_time = p_arm
	CombatFx.layer_for(host, true).add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	add_to_group(&"combat_fx")
	_seed = randf() * TAU


func is_armed() -> bool:
	return _age >= arm_time and _age < lifetime


func _physics_process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= lifetime:
		queue_free()
		return
	if is_armed():
		for group: StringName in [PLAYER_GROUP, COMPANION_GROUP]:
			for node in get_tree().get_nodes_in_group(group):
				var victim := node as Node2D
				if victim == null or not victim.has_method(&"take_damage") or _burned.has(victim.get_instance_id()):
					continue
				if victim.has_method(&"is_downed") and bool(victim.call(&"is_downed")):
					continue
				if global_position.distance_to(victim.global_position) <= radius + EnemyBase.radius_of(victim) * 0.5:
					_burned.append(victim.get_instance_id())
					hits += 1
					victim.call(&"take_damage", damage)
					var puff := CombatFx.spawn(self, &"dust", victim.global_position + Vector2(0, -6), 0.0, Vector2.ONE * 0.7,
							Color(1, 1, 1, 0.9), false, 0.5)
					if puff != null:
						puff.drift = Vector2(0, -20.0)
						puff.fade_out = true
	queue_redraw()


func _draw() -> void:
	var shrink := clampf((lifetime - _age) / 0.3, 0.0, 1.0)
	var flicker := 0.8 + 0.2 * sin(_age * 30.0 + _seed)
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius * 1.1 * shrink, Color(FLAME, 0.25))
	draw_set_transform(Vector2.ZERO)
	if _age < arm_time:
		# 剛落下:只有兩三顆小火星。
		for i in 3:
			var at := Vector2(sin(_seed + float(i) * 2.1) * radius * 0.6, -float(i))
			draw_rect(Rect2(at.round(), Vector2.ONE), Color(FLAME_CORE, 0.9))
		return
	var h := radius * 1.6 * shrink * flicker
	var w := radius * 0.9 * shrink
	draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(0, -h), Vector2(w, 0)]), Color(FLAME, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(0, -h * 0.6), Vector2(w * 0.5, 0)]), Color(FLAME_CORE, 0.95))
