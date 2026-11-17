class_name FoxfireEnemy
extends EnemyBase
## 狐火(v2.6 AV3,3-1 起):成群出現(B 線一次生成 3 至 5 隻)、飄著追蹤目標、很脆(任何一下就打散)。
## 數值在 data/enemies/foxfire.tres(爆炸傷害 = 接觸傷害),節奏在本場景的屬性欄。
##
## - 追蹤:每一隻有自己的角度,從不同方向圍上來(不會疊成一團)。
## - 接近目標(burst_trigger 以內)或追了 max_chase_time 秒:停下,地上亮預警圈 warn_time 秒
##   (位置固定,不再跟著走),然後爆開(圈內的角色受傷)。看到圈就走出去。
## - 爆開的狐火就消失了:不掉經驗、不發 enemy_died(不是被打倒)。被打倒的狐火不會爆開(只是「噗」地散掉)。

enum Phase { CHASE, WARN }

const FLAME := Color(0.55, 0.85, 1.0)
const FLAME_HOT := Color(0.85, 0.95, 1.0)

@export_group("追蹤")
@export var orbit_spread: float = 12.0          ## 各自瞄準目標旁邊多遠(從不同方向圍上來)
@export var wobble: float = 0.5                 ## 飄來飄去的幅度(弧度)
@export var float_height: float = 4.0
@export_group("爆開")
@export var burst_trigger: float = 20.0         ## 與目標中心的距離小於這個就停下預警
@export var max_chase_time: float = 4.0         ## 追了這麼久也停下預警
@export var warn_time: float = 0.6              ## 預警圈秒數(× 難度)
@export var burst_radius: float = 18.0          ## 預警圈半徑 = 爆炸範圍
@export var burst_hit_margin: float = 2.0       ## 角色中心離圈邊多近也算打中

var phase: Phase = Phase.CHASE
var chase_time: float = 0.0
var bursts: int = 0
var burst_away: bool = false                    ## 自己爆開消失了(不是被打倒)

var _phase_left: float = 0.0
var _warn_total: float = 0.6
var _angle: float = 0.0
var _wobble_phase: float = 0.0


func _on_ready() -> void:
	_angle = rng.randf() * TAU
	_wobble_phase = rng.randf() * TAU
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.CHASE
	chase_time = 0.0


## 很脆:任何一下都打散。
func take_damage(amount: int) -> void:
	if amount > 0 and state == State.ACTIVE:
		amount = maxi(amount, hp)
	super(amount)


func _ai(delta: float) -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 6.0 + _wobble_phase)))
	if sprite != null:
		sprite.position = _sprite_base_offset + (Vector2(sin(_age * 50.0) * 0.6, 0).round() if phase == Phase.WARN else Vector2.ZERO)
	match phase:
		Phase.CHASE:
			if target == null:
				desired_velocity = Vector2.ZERO
				anim_state = &"idle"
				return
			chase_time += delta
			var to_target := target.global_position - global_position
			var dist := to_target.length()
			if dist <= burst_trigger or chase_time >= max_chase_time:
				_start_warn()
				return
			var aim := target.global_position + Vector2.from_angle(_angle) * minf(orbit_spread, dist * 0.5) - global_position
			var dir := aim.normalized().rotated(sin(_age * 2.5 + _wobble_phase) * wobble * clampf(dist / 60.0, 0.0, 1.0))
			facing = dir
			desired_velocity = dir * data.move_speed
			anim_state = &"run"
		Phase.WARN:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_warn_total, 0.001)
			if _phase_left <= 0.0:
				_burst()


func _start_warn() -> void:
	phase = Phase.WARN
	_warn_total = tell(warn_time)
	_phase_left = _warn_total
	desired_velocity = Vector2.ZERO
	_play(&"attack", true)
	_show_telegraph(AttackTelegraph.make_circle(burst_radius))
	CombatFx.sfx(&"foxfire_hiss", &"boss_warning", -10.0)


func _burst() -> void:
	_clear_telegraph()
	bursts += 1
	var damage := data.contact_damage
	for victim in victims():
		if global_position.distance_to(victim.global_position) <= burst_radius + burst_hit_margin:
			victim.call(&"take_damage", damage)
	_play(&"burst", true)
	CombatFx.ring(self, global_position, 3.0, burst_radius + 3.0, 0.25, Color(FLAME_HOT, 0.95), 2.0)
	CombatFx.ring(self, global_position, 2.0, burst_radius, 0.3, Color(FLAME, 0.5), 1.0, true, true)
	CombatFx.particles(self, &"sparkle", global_position, false)
	CombatFx.sfx(&"foxfire_burst", &"hit", -4.0)
	_vanish()


## 爆開後消失:離開 enemy 群組,不掉經驗,不發 enemy_died。
func _vanish() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	burst_away = true
	remove_from_group(ENEMY_GROUP)
	collision_layer = 0
	release_attack_slot()
	_clear_spawn_marker()
	_clear_dizzy()
	if _light != null:
		_light.visible = false
	_death_left = death_time


func _cancel_attack() -> void:
	super()
	if phase == Phase.WARN:
		# 被吠叫震懾:火熄了一下,之後重新追(追蹤時間重新算一半)。
		phase = Phase.CHASE
		chase_time = max_chase_time * 0.5


func _is_committed() -> bool:
	return phase == Phase.WARN


func _uses_separation() -> bool:
	return phase == Phase.CHASE


func _on_died() -> void:
	_poof()
	CombatFx.ring(self, global_position, 1.0, 10.0, 0.2, Color(FLAME, 0.7), 1.0)
