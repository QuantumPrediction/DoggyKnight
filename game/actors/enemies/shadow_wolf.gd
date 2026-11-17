class_name ShadowWolfEnemy
extends EnemyBase
## 影狼(v2.6 AV4,3-2 起):成群在目標外圍繞圈,輪流以紅線預警後直線衝鋒。
## 數值在 data/enemies/shadow_wolf.tres(衝鋒傷害 = 接觸傷害、繞圈速度),節奏在本場景的屬性欄。
##
## - 繞圈:在目標外圍 circle_radius 的圈上同一個方向跑(像狼群包圍);彼此推開,不會疊在一起。
## - 輪流:同一時間只有一隻影狼在預警或衝鋒(其他的繼續繞),而且要拿到場地的近戰名額。
## - 衝鋒:停下低頭,地上畫紅線(方向在這一刻鎖定)dash_telegraph 秒,然後沿線衝過去(身體碰到紅線就打中);
##   衝完喘氣 recover_time 秒(反擊好時機),再回到圈上。
## - 倒下:播 down(趴下),然後散成一陣落葉(BitsScatter.LEAF)淡出——不是受傷。

enum Phase { CIRCLE, TELL, DASH, RECOVER }

const LEAF_COLORS: Array[Color] = [Color("4f3f73"), Color("2f5a3a"), Color("6f8f4a"), Color("8a6fb0")]

@export_group("繞圈")
@export var circle_radius: float = 70.0
@export var circle_pull: float = 2.5            ## 拉回圈上的力道
@export_group("衝鋒")
@export var dash_telegraph: float = 0.75        ## 紅線預警(× 難度)
@export var dash_speed: float = 175.0           ## × 難度的速度倍數
@export var dash_overshoot: float = 30.0        ## 衝過目標多遠
@export var dash_max_distance: float = 180.0
@export var hit_radius: float = 7.0             ## 預警線寬度 = 2 × 這個
@export var recover_time: float = 0.7
@export var dash_cooldown_min: float = 2.4
@export var dash_cooldown_max: float = 3.8
@export var first_dash_min: float = 1.2
@export var first_dash_max: float = 2.6
@export var dash_range: float = 120.0           ## 目標在這個距離內才衝
@export_group("倒下")
@export var leaf_at: float = 0.45               ## 倒下演出的這個比例時散成落葉

var phase: Phase = Phase.CIRCLE
var dashes: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _tell_total: float = 0.75
var _angle: float = 0.0
var _dir: Vector2 = Vector2.DOWN
var _length: float = 0.0
var _traveled: float = 0.0
var _hit: Array[Node2D] = []
var _leaves_done: bool = false


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_activated() -> void:
	phase = Phase.CIRCLE
	_cooldown_left = rest(rng.randf_range(first_dash_min, first_dash_max))
	if target != null:
		_angle = (global_position - target.global_position).angle()


