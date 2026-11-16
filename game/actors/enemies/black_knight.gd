class_name BlackKnightBoss
extends EnemyBase
## 黑騎士(A11):被魔法驅動的空盔甲。三種招式,每招都有清楚預警並播 boss_warning 音效:
## - 衝鋒:地上畫出直線,然後沿線直衝;撞牆會頭昏一下(最好的反擊時機)。
## - 重劈:腳下畫出圓圈,填滿時重劈,打出震波。
## - 召喚:兩個紫色魔法圈,之後從場地的 spawn_enemy() 叫出兩隻稻草人兵。
## 生命降到一半:發 boss_phase_changed(2),怒吼一下,之後預警變短、動作變快。
## 被打敗:盔甲散落一地,頭盔滾出來,裡面是空的;它召喚的稻草人兵也一起倒下。
##
## M3 打磨(AP5,演出數值在本場景的屬性欄與 data/player/feel_tuning.tres):
## - 出場:從橋頭城門(場地上方中央)走進來,約 intro_walk_time 秒,每一步鏡頭震一下;
##   這段時間無敵、不攻擊。走到定點後怒吼(boss_roar)再開打。出場時發 boss_hp_changed。
## - 每次受傷都發 boss_hp_changed(current, maximum)。
## - 第二階段:怒吼(boss_roar)、紅色衝擊波、鏡頭震動,怒吼期間無敵;之後盔甲一直發紅光。
## - 重劈:shockwave 粒子、大震動、手機 heavy 震動。
## - 被打倒:白光一閃、慢動作、heavy 震動,盔甲搖晃、裂縫透出紫光約 boss_defeat_time 秒
##   (這段時間仍在 enemy 群組、無敵、不能被瞄準),然後盔甲爆開散落、頭盔滾動,
##   這時才離開 enemy 群組並發 enemy_died(B 線因此在約 1 秒後才過關)。

enum Phase { INTRO, IDLE, CHASE, CHARGE_TELL, CHARGE, CHARGE_RECOVER, SLAM_TELL, SLAM_RECOVER,
		SUMMON_TELL, SUMMON_RECOVER, ROAR }

const REMAINS_SCRIPT: GDScript = preload("res://game/actors/enemies/armor_remains.gd")
const RAGE := Color(1.0, 0.18, 0.12)
const MAGIC_LIGHT := Color(0.8, 0.55, 1.0)

@export_group("出場")
@export var intro_walk_time: float = 1.5         ## 從城門走到定點的秒數(無敵、不攻擊)
@export var intro_gate_offset: float = 40.0      ## 城門在戰鬥區上緣之上幾像素
@export var intro_stop_depth: float = 42.0       ## 走到戰鬥區上緣之下幾像素停下
@export var intro_step_interval: float = 0.375   ## 腳步(鏡頭震一下、揚起塵土)的間隔
@export_group("節奏")
@export var intro_time: float = 0.7              ## 走到定點後怒吼的秒數
@export var idle_time: float = 1.0
@export var idle_time_phase2: float = 0.55
@export var chase_time: float = 1.4
@export var phase2_threshold: float = 0.5
@export var phase2_telegraph_mult: float = 0.7
@export var phase2_speed_mult: float = 1.3
@export var roar_time: float = 1.0               ## 第二階段怒吼(無敵)的秒數
@export var stun_resist: float = 0.5             ## 被吠叫震懾的時間減半
@export var rage_glow: float = 0.28              ## 第二階段盔甲紅光的強度(0 至 1)
@export_group("衝鋒")
@export var charge_telegraph: float = 0.85
@export var charge_speed: float = 150.0
@export var charge_width: float = 32.0           ## 預警線的寬度 = 打中範圍(角色中心在線內才算打中)
@export var charge_max_distance: float = 200.0
@export var charge_recover: float = 0.6
@export var charge_bonk_time: float = 1.0
@export_group("重劈")
@export var slam_damage: int = 22
@export var slam_telegraph: float = 0.9
@export var slam_radius: float = 44.0
@export var slam_recover: float = 0.75
@export var slam_hit_margin: float = 2.0         ## 角色中心離圓圈邊緣多近也算打中(畫出來的圓圈就是打中範圍)
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
var defeated: bool = false                       ## 生命歸零,正在播倒下演出(或已經倒下)

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
var _walking: bool = false
var _walk_from: Vector2 = Vector2.ZERO
var _walk_to: Vector2 = Vector2.ZERO
var _walk_t: float = 0.0
var _step_left: float = 0.0
var _roar_ring_left: float = 0.0
var _defeat_left: float = -1.0
var _defeat_puff_left: float = 0.0


