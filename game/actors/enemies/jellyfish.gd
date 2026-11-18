class_name JellyfishEnemy
extends EnemyBase
## 電電水母(v2.7 AW1,第四章 4-2 起,24×24):半透明、會發光,慢慢飄向目標。
## 數值在 data/enemies/jellyfish.tres(放電傷害 = 接觸傷害),節奏在本場景的屬性欄。
##
## - 放電:離目標 zap_trigger 以內(而且拿到近戰名額)就停下,地上以自己為中心亮預警圈
##   zap_telegraph 秒(位置固定),然後放電(圈內的角色受傷,ZapFx 小閃電)。看到圈就走出去。
##   放完電休息 zap_recover 秒(反擊時機),zap_cooldown 秒內不再放電。
## - 被吠叫震懾時電流消散,重新慢慢飄。
## - 倒下:縮成一團冒泡泡,「啵」地散掉(BitsScatter.BUBBLE),不是受傷。

enum Phase { DRIFT, CHARGE, REST }

const GLOW := Color(0.6, 0.9, 1.0)
const BUBBLE_COLORS: Array[Color] = [Color(0.85, 0.75, 1.0, 0.9), Color(0.6, 0.9, 1.0, 0.9)]

@export_group("飄")
@export var float_height: float = 6.0
@export var bob_amount: float = 2.0
@export var wobble: float = 0.6                  ## 飄來飄去的幅度(弧度)
@export_group("放電")
@export var zap_trigger: float = 30.0            ## 和目標(中心)這麼近就準備放電
@export var zap_radius: float = 24.0             ## 預警圈半徑 = 放電範圍
@export var zap_hit_margin: float = 2.0
@export var zap_telegraph: float = 0.8           ## 預警圈秒數(× 難度)
@export var zap_recover: float = 0.9
@export var zap_cooldown_min: float = 2.4
@export var zap_cooldown_max: float = 3.4
@export var first_zap_min: float = 0.8
@export var first_zap_max: float = 1.6

var phase: Phase = Phase.DRIFT
var zaps: int = 0
var zaps_landed: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _tell_total: float = 0.8
var _wobble_phase: float = 0.0


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_ready() -> void:
	_wobble_phase = rng.randf() * TAU
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.DRIFT
	_cooldown_left = rest(rng.randf_range(first_zap_min, first_zap_max))


func _ai(delta: float) -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 2.4 + _wobble_phase) * bob_amount))
	if sprite != null:
		var shiver := Vector2(sin(_age * 60.0) * 0.6, 0).round() if phase == Phase.CHARGE else Vector2.ZERO
		sprite.position = _sprite_base_offset + shiver
	match phase:
		Phase.DRIFT:
			_cooldown_left -= delta
			if target == null:
				desired_velocity = Vector2.ZERO
				anim_state = &"idle"
				return
			var to_target := target.global_position - global_position
			var dist := to_target.length()
			if dist > 0.5:
				facing = to_target / dist
			if _cooldown_left <= 0.0 and dist <= zap_trigger + body_radius and claim_attack_slot():
				_start_charge()
				return
			var dir := facing.rotated(sin(_age * 1.7 + _wobble_phase) * wobble)
			desired_velocity = dir * data.move_speed if dist > 12.0 else Vector2.ZERO
			anim_state = &"run"
		Phase.CHARGE:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if _phase_left <= 0.0:
				_zap()
		Phase.REST:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			_phase_left -= delta
			if _phase_left <= 0.0:
				phase = Phase.DRIFT


func _start_charge() -> void:
	phase = Phase.CHARGE
	zaps += 1
	_tell_total = tell(zap_telegraph)
	_phase_left = _tell_total
	desired_velocity = Vector2.ZERO
	_play(&"attack", true)
	_show_telegraph(AttackTelegraph.make_circle(zap_radius))
	_call_pincer(target)
	CombatFx.sfx(&"zap_charge", &"boss_warning", -10.0)


func _zap() -> void:
	_clear_telegraph()
	release_attack_slot()
	# 角色中心在圈內(離圈邊 zap_hit_margin 以內)才算打中:看到的圈 = 打中範圍。
	for victim in victims():
		if global_position.distance_to(victim.global_position) <= zap_radius + zap_hit_margin:
			victim.call(&"take_damage", data.contact_damage)
			zaps_landed += 1
	_play(&"zap", true)
	ZapFx.zap(self, global_position, zap_radius)
	CombatFx.ring(self, global_position, 3.0, zap_radius + 2.0, 0.22, Color(GLOW, 0.95), 2.0)
	CombatFx.sfx(&"zap", &"magic", -4.0)
	phase = Phase.REST
	_phase_left = rest(zap_recover)
	_cooldown_left = rest(rng.randf_range(zap_cooldown_min, zap_cooldown_max))


func is_attacking_target(victim: Node2D) -> bool:
	return target == victim and phase == Phase.CHARGE


func _cancel_attack() -> void:
	super()
	if phase == Phase.CHARGE:
		phase = Phase.REST
		_phase_left = rest(zap_recover) * 0.5
		_cooldown_left = maxf(_cooldown_left, rest(zap_cooldown_min) * 0.5)
	release_attack_slot()


func _is_committed() -> bool:
	return phase == Phase.CHARGE


func _uses_separation() -> bool:
	return phase == Phase.DRIFT


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.BUBBLE, BUBBLE_COLORS, 10)
	CombatFx.particles(self, &"bubble_pop", global_position, false)
