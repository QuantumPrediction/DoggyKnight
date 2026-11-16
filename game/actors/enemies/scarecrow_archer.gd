class_name ArcherEnemy
extends EnemyBase
## 稻草人弓兵(AS1):遠程。數值在 data/enemies/scarecrow_archer.tres(生命 18、箭傷害 7、速度 24、經驗 2),
## 動作節奏在本場景的屬性欄,箭在 data/enemies/projectiles/arrow.tres(速度約 120、射程約 160)。
##
## - 和目標保持 keep_min 至 keep_max(60 至 90)像素:太遠就走近,在範圍內慢慢橫移;
##   金毛靠近(retreat_distance 以內)就往後退(避開牆角)。
## - 射箭:停下、拉弓(aim 動畫),地上畫出紅色預警線 aim_time(0.7)秒;前 aim_track_ratio
##   的時間預警線跟著目標轉,之後鎖定,箭沿著鎖定的線飛(站著不動會被射中,看到線就走開)。
## - 同時瞄準的弓兵有上限(場地的 ranged 名額,隨關卡增加)。
## - 交叉火力(AS7,後段關卡):近戰同伴對同一個目標出招時,冷卻快好的弓兵立刻瞄準。
## - 被鬥牛犬挑釁時改射鬥牛犬,而且不後退(舉盾的鬥牛犬擋得住箭:同伴的價值)。
## - 倒下時噴 straw_bits(和稻草人兵一樣)。

enum Phase { MOVE, AIM, RELEASE }

const ARROW: ProjectileData = preload("res://data/enemies/projectiles/arrow.tres")

@export_group("距離")
@export var keep_min: float = 60.0
@export var keep_max: float = 90.0
@export var retreat_distance: float = 52.0      ## 金毛比這個近就後退
@export var retreat_speed_mult: float = 1.15
@export var strafe_speed_mult: float = 0.45
@export var strafe_switch_min: float = 1.2
@export var strafe_switch_max: float = 2.6

@export_group("射箭")
@export var projectile: ProjectileData = ARROW
@export var aim_time: float = 0.7                ## 預警線出現到放箭的秒數(× 難度)
@export var aim_track_ratio: float = 0.45        ## 預警的前這麼多比例,預警線跟著目標轉;之後鎖定
@export var shoot_range: float = 150.0           ## 目標在這個距離內才瞄準
@export var shot_interval: float = 2.6           ## 放箭後多久才能再瞄準(× 難度)
@export var shot_interval_jitter: float = 0.15   ## 每次 ± 這個比例,幾隻弓兵才不會同時放箭
@export var first_shot_min: float = 0.8
@export var first_shot_max: float = 1.6
@export var release_time: float = 0.3            ## 放箭後的收弓動作

var phase: Phase = Phase.MOVE
var shots_fired: int = 0
var aims_started: int = 0
var crossfire_aims: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _aim_total: float = 0.7
var _aim_dir: Vector2 = Vector2.LEFT
var _aim_length: float = 100.0
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0


func attack_role() -> StringName:
	return DifficultyScaling.RANGED


func _on_ready() -> void:
	_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_strafe_left = rng.randf_range(strafe_switch_min, strafe_switch_max)


func _on_activated() -> void:
	phase = Phase.MOVE
	_cooldown_left = rng.randf_range(first_shot_min, first_shot_max)


func _ai(delta: float) -> void:
	match phase:
		Phase.MOVE:
			_cooldown_left -= delta
			_move_around(delta)
			if target != null and _wants_to_shoot():
				_start_aim()
		Phase.AIM:
			desired_velocity = Vector2.ZERO
			anim_state = &"aim"
			_phase_left -= delta
			var progress := 1.0 - _phase_left / maxf(_aim_total, 0.001)
			if progress < aim_track_ratio and _is_valid_victim(target):
				_aim_at(target.global_position)
			if _telegraph != null:
				_telegraph.progress = progress
			if _phase_left <= 0.0:
				_release()
		Phase.RELEASE:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.MOVE
				anim_state = &"idle"


