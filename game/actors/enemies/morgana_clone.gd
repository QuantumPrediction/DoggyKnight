class_name MorganaClone
extends EnemyBase
## 摩根娜的鏡像分身(v2.6 AV7,第二階段起由摩根娜召喚):半透明、淡藍紫色,一下就打散。
## 只會射較弱的單顆月光球:先畫直線預警(方向鎖定),之後沿線射出(傷害 = 接觸傷害,
## data/enemies/morgana_clone.tres)。不掉經驗、寶箱與零食;摩根娜倒下時一起散掉。
## 打散時化成一團月光霧(BitsScatter.MIST),不是受傷。

enum Phase { FLOAT, AIM, REST }

const MOON_ORB: ProjectileData = preload("res://data/enemies/projectiles/moon_orb.tres")
const MIST_COLORS: Array[Color] = [Color(0.8, 0.85, 1.0, 0.9), Color(0.72, 0.5, 1.0, 0.9)]

@export var projectile: ProjectileData = MOON_ORB
@export var aim_time: float = 0.8                ## 直線預警秒數(× 難度)
@export var shot_interval: float = 2.6
@export var first_shot_min: float = 1.0
@export var first_shot_max: float = 1.8
@export var rest_time: float = 0.4
@export var float_height: float = 6.0
@export var drift_speed: float = 14.0

var phase: Phase = Phase.FLOAT
var shots: int = 0

var _phase_left: float = 0.0
var _aim_total: float = 0.8
var _aim_dir: Vector2 = Vector2.DOWN
var _aim_length: float = 100.0
var _drift_sign: float = 1.0


func _on_ready() -> void:
	_drift_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.FLOAT
	_phase_left = rng.randf_range(first_shot_min, first_shot_max)


## 一下就打散。
func take_damage(amount: int) -> void:
	if amount > 0 and state == State.ACTIVE:
		amount = maxi(amount, hp)
	super(amount)


func _ai(delta: float) -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 2.2) * 1.5))
	if sprite != null:
		sprite.position = _sprite_base_offset
		sprite.modulate = Color(tint, tint.a * (0.8 + 0.2 * sin(_age * 5.0)))
	_phase_left -= delta
	match phase:
		Phase.FLOAT:
			anim_state = &"idle"
			if target != null:
				var to_target := target.global_position - global_position
				facing = to_target.normalized() if to_target.length() > 1.0 else facing
				var side := facing.orthogonal() * _drift_sign
				if not CombatMath.arena_bounds(arena_margin).has_point(global_position + side * 10.0):
					_drift_sign = -_drift_sign
				desired_velocity = side * drift_speed
			else:
				desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0 and target != null:
				_start_aim()
		Phase.AIM:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_aim_total, 0.001)
			if _phase_left <= 0.0:
				_shoot()
		Phase.REST:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if _phase_left <= 0.0:
				phase = Phase.FLOAT
				_phase_left = rest(shot_interval)


func _start_aim() -> void:
	var to_target := target.global_position - global_position
	_aim_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	facing = _aim_dir
	_aim_length = EnemyProjectile.travel_length(global_position, _aim_dir, projectile.max_range)
	phase = Phase.AIM
	_aim_total = tell(aim_time)
	_phase_left = _aim_total
	_play(&"cast", true)
	_show_telegraph(AttackTelegraph.make_line(_aim_dir, _aim_length, projectile.telegraph_width()))


func _shoot() -> void:
	_clear_telegraph()
	phase = Phase.REST
	_phase_left = rest_time
	shots += 1
	EnemyProjectile.launch(self, projectile, global_position, _aim_dir, _aim_length, data.contact_damage,
			projectile_speed_mult(), self)
	CombatFx.sfx(&"magic", &"whoosh", -8.0)


func _cancel_attack() -> void:
	super()
	if phase == Phase.AIM:
		phase = Phase.FLOAT
		_phase_left = rest(shot_interval) * 0.5


func _is_committed() -> bool:
	return phase == Phase.AIM


## 分身不掉寶箱與零食。
func _drop_loot() -> void:
	pass


func _on_died() -> void:
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.MIST, MIST_COLORS, 10)
	CombatFx.ring(self, global_position, 3.0, 20.0, 0.3, Color(0.8, 0.85, 1.0, 0.8), 1.0)
