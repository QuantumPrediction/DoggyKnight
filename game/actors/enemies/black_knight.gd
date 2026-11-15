class_name BlackKnightBoss
extends EnemyBase
## 黑騎士(A11):被魔法驅動的空盔甲。三種招式,每招都有清楚預警並播 boss_warning 音效:
## - 衝鋒:地上畫出直線,然後沿線直衝;撞牆會頭昏一下(最好的反擊時機)。
## - 重劈:腳下畫出圓圈,填滿時重劈,打出震波。
## - 召喚:兩個紫色魔法圈,之後從場地的 spawn_enemy() 叫出兩隻稻草人兵。
## 生命降到一半:發 boss_phase_changed(2),怒吼一下,之後預警變短、動作變快。
## 被打敗:盔甲散落一地,頭盔滾出來,裡面是空的;它召喚的稻草人兵也一起倒下。

enum Phase { INTRO, IDLE, CHASE, CHARGE_TELL, CHARGE, CHARGE_RECOVER, SLAM_TELL, SLAM_RECOVER,
		SUMMON_TELL, SUMMON_RECOVER, ROAR }

const REMAINS_SCRIPT: GDScript = preload("res://game/actors/enemies/armor_remains.gd")

@export_group("節奏")
@export var intro_time: float = 1.0
@export var idle_time: float = 1.0
@export var idle_time_phase2: float = 0.55
@export var chase_time: float = 1.4
@export var phase2_threshold: float = 0.5
@export var phase2_telegraph_mult: float = 0.7
@export var phase2_speed_mult: float = 1.3
@export var roar_time: float = 0.9
@export var stun_resist: float = 0.5             ## 被吠叫震懾的時間減半
@export_group("衝鋒")
@export var charge_telegraph: float = 0.85
@export var charge_speed: float = 150.0
@export var charge_width: float = 22.0
@export var charge_max_distance: float = 200.0
@export var charge_recover: float = 0.6
@export var charge_bonk_time: float = 1.0
@export_group("重劈")
@export var slam_damage: int = 22
@export var slam_telegraph: float = 0.9
@export var slam_radius: float = 44.0
@export var slam_recover: float = 0.75
@export_group("召喚")
@export var summon_enemy: StringName = &"scarecrow"
@export var summon_count: int = 2
@export var summon_telegraph: float = 0.8
@export var summon_recover: float = 0.5
@export var max_summons_alive: int = 4
@export var summon_every: int = 3                ## 每第幾招是召喚
@export var summon_offset: float = 30.0

var phase: Phase = Phase.INTRO
var boss_phase: int = 1
var moves_started: Dictionary = {&"charge": 0, &"slam": 0, &"summon": 0}

var _phase_left: float = 0.0
var _move_index: int = 0
var _charge_dir: Vector2 = Vector2.DOWN
var _charge_length: float = 0.0
var _charge_traveled: float = 0.0
var _charge_into_wall: bool = false
var _charge_hit: Array[Node2D] = []
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []
var _summons: Array[Node] = []


func _on_activated() -> void:
	phase = Phase.INTRO
	_phase_left = intro_time
	EventBus.boss_phase_changed.emit(1)
	Sfx.play(&"boss_warning")
	CombatFx.shake(self, 1.5, 0.3)


func stun(duration: float) -> void:
	super(duration * (1.0 - stun_resist))