## 冷卻好了、目標在射程內、拿得到名額;或交叉火力(近戰同伴正在打同一個目標)。
func _wants_to_shoot() -> bool:
	var dist := global_position.distance_to(target.global_position)
	if dist > shoot_range:
		return false
	var ready := _cooldown_left <= 0.0
	var crossfire := false
	if not ready and _arena_ok() and arena.has_method(&"melee_attack_on"):
		var window := DifficultyScaling.get_default().crossfire_ready
		crossfire = _cooldown_left <= window and bool(arena.call(&"melee_attack_on", target))
	if not ready and not crossfire:
		return false
	if not claim_attack_slot():
		return false
	if crossfire:
		crossfire_aims += 1
	return true


func _move_around(delta: float) -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > 0.01:
		facing = to_target / dist
	var away := -facing
	var speed := data.move_speed
	var taunted := target.is_in_group(COMPANION_GROUP)
	var dir := Vector2.ZERO
	if not taunted and dist < retreat_distance:
		dir = _escape_direction(away)
		speed *= retreat_speed_mult
	elif dist > keep_max:
		dir = facing
	elif dist < keep_min and not taunted:
		dir = _escape_direction(away)
	else:
		# 在喜歡的距離:慢慢橫移,看起來在找射擊角度;撞到牆就換方向。
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe_left = rng.randf_range(strafe_switch_min, strafe_switch_max)
			_strafe_sign = -_strafe_sign
		var tangent := facing.orthogonal() * _strafe_sign
		if not _room_ahead(tangent, 10.0):
			_strafe_sign = -_strafe_sign
			tangent = -tangent
		dir = tangent
		speed *= strafe_speed_mult
	desired_velocity = dir * speed
	anim_state = &"run" if desired_velocity.length() > 1.0 else &"idle"


## 後退的方向:正後方;前面是牆就斜著退或沿著牆走(挑離目標最遠、又不撞牆的方向)。
func _escape_direction(away: Vector2) -> Vector2:
	var best := away
	var best_score := -INF
	for angle: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var dir := away.rotated(angle)
		var probe := global_position + dir * 16.0
		var inside := CombatMath.arena_bounds(arena_margin).has_point(probe)
		var score := (dir.dot(away)) + (0.0 if inside else -3.0)
		if score > best_score:
			best_score = score
			best = dir
	return best


func _room_ahead(dir: Vector2, distance: float) -> bool:
	return CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * distance)


func _start_aim() -> void:
	phase = Phase.AIM
	aims_started += 1
	_aim_total = tell(aim_time)
	_phase_left = _aim_total
	desired_velocity = Vector2.ZERO
	anim_state = &"aim"
	_play(&"aim", true)
	_show_telegraph(AttackTelegraph.make_line(facing, 10.0, projectile.telegraph_width()))
	_aim_at(target.global_position)


func _aim_at(point: Vector2) -> void:
	var to_point := point - global_position
	if to_point.length() > 0.5:
		_aim_dir = to_point.normalized()
		facing = _aim_dir
	_aim_length = EnemyProjectile.travel_length(global_position, _aim_dir, projectile.max_range)
	if _telegraph != null:
		_telegraph.direction = _aim_dir
		_telegraph.length = _aim_length


func _release() -> void:
	_clear_telegraph()
	release_attack_slot()
	phase = Phase.RELEASE
	_phase_left = release_time
	anim_state = &"attack"
	_play(&"attack", true)
	shots_fired += 1
	var jitter := 1.0 + rng.randf_range(-shot_interval_jitter, shot_interval_jitter)
	_cooldown_left = rest(shot_interval) * jitter
	var dmg := data.contact_damage if projectile.damage <= 0 else scaled_damage(projectile.damage)
	EnemyProjectile.launch(self, projectile, global_position, _aim_dir, _aim_length, dmg,
			projectile_speed_mult(), self)
	CombatFx.sfx(&"arrow_shot", &"swing", -4.0)


func is_attacking_target(_victim: Node2D) -> bool:
	return false


func _is_committed() -> bool:
	return phase == Phase.AIM


func _cancel_attack() -> void:
	super()
	if phase == Phase.AIM:
		phase = Phase.MOVE
		_cooldown_left = maxf(_cooldown_left, rest(shot_interval) * 0.5)
	release_attack_slot()
