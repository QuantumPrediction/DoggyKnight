class_name ShadowKnightEnemy
extends EnemyBase
## 影子騎士(v2.7 AW5,第六章 6-1 起,32×32):拿大盾牌的影子兵。數值在 data/enemies/shadow_knight.tres
## (揮劍傷害 = 接觸傷害),節奏在本場景的屬性欄。
##
## - 盾牌擋正面:盾牌朝著 shield_dir(地上畫一道淡藍色的弧,看得出哪邊是正面)。從正面(shield_half_angle_deg 以內)
##   打來的傷害 × shield_damage_mult(0.2,冒「鏘!」、播 guard),從側面或背後打才打得痛。
##   攻擊者的位置:金毛與同伴的 hit() 傳進來的位置;沒有位置的(把戲)當作從金毛那邊打來。
## - 慢慢轉身:盾牌每秒最多轉 shield_turn_deg 度面向目標(揮劍後喘氣時轉得更慢):繞到背後就打得痛。
## - 揮劍:目標在正前方、夠近、拿到近戰名額時,地上畫扇形預警(方向鎖定)swing_telegraph 秒,然後揮劍;
##   之後喘氣 recover_time 秒。
## - 倒下:播 down(單膝跪下),然後化成一團影子霧散掉(BitsScatter.MIST),不是受傷。

enum Phase { ADVANCE, TELL, RECOVER }

const SHIELD := Color(0.6, 0.75, 1.0)
const MIST_COLORS: Array[Color] = [Color(0.35, 0.3, 0.5, 0.9), Color(0.55, 0.5, 0.75, 0.85)]

@export_group("盾牌")
@export var shield_half_angle_deg: float = 70.0
@export var shield_damage_mult: float = 0.2
@export var shield_turn_deg: float = 100.0       ## 每秒最多轉幾度(繞著跑比這個快)
@export var shield_turn_recover_deg: float = 35.0
@export var guard_flash_time: float = 0.25
@export var clang_cooldown: float = 0.3
@export_group("揮劍")
@export var approach_stop: float = 18.0
@export var swing_start: float = 24.0            ## 和目標(身體邊緣)這麼近就準備揮劍
@export var swing_reach: float = 24.0            ## 扇形半徑 = 打中範圍
@export var swing_half_angle_deg: float = 55.0
@export var swing_aim_deg: float = 50.0          ## 目標在盾牌正前方這個角度內才揮劍
@export var swing_telegraph: float = 0.7
@export var recover_time: float = 0.9
@export var swing_cooldown_min: float = 1.4
@export var swing_cooldown_max: float = 2.2
@export_group("倒下")
@export var mist_at: float = 0.5

var phase: Phase = Phase.ADVANCE
var shield_dir: Vector2 = Vector2.DOWN
var blocked_hits: int = 0
var swings: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _tell_total: float = 0.7
var _swing_dir: Vector2 = Vector2.DOWN
var _guard_left: float = 0.0
var _hit_from: Vector2 = Vector2.INF
var _clang_ready_at: float = 0.0
var _mist_done: bool = false


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_activated() -> void:
	phase = Phase.ADVANCE
	_cooldown_left = rest(rng.randf_range(0.6, 1.2))
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 0.5:
			shield_dir = to_target.normalized()


## from 打來的攻擊是不是打在盾牌上(正面)。
func is_front(from_position: Vector2) -> bool:
	var to := from_position - global_position
	if to.length() < 0.5:
		return true
	return absf(shield_dir.angle_to(to)) <= deg_to_rad(shield_half_angle_deg)


