class_name CaptainBoss
extends BossBase
## 稻草人隊長(AS3,1-4 的中頭目,32×32):戴隊長帽、插著摩根娜的紫色羽毛的大稻草人,拿乾草叉。
## 數值在 data/enemies/scarecrow_captain.tres(生命約 320、橫掃傷害 12、經驗 12),節奏在本場景的屬性欄。
## 共同的頭目行為(出場宣告 boss_appeared / boss_hp_changed、第二階段、倒下演出、召喚)在 BossBase。
##
## - 出場:從地面冒出(和小怪一樣有塵土預警,這段時間無敵),然後吶喊(captain_shout)、發 boss_appeared。
## - 招式(每招都有清楚預警):
##   1. 乾草叉橫掃:扇形預警,填滿時橫掃(碰到扇形就被打中)。
##   2. 號令稻草人:三個紫色魔法圈,之後從場地的 spawn_enemy() 叫出 3 隻稻草人兵。
##   3. 擲乾草叉:直線預警,乾草叉沿線飛出去、再沿同一條線飛回來(去回都會打中;
##      隊長站著等,這時手上沒有武器——反擊的好機會)。被鬥牛犬的盾擋下時乾草叉落地,隊長要變出一支新的。
## - 一半生命:吶喊(短暫無敵、紫光),之後預警變短、動作變快、更常號令。
## - 倒下:散成一堆稻草(straw_bits 粒子與 StrawScatter 的稻草、隊長帽),帽子上的紫色羽毛
##   (PurpleFeather)慢慢飄落到地上(故事伏筆),
##   它叫來的稻草人兵一起倒下。

enum Phase { INTRO, IDLE, CHASE, SWEEP_TELL, SWEEP_RECOVER, THROW_TELL, THROW_WAIT, THROW_RECOVER,
		RALLY_TELL, RALLY_RECOVER, SHOUT }

const PITCHFORK: ProjectileData = preload("res://data/enemies/projectiles/pitchfork.tres")
const PURPLE := Color(0.72, 0.42, 1.0)
const STRAW := Color(0.93, 0.8, 0.45)

@export_group("節奏")
@export var intro_time: float = 0.9              ## 冒出地面後吶喊的秒數(不攻擊)
@export var idle_time: float = 0.9
@export var idle_time_phase2: float = 0.6
@export var chase_time: float = 1.3
@export var shout_time: float = 0.8              ## 第二階段吶喊(無敵)的秒數
@export_group("乾草叉橫掃")
@export var sweep_radius: float = 34.0
@export var sweep_half_angle_deg: float = 70.0
@export var sweep_telegraph: float = 0.7
@export var sweep_recover: float = 0.65
@export var sweep_trigger: float = 22.0          ## 與目標身體的距離小於這個就橫掃
@export var sweep_lunge: float = 4.0
@export_group("擲乾草叉")
@export var pitchfork: ProjectileData = PITCHFORK
@export var throw_telegraph: float = 0.75
@export var throw_min_distance: float = 46.0     ## 目標比這個遠才擲
@export var throw_max_wait: float = 3.5          ## 最多等乾草叉飛回來幾秒
@export var throw_recover: float = 0.45
@export var throw_lost_recover: float = 0.9      ## 乾草叉被擋下落地:變出一支新的要多久
@export_group("號令稻草人")
@export var rally_enemy: StringName = &"scarecrow"
@export var rally_count: int = 3
@export var rally_telegraph: float = 1.0
@export var rally_recover: float = 0.6
@export var max_summons_alive: int = 4
@export var rally_every: int = 4                 ## 每幾招號令一次(第二階段少一招)
@export var rally_spread: float = 30.0
@export_group("倒下")
@export var feather_fall_height: float = 26.0    ## 羽毛從帽子再往上多高開始飄落

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"sweep": 0, &"throw": 0, &"rally": 0}
var fork_in_hand: bool = true

var _phase_left: float = 0.0
var _move_index: int = 0
var _sweep_dir: Vector2 = Vector2.DOWN
var _sweep_origin: Vector2 = Vector2.ZERO
var _throw_dir: Vector2 = Vector2.DOWN
var _throw_length: float = 100.0
var _fork: EnemyProjectile
var _rally_points: Array[Vector2] = []
var _rally_marks: Array[AttackTelegraph] = []
var _shout_ring_left: float = 0.0
var _intent_key: String = ""


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"rally"
	_play(&"rally", true)
	_shout(0.6)


