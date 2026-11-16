class_name ScarecrowEnemy
extends EnemyBase
## 稻草人兵(A5):慢慢走近,到了攻擊距離就停下,0.4 秒預警(紅色扇形逐漸填滿),然後揮擊。
## 精英稻草人兵用同一個腳本(scarecrow_elite.tscn 只改大小、顏色與攻擊範圍,另有光環)。
##
## M3 打磨:
## - 分散包圍(AP7):每隻稻草人有自己的「側翼角度」,遠處時斜斜地繞過來;接近目標時,
##   和角度太接近的同伴互相讓開,所以會從不同方向圍上來,不會排成一條線。
## - 攻擊距離(AP3):開始預警的距離比金毛揮劍的擊退距離稍長,所以單獨一隻稻草人
##   也打得中站著不動的金毛(站著不動會被打,看到紅色就要走開)。揮擊時往前踏一步。
##
## v2.3(AS6、AS7):
## - 預警 0.5 秒(一般模式;困難模式 × 0.8 = 0.4 秒),收招時間 × 難度。
## - 進攻名額:出手前要拿到場地的近戰名額(同時出手的數量隨關卡增加);拿不到就在攻擊距離外
##   繞著目標等(不擠上去)。
## - 夾擊(後段關卡):同伴開始預警時,附近等著的稻草人一起出手(join_attack)。

enum Phase { APPROACH, TELEGRAPH, SWING, RECOVER }

@export_group("攻擊")
@export var attack_trigger_range: float = 18.0    ## 與目標「身體邊緣」的距離小於這個就開始預警(要比金毛的擊退遠)
@export var attack_radius: float = 24.0
@export var attack_half_angle_deg: float = 60.0
@export var telegraph_time: float = 0.5
@export var swing_time: float = 0.15
@export var recover_time: float = 0.7
@export var lunge_distance: float = 3.0           ## 揮擊時往前踏幾個像素

@export_group("包圍")
@export var flank_angle_max: float = 0.7          ## 遠處時斜著繞過來的最大角度(弧度)
@export var flank_fade_distance: float = 70.0     ## 距離目標多遠以內,斜行慢慢變成直走
@export var surround_radius: float = 64.0         ## 目標身邊這個範圍內的稻草人會互相讓開角度
@export var surround_spacing: float = 0.9         ## 兩隻稻草人圍繞目標的角度至少相差多少(弧度)
@export var surround_strength: float = 1.1
@export_group("等名額")
@export var wait_margin: float = 10.0             ## 拿不到進攻名額時,在攻擊距離外再多這麼遠的地方等
@export var wait_speed_mult: float = 0.6          ## 等的時候繞圈的速度

var phase: Phase = Phase.APPROACH
var attacks_started: int = 0

var _phase_left: float = 0.0
var _attack_dir: Vector2 = Vector2.LEFT
var _flank: float = 0.0
var _tell_total: float = 0.5
var _circle_sign: float = 1.0


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_ready() -> void:
	_flank = rng.randf_range(-flank_angle_max, flank_angle_max)
	_circle_sign = 1.0 if rng.randf() < 0.5 else -1.0


func _ai(delta: float) -> void:
	match phase:
		Phase.APPROACH:
			_approach()
		Phase.TELEGRAPH:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
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
				_phase_left = rest(recover_time)
				release_attack_slot()
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
	var edge := dist - radius_of(target) - body_radius
	if edge <= attack_trigger_range and claim_attack_slot():
		_start_telegraph(to_target)
		return
	if edge <= attack_trigger_range + wait_margin and not attack_slot_free():
		_wait_for_slot(edge)
		return
	desired_velocity = approach_direction(to_target) * data.move_speed
	anim_state = &"run"


