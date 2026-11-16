class_name EnemyProjectile
extends Node2D
## 敵方投射物(AS5):箭、劍氣、乾草叉共用。數值在 ProjectileData(data/enemies/projectiles/)。
##
## - 射出者先畫直線預警(長度用 travel_length() 算,寬度 = ProjectileData.telegraph_width()),
##   預警結束才呼叫 launch();投射物沿著同一條線飛,碰到場地邊緣或飛滿射程就停。
## - 打中:金毛或同伴的身體碰到投射物(每一格檢查走過的線段,倍速時也不會穿過去)。
##   不能穿透的(箭)打中就消失;劍氣穿透(每個角色只打一次)。
## - 鬥牛犬舉盾時擋得住(is_taunting() 且牠有 block_projectile()):「鏘!」一聲,投射物被彈開、落地。
## - 會飛回來的(乾草叉)飛到盡頭後飛回射出者手上(catch_projectile());射出者倒下就落地。
## - 在群組 enemy_projectile;放在場地的特效層(在角色之上,最顯眼),場地 clear() 時一起移除。
## - 慢動作時(CombatFx.time_scale)跟著變慢。

const GROUP: StringName = &"enemy_projectile"
const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const MAX_RETURN_TIME := 4.0
const TRAIL_LENGTH := 5
const HALO_DARK := Color(0.12, 0.02, 0.06, 0.32)

enum State { FLYING, RETURNING, FALLING }

var data: ProjectileData
var shooter: Node2D
var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var speed: float = 120.0
var speed_mult: float = 1.0
var length: float = 100.0                 ## 這一次最遠飛多遠(= 預警線的長度)
var traveled: float = 0.0
var origin: Vector2 = Vector2.ZERO
var state: State = State.FLYING
var blocked: bool = false
var hits: int = 0

var _hit_ids: Array[int] = []
var _sprite: AnimatedSprite2D
var _age: float = 0.0
var _fall_left: float = 0.0
var _fall_total: float = 0.3
var _fall_velocity: Vector2 = Vector2.ZERO
var _fall_spin: float = 0.0
var _return_time: float = 0.0
var _trail: Array[Vector2] = []           ## 最近幾格的位置(殘影)


## 射出一個投射物。from、dir:起點與方向(與預警線相同);travel:最遠飛多遠(travel_length());
## p_damage:已乘好難度的傷害。傳回投射物;host 不在場景樹時傳回 null。
static func launch(host: Node, p_data: ProjectileData, from: Vector2, dir: Vector2, travel: float,
		p_damage: int, p_speed_mult: float = 1.0, p_shooter: Node2D = null) -> EnemyProjectile:
	if host == null or not host.is_inside_tree() or p_data == null:
		return null
	var p := EnemyProjectile.new()
	p.data = p_data
	p.direction = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	p.length = maxf(0.0, travel)
	p.damage = maxi(1, p_damage)
	p.speed_mult = maxf(0.05, p_speed_mult)
	p.speed = p_data.speed * p.speed_mult
	p.shooter = p_shooter
	CombatFx.layer_for(host).add_child(p)
	p.global_position = from
	p.origin = from
	return p


## 從 from 往 dir 飛,最遠 max_range,撞到戰鬥區邊緣為止的長度(預警線與投射物共用)。
static func travel_length(from: Vector2, dir: Vector2, max_range: float) -> float:
	var bounds := Layout.ARENA_RECT.grow(-2.0)
	if not bounds.has_point(from):
		return 0.0
	return minf(max_range, CombatMath.distance_to_rect_edge(from, dir.normalized(), bounds))


## 點 p 到線段 a→b 的距離。
static func segment_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 1
	var frames := CombatFx.frames(data.fx) if data != null else null
	if frames != null and frames.has_animation(&"default"):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2.ONE * data.visual_scale
		_sprite.rotation = direction.angle()
		add_child(_sprite)
		_sprite.play(&"default")


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if state != State.FALLING:
		_trail.push_front(global_position)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_back()
	if _sprite != null:
		_sprite.speed_scale = CombatFx.time_scale
	match state:
		State.FLYING:
			var step := minf(speed * delta, maxf(0.0, length - traveled))
			var from := global_position
			global_position += direction * step
			traveled += step
			_spin(delta)
			if _check_hits(from, global_position):
				return
			if traveled >= length - 0.001:
				if data.returns:
					_start_return()
				else:
					_stop(direction * 10.0)
		State.RETURNING:
			_return_time += delta
			var home := _home()
			var to_home := home - global_position
			var step := data.return_speed * speed_mult * delta
			_spin(delta)
			if to_home.length() <= step + 3.0:
				_caught()
				return
			if _return_time > MAX_RETURN_TIME:
				_stop(Vector2.ZERO)
				return
			direction = to_home.normalized()
			var from := global_position
			global_position += direction * step
			_check_hits(from, global_position)
		State.FALLING:
			_fall_left -= delta
			position += _fall_velocity * delta
			_fall_velocity = _fall_velocity.move_toward(Vector2.ZERO, 120.0 * delta)
			if _sprite != null:
				_sprite.rotation += _fall_spin * delta
			modulate.a = clampf(_fall_left / maxf(_fall_total, 0.001), 0.0, 1.0)
			if _fall_left <= 0.0:
				queue_free()
	queue_redraw()


func is_flying() -> bool:
	return state == State.FLYING or state == State.RETURNING


