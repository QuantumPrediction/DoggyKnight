class_name SpellbookEnemy
extends EnemyBase
## 魔法書(v2.6 AV2,2-3 起):飄在空中,和目標保持 keep_min 至 keep_max(70 至 110)像素;
## 金毛走近就往後飄(避開牆角)。數值在 data/enemies/spellbook.tres,光球在
## data/enemies/projectiles/magic_orb.tres,節奏在本場景的屬性欄。
##
## - 施法:停下翻開書(cast),地上畫出 3 條(困難模式或後段關卡 5 條)扇形的紅色預警線,
##   方向在預警開始時就鎖定;cast_telegraph 秒後沿每條線射出一顆光球(magic_orb)。
##   相鄰兩條線的角度 fan_step_deg 夠大,在 keep_min 的距離上光球之間留有可以鑽過的空隙
##   (gap_at() 算空隙的寬度,測試會檢查)。
## - 同時施法的魔法書受場地的 ranged 名額限制(和弓兵一樣)。
## - 被鬥牛犬挑釁時改打鬥牛犬,也不後退;舉盾的鬥牛犬擋得住光球。
## - 倒下:書闔起來,書頁翻飛飄落(BitsScatter.PAGE),不是受傷。

enum Phase { MOVE, CAST, RELEASE }

const MAGIC_ORB: ProjectileData = preload("res://data/enemies/projectiles/magic_orb.tres")
const PAGE_COLORS: Array[Color] = [Color("f3ead2"), Color("d9cba6"), Color("b48ae8")]
const MAGIC := Color(0.72, 0.42, 1.0)

@export_group("距離")
@export var keep_min: float = 70.0
@export var keep_max: float = 110.0
@export var retreat_distance: float = 60.0
@export var retreat_speed_mult: float = 1.2
@export var strafe_speed_mult: float = 0.5
@export var strafe_switch_min: float = 1.2
@export var strafe_switch_max: float = 2.4
@export var float_height: float = 5.0            ## 飄在空中的高度(圖往上提)
@export var bob_amount: float = 1.5

@export_group("施法")
@export var projectile: ProjectileData = MAGIC_ORB
@export var cast_telegraph: float = 0.85         ## 預警線出現到射出的秒數(× 難度)
@export var orb_count: int = 3
@export var orb_count_strong: int = 5            ## 困難模式或後段關卡
@export var strong_from_level: int = 4           ## 故事模式第幾關起(0 起算)用 orb_count_strong
@export var strong_from_chapter: int = 3         ## 故事模式第幾章起一律用 orb_count_strong
@export var fan_step_deg: float = 24.0           ## 相鄰兩顆光球的角度
@export var cast_range: float = 150.0
@export var cast_interval: float = 3.2           ## 射出後多久才能再施法(× 難度)
@export var cast_interval_jitter: float = 0.15
@export var first_cast_min: float = 1.0
@export var first_cast_max: float = 1.8
@export var release_time: float = 0.35

var phase: Phase = Phase.MOVE
var casts: int = 0
var orbs_fired: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _cast_total: float = 0.85
var _dirs: Array[Vector2] = []
var _lengths: Array[float] = []
var _lines: Array[AttackTelegraph] = []
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0


func attack_role() -> StringName:
	return DifficultyScaling.RANGED


## 這一關射幾顆光球(困難模式、後段關卡或第三章:orb_count_strong)。
func current_orb_count() -> int:
	var strong := GameState.difficulty == &"hard"
	if GameState.mode == &"story":
		strong = strong or GameState.level_index >= strong_from_level or GameState.chapter >= strong_from_chapter
	return orb_count_strong if strong else orb_count


## 在距離 distance 的地方,相鄰兩顆光球之間「角色中心可以站的空隙」有多寬(像素)。
func gap_at(distance: float, victim_radius: float = 6.0) -> float:
	var chord := 2.0 * distance * sin(deg_to_rad(fan_step_deg) * 0.5)
	return chord - 2.0 * (projectile.hit_radius + victim_radius)


func _on_ready() -> void:
	_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_strafe_left = rng.randf_range(strafe_switch_min, strafe_switch_max)
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.MOVE
	_cooldown_left = rng.randf_range(first_cast_min, first_cast_max)