## 進攻名額滿了:在攻擊距離外一點的圈上慢慢繞著目標走,等同伴收招。
func _wait_for_slot(edge: float) -> void:
	var ring := attack_trigger_range + wait_margin
	var radial := clampf((edge - ring) / 6.0, -1.0, 1.0)
	var dir := facing * radial + facing.orthogonal() * _circle_sign * 0.7 + surround_push() * 0.5
	if not CombatMath.arena_bounds(arena_margin).has_point(global_position + dir.normalized() * 8.0):
		_circle_sign = -_circle_sign
	desired_velocity = dir.limit_length(1.0) * data.move_speed * wait_speed_mult
	anim_state = &"run" if desired_velocity.length() > 2.0 else &"idle"


## 走向目標的方向:遠處斜著繞(側翼角度),近處和其他稻草人錯開角度(包圍)。
func approach_direction(to_target: Vector2) -> Vector2:
	var dist := to_target.length()
	if dist < 0.01:
		return Vector2.ZERO
	var dir := to_target / dist
	var far := clampf((dist - attack_trigger_range - 12.0) / maxf(flank_fade_distance, 1.0), 0.0, 1.0)
	dir = dir.rotated(_flank * far)
	if dist <= surround_radius + 24.0:
		dir = (dir + surround_push() * surround_strength).normalized()
	return dir


## 和其他圍著同一個目標的稻草人錯開角度:角度太接近時,往相反的切線方向讓開。
func surround_push() -> Vector2:
	if target == null:
		return Vector2.ZERO
	var center := target.global_position
	var mine := global_position - center
	if mine.length() < 0.01:
		return Vector2.ZERO
	var my_angle := mine.angle()
	var tangent := Vector2(-sin(my_angle), cos(my_angle))
	var push := 0.0
	for node in _enemies_cached():
		var other := node as ScarecrowEnemy
		if other == null or other == self or other.state != State.ACTIVE or other.target != target:
			continue
		var offset := other.global_position - center
		if offset.length() > surround_radius + 24.0:
			continue
		var diff := wrapf(my_angle - offset.angle(), -PI, PI)
		if absf(diff) >= surround_spacing:
			continue
		var side := signf(diff)
		if side == 0.0:
			side = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		push += side * (1.0 - absf(diff) / surround_spacing)
	return tangent * clampf(push, -1.5, 1.5)


func _start_telegraph(to_target: Vector2, call_friends: bool = true) -> void:
	phase = Phase.TELEGRAPH
	attacks_started += 1
	_tell_total = tell(telegraph_time)
	_phase_left = _tell_total
	_attack_dir = to_target.normalized() if to_target.length() > 0.01 else facing
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"
	_show_telegraph(AttackTelegraph.make_sector(attack_radius * visual_scale, _attack_dir,
			deg_to_rad(attack_half_angle_deg)))
	if call_friends:
		_call_pincer(target)


## 夾擊(AS7,後段關卡):同伴開始預警時,在攻擊距離附近等著的就一起出手(從不同方向)。
func join_attack(victim: Node2D) -> bool:
	if state != State.ACTIVE or phase != Phase.APPROACH or is_stunned() or victim == null or target != victim:
		return false
	var to_target := victim.global_position - global_position
	var edge := to_target.length() - radius_of(victim) - body_radius
	if edge > attack_trigger_range + DifficultyScaling.get_default().pincer_reach:
		return false
	if not claim_attack_slot():
		return false
	if to_target.length() > 0.01:
		facing = to_target.normalized()
	_start_telegraph(to_target, false)
	return true


func is_attacking_target(victim: Node2D) -> bool:
	return (phase == Phase.TELEGRAPH or phase == Phase.SWING) and target == victim


func _swing() -> void:
	_clear_telegraph()
	phase = Phase.SWING
	_phase_left = swing_time
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.position = _sprite_base_offset + _attack_dir * 2.0
	# 揮擊時往前踏一步(不穿牆,仍限制在場內)。
	global_position = CombatMath.clamp_to_bounds(global_position + _attack_dir * lunge_distance, arena_margin)
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
		_phase_left = rest(recover_time) * 0.5
	release_attack_slot()
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset
