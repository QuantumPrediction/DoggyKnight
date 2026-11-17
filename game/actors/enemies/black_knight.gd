class_name BlackKnightBoss
extends BossBase
## 黑騎士(A11):被魔法驅動的空盔甲。三種招式,每招都有清楚預警並播 boss_warning 音效:
## - 衝鋒:地上畫出直線,然後沿線直衝;撞牆會頭昏一下(最好的反擊時機)。
## - 重劈:腳下畫出圓圈,填滿時重劈,打出震波。
## - 召喚:兩個紫色魔法圈,之後從場地的 spawn_enemy() 叫出兩隻稻草人兵。
## 生命降到一半:發 boss_phase_changed(2),怒吼一下,之後預警變短、動作變快。
## 被打敗:盔甲散落一地,頭盔滾出來,裡面是空的;它召喚的小怪也一起倒下。
## 共同的頭目行為(出場宣告、boss_hp_changed、第二階段、倒下演出、召喚)在 BossBase。
##
## M3 打磨(AP5,演出數值在本場景的屬性欄與 data/player/feel_tuning.tres):
## - 出場:從橋頭城門(場地上方中央)走進來,約 intro_walk_time 秒,每一步鏡頭震一下;
##   這段時間無敵、不攻擊。走到定點後怒吼(boss_roar)再開打。
## - 第二階段:怒吼(boss_roar)、紅色衝擊波、鏡頭震動,怒吼期間無敵;之後盔甲一直發紅光。
## - 重劈:shockwave 粒子、大震動、手機 heavy 震動。
##
## v2.3 深化(AS4):
## - 出場時發 boss_appeared(&"black_knight")(HUD 的頭目血條顯示名字)。
## - 第二階段:重劈之後放出劍氣——先畫直線預警,再沿線射出弧形的劍氣(EnemyProjectile,
##   data/enemies/projectiles/sword_wave.tres;穿透、鬥牛犬的盾擋得住)。
## - 第二階段的召喚改為 2 隻空盔甲兵(armored_husk)。
##
## v2.6(AV5):中頭目幻影黑騎士(phantom_knight.tscn,3-4)用同一個腳本:action_speed_scale(動作速度 ×1.3)、
## tell_scale(預警 ×0.8)、phantom(半透明紫色、輕輕閃爍、倒下時散成紫色霧,沒有盔甲碎片)。

enum Phase { INTRO, IDLE, CHASE, CHARGE_TELL, CHARGE, CHARGE_RECOVER, SLAM_TELL, SLAM_RECOVER,
		SUMMON_TELL, SUMMON_RECOVER, ROAR, WAVE_TELL, WAVE_RECOVER }

const REMAINS_SCRIPT: GDScript = preload("res://game/actors/enemies/armor_remains.gd")
const SWORD_WAVE: ProjectileData = preload("res://data/enemies/projectiles/sword_wave.tres")
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
@export var roar_time: float = 1.0               ## 第二階段怒吼(無敵)的秒數
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
@export_group("劍氣(第二階段,AS4)")
@export var sword_wave: ProjectileData = SWORD_WAVE
@export var wave_from_phase: int = 2             ## 從第幾階段開始,重劈之後放劍氣
@export var wave_telegraph: float = 0.7          ## 劍氣的直線預警(× 第二階段與難度倍數)
@export var wave_pause: float = 0.3              ## 重劈打下去到劍氣預警出現的秒數
@export var wave_recover: float = 0.45
@export_group("幻影(v2.6 AV5)")
@export var tell_scale: float = 1.0              ## 所有預警再 × 這個(幻影黑騎士 0.8)
@export var action_speed_scale: float = 1.0      ## 走路、衝鋒速度再 × 這個(幻影黑騎士 1.3)
@export var phantom: bool = false                ## 半透明閃爍;倒下時散成紫色霧(沒有盔甲碎片)
@export_group("召喚")
@export var summon_enemy: StringName = &"scarecrow"
@export var summon_enemy_phase2: StringName = &"armored_husk"   ## 第二階段召喚空盔甲兵(AS4)
@export var summon_count: int = 2
@export var summon_telegraph: float = 0.8
@export var summon_recover: float = 0.5
@export var max_summons_alive: int = 4
@export var max_summons_alive_phase2: int = 2
@export var summon_every: int = 3                ## 每第幾招是召喚
@export var summon_offset: float = 30.0

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"charge": 0, &"slam": 0, &"summon": 0, &"wave": 0}

