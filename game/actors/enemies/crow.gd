class_name CrowEnemy
extends EnemyBase
## 烏鴉斥候(A6):沿著場邊盤旋 → 鎖定金毛,停下並畫出預警線 → 沿直線俯衝(140 像素/秒,
## EnemyData.move_speed)→ 落地喘口氣(這時最好打)→ 飛回場邊。

enum Phase { TO_EDGE, CIRCLE, TELEGRAPH, DIVE, RECOVER }

@export_group("盤旋")
@export var circle_speed: float = 46.0
@export var edge_inset: float = 18.0             ## 盤旋路線距離場地邊緣
@export var circle_time_min: float = 1.4
@export var circle_time_max: float = 2.6
@export var fly_height: float = 7.0
@export_group("俯衝")
@export var telegraph_time: float = 0.55
@export var dive_overshoot: float = 28.0         ## 衝過目標多遠
@export var max_dive_distance: float = 190.0
@export var hit_radius: float = 6.0
@export var recover_time: float = 0.75

var phase: Phase = Phase.TO_EDGE
var dives_started: int = 0

var _phase_left: float = 0.0
var _theta: float = 0.0
var _direction_sign: float = 1.0
var _dive_dir: Vector2 = Vector2.DOWN
var _dive_length: float = 0.0
var _dive_traveled: float = 0.0
var _dive_hit: Array[Node2D] = []
var _height: float = 0.0


func _on_ready() -> void:
	_direction_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_height = fly_height
	_sprite_base_offset = Vector2(0, -_height)


func _on_activated() -> void:
	phase = Phase.TO_EDGE


func _ai(delta: float) -> void:
	match phase:
		Phase.TO_EDGE:
			_set_height(fly_height, delta)
			_theta = _nearest_theta(global_position)
			var to_edge := path_point(_theta) - global_position
			if to_edge.length() < 3.0:
				_start_circling()
			else:
				desired_velocity = to_edge.normalized() * circle_speed * 1.3
				facing = to_edge.normalized()
			anim_state = &"run"
		Phase.CIRCLE:
			_set_height(fly_height, delta)
			var radius := (_path_rect().size.x + _path_rect().size.y) * 0.3
			_theta += _direction_sign * circle_speed / maxf(radius, 1.0) * delta
			var to_point := path_point(_theta) - global_position
			desired_velocity = (to_point * 8.0).limit_length(circle_speed * 1.6)
			if desired_velocity.length() > 1.0:
				facing = desired_velocity.normalized()
			anim_state = &"run"
			_phase_left -= delta
			if _phase_left <= 0.0 and target != null:
				_start_telegraph()
		Phase.TELEGRAPH:
			_set_height(fly_height + 2.0, delta)
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / telegraph_time
			anim_state = &"idle"
			if _phase_left <= 0.0:
				_start_dive()
		Phase.DIVE:
			_set_height(1.0, delta * 3.0)
			desired_velocity = _dive_dir * data.move_speed
			facing = _dive_dir
			anim_state = &"attack"
			_dive_traveled += data.move_speed * delta
			_check_dive_hits()
			if _dive_traveled >= _dive_length or get_slide_collision_count() > 0:
				_land()
		Phase.RECOVER:
			_set_height(0.0, delta * 2.0)
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.TO_EDGE


# --- 盤旋路線:接近場地四邊的圓角矩形(超橢圓) -----------------------------------------

func _path_rect() -> Rect2:
	return Layout.ARENA_RECT.grow(-edge_inset)


func path_point(theta: float) -> Vector2:
	var rect := _path_rect()
	var c := cos(theta)
	var s := sin(theta)
	var x := signf(c) * sqrt(absf(c))
	var y := signf(s) * sqrt(absf(s))
	return rect.get_center() + Vector2(x * rect.size.x * 0.5, y * rect.size.y * 0.5)


func _nearest_theta(pos: Vector2) -> float:
	var rect := _path_rect()
	var u := (pos.x - rect.get_center().x) / maxf(rect.size.x * 0.5, 1.0)
	var v := (pos.y - rect.get_center().y) / maxf(rect.size.y * 0.5, 1.0)
	if absf(u) < 0.001 and absf(v) < 0.001:
		return 0.0
	return atan2(signf(v) * v * v, signf(u) * u * u)


func _start_circling() -> void:
	phase = Phase.CIRCLE
	_phase_left = rng.randf_range(circle_time_min, circle_time_max)


# --- 俯衝 -----------------------------------------------------------------------

func _start_telegraph() -> void:
	var to_target := target.global_position - global_position
	_dive_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	var to_edge := CombatMath.distance_to_rect_edge(global_position, _dive_dir, CombatMath.arena_bounds(arena_margin))
	_dive_length = minf(minf(to_target.length() + dive_overshoot, max_dive_distance), to_edge)
	phase = Phase.TELEGRAPH
	dives_started += 1
	_phase_left = telegraph_time
	facing = _dive_dir
	_show_telegraph(AttackTelegraph.make_line(_dive_dir, _dive_length, hit_radius * 2.0))


func _start_dive() -> void:
	_clear_telegraph()
	phase = Phase.DIVE
	_dive_traveled = 0.0
	_dive_hit.clear()
	_play(&"attack", true)


func _check_dive_hits() -> void:
	for victim in victims():
		if _dive_hit.has(victim):
			continue
		if global_position.distance_to(victim.global_position) <= hit_radius + radius_of(victim):
			_dive_hit.append(victim)
			victim.call(&"take_damage", data.contact_damage)


func _land() -> void:
	phase = Phase.RECOVER
	_phase_left = recover_time
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE, Color.WHITE, true)


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELEGRAPH or phase == Phase.DIVE:
		phase = Phase.RECOVER
		_phase_left = recover_time


func _on_damaged(_amount: int) -> void:
	# 俯衝中被打到會被打斷,掉到地上。
	if phase == Phase.DIVE:
		_land()


func _is_committed() -> bool:
	return phase == Phase.TELEGRAPH


func _uses_separation() -> bool:
	return phase == Phase.TO_EDGE or phase == Phase.CIRCLE or phase == Phase.RECOVER


func _set_height(height: float, delta: float) -> void:
	_height = move_toward(_height, height, 30.0 * delta)
	_sprite_base_offset = Vector2(0, -_height)
	if sprite != null:
		sprite.position = _sprite_base_offset
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.position = Vector2(0, -_frame_size.y * 0.55) + _sprite_base_offset
