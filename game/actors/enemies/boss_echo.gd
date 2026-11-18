class_name BossEcho
extends EnemyBase
## 舊頭目的幻影(v2.7 AW6,莫德雷德 33% 起召喚):半透明紫色、比本尊小,只會一招(簡化版):
## - echo_black_knight.tscn(黑騎士的幻影):紅線預警後沿線衝鋒(身體碰到紅線就打中)。
## - echo_green_knight.tscn(綠騎士的幻影):紅線預警後藤鞭沿線甩出去(VineLash)。
## 數值在 data/enemies/echo_black_knight.tres、echo_green_knight.tres(生命、傷害 = 接觸傷害),節奏在場景的屬性欄。
## 不掉寶箱與零食;lifetime 秒後自己消失(撤退,不算打倒);莫德雷德倒下時一起散掉。
## 打散時化成一團紫色的霧(BitsScatter.MIST),不是受傷。

enum Kind { CHARGE, WHIP }
enum Phase { DRIFT, TELL, CHARGE, REST }

const MIST_COLORS: Array[Color] = [Color(0.72, 0.55, 1.0, 0.85), Color(0.5, 0.4, 0.8, 0.8)]
const VIOLET := Color(0.72, 0.42, 1.0)

@export var kind: Kind = Kind.CHARGE
@export var lifetime: float = 14.0
@export var keep_distance: float = 48.0
@export var tell_time: float = 0.9               ## 紅線預警(× 難度)
@export var move_interval: float = 2.6
@export var first_move_min: float = 1.0
@export var first_move_max: float = 1.6
@export var rest_time: float = 0.7
@export var line_width: float = 18.0             ## 紅線寬度 = 打中範圍
@export var line_length: float = 120.0
@export var charge_speed: float = 170.0
@export var float_height: float = 3.0
@export var attack_anim: StringName = &"charge"

var phase: Phase = Phase.DRIFT
var moves: int = 0
var faded: bool = false

var _phase_left: float = 0.0
var _life_left: float = 14.0
var _tell_total: float = 0.9
var _dir: Vector2 = Vector2.DOWN
var _length: float = 100.0
var _traveled: float = 0.0
var _hit: Array[Node2D] = []


func _on_ready() -> void:
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.DRIFT
	_life_left = lifetime
	_phase_left = rest(rng.randf_range(first_move_min, first_move_max))


func _ai(delta: float) -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 2.5) * 1.0))
	if sprite != null:
		sprite.position = _sprite_base_offset
		sprite.modulate = Color(tint, tint.a * (0.8 + 0.2 * sin(_age * 6.0)))
	_life_left -= delta
	if _life_left <= 0.0 and phase != Phase.TELL and phase != Phase.CHARGE:
		faded = true
		retreat()
		return
	_phase_left -= delta
	match phase:
		Phase.DRIFT:
			anim_state = &"run"
			if target == null:
				desired_velocity = Vector2.ZERO
				anim_state = &"idle"
				return
			var to_target := target.global_position - global_position
			var dist := to_target.length()
			if dist > 0.5:
				facing = to_target / dist
			desired_velocity = facing * data.move_speed if dist > keep_distance else facing.orthogonal() * data.move_speed * 0.4
			if _phase_left <= 0.0:
				_start_tell()
		Phase.TELL:
			desired_velocity = Vector2.ZERO
			anim_state = attack_anim
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if _phase_left <= 0.0:
				_act()
		Phase.CHARGE:
			var speed := scaled_speed(charge_speed)
			desired_velocity = _dir * speed
			anim_state = attack_anim
			_traveled += speed * delta
			for victim in victims():
				if not _hit.has(victim) and global_position.distance_to(victim.global_position) <= line_width * 0.5 + radius_of(victim):
					_hit.append(victim)
					victim.call(&"take_damage", data.contact_damage)
			if _traveled >= _length or get_slide_collision_count() > 0:
				_rest()
		Phase.REST:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if _phase_left <= 0.0:
				phase = Phase.DRIFT
				_phase_left = rest(move_interval)


func _start_tell() -> void:
	if target == null:
		_phase_left = 0.5
		return
	var to_target := target.global_position - global_position
	_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	facing = _dir
	var bounds := CombatMath.arena_bounds(arena_margin) if kind == Kind.CHARGE else Layout.ARENA_RECT.grow(-2.0)
	_length = minf(line_length, CombatMath.distance_to_rect_edge(global_position, _dir, bounds))
	phase = Phase.TELL
	moves += 1
	_tell_total = tell(tell_time)
	_phase_left = _tell_total
	_play(attack_anim, true)
	_show_telegraph(AttackTelegraph.make_line(_dir, _length, line_width))
	CombatFx.sfx(&"boss_warning", &"", -10.0)


func _act() -> void:
	_clear_telegraph()
	if kind == Kind.CHARGE:
		phase = Phase.CHARGE
		_traveled = 0.0
		_hit.clear()
		CombatFx.sfx(&"whoosh", &"swing", -6.0)
		return
	var end := global_position + _dir * _length
	for victim in victims():
		if EnemyProjectile.segment_distance(global_position, end, victim.global_position) <= line_width * 0.5 + radius_of(victim):
			victim.call(&"take_damage", data.contact_damage)
	VineLash.lash(self, global_position, _dir, _length, line_width)
	CombatFx.sfx(&"whip", &"whoosh", -6.0)
	_rest()


func _rest() -> void:
	phase = Phase.REST
	_phase_left = rest(rest_time)
	desired_velocity = Vector2.ZERO


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELL or phase == Phase.CHARGE:
		_rest()


func _is_committed() -> bool:
	return phase == Phase.TELL


func _uses_separation() -> bool:
	return phase == Phase.DRIFT or phase == Phase.REST


## 幻影不掉寶箱與零食。
func _drop_loot() -> void:
	pass


func _poof() -> void:
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.MIST, MIST_COLORS, 10)
	CombatFx.ring(self, global_position, 3.0, 22.0, 0.3, Color(VIOLET, 0.8), 1.0)


func _on_died() -> void:
	_poof()
