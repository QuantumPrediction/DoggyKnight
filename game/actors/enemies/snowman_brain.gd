class_name SnowmanBrain
extends RefCounted
## 雪人兵的動作(v2.7 AW3)。雪人兵(SnowmanEnemy)與中頭目雪人隊長(SnowmanEliteBoss)共用,數值在 SnowmanTuning。
##
## - 和目標保持 keep_min 至 keep_max 的距離(太近就往後退,避開牆角;在範圍內就左右慢慢走)。
## - 拋雪球:停下舉起雪球(throw),落點(目標現在的位置;一次幾顆時左右散開)先出現影子與紅圈,
##   throw_telegraph 秒後雪球沿拋物線飛過去(LobbedShot),落地時圈內的角色受傷。
##   落點在出手前就固定:看到影子就走開。
## - 同時瞄準的雪人受場地的 ranged 名額限制(和弓兵、魔法書一樣)。

enum Phase { MOVE, WINDUP, RELEASE }

const SNOWBALL: ProjectileData = preload("res://data/enemies/projectiles/snowball.tres")

var host: EnemyBase
var tuning: SnowmanTuning
var projectile: ProjectileData = SNOWBALL
var phase: Phase = Phase.MOVE
var throws: int = 0
var balls_thrown: int = 0
var extra_balls: int = 0                        ## 頭目第二階段:一次多丟幾顆
var tell_mult: float = 1.0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0
var _shots: Array[LobbedShot] = []


func _init(p_host: EnemyBase, p_tuning: SnowmanTuning) -> void:
	host = p_host
	tuning = p_tuning if p_tuning != null else SnowmanTuning.new()


func on_ready() -> void:
	_strafe_sign = 1.0 if host.rng.randf() < 0.5 else -1.0
	_strafe_left = host.rng.randf_range(tuning.strafe_switch_min, tuning.strafe_switch_max)


func on_activated() -> void:
	phase = Phase.MOVE
	_cooldown_left = host.rest(host.rng.randf_range(tuning.first_throw_min, tuning.first_throw_max))


func is_committed() -> bool:
	return phase == Phase.WINDUP


func uses_separation() -> bool:
	return phase == Phase.MOVE


func ball_count() -> int:
	return maxi(1, tuning.balls_per_throw + extra_balls)


func ai(delta: float) -> void:
	match phase:
		Phase.MOVE:
			_cooldown_left -= delta
			_move_around(delta)
			if host.target != null and _wants_to_throw():
				start_throw()
		Phase.WINDUP:
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"throw"
			_phase_left -= delta
			if _phase_left <= 0.0:
				_release()
		Phase.RELEASE:
			host.desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.MOVE
				host.anim_state = &"idle"


func _wants_to_throw() -> bool:
	if _cooldown_left > 0.0:
		return false
	if host.global_position.distance_to(host.target.global_position) > tuning.throw_range:
		return false
	return host.claim_attack_slot()


func _move_around(delta: float) -> void:
	var target := host.target
	if target == null:
		host.desired_velocity = Vector2.ZERO
		host.anim_state = &"idle"
		return
	var to_target := target.global_position - host.global_position
	var dist := to_target.length()
	if dist > 0.01:
		host.facing = to_target / dist
	var away := -host.facing
	var speed := host.data.move_speed
	var taunted := target.is_in_group(EnemyBase.COMPANION_GROUP)
	var dir := Vector2.ZERO
	if not taunted and dist < tuning.retreat_distance:
		dir = _escape_direction(away)
		speed *= tuning.retreat_speed_mult
	elif dist > tuning.keep_max:
		dir = host.facing
	elif dist < tuning.keep_min and not taunted:
		dir = _escape_direction(away)
	else:
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe_left = host.rng.randf_range(tuning.strafe_switch_min, tuning.strafe_switch_max)
			_strafe_sign = -_strafe_sign
		var tangent := host.facing.orthogonal() * _strafe_sign
		if not CombatMath.arena_bounds(host.arena_margin).has_point(host.global_position + tangent * 10.0):
			_strafe_sign = -_strafe_sign
			tangent = -tangent
		dir = tangent
		speed *= tuning.strafe_speed_mult
	host.desired_velocity = dir * speed
	host.anim_state = &"run" if host.desired_velocity.length() > 1.0 else &"idle"


func _escape_direction(away: Vector2) -> Vector2:
	var best := away
	var best_score := -INF
	for angle: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var dir := away.rotated(angle)
		var inside := CombatMath.arena_bounds(host.arena_margin).has_point(host.global_position + dir * 16.0)
		var score := dir.dot(away) + (0.0 if inside else -3.0)
		if score > best_score:
			best_score = score
			best = dir
	return best


## 落點:第一顆在目標腳下;一次幾顆時,其他的在目標左右(和投擲方向垂直)散開。
func landing_points(center: Vector2, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var aim := (center - host.global_position).normalized()
	if aim.length() < 0.5:
		aim = Vector2.DOWN
	var side := aim.orthogonal()
	for i in count:
		var k := 0.0
		if i > 0:
			k = floorf(float(i + 1) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		points.append(CombatMath.clamp_to_arena(center + side * k * tuning.ball_spread, projectile.hit_radius))
	return points


func start_throw() -> void:
	var target := host.target
	phase = Phase.WINDUP
	throws += 1
	var windup := host.tell(tuning.throw_telegraph) * tell_mult
	_phase_left = windup
	host.desired_velocity = Vector2.ZERO
	host._play(&"throw", true)
	if host.sprite != null:
		host.sprite.pause()
	var center := target.global_position if target != null else host.global_position + host.facing * 60.0
	var dmg := host.scaled_damage(projectile.damage) if projectile.damage > 0 else host.data.contact_damage
	_prune()
	for point in landing_points(center, ball_count()):
		var shot := LobbedShot.lob(host, projectile, host.global_position + Vector2(0, -10), point, dmg, windup,
				tuning.min_flight, host.projectile_speed_mult(), tuning.arc_height)
		if shot != null:
			shot.splash = &"snow"
			_shots.append(shot)
	CombatFx.sfx(&"snow_pack", &"swing", -10.0)


func _release() -> void:
	host.release_attack_slot()
	phase = Phase.RELEASE
	_phase_left = tuning.release_time
	balls_thrown += ball_count()
	host._play(&"attack", true)
	if host.sprite != null:
		host.sprite.play()
	var jitter := 1.0 + host.rng.randf_range(-tuning.throw_interval_jitter, tuning.throw_interval_jitter)
	_cooldown_left = host.rest(tuning.throw_interval) * jitter
	CombatFx.sfx(&"whoosh", &"swing", -6.0)


func pending_shots() -> Array[LobbedShot]:
	_prune()
	return _shots


func _prune() -> void:
	var alive: Array[LobbedShot] = []
	for s in _shots:
		if is_instance_valid(s) and s.is_pending():
			alive.append(s)
	_shots = alive


## 被吠叫震懾:手上的雪球掉了(還沒丟出去的落點影子一起消失)。
func cancel() -> void:
	if phase == Phase.WINDUP:
		for s in pending_shots():
			s.cancel()
		phase = Phase.MOVE
		_cooldown_left = maxf(_cooldown_left, host.rest(tuning.throw_interval) * 0.5)
		if host.sprite != null and not host.sprite.is_playing():
			host.sprite.play()
	host.release_attack_slot()


## 倒下:還在飛的雪球一起散掉。
func fizzle() -> void:
	for s in pending_shots():
		s.fizzle()
	_shots.clear()