var _phase_left: float = 0.0
var _move_index: int = 0
var _charge_dir: Vector2 = Vector2.DOWN
var _charge_length: float = 0.0
var _charge_traveled: float = 0.0
var _charge_into_wall: bool = false
var _charge_hit: Array[Node2D] = []
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []
var _walking: bool = false
var _walk_from: Vector2 = Vector2.ZERO
var _walk_to: Vector2 = Vector2.ZERO
var _walk_t: float = 0.0
var _step_left: float = 0.0
var _roar_ring_left: float = 0.0
var _wave_pending: bool = false
var _wave_dir: Vector2 = Vector2.DOWN
var _wave_length: float = 100.0


# --- 出場(AP5) -------------------------------------------------------------------

## 由場地的 spawn_enemy() 呼叫。duration = 0(測試)時立刻開打;否則從城門走進來。
func begin_spawn(duration: float = -1.0) -> void:
	if state == State.DYING:
		return
	if duration == 0.0 or intro_walk_time <= 0.0:
		super(duration)
		return
	announce()
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
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"idle"
	CombatFx.sfx(&"boss_roar", &"boss_warning")
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_roar)
	CombatFx.ring(self, global_position, 8.0, 46.0, 0.45, Color(MAGIC_LIGHT, 0.8), 2.0)


func _is_enraging() -> bool:
	return phase == Phase.ROAR


func _tell_time(base: float) -> float:
	return super(base) * tell_scale


func _speed_mult() -> float:
	return super() * action_speed_scale


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
			var speed := scaled_speed(charge_speed) * _speed_mult()
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
					_end_charge(rest(charge_recover))
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
		Phase.WAVE_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell(wave_telegraph)
			if _phase_left <= 0.0:
				_release_wave()
		Phase.SLAM_RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				if _wave_pending:
					_start_wave()
				else:
					_go_idle()
		Phase.CHARGE_RECOVER, Phase.SUMMON_RECOVER, Phase.WAVE_RECOVER:
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
	var summon_cap := max_summons_alive_phase2 if boss_phase >= 2 else max_summons_alive
	if n % summon_every == summon_every - 1 and alive_summons() < summon_cap:
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
	_phase_left = rest(idle_time_phase2 if boss_phase >= 2 else idle_time)
	anim_state = &"idle"
	_wave_pending = false
	if sprite != null:
		sprite.position = Vector2.ZERO
		if not sprite.is_playing():
			sprite.play()


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
	_end_charge(rest(charge_bonk_time))
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
	_wave_pending = boss_phase >= wave_from_phase and sword_wave != null
	_phase_left = wave_pause if _wave_pending else rest(slam_recover)
	anim_state = &"slam"
	if sprite != null:
		sprite.play(&"slam")
	# 公平:角色中心在畫出來的圓圈內(加一點點寬容)才算打中,站在圈外就一定閃得掉。
	var damage := scaled_damage(slam_damage)
	for victim in victims():
		if global_position.distance_to(victim.global_position) <= slam_radius + slam_hit_margin:
			victim.call(&"take_damage", damage)
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


# --- 劍氣(第二階段,AS4) ------------------------------------------------------------

## 重劈之後:朝目標畫一條直線預警(鎖定方向),之後沿線射出劍氣。
func _start_wave() -> void:
	_wave_pending = false
	if target == null or sword_wave == null:
		_go_idle()
		return
	moves_started[&"wave"] += 1
	var to_target := target.global_position - global_position
	_wave_dir = to_target.normalized() if to_target.length() > 1.0 else Vector2.DOWN
	facing = _wave_dir
	_wave_length = EnemyProjectile.travel_length(global_position, _wave_dir, sword_wave.max_range)
	phase = Phase.WAVE_TELL
	_phase_left = _tell_time(wave_telegraph)
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_line(_wave_dir, _wave_length, sword_wave.telegraph_width()))
	Sfx.play(&"boss_warning")


func _release_wave() -> void:
	_clear_telegraph()
	phase = Phase.WAVE_RECOVER
	_phase_left = rest(wave_recover)
	if sprite != null:
		sprite.play()
	EnemyProjectile.launch(self, sword_wave, global_position, _wave_dir, _wave_length,
			scaled_damage(sword_wave.damage), projectile_speed_mult(), self)
	CombatFx.ring(self, global_position + _wave_dir * 10.0, 4.0, 18.0, 0.25, Color(MAGIC_LIGHT, 0.9), 2.0)
	CombatFx.sfx(&"magic", &"whoosh")


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


## 現在召喚哪一種小怪(第二階段是空盔甲兵)。
func current_summon() -> StringName:
	return summon_enemy_phase2 if boss_phase >= 2 and summon_enemy_phase2 != &"" else summon_enemy


func _summon() -> void:
	_clear_summon_marks()
	phase = Phase.SUMMON_RECOVER
	_phase_left = rest(summon_recover)
	anim_state = &"idle"
	if sprite != null:
		sprite.play()
	summon_at(current_summon(), _summon_points)


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


## 衝鋒與重劈預警時不被小怪推開,地上的預警才會準確。
func _uses_separation() -> bool:
	return not (phase in [Phase.CHARGE_TELL, Phase.CHARGE, Phase.SLAM_TELL, Phase.SUMMON_TELL, Phase.WAVE_TELL])


# --- 第二階段與倒下 ----------------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	phase = Phase.ROAR
	_phase_left = roar_time
	_roar_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(RAGE, rage_glow * 1.8)
	CombatFx.sfx(&"boss_roar", &"boss_warning")
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_roar)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _tick_boss(_delta: float) -> bool:
	if phantom and sprite != null and state == State.ACTIVE:
		# 幻影:輕輕地閃爍。
		sprite.modulate = Color(tint, tint.a * (0.85 + 0.15 * sin(_age * 4.0)))
	if boss_phase >= 2:
		# 第二階段:盔甲一直發著脈動的紅光。
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		set_glow(RAGE, rage_glow * (0.6 + 0.6 * pulse) * (1.8 if phase == Phase.ROAR else 1.0))
		queue_redraw()
	return false


func _on_defeat_started() -> void:
	_clear_summon_marks()


func _cancel_attack() -> void:
	super()
	_clear_summon_marks()
	_wave_pending = false
	if phase in [Phase.CHARGE_TELL, Phase.CHARGE, Phase.SLAM_TELL, Phase.SUMMON_TELL, Phase.WAVE_TELL]:
		_go_idle()
	if sprite != null:
		sprite.position = Vector2.ZERO
		if not sprite.is_playing():
			sprite.play()


## 盔甲爆開(真正倒下的一刻):散落的盔甲、白光、震波。幻影黑騎士:散成紫色霧。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	if phantom:
		_vanish_into_mist()
		return
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
	# 保險:召喚的小怪一定一起倒下(倒下演出開始時已經處理,這裡處理演出被略過的情況)。
	_drop_summons()


const MIST_COLORS: Array[Color] = [Color(0.72, 0.5, 1.0, 0.9), Color(0.9, 0.8, 1.0, 0.8), Color(0.45, 0.3, 0.75, 0.9)]


func _vanish_into_mist() -> void:
	BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.2), BitsScatter.Kind.MIST, MIST_COLORS, 16)
	var feel := CombatFx.feel()
	CombatFx.trauma(self, feel.trauma_boss_defeat * 0.5)
	CombatFx.ring(self, global_position, 6.0, 52.0, 0.5, Color(MAGIC_LIGHT, 0.9), 2.0)
	CombatFx.ring(self, global_position, 4.0, 70.0, 0.6, Color(1, 1, 1, 0.5), 1.0)
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.2), false, true)
	CombatFx.sfx(&"magic", &"whoosh")
	_drop_summons()


func _draw_under() -> void:
	# 第二階段:腳下一圈脈動的紅光。
	if boss_phase >= 2 and not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.42 + pulse * 2.0, Color(RAGE, 0.18 + 0.14 * pulse))
		draw_set_transform(Vector2.ZERO)
