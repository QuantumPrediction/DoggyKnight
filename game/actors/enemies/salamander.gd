class_name SalamanderEnemy
extends EnemyBase
## 火蜥蜴(v2.7 AW3,第五章 5-2 起,24×24):小火尾巴的蜥蜴,快速衝刺,身後留下短暫的小火苗。
## 數值在 data/enemies/salamander.tres(衝刺傷害 = 接觸傷害),節奏在本場景的屬性欄。
##
## - 平時在目標附近繞著跑(dash_min 至 dash_range 的距離)。
## - 衝刺:停下壓低身子,地上畫紅線(方向在這一刻鎖定)dash_telegraph 秒,然後沿線衝過去(身體碰到線就打中);
##   每跑 ember_spacing 像素在身後留下一個小火苗(EmberPatch:先是小火星,arm 秒後才會燙,ember_lifetime 秒後熄掉;
##   踩到會被燙一下,可愛表現)。衝完喘氣 recover_time 秒(反擊時機)。
## - 同時衝刺的火蜥蜴受場地的近戰名額限制。
## - 倒下:尾巴的火「噗」地熄掉,冒一縷白煙(BitsScatter.MIST),不是受傷。

enum Phase { PROWL, TELL, DASH, RECOVER }

const SMOKE_COLORS: Array[Color] = [Color(1, 1, 1, 0.85), Color(1.0, 0.8, 0.55, 0.8)]

@export_group("繞著跑")
@export var prowl_radius: float = 60.0
@export var prowl_pull: float = 2.0
@export_group("衝刺")
@export var dash_telegraph: float = 0.65         ## 紅線預警(× 難度)
@export var dash_speed: float = 190.0            ## × 難度的速度倍數
@export var dash_overshoot: float = 30.0
@export var dash_max_distance: float = 170.0
@export var dash_range: float = 120.0            ## 目標在這個距離內才衝
@export var hit_radius: float = 6.0              ## 預警線寬度 = 2 × 這個
@export var recover_time: float = 1.0
@export var dash_cooldown_min: float = 2.4
@export var dash_cooldown_max: float = 3.4
@export var first_dash_min: float = 1.0
@export var first_dash_max: float = 2.0
@export_group("小火苗")
@export var ember_damage: int = 4
@export var ember_spacing: float = 12.0
@export var ember_radius: float = 4.0
@export var ember_lifetime: float = 1.5
@export var ember_arm_time: float = 0.3
@export var max_embers_per_dash: int = 12

var phase: Phase = Phase.PROWL
var dashes: int = 0
var embers_dropped: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _tell_total: float = 0.65
var _dir: Vector2 = Vector2.DOWN
var _length: float = 0.0
var _traveled: float = 0.0
var _since_ember: float = 0.0
var _embers_this_dash: int = 0
var _hit: Array[Node2D] = []
var _orbit_sign: float = 1.0


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_ready() -> void:
	_orbit_sign = 1.0 if rng.randf() < 0.5 else -1.0


func _on_activated() -> void:
	phase = Phase.PROWL
	_cooldown_left = rest(rng.randf_range(first_dash_min, first_dash_max))


func _ai(delta: float) -> void:
	match phase:
		Phase.PROWL:
			_prowl()
			_cooldown_left -= delta
			if _cooldown_left <= 0.0 and target != null \
					and global_position.distance_to(target.global_position) <= dash_range and claim_attack_slot():
				start_tell()
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
			var step := speed * delta
			_traveled += step
			_since_ember += step
			if _since_ember >= ember_spacing and _embers_this_dash < max_embers_per_dash:
				_since_ember = 0.0
				_embers_this_dash += 1
				embers_dropped += 1
				EmberPatch.drop(self, global_position - _dir * 4.0 + Vector2(0, 3), scaled_damage(ember_damage),
						ember_radius, ember_lifetime, ember_arm_time)
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
				phase = Phase.PROWL


func _prowl() -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	var from_center := global_position - target.global_position
	var dist := from_center.length()
	var out := from_center / dist if dist > 1.0 else Vector2.UP
	var tangent := out.orthogonal() * _orbit_sign
	var radial := out * clampf((prowl_radius - dist) / 20.0, -1.0, 1.0) * prowl_pull
	var dir := (tangent + radial).normalized()
	if not CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 10.0):
		_orbit_sign = -_orbit_sign
		dir = (-out * 0.6 + tangent * -0.4).normalized()
	desired_velocity = dir * data.move_speed
	if desired_velocity.length() > 1.0:
		facing = desired_velocity.normalized()
	anim_state = &"run"


func start_tell() -> void:
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
	_call_pincer(target)
	CombatFx.sfx(&"salamander_hiss", &"boss_warning", -10.0)


func _start_dash() -> void:
	_clear_telegraph()
	phase = Phase.DASH
	_traveled = 0.0
	_since_ember = 0.0
	_embers_this_dash = 0
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
	return phase == Phase.PROWL or phase == Phase.RECOVER


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + Vector2(0, -4), BitsScatter.Kind.MIST, SMOKE_COLORS, 6)