# --- 出場(AP5) -------------------------------------------------------------------

## 由場地的 spawn_enemy() 呼叫。duration = 0(測試)時立刻開打;否則從城門走進來。
func begin_spawn(duration: float = -1.0) -> void:
	if state == State.DYING:
		return
	if duration == 0.0 or intro_walk_time <= 0.0:
		super(duration)
		return
	state = State.SPAWNING
	_walking = true
	_walk_t = 0.0
	_step_left = 0.0
	var rect := Layout.ARENA_RECT
	_walk_to = Vector2(rect.get_center().x, rect.position.y + intro_stop_depth)
	_walk_from = Vector2(_walk_to.x, rect.position.y - intro_gate_offset)
	global_position = _walk_from
	facing = Vector2.DOWN
	anim_state = &"run"
	_play(&"run")
	if sprite != null:
		sprite.modulate = Color(tint, 0.0)
	EventBus.boss_hp_changed.emit(hp, max_hp)


func is_walking_in() -> bool:
	return _walking


func _tick_spawn(delta: float) -> void:
	if not _walking:
		super(delta)
		return
	_walk_t += delta / maxf(intro_walk_time, 0.001)
	var t := clampf(_walk_t, 0.0, 1.0)
	# 一步一步走:每一步的前半段比較快,看起來是沉重的腳步。
	var steps := maxf(1.0, intro_walk_time / maxf(intro_step_interval, 0.05))
	var stepped := (floorf(t * steps) + smoothstep(0.0, 1.0, fmod(t * steps, 1.0))) / steps
	global_position = _walk_from.lerp(_walk_to, minf(stepped, 1.0))
	if sprite != null:
		sprite.modulate = Color(tint, clampf(t * 4.0, 0.0, 1.0))
		sprite.position = _sprite_base_offset
	_step_left -= delta
	if _step_left <= 0.0 and t < 1.0:
		_step_left = intro_step_interval
		CombatFx.trauma(self, CombatFx.feel().trauma_boss_step)
		CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, _frame_size.y * 0.4), true, true)
	if _walk_t >= 1.0:
		_walking = false
		global_position = _walk_to
		_activate()


func _on_activated() -> void:
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"idle"
	EventBus.boss_phase_changed.emit(1)
	EventBus.boss_hp_changed.emit(hp, max_hp)
	CombatFx.sfx(&"boss_roar", &"boss_warning")
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_roar)
	CombatFx.ring(self, global_position, 8.0, 46.0, 0.45, Color(MAGIC_LIGHT, 0.8), 2.0)


## 無敵:出場走進來、第二階段怒吼、倒下演出的時候。
func is_invulnerable() -> bool:
	return state == State.SPAWNING or phase == Phase.ROAR or defeated


func is_targetable() -> bool:
	return super() and not is_invulnerable()


func stun(duration: float) -> void:
	if defeated:
		return
	super(duration * (1.0 - stun_resist))


func apply_hitstop(duration: float) -> void:
	if defeated:
		return
	super(duration)


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
				if not _charge_hit.has(victim) and global_position.distance_to(victim.global_position) <= charge_width * 0.5 + slam_hit_margin:
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
				sprite.position = Vector2(sin(_phase_left * 80.0) * 1.5, 0).round()
			# 怒吼時一圈圈紅色衝擊波。
			_roar_ring_left -= delta
			if _roar_ring_left <= 0.0:
				_roar_ring_left = 0.28
				CombatFx.ring(self, global_position, 10.0, 54.0, 0.4, Color(RAGE, 0.75), 2.0)
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
	CombatFx.sfx(&"whoosh", &"swing")


func _end_charge(recover: float) -> void:
	phase = Phase.CHARGE_RECOVER
	_phase_left = recover
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"