func _spin(delta: float) -> void:
	if _sprite == null:
		return
	if data.spin_speed != 0.0:
		_sprite.rotation += data.spin_speed * delta
	else:
		_sprite.rotation = direction.angle()


## 檢查這一格走過的線段 a→b。傳回 true 表示投射物停下了(被擋下或打中後消失)。
func _check_hits(a: Vector2, b: Vector2) -> bool:
	if not is_inside_tree():
		return true
	# 先看舉盾的鬥牛犬(擋在前面就擋下)。
	if data.blockable:
		for node in get_tree().get_nodes_in_group(COMPANION_GROUP):
			var dog := node as Node2D
			if dog == null or not dog.has_method(&"is_taunting") or not bool(dog.call(&"is_taunting")):
				continue
			var reach: Variant = dog.get(&"block_reach")
			var r := EnemyBase.radius_of(dog) + (float(reach) if reach != null else 4.0) + data.hit_radius
			if segment_distance(a, b, dog.global_position) <= r:
				_block(dog)
				return true
	for victim in _victims():
		var id := victim.get_instance_id()
		if _hit_ids.has(id):
			continue
		if segment_distance(a, b, victim.global_position) <= data.hit_radius + EnemyBase.radius_of(victim):
			_hit_ids.append(id)
			hits += 1
			victim.call(&"take_damage", damage)
			CombatFx.spawn(self, &"hit_spark", victim.global_position.lerp(global_position, 0.5), randf() * TAU,
					Vector2.ONE * 0.8, Color(1.0, 0.95, 0.6))
			if not data.pierce:
				_stop(direction * 6.0, 0.12)
				return true
	return false


func _victims() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for group: StringName in [PLAYER_GROUP, COMPANION_GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var victim := node as Node2D
			if victim == null or not victim.has_method(&"take_damage"):
				continue
			if victim.has_method(&"is_downed") and bool(victim.call(&"is_downed")):
				continue
			result.append(victim)
	return result


## 被鬥牛犬的盾擋下:「鏘!」,彈開、落地。
func _block(dog: Node2D) -> void:
	blocked = true
	if dog.has_method(&"block_projectile"):
		dog.call(&"block_projectile", self)
	var bounce := (-direction).rotated(randf_range(-0.6, 0.6)) * 50.0
	_stop(bounce, 0.45, 18.0)


func _start_return() -> void:
	state = State.RETURNING
	_return_time = 0.0
	_hit_ids.clear()          # 飛回來的路上也會打中(看得到的同一條線)


func _home() -> Vector2:
	if shooter != null and is_instance_valid(shooter) and shooter.is_inside_tree() \
			and not (shooter.has_method(&"is_dead") and bool(shooter.call(&"is_dead"))):
		return shooter.global_position
	return origin


func _caught() -> void:
	if shooter != null and is_instance_valid(shooter) and shooter.has_method(&"catch_projectile") \
			and not (shooter.has_method(&"is_dead") and bool(shooter.call(&"is_dead"))):
		shooter.call(&"catch_projectile", self)
		queue_free()
		return
	_stop(Vector2.ZERO)


## 停下:落地(或插在牆上)、慢慢透明後消失。
func _stop(drift: Vector2, fade: float = -1.0, spin: float = 0.0) -> void:
	state = State.FALLING
	_fall_total = data.end_fade_time if fade < 0.0 else fade
	_fall_left = _fall_total
	_fall_velocity = drift
	_fall_spin = spin
	if shooter != null and is_instance_valid(shooter) and shooter.has_method(&"projectile_lost"):
		shooter.call(&"projectile_lost", self)


## 投射物的「光暈」:在任何背景上都看得清楚(品質標準 2:危險的東西最顯眼)。
## 地上的影子 → 殘影 → 深色外框 → 會閃的亮色光暈 → 圖(子節點,畫在最上面)。
func _draw() -> void:
	if state == State.FALLING:
		return
	var r := maxf(2.5, data.hit_radius) * maxf(1.0, data.visual_scale * 0.8)
	var pulse := 0.5 + 0.5 * sin(_age * 18.0)
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r + 1.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	for i in _trail.size():
		var k := 1.0 - float(i + 1) / float(_trail.size() + 1)
		draw_circle(_trail[i] - global_position, r * (0.5 + 0.5 * k), Color(data.trail_color, data.trail_color.a * k * 0.7))
	if data.spin_speed != 0.0:
		# 會旋轉的(乾草叉):圓形光暈。
		draw_circle(Vector2.ZERO, r + 4.0, HALO_DARK)
		draw_circle(Vector2.ZERO, r + 2.0 + pulse, Color(data.trail_color, 0.5))
	else:
		# 直直飛的(箭、劍氣):沿著飛行方向的膠囊形光暈。
		var back := -direction * (5.0 + r)
		var front := direction * minf(3.0, r * 0.5)
		draw_line(back, front, HALO_DARK, r * 2.0 + 4.0)
		draw_circle(back, r + 2.0, HALO_DARK)
		draw_circle(front, r + 2.0, HALO_DARK)
		draw_line(back * 0.8, front, Color(data.trail_color, 0.45 + 0.25 * pulse), r * 2.0 + 1.0)
	if _sprite == null:
		draw_circle(Vector2.ZERO, maxf(1.5, data.hit_radius), Color(1, 1, 1, 0.9))
