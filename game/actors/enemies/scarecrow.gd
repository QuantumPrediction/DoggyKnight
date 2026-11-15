class_name ScarecrowEnemy
extends EnemyBase
## 稻草人兵(A5):慢慢走近,到了攻擊距離就停下,0.4 秒預警(紅色扇形逐漸填滿),然後揮擊。
## 精英稻草人兵用同一個腳本(scarecrow_elite.tscn 只改大小、顏色與攻擊範圍)。

enum Phase { APPROACH, TELEGRAPH, SWING, RECOVER }

@export_group("攻擊")
@export var attack_trigger_range: float = 14.0    ## 與目標「身體邊緣」的距離小於這個就開始預警
@export var attack_radius: float = 20.0
@export var attack_half_angle_deg: float = 60.0
@export var telegraph_time: float = 0.4
@export var swing_time: float = 0.15
@export var recover_time: float = 0.7

var phase: Phase = Phase.APPROACH
var attacks_started: int = 0

var _phase_left: float = 0.0
var _attack_dir: Vector2 = Vector2.LEFT


func _ai(delta: float) -> void:
	match phase:
		Phase.APPROACH:
			_approach()
		Phase.TELEGRAPH:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / telegraph_time
			# 蓄力:往後仰、微微發抖。
			if sprite != null:
				sprite.position = _sprite_base_offset - _attack_dir * 1.5 + Vector2(sin(_phase_left * 90.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_swing()
		Phase.SWING:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.RECOVER
				_phase_left = recover_time
				anim_state = &"idle"
				if sprite != null:
					sprite.position = _sprite_base_offset
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.APPROACH


func _approach() -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > 0.01:
		facing = to_target / dist
	if dist - radius_of(target) - body_radius <= attack_trigger_range:
		_start_telegraph(to_target)
		return
	desired_velocity = facing * data.move_speed
	anim_state = &"run"


func _start_telegraph(to_target: Vector2) -> void:
	phase = Phase.TELEGRAPH
	attacks_started += 1
	_phase_left = telegraph_time
	_attack_dir = to_target.normalized() if to_target.length() > 0.01 else facing
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"
	_show_telegraph(AttackTelegraph.make_sector(attack_radius * visual_scale, _attack_dir,
			deg_to_rad(attack_half_angle_deg)))


func _swing() -> void:
	_clear_telegraph()
	phase = Phase.SWING
	_phase_left = swing_time
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.position = _sprite_base_offset + _attack_dir * 2.0
	var slash := CombatFx.spawn(self, &"slash", global_position + _attack_dir * 8.0 * visual_scale,
			_attack_dir.angle(), Vector2.ONE * 0.8 * visual_scale, Color(0.95, 0.75, 0.45))
	if slash != null:
		slash.flip_v = _attack_dir.x < 0.0
	hit_victims_in_sector(global_position, _attack_dir, attack_radius * visual_scale,
			deg_to_rad(attack_half_angle_deg), data.contact_damage)


func _is_committed() -> bool:
	return phase == Phase.TELEGRAPH or phase == Phase.SWING


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELEGRAPH or phase == Phase.SWING:
		phase = Phase.RECOVER
		_phase_left = recover_time * 0.5
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset
