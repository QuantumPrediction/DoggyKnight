class_name PawPrint
extends Node2D
## 擊掌連打(進化把戲 high_five)放出的掌印:金色的肉球,拖著光點飛向最近的敵人。
## 打中時呼叫金毛的 ability_hit(傷害、擊退、忠誠度都照能力的規則),噴 star_burst。
## 目標倒下時改追最近的另一隻;找不到或超過壽命就淡出消失。放在場地的特效層。

const GROUP: StringName = &"paw_print"
const ENEMY_GROUP: StringName = &"enemy"
const PAW := Color(1.0, 0.82, 0.35)
const PAW_LIGHT := Color(1.0, 0.95, 0.7)
const OUTLINE := Color(0.35, 0.2, 0.1)
const TRAIL_POINTS := 6

var damage: int = 10
var speed: float = 150.0
var search_range: float = 120.0
var lifetime: float = 1.2
var knockback: float = 70.0
var shooter: Node2D                       ## 金毛(有 ability_hit 方法)
var target: Node2D
var hit_count: int = 0

var _age: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _trail: PackedVector2Array = PackedVector2Array()
var _done: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 1
	if not _valid(target):
		target = _nearest()


func _physics_process(delta: float) -> void:
	if _done:
		return
	delta *= CombatFx.time_scale
	_age += delta
	if _age >= lifetime:
		_finish(false)
		return
	if not _valid(target):
		target = _nearest()
	if target != null:
		var to := target.global_position + Vector2(0, -4) - global_position
		if to.length() <= 5.0 + _radius_of(target):
			_hit(target)
			return
		# 轉向目標(稍微有弧度,不是直線瞬移)。
		_dir = _dir.lerp(to.normalized(), clampf(delta * 14.0, 0.0, 1.0)).normalized()
	_trail.append(global_position)
	if _trail.size() > TRAIL_POINTS:
		_trail.remove_at(0)
	global_position += _dir * speed * delta
	rotation = 0.0
	queue_redraw()


func launch(from: Vector2, direction: Vector2) -> void:
	global_position = from
	if direction.length() > 0.01:
		_dir = direction.normalized()


func _hit(enemy: Node2D) -> void:
	hit_count += 1
	if shooter != null and is_instance_valid(shooter) and shooter.has_method(&"ability_hit"):
		shooter.call(&"ability_hit", enemy, damage, knockback)
	elif enemy.has_method(&"take_damage"):
		enemy.call(&"take_damage", damage)
	CombatFx.particles(self, &"star_burst", global_position)
	CombatFx.ring(self, global_position, 2.0, 12.0, 0.2, Color(PAW_LIGHT, 0.9), 1.0)
	CombatFx.sfx(&"high_five", &"hit")
	_finish(true)


func _finish(_landed: bool) -> void:
	_done = true
	remove_from_group(GROUP)
	queue_free()


func _nearest() -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_d := search_range
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d:
			best = enemy
			best_d = d
	return best


func _valid(enemy: Variant) -> bool:
	if not is_instance_valid(enemy):
		return false
	var node := enemy as Node2D
	if node == null or not node.is_inside_tree() or not node.is_in_group(ENEMY_GROUP):
		return false
	return not node.has_method(&"is_targetable") or bool(node.call(&"is_targetable"))


static func _radius_of(node: Node) -> float:
	var r: Variant = node.get(&"body_radius")
	return float(r) if r != null else 6.0


func _draw() -> void:
	# 光點尾巴。
	for i in _trail.size():
		var p := (_trail[i] - global_position).round()
		var a := 0.2 + 0.6 * float(i) / float(maxi(1, _trail.size()))
		draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(PAW_LIGHT, a))
	# 肉球:一個大掌墊 + 三個小趾頭(朝飛行方向),深色外框。
	var fwd := _dir.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var pad := (-fwd * 1.0).round()
	draw_circle(pad, 3.5, OUTLINE)
	draw_circle(pad, 2.5, PAW)
	for k: int in [-1, 0, 1]:
		var toe := (fwd * 3.5 + side * 2.6 * float(k) - fwd * (0.8 if k != 0 else 0.0)).round()
		draw_circle(toe, 1.9, OUTLINE)
		draw_circle(toe, 1.1, PAW_LIGHT)