func _ai(delta: float) -> void:
	_bob()
	match phase:
		Phase.MOVE:
			_cooldown_left -= delta
			_move_around(delta)
			if target != null and _wants_to_cast():
				_start_cast()
		Phase.CAST:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			_phase_left -= delta
			var progress := 1.0 - _phase_left / maxf(_cast_total, 0.001)
			for line in _lines:
				if is_instance_valid(line):
					line.progress = progress
			if _phase_left <= 0.0:
				_release()
		Phase.RELEASE:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.MOVE
				anim_state = &"idle"


func _bob() -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 3.0) * bob_amount))
	if sprite != null:
		sprite.position = _sprite_base_offset


func _wants_to_cast() -> bool:
	if _cooldown_left > 0.0:
		return false
	if global_position.distance_to(target.global_position) > cast_range:
		return false
	if EnemyProjectile.flying_count(self) + current_orb_count() > CombatFx.feel().max_enemy_projectiles:
		return false
	return claim_attack_slot()


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
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe_left = rng.randf_range(strafe_switch_min, strafe_switch_max)
			_strafe_sign = -_strafe_sign
		var tangent := facing.orthogonal() * _strafe_sign
		if not CombatMath.arena_bounds(arena_margin).has_point(global_position + tangent * 10.0):
			_strafe_sign = -_strafe_sign
			tangent = -tangent
		dir = tangent
		speed *= strafe_speed_mult
	desired_velocity = dir * speed
	anim_state = &"run" if desired_velocity.length() > 1.0 else &"idle"


## 後退的方向:正後方;前面是牆就斜著退或沿著牆飄。
func _escape_direction(away: Vector2) -> Vector2:
	var best := away
	var best_score := -INF
	for angle: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var dir := away.rotated(angle)
		var inside := CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 16.0)
		var score := dir.dot(away) + (0.0 if inside else -3.0)
		if score > best_score:
			best_score = score
			best = dir
	return best


# --- 施法 -----------------------------------------------------------------------

func _start_cast() -> void:
	phase = Phase.CAST
	casts += 1
	_cast_total = tell(cast_telegraph)
	_phase_left = _cast_total
	desired_velocity = Vector2.ZERO
	anim_state = &"cast"
	_play(&"cast", true)
	var to_target := target.global_position - global_position
	var aim := to_target.normalized() if to_target.length() > 0.5 else facing
	facing = aim
	_clear_lines()
	_dirs.clear()
	_lengths.clear()
	var n := maxi(1, current_orb_count())
	var step := deg_to_rad(fan_step_deg)
	for i in n:
		var dir := aim.rotated((float(i) - float(n - 1) * 0.5) * step)
		var length := EnemyProjectile.travel_length(global_position, dir, projectile.max_range)
		_dirs.append(dir)
		_lengths.append(length)
		var line := AttackTelegraph.make_line(dir, length, projectile.telegraph_width())
		add_child(line)
		_lines.append(line)
	CombatFx.ring(self, global_position + _sprite_base_offset, 2.0, 12.0, 0.3, Color(MAGIC, 0.8), 1.0)
	CombatFx.sfx(&"magic", &"boss_warning", -8.0)


func _release() -> void:
	_clear_lines()
	release_attack_slot()
	phase = Phase.RELEASE
	_phase_left = release_time
	anim_state = &"attack"
	_play(&"attack", true)
	var jitter := 1.0 + rng.randf_range(-cast_interval_jitter, cast_interval_jitter)
	_cooldown_left = rest(cast_interval) * jitter
	var dmg := data.contact_damage if projectile.damage <= 0 else scaled_damage(projectile.damage)
	for i in _dirs.size():
		EnemyProjectile.launch(self, projectile, global_position, _dirs[i], _lengths[i], dmg,
				projectile_speed_mult(), self)
		orbs_fired += 1
	CombatFx.sfx(&"magic", &"whoosh", -4.0)


func _clear_lines() -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()


func _is_committed() -> bool:
	return phase == Phase.CAST


func _cancel_attack() -> void:
	super()
	_clear_lines()
	if phase == Phase.CAST:
		phase = Phase.MOVE
		_cooldown_left = maxf(_cooldown_left, rest(cast_interval) * 0.5)
	release_attack_slot()


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.PAGE, PAGE_COLORS, 9)