func _bonk() -> void:
	# 撞牆:頭昏一下,冒星星。這是玩家反擊的好機會。
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_bonk)
	CombatFx.spawn(self, &"dust", global_position + _charge_dir * body_radius, 0.0, Vector2.ONE * 2.0, Color.WHITE, true)
	CombatFx.particles(self, &"star_burst", global_position + Vector2(0, -_frame_size.y * 0.5))
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
	# 公平:角色中心在畫出來的圓圈內(加一點點寬容)才算打中,站在圈外就一定閃得掉。
	for victim in victims():
		if global_position.distance_to(victim.global_position) <= slam_radius + slam_hit_margin:
			victim.call(&"take_damage", slam_damage)
	CombatFx.ring(self, global_position, 6.0, slam_radius + 4.0, 0.3, Color(1.0, 0.85, 0.6, 0.95), 3.0, true)
	CombatFx.ring(self, global_position, 4.0, slam_radius * 0.6, 0.2, Color(1, 1, 1, 0.6), 2.0, true)
	for i in 6:
		var dir := Vector2.from_angle(TAU * float(i) / 6.0)
		CombatFx.spawn(self, &"dust", global_position + dir * slam_radius * 0.7, 0.0, Vector2.ONE * 1.3, Color.WHITE, true)
	CombatFx.particles(self, &"shockwave", global_position, true, true)
	var feel := CombatFx.feel()
	CombatFx.trauma(self, feel.trauma_boss_slam)
	CombatFx.haptic(feel.haptic_boss_slam)
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


## 衝鋒與重劈預警時不被小怪推開,地上的預警才會準確。
func _uses_separation() -> bool:
	return not (phase in [Phase.CHARGE_TELL, Phase.CHARGE, Phase.SLAM_TELL, Phase.SUMMON_TELL])


# --- 生命、第二階段與倒下 ------------------------------------------------------------

func _on_damaged(_amount: int) -> void:
	EventBus.boss_hp_changed.emit(hp, max_hp)
	if boss_phase == 1 and hp > 0 and float(hp) <= float(max_hp) * phase2_threshold:
		_enter_phase_two()


func _enter_phase_two() -> void:
	boss_phase = 2
	EventBus.boss_phase_changed.emit(2)
	_cancel_attack()
	phase = Phase.ROAR
	_phase_left = roar_time
	_roar_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(RAGE, rage_glow * 1.8)
	CombatFx.sfx(&"boss_roar", &"boss_warning")
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_roar)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _tick_custom(delta: float) -> bool:
	if defeated:
		_tick_defeat()
		return true
	if boss_phase >= 2:
		# 第二階段:盔甲一直發著脈動的紅光。
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		set_glow(RAGE, rage_glow * (0.6 + 0.6 * pulse) * (1.8 if phase == Phase.ROAR else 1.0))
		queue_redraw()
	return false


## 生命歸零:先播倒下演出(白光、慢動作、盔甲搖晃),boss_defeat_time 秒後盔甲爆開、真正倒下。
func die() -> void:
	if state == State.DYING:
		return
	var feel := CombatFx.feel()
	if defeated:
		if _defeat_left > 0.0:
			return
		super()
		return
	if feel.boss_defeat_time <= 0.0 or not is_inside_tree():
		defeated = true
		super()
		return
	defeated = true
	_defeat_left = feel.boss_defeat_time
	_defeat_puff_left = 0.0
	_cancel_attack()
	_clear_telegraph()
	_clear_summon_marks()
	_clear_dizzy()
	_hitstop_left = 0.0
	_stun_left = 0.0
	desired_velocity = Vector2.ZERO
	anim_state = &"hurt"
	_play(&"hurt", true)
	set_glow(Color.WHITE, 0.0)
	# 驅動盔甲的魔法消失了,它召喚的稻草人兵立刻一起倒下。
	for s in _summons:
		if is_instance_valid(s) and s.has_method(&"die"):
			s.call(&"die")
	_summons.clear()
	CombatFx.haptic(feel.haptic_boss_defeat)
	CombatFx.trauma(self, feel.trauma_boss_defeat)
	CombatFx.tint(self, Color(1, 1, 1, feel.boss_flash_alpha), feel.boss_flash_time, 0.0, feel.boss_flash_time, 50)
	CombatFx.slow_motion(self, feel.boss_slowmo_scale, feel.boss_slowmo_time)
	CombatFx.sfx(&"crit", &"hit")
	CombatFx.particles(self, &"star_burst", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)


func is_defeat_playing() -> bool:
	return defeated and state != State.DYING


## 倒下演出:用真實時間計時(不受慢動作影響),所以一定在 boss_defeat_time 秒後離開 enemy 群組。
func _tick_defeat() -> void:
	var real_delta := get_physics_process_delta_time()
	_defeat_left -= real_delta
	var feel := CombatFx.feel()
	var t := 1.0 - clampf(_defeat_left / maxf(feel.boss_defeat_time, 0.001), 0.0, 1.0)
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if sprite != null:
		# 搖晃越來越厲害,一閃一閃地發白。
		var amp := 0.5 + 1.5 * t
		sprite.position = Vector2(randf_range(-amp, amp), randf_range(-amp * 0.5, amp * 0.5)).round()
		sprite.speed_scale = CombatFx.time_scale
		var blink := int(t * 14.0) % 2 == 0
		_set_flash(0.75 if blink else 0.15)
	_defeat_puff_left -= real_delta
	if _defeat_puff_left <= 0.0:
		_defeat_puff_left = 0.12
		var at := global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-_frame_size.y * 0.5, 0.0))
		var puff := CombatFx.spawn(self, &"dust", at, 0.0, Vector2.ONE, Color(MAGIC_LIGHT, 0.9), false, 0.6)
		if puff != null:
			puff.drift = Vector2(0, -18.0)
			puff.fade_out = true
	queue_redraw()
	if _defeat_left <= 0.0:
		_defeat_left = 0.0
		die()


func _cancel_attack() -> void:
	super()
	_clear_summon_marks()
	if phase in [Phase.CHARGE_TELL, Phase.CHARGE, Phase.SLAM_TELL, Phase.SUMMON_TELL]:
		_go_idle()
	if sprite != null:
		sprite.position = Vector2.ZERO
		if not sprite.is_playing():
			sprite.play()


## 盔甲爆開(真正倒下的一刻):散落的盔甲、白光、震波。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	var remains := REMAINS_SCRIPT.new() as Node2D
	remains.set(&"flip", facing.x < 0.0)
	remains.set(&"sprite_frames", sprite.sprite_frames if sprite != null else null)
	CombatFx.layer_for(self, true).add_child(remains)
	remains.global_position = global_position
	var feel := CombatFx.feel()
	CombatFx.trauma(self, feel.trauma_boss_defeat * 0.6)
	CombatFx.tint(self, Color(1, 1, 1, feel.boss_flash_alpha * 0.5), feel.boss_flash_time * 0.6, 0.0,
			feel.boss_flash_time * 0.6, 50)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 3.0, Color.WHITE, true)
	CombatFx.ring(self, global_position, 6.0, 48.0, 0.45, Color(0.75, 0.45, 1.0, 0.9), 2.0)
	CombatFx.ring(self, global_position, 4.0, 70.0, 0.6, Color(1, 1, 1, 0.6), 1.0)
	CombatFx.particles(self, &"shockwave", global_position, true, true)
	CombatFx.sfx(&"whoosh", &"swing")
	# 保險:召喚的稻草人兵一定一起倒下(倒下演出開始時已經處理,這裡處理演出被略過的情況)。
	for s in _summons:
		if is_instance_valid(s) and s.has_method(&"die"):
			s.call(&"die")
	_summons.clear()


func _draw() -> void:
	if state == State.DYING:
		return
	# 第二階段:腳下一圈脈動的紅光。
	if boss_phase >= 2 and not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.42 + pulse * 2.0, Color(RAGE, 0.18 + 0.14 * pulse))
		draw_set_transform(Vector2.ZERO)
	super()
	if defeated:
		# 倒下演出:盔甲的縫隙透出紫色的光,越來越多、越來越長。
		var t := 1.0 - clampf(_defeat_left / maxf(CombatFx.feel().boss_defeat_time, 0.001), 0.0, 1.0)
		var center := Vector2(0, -_frame_size.y * 0.15)
		var rays := 3 + int(t * 5.0)
		for i in rays:
			var a := float(i) * 2.399 + _age * 0.6
			var length := (10.0 + 26.0 * t) * (0.7 + 0.3 * sin(float(i) * 1.7))
			var dir := Vector2.from_angle(a)
			draw_line(center, center + dir * length, Color(MAGIC_LIGHT, 0.55 + 0.35 * t), 2.0)
			draw_line(center, center + dir * length * 0.6, Color(1, 1, 1, 0.7 * t), 1.0)