func _ai(delta: float) -> void:
	match phase:
		Phase.CIRCLE:
			_circle(delta)
			_cooldown_left -= delta
			if _cooldown_left <= 0.0 and target != null and _may_dash():
				_start_tell()
		Phase.TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if sprite != null:
				sprite.position = _sprite_base_offset - _dir * 1.5 + Vector2(sin(_phase_left * 80.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_start_dash()
		Phase.DASH:
			var speed := scaled_speed(dash_speed)
			desired_velocity = _dir * speed
			facing = _dir
			anim_state = &"dash"
			_traveled += speed * delta
			for victim in victims():
				if not _hit.has(victim) and global_position.distance_to(victim.global_position) <= hit_radius + radius_of(victim):
					_hit.append(victim)
					victim.call(&"take_damage", data.contact_damage)
			if _traveled >= _length or get_slide_collision_count() > 0:
				_end_dash()
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.CIRCLE
				if target != null:
					_angle = (global_position - target.global_position).angle()


func _circle(delta: float) -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	var center := target.global_position
	var from_center := global_position - center
	var dist := from_center.length()
	_angle = from_center.angle() if dist > 1.0 else _angle
	var tangent := Vector2.from_angle(_angle).orthogonal()
	var radial := Vector2.from_angle(_angle) * clampf((circle_radius - dist) / 20.0, -1.0, 1.0) * circle_pull
	var dir := (tangent + radial).normalized()
	# 圈的一部分在場外:沿著牆反方向跑也可以;這裡只要不撞牆。
	if not CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 10.0):
		dir = (radial.normalized() if radial.length() > 0.1 else -from_center.normalized()) * 0.6 + tangent * 0.4
	desired_velocity = dir.limit_length(1.0) * data.move_speed
	facing = desired_velocity.normalized() if desired_velocity.length() > 1.0 else facing
	anim_state = &"run"


## 輪流:場上沒有別的影狼正在預警或衝鋒,目標在範圍內,並且拿到近戰名額。
func _may_dash() -> bool:
	if global_position.distance_to(target.global_position) > dash_range:
		return false
	for node in _enemies_cached():
		var other := node as ShadowWolfEnemy
		if other != null and other != self and other.state == State.ACTIVE \
				and (other.phase == Phase.TELL or other.phase == Phase.DASH):
			return false
	return claim_attack_slot()


func _start_tell() -> void:
	var to_target := target.global_position - global_position
	_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	var to_edge := CombatMath.distance_to_rect_edge(global_position, _dir, CombatMath.arena_bounds(arena_margin))
	_length = minf(minf(to_target.length() + dash_overshoot, dash_max_distance), to_edge)
	phase = Phase.TELL
	dashes += 1
	_tell_total = tell(dash_telegraph)
	_phase_left = _tell_total
	facing = _dir
	desired_velocity = Vector2.ZERO
	_play(&"attack", true)
	_show_telegraph(AttackTelegraph.make_line(_dir, _length, hit_radius * 2.0))
	CombatFx.sfx(&"wolf_growl", &"boss_warning", -8.0)


func _start_dash() -> void:
	_clear_telegraph()
	phase = Phase.DASH
	_traveled = 0.0
	_hit.clear()
	if sprite != null:
		sprite.position = _sprite_base_offset
	_play(&"dash", true)
	CombatFx.sfx(&"whoosh", &"swing", -4.0)


func _end_dash() -> void:
	phase = Phase.RECOVER
	_phase_left = rest(recover_time)
	_cooldown_left = rest(rng.randf_range(dash_cooldown_min, dash_cooldown_max))
	desired_velocity = Vector2.ZERO
	release_attack_slot()
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 4), true)


func is_attacking_target(victim: Node2D) -> bool:
	return target == victim and (phase == Phase.TELL or phase == Phase.DASH)


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELL or phase == Phase.DASH:
		phase = Phase.RECOVER
		_phase_left = rest(recover_time)
		_cooldown_left = maxf(_cooldown_left, rest(dash_cooldown_min))
	release_attack_slot()
	if sprite != null:
		sprite.position = _sprite_base_offset


func _is_committed() -> bool:
	return phase == Phase.TELL


func _uses_separation() -> bool:
	return phase == Phase.CIRCLE or phase == Phase.RECOVER


# --- 倒下:趴下 → 散成落葉 ------------------------------------------------------------

func _on_died() -> void:
	_leaves_done = false
	_flash_left = 0.0
	_set_flash(0.0)
	_play(&"down", true)
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 4), true)


func _tick_death(delta: float) -> void:
	_death_left -= delta
	var t := 1.0 - clampf(_death_left / maxf(death_time, 0.001), 0.0, 1.0)
	if t >= leaf_at and not _leaves_done:
		_leaves_done = true
		BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.15), BitsScatter.Kind.LEAF, LEAF_COLORS, 14)
		CombatFx.particles(self, &"leaves", global_position, false)
	if sprite != null and t >= leaf_at:
		var k := (t - leaf_at) / maxf(1.0 - leaf_at, 0.001)
		sprite.modulate = Color(tint, 1.0 - k)
		sprite.scale = Vector2(visual_scale * (1.0 + 0.3 * k), visual_scale * (1.0 - 0.3 * k))
	if _death_left <= 0.0:
		queue_free()