func _is_enraging() -> bool:
	return phase == Phase.SHOUT


func _ai(delta: float) -> void:
	_phase_left -= delta
	match phase:
		Phase.INTRO, Phase.IDLE:
			desired_velocity = Vector2.ZERO
			if phase == Phase.IDLE:
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
			if _gap_to_target() <= sweep_trigger:
				_start_sweep()
			elif _phase_left <= 0.0:
				if to_target.length() >= throw_min_distance:
					_start_throw()
				else:
					_go_idle()
		Phase.SWEEP_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell(sweep_telegraph)
			if sprite != null:
				sprite.position = _sprite_base_offset - _sweep_dir * 2.0 + Vector2(sin(_phase_left * 70.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_sweep()
		Phase.THROW_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell(throw_telegraph)
			if _phase_left <= 0.0:
				_throw()
		Phase.THROW_WAIT:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if fork_in_hand or _phase_left <= 0.0 or _fork == null or not is_instance_valid(_fork):
				_end_throw(not fork_in_hand)
		Phase.RALLY_TELL:
			desired_velocity = Vector2.ZERO
			var p := 1.0 - _phase_left / _tell_time(rally_telegraph)
			for mark in _rally_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _phase_left <= 0.0:
				_rally()
		Phase.SWEEP_RECOVER, Phase.THROW_RECOVER, Phase.RALLY_RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				_go_idle()
		Phase.SHOUT:
			desired_velocity = Vector2.ZERO
			anim_state = &"rally"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 80.0) * 1.0, 0).round()
			_shout_ring_left -= delta
			if _shout_ring_left <= 0.0:
				_shout_ring_left = 0.25
				CombatFx.ring(self, global_position, 8.0, 44.0, 0.35, Color(PURPLE, 0.75), 2.0)
			if _phase_left <= 0.0:
				_go_idle()
	_publish_intent()


func _publish_intent() -> void:
	var intent: StringName = &""
	match phase:
		Phase.SWEEP_TELL: intent = &"sweep"
		Phase.THROW_TELL: intent = &"throw"
		Phase.THROW_WAIT: intent = &"returning"
		Phase.SWEEP_RECOVER, Phase.THROW_RECOVER, Phase.RALLY_RECOVER: intent = &"opening"
		Phase.RALLY_TELL: intent = &"rally"
		Phase.SHOUT: intent = &"shout"
	var key := "%s:%d" % [intent, ceili(maxf(0, _phase_left) * 10)]
	if key != _intent_key:
		_intent_key = key
		EventBus.boss_intent_changed.emit(&"scarecrow_captain", intent, maxf(0, _phase_left))


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	var every := maxi(2, rally_every - (1 if boss_phase >= 2 else 0))
	var dist := global_position.distance_to(target.global_position)
	if n % every == 1 and alive_summons() < max_summons_alive:
		_start_rally()
	elif _gap_to_target() <= sweep_trigger + 6.0:
		_start_sweep()
	elif dist >= throw_min_distance and n % 2 == 0 and fork_in_hand:
		_start_throw()
	else:
		phase = Phase.CHASE
		_phase_left = chase_time


func _go_idle() -> void:
	phase = Phase.IDLE
	_phase_left = rest(idle_time_phase2 if boss_phase >= 2 else idle_time)
	anim_state = &"idle"
	if sprite != null:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


func _gap_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position) - radius_of(target) - body_radius


func _update_tell(base: float) -> void:
	if _telegraph != null:
		_telegraph.progress = 1.0 - _phase_left / _tell_time(base)


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


# --- 乾草叉橫掃 ---------------------------------------------------------------------

func _start_sweep() -> void:
	if target == null:
		_go_idle()
		return
	moves_started[&"sweep"] += 1
	var to_target := target.global_position - global_position
	_sweep_dir = to_target.normalized() if to_target.length() > 0.5 else facing
	facing = _sweep_dir
	desired_velocity = Vector2.ZERO
	_sweep_origin = CombatMath.clamp_to_bounds(global_position + _sweep_dir * sweep_lunge, arena_margin)
	phase = Phase.SWEEP_TELL
	_phase_left = _tell_time(sweep_telegraph)
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_sector(sweep_radius, _sweep_dir, deg_to_rad(sweep_half_angle_deg)))
	_telegraph.global_position = _sweep_origin
	Sfx.play(&"boss_warning", -6.0)