func _ai(delta: float) -> void:
	_phase_left -= delta
	match phase:
		Phase.INTRO, Phase.IDLE:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			_face_target()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.CHASE:
			anim_state = &"run"
			if target == null:
				_go_idle()
				return
			var to_target := target.global_position - global_position
			facing = to_target.normalized()
			desired_velocity = facing * data.move_speed * _speed_mult()
			if to_target.length() <= slam_radius * 0.8:
				_start_slam()
			elif _phase_left <= 0.0:
				_start_charge()
		Phase.CHARGE_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell(charge_telegraph)
			if sprite != null:
				sprite.position = -_charge_dir * 2.0 + Vector2(sin(_phase_left * 70.0), 0)
			if _phase_left <= 0.0:
				_begin_charge()
		Phase.CHARGE:
			anim_state = &"charge"
			var speed := charge_speed * _speed_mult()
			desired_velocity = _charge_dir * speed
			_charge_traveled += speed * delta
			for victim in victims():
				if not _charge_hit.has(victim) and global_position.distance_to(victim.global_position) <= body_radius + radius_of(victim) + 3.0:
					_charge_hit.append(victim)
					victim.call(&"take_damage", data.contact_damage)
			if _charge_traveled >= _charge_length:
				if _charge_into_wall:
					_bonk()
				else:
					_end_charge(charge_recover)
		Phase.SLAM_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell(slam_telegraph)
			if _phase_left <= 0.0:
				_slam()
		Phase.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			var p := 1.0 - _phase_left / _tell_time(summon_telegraph)
			for mark in _summon_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _phase_left <= 0.0:
				_summon()
		Phase.CHARGE_RECOVER, Phase.SLAM_RECOVER, Phase.SUMMON_RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				_clear_dizzy()
				_go_idle()
		Phase.ROAR:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if sprite != null:
				sprite.position = Vector2(sin(_phase_left * 80.0) * 1.5, 0)
			if _phase_left <= 0.0:
				_go_idle()


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	var dist := global_position.distance_to(target.global_position)
	if n % summon_every == summon_every - 1 and alive_summons() < max_summons_alive:
		_start_summon()
	elif dist <= slam_radius * 0.85:
		_start_slam()
	elif n % 2 == 0:
		_start_charge()
	else:
		phase = Phase.CHASE
		_phase_left = chase_time


func _go_idle() -> void:
	phase = Phase.IDLE
	_phase_left = idle_time_phase2 if boss_phase >= 2 else idle_time
	anim_state = &"idle"
	if sprite != null:
		sprite.position = Vector2.ZERO


func _tell_time(base: float) -> float:
	return base * (phase2_telegraph_mult if boss_phase >= 2 else 1.0)


func _speed_mult() -> float:
	return phase2_speed_mult if boss_phase >= 2 else 1.0


func _update_tell(base: float) -> void:
	if _telegraph != null:
		_telegraph.progress = 1.0 - _phase_left / _tell_time(base)


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


# --- 衝鋒 -----------------------------------------------------------------------

func _start_charge() -> void:
	if target == null:
		_go_idle()
		return
	moves_started[&"charge"] += 1
	var to_target := target.global_position - global_position
	_charge_dir = to_target.normalized() if to_target.length() > 1.0 else Vector2.DOWN
	facing = _charge_dir
	var to_edge := CombatMath.distance_to_rect_edge(global_position, _charge_dir, CombatMath.arena_bounds(arena_margin))
	_charge_length = minf(charge_max_distance, to_edge)
	_charge_into_wall = to_edge <= charge_max_distance
	phase = Phase.CHARGE_TELL
	_phase_left = _tell_time(charge_telegraph)
	anim_state = &"idle"
	_show_telegraph(AttackTelegraph.make_line(_charge_dir, _charge_length + body_radius, charge_width))
	Sfx.play(&"boss_warning")


func _begin_charge() -> void:
	_clear_telegraph()
	phase = Phase.CHARGE
	_charge_traveled = 0.0
	_charge_hit.clear()
	if sprite != null:
		sprite.position = Vector2.ZERO
	_play(&"charge", true)


func _end_charge(recover: float) -> void:
	phase = Phase.CHARGE_RECOVER
	_phase_left = recover
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"


func _bonk() -> void:
	# 撞牆:頭昏一下,冒星星。這是玩家反擊的好機會。
	CombatFx.shake(self, 2.0, 0.2)
	CombatFx.spawn(self, &"dust", global_position + _charge_dir * body_radius, 0.0, Vector2.ONE * 2.0, Color.WHITE, true)
	_end_charge(charge_bonk_time)
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.5))


# --- 重劈 -----------------------------------------------------------------------

func _start_slam() -> void:
	moves_started[&"slam"] += 1
	phase = Phase.SLAM_TELL
	_phase_left = _tell_time(slam_telegraph)
	_face_target()
	anim_state = &"slam"
	_play(&"slam", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_circle(slam_radius))
	Sfx.play(&"boss_warning")