func hit(amount: int, from_position: Vector2, knockback_speed: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> void:
	_hit_from = from_position
	super(amount, from_position, knockback_speed, style)
	_hit_from = Vector2.INF


func take_damage(amount: int) -> void:
	if state == State.ACTIVE and amount > 0:
		var from := _hit_from if _hit_from != Vector2.INF else _attacker_guess()
		if is_front(from):
			blocked_hits += 1
			amount = maxi(1, roundi(float(amount) * shield_damage_mult))
			_guard_left = guard_flash_time
			if _age >= _clang_ready_at:
				_clang_ready_at = _age + clang_cooldown
				clang_fx(from, SHIELD)
	super(amount)


## 正面打來的推不動(擋在盾牌上)。
func apply_knockback(from_position: Vector2, speed: float) -> void:
	if is_front(from_position):
		return
	super(from_position, speed)


func _attacker_guess() -> Vector2:
	if not is_inside_tree():
		return global_position + shield_dir
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	return player.global_position if player != null else global_position + shield_dir


func _ai(delta: float) -> void:
	_guard_left = maxf(0.0, _guard_left - delta)
	match phase:
		Phase.ADVANCE:
			_turn_shield(delta, shield_turn_deg)
			_cooldown_left -= delta
			if target == null:
				desired_velocity = Vector2.ZERO
				anim_state = &"idle"
			else:
				var to_target := target.global_position - global_position
				var gap := to_target.length() - body_radius - radius_of(target)
				desired_velocity = to_target.normalized() * data.move_speed if gap > approach_stop - body_radius else Vector2.ZERO
				anim_state = &"run" if desired_velocity.length() > 1.0 else &"idle"
				var aimed := absf(shield_dir.angle_to(to_target)) <= deg_to_rad(swing_aim_deg)
				if _cooldown_left <= 0.0 and gap <= swing_start and aimed and claim_attack_slot():
					_start_tell()
			if _guard_left > 0.0:
				anim_state = &"guard"
		Phase.TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if _phase_left <= 0.0:
				_swing()
		Phase.RECOVER:
			_turn_shield(delta, shield_turn_recover_deg)
			desired_velocity = Vector2.ZERO
			anim_state = &"guard" if _guard_left > 0.0 else &"idle"
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.ADVANCE
	facing = Vector2(signf(shield_dir.x), 0) if absf(shield_dir.x) > 0.1 else facing
	queue_redraw()


## 盾牌慢慢轉向目標(每秒最多 deg_per_sec 度)。
func _turn_shield(delta: float, deg_per_sec: float) -> void:
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() < 0.5:
		return
	var angle := shield_dir.angle_to(to_target.normalized())
	var step := deg_to_rad(deg_per_sec) * delta
	shield_dir = shield_dir.rotated(clampf(angle, -step, step)).normalized()


func _start_tell() -> void:
	phase = Phase.TELL
	swings += 1
	_swing_dir = shield_dir
	_tell_total = tell(swing_telegraph)
	_phase_left = _tell_total
	desired_velocity = Vector2.ZERO
	_play(&"attack", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_sector(swing_reach + body_radius, _swing_dir, deg_to_rad(swing_half_angle_deg)))
	_call_pincer(target)
	CombatFx.sfx(&"swing", &"boss_warning", -10.0)


func _swing() -> void:
	_clear_telegraph()
	if sprite != null:
		sprite.play()
	hit_victims_in_sector(global_position, _swing_dir, swing_reach + body_radius, deg_to_rad(swing_half_angle_deg),
			data.contact_damage)
	CombatFx.spawn(self, &"hit_spark", global_position + _swing_dir * swing_reach, _swing_dir.angle(), Vector2.ONE * 0.9,
			Color(0.75, 0.6, 1.0))
	CombatFx.sfx(&"swing", &"whoosh", -4.0)
	phase = Phase.RECOVER
	_phase_left = rest(recover_time)
	_cooldown_left = rest(rng.randf_range(swing_cooldown_min, swing_cooldown_max))
	release_attack_slot()


func is_attacking_target(victim: Node2D) -> bool:
	return target == victim and phase == Phase.TELL


func join_attack(victim: Node2D) -> bool:
	if phase != Phase.ADVANCE or target != victim or state != State.ACTIVE:
		return false
	var gap := global_position.distance_to(victim.global_position) - body_radius - radius_of(victim)
	if gap > swing_start + 8.0 or not claim_attack_slot():
		return false
	_start_tell()
	return true


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELL:
		phase = Phase.RECOVER
		_phase_left = rest(recover_time) * 0.5
		_cooldown_left = maxf(_cooldown_left, rest(swing_cooldown_min))
		if sprite != null and not sprite.is_playing():
			sprite.play()
	release_attack_slot()


func _is_committed() -> bool:
	return phase == Phase.TELL


func _uses_separation() -> bool:
	return phase != Phase.TELL


func _draw() -> void:
	super()
	if state != State.ACTIVE:
		return
	# 盾牌的方向:地上一道淡藍色的弧(被擋下時亮一下)。
	var a := shield_dir.angle()
	var half := deg_to_rad(shield_half_angle_deg)
	var bright := 0.35 + (0.5 if _guard_left > 0.0 else 0.0)
	draw_set_transform(Vector2(0, _frame_size.y * 0.3), 0.0, Vector2(1.0, 0.6))
	draw_arc(Vector2.ZERO, body_radius + 6.0, a - half, a + half, 12, Color(SHIELD, bright), 2.0)
	draw_set_transform(Vector2.ZERO)


# --- 倒下:跪下 → 化成影子霧 ------------------------------------------------------------

func _on_died() -> void:
	_mist_done = false
	_flash_left = 0.0
	_set_flash(0.0)
	_play(&"down", true)
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 4), true)


func _tick_death(delta: float) -> void:
	_death_left -= delta
	var t := 1.0 - clampf(_death_left / maxf(death_time, 0.001), 0.0, 1.0)
	if t >= mist_at and not _mist_done:
		_mist_done = true
		BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.2), BitsScatter.Kind.MIST, MIST_COLORS, 10)
	if sprite != null and t >= mist_at:
		var k := (t - mist_at) / maxf(1.0 - mist_at, 0.001)
		sprite.modulate = Color(tint, 1.0 - k)
	if _death_left <= 0.0:
		queue_free()