func _sweep() -> void:
	if phase != Phase.SWEEP_TELL:
		return
	var mark := _telegraph
	var warning_transform := mark.global_transform if is_instance_valid(mark) else Transform2D.IDENTITY
	phase = Phase.SWEEP_RECOVER
	_phase_left = rest(sweep_recover)
	if sprite != null:
		sprite.position = _sprite_base_offset + _sweep_dir * 2.0
		sprite.play(&"attack")
	global_position = _sweep_origin
	var slash := CombatFx.spawn(self, &"slash", global_position + _sweep_dir * 12.0, _sweep_dir.angle(),
			Vector2.ONE * 1.4, Color(0.95, 0.78, 0.45))
	if slash != null:
		slash.flip_v = _sweep_dir.x < 0.0
	if is_instance_valid(mark):
		mark.global_transform = warning_transform
		hit_victims_in_marked_sector(mark, data.contact_damage)
	_clear_telegraph()
	CombatFx.sfx(&"whoosh", &"swing")


# --- 擲乾草叉 -----------------------------------------------------------------------

func _start_throw() -> void:
	if target == null or pitchfork == null or not fork_in_hand:
		_go_idle()
		return
	moves_started[&"throw"] += 1
	var to_target := target.global_position - global_position
	_throw_dir = to_target.normalized() if to_target.length() > 0.5 else facing
	facing = _throw_dir
	_throw_length = EnemyProjectile.travel_length(global_position, _throw_dir, pitchfork.max_range)
	phase = Phase.THROW_TELL
	_phase_left = _tell_time(throw_telegraph)
	anim_state = &"throw"
	_play(&"throw", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_line(_throw_dir, _throw_length, pitchfork.telegraph_width()))
	Sfx.play(&"boss_warning", -6.0)


func _throw() -> void:
	_clear_telegraph()
	phase = Phase.THROW_WAIT
	_phase_left = throw_max_wait
	if sprite != null:
		sprite.play(&"throw")
	fork_in_hand = false
	_fork = EnemyProjectile.launch(self, pitchfork, global_position, _throw_dir, _throw_length,
			scaled_damage(pitchfork.damage), projectile_speed_mult(), self)
	if _fork == null:
		fork_in_hand = true
		_end_throw(false)
		return
	# 乾草叉會沿同一條線飛回來:留一條淡淡的線提醒玩家。
	var path := AttackTelegraph.make_line(_throw_dir, _throw_length, pitchfork.telegraph_width())
	path.modulate.a = 0.45
	_show_telegraph(path)
	CombatFx.sfx(&"whoosh", &"swing")


## 乾草叉飛回手上(EnemyProjectile 呼叫)。
func catch_projectile(projectile: Node2D) -> void:
	if projectile != _fork:
		return
	fork_in_hand = true
	_fork = null
	CombatFx.spawn(self, &"hit_spark", global_position + facing * 6.0, 0.0, Vector2.ONE * 0.7, STRAW)


## 乾草叉被盾擋下或落地了(EnemyProjectile 呼叫)。
func projectile_lost(projectile: Node2D) -> void:
	if projectile == _fork:
		_fork = null


func _end_throw(lost: bool) -> void:
	_clear_telegraph()
	if lost or not fork_in_hand:
		# 變出一支新的乾草叉(紫色的魔法光),要多花一點時間。
		fork_in_hand = true
		_fork = null
		phase = Phase.THROW_RECOVER
		_phase_left = rest(throw_lost_recover)
		CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.2), false, true)
		CombatFx.ring(self, global_position, 3.0, 16.0, 0.3, Color(PURPLE, 0.8), 1.0)
		return
	phase = Phase.THROW_RECOVER
	_phase_left = rest(throw_recover)


# --- 號令稻草人 ---------------------------------------------------------------------