func _slam() -> void:
	_clear_telegraph()
	phase = Phase.SLAM_RECOVER
	_phase_left = slam_recover
	anim_state = &"slam"
	if sprite != null:
		sprite.play(&"slam")
	hit_victims_in_circle(global_position, slam_radius, slam_damage)
	CombatFx.ring(self, global_position, 6.0, slam_radius + 4.0, 0.3, Color(1.0, 0.85, 0.6, 0.95), 3.0, true)
	CombatFx.ring(self, global_position, 4.0, slam_radius * 0.6, 0.2, Color(1, 1, 1, 0.6), 2.0, true)
	for i in 6:
		var dir := Vector2.from_angle(TAU * float(i) / 6.0)
		CombatFx.spawn(self, &"dust", global_position + dir * slam_radius * 0.7, 0.0, Vector2.ONE * 1.3, Color.WHITE, true)
	CombatFx.shake(self, 2.5, 0.25)
	Sfx.play(&"hit")


# --- 召喚 -----------------------------------------------------------------------

func _start_summon() -> void:
	moves_started[&"summon"] += 1
	phase = Phase.SUMMON_TELL
	_phase_left = _tell_time(summon_telegraph)
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.pause()
	_clear_summon_marks()
	_summon_points = _pick_summon_points()
	for point in _summon_points:
		var mark := AttackTelegraph.make_circle(8.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_summon_marks.append(mark)
	Sfx.play(&"boss_warning")


func _pick_summon_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := Vector2(side * summon_offset, floorf(float(i) * 0.5) * 18.0 - 6.0)
		points.append(CombatMath.clamp_to_arena(global_position + offset, 10.0))
	return points


func _summon() -> void:
	_clear_summon_marks()
	phase = Phase.SUMMON_RECOVER
	_phase_left = summon_recover
	anim_state = &"idle"
	if sprite != null:
		sprite.play()
	for point in _summon_points:
		var spawned: Node = null
		if arena != null and is_instance_valid(arena) and arena.has_method(&"spawn_enemy"):
			spawned = arena.call(&"spawn_enemy", summon_enemy, point)
		if spawned != null:
			_summons.append(spawned)


func alive_summons() -> int:
	var alive := 0
	for s in _summons:
		if is_instance_valid(s) and s.is_in_group(ENEMY_GROUP):
			alive += 1
	return alive


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


# --- 第二階段與倒下 ----------------------------------------------------------------

func _on_damaged(_amount: int) -> void:
	if boss_phase == 1 and hp > 0 and float(hp) <= float(max_hp) * phase2_threshold:
		boss_phase = 2
		EventBus.boss_phase_changed.emit(2)
		_cancel_attack()
		phase = Phase.ROAR
		_phase_left = roar_time
		tint = Color(1.0, 0.72, 0.72)
		if sprite != null:
			sprite.modulate = tint
		Sfx.play(&"boss_warning")
		CombatFx.shake(self, 2.0, 0.4)
		CombatFx.ring(self, global_position, 8.0, 40.0, 0.4, Color(1.0, 0.3, 0.3, 0.8), 2.0)


func _cancel_attack() -> void:
	super()
	_clear_summon_marks()
	if phase in [Phase.CHARGE_TELL, Phase.CHARGE, Phase.SLAM_TELL, Phase.SUMMON_TELL]:
		_go_idle()
	if sprite != null:
		sprite.position = Vector2.ZERO
		if not sprite.is_playing():
			sprite.play()


func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	var remains := REMAINS_SCRIPT.new() as Node2D
	remains.set(&"flip", facing.x < 0.0)
	remains.set(&"sprite_frames", sprite.sprite_frames if sprite != null else null)
	CombatFx.layer_for(self, true).add_child(remains)
	remains.global_position = global_position
	CombatFx.shake(self, 3.0, 0.4)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 3.0, Color.WHITE, true)
	CombatFx.ring(self, global_position, 6.0, 48.0, 0.45, Color(0.75, 0.45, 1.0, 0.9), 2.0)
	# 驅動盔甲的魔法消失了,它召喚的稻草人兵也一起倒下。
	for s in _summons:
		if is_instance_valid(s) and s.has_method(&"die"):
			s.call(&"die")
	_summons.clear()