func _start_rally() -> void:
	_clear_rally_marks()
	_rally_points = _pick_rally_points()
	if _rally_points.is_empty():
		_go_idle()
		return
	moves_started[&"rally"] += 1
	phase = Phase.RALLY_TELL
	_phase_left = _tell_time(rally_telegraph)
	anim_state = &"rally"
	_play(&"rally", true)
	for point in _rally_points:
		var mark := AttackTelegraph.make_arrival_circle(8.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_rally_marks.append(mark)
	_shout(0.25)


func _pick_rally_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var count := mini(rally_count, maxi(0, max_summons_alive - alive_summons()))
	var forward := facing if facing.length() > 0.1 else Vector2.DOWN
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1) - 0.5
		var dir := forward.rotated(t * 2.4)
		points.append(CombatMath.clamp_to_arena(global_position + dir * rally_spread, 10.0))
	return points


func _rally() -> void:
	if phase != Phase.RALLY_TELL:
		return
	_clear_rally_marks()
	phase = Phase.RALLY_RECOVER
	_phase_left = rest(rally_recover)
	anim_state = &"idle"
	# Never add unannounced reinforcements if more slots open during the tell.
	var count := mini(_rally_points.size(), maxi(0, max_summons_alive - alive_summons()))
	summon_at(rally_enemy, _rally_points.slice(0, count))
	_rally_points.clear()


func _clear_rally_marks() -> void:
	for mark in _rally_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_rally_marks.clear()


## 吶喊:captain_shout、紫色衝擊波、鏡頭震一下。
func _shout(trauma_amount: float) -> void:
	CombatFx.sfx(&"captain_shout", &"boss_warning")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 40.0, 0.4, Color(PURPLE, 0.85), 2.0)


func _uses_separation() -> bool:
	return not (phase in [Phase.SWEEP_TELL, Phase.THROW_TELL, Phase.THROW_WAIT, Phase.RALLY_TELL])


# --- 第二階段與倒下 ----------------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	phase = Phase.SHOUT
	_phase_left = shout_time
	_shout_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(PURPLE, 0.35)
	_shout(CombatFx.feel().trauma_boss_roar * 0.8)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(PURPLE, 0.12 + 0.12 * pulse + (0.2 if phase == Phase.SHOUT else 0.0))
		queue_redraw()
	return false


func _on_defeat_started() -> void:
	_clear_rally_marks()
	EventBus.boss_intent_changed.emit(&"scarecrow_captain", &"", 0.0)


func _cancel_attack() -> void:
	super()
	_clear_rally_marks()
	if phase in [Phase.SWEEP_TELL, Phase.THROW_TELL, Phase.RALLY_TELL]:
		_go_idle()
	elif phase == Phase.THROW_WAIT:
		# 乾草叉還在飛:讓它自己飛回來,隊長先休息。
		phase = Phase.THROW_RECOVER
		_phase_left = rest(throw_recover)
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


## 散成一堆稻草,紫色羽毛慢慢飄落。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	var center := global_position + Vector2(0, -_frame_size.y * 0.1)
	CombatFx.particles(self, &"straw_bits", center, false, true)
	CombatFx.particles(self, &"straw_bits", center + Vector2(0, _frame_size.y * 0.25), true, true)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 2.4, STRAW, true)
	CombatFx.ring(self, global_position, 4.0, 40.0, 0.45, Color(PURPLE, 0.9), 2.0)
	CombatFx.ring(self, global_position, 3.0, 26.0, 0.3, Color(STRAW, 0.8), 1.0, true)
	var straw := StrawScatter.new()
	straw.flip = facing.x < 0.0
	CombatFx.layer_for(self, true).add_child(straw)
	straw.global_position = global_position + Vector2(0, _frame_size.y * 0.2)
	var feet := global_position.y + _frame_size.y * 0.4
	var hat := global_position + Vector2(facing.x * 4.0, -_frame_size.y * 0.5 - feather_fall_height)
	PurpleFeather.drop(self, hat, feet)
	CombatFx.sfx(&"whoosh", &"swing")
	_drop_summons()


func _draw_under() -> void:
	if boss_phase >= 2 and not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.4 + pulse * 2.0, Color(PURPLE, 0.16 + 0.12 * pulse))
		draw_set_transform(Vector2.ZERO)
