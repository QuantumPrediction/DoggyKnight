class_name MordredBoss
extends BossBase
## 莫德雷德(v2.7 AW6,48×48):杜賓犬黑騎士,腰間掛著發紫光的劍鞘。同一個腳本兩個場景:
## - mordred_duel.tscn(中頭目第一戰,6-4,duel = true):衝刺斬與劍氣;生命剩 flee_threshold(一半)時逃走
##   ——說一句話、往場地上方跑掉(無敵),離開 enemy 群組並發 enemy_died(掉經驗與寶箱),
##   場上的其他手下也跟著撤退(retreat_others_on_flee),所以逃走 = 過關。逃走前不會被打倒。
## - mordred.tscn(最終頭目,6-6,三個階段):
##   1. 衝刺斬(紅線預警,方向鎖定,沿線衝過去;衝完喘氣是反擊時機)與劍氣(直線預警後射出 shadow_slash)。
##   2. 66% 起:劍鞘護盾。紫色的護盾罩住他,這時金毛打不動(「鏘!」),只有同伴的攻擊(Style.ALLY)
##      能削弱護盾(shield_hp);破盾後暈眩 break_stun_time 秒(冒星星,最好打)。shield_regen_time 秒後再張開。
##      場上沒有同伴時,護盾 shield_solo_time 秒後自己消失;有同伴也最多維持 shield_max_time 秒(不會打不完)。
##      劍氣改成三道扇形(中間有空隙)。
##   3. 33% 起:召喚舊頭目的幻影(BossEcho:黑騎士衝鋒、綠騎士藤鞭的簡化版),動作加快
##      (phase3_speed_mult、預警 × phase3_telegraph_mult,仍有完整預警)。
##   換階段:停下舉劍(無敵)、紫光、鏡頭震動、手機震動。
##   倒下:單膝跪下(down,DefeatPose 留在場上,不是受傷),幻影一起散掉。

enum Phase { INTRO, IDLE, DASH_TELL, DASH, DASH_RECOVER, SLASH_TELL, SLASH_RECOVER, SHIFT, SHIELD_RAISE,
		STUNNED, SUMMON_TELL, FLEE }

const SHADOW_SLASH: ProjectileData = preload("res://data/enemies/projectiles/shadow_slash.tres")
const SCABBARD := Color(0.72, 0.42, 1.0)
const STEEL := Color(0.8, 0.85, 0.95)
const SHARD_COLORS: Array[Color] = [Color(0.72, 0.42, 1.0, 0.9), Color(0.85, 0.7, 1.0, 0.9), Color(0.45, 0.3, 0.8, 0.9)]
const MIST_COLORS: Array[Color] = [Color(0.35, 0.3, 0.5, 0.9), Color(0.55, 0.5, 0.75, 0.85)]

@export_group("第一戰(6-4)")
@export var duel: bool = false
@export var flee_threshold: float = 0.5
@export var flee_time: float = 1.4
@export var retreat_others_on_flee: bool = true
@export_group("節奏")
@export var intro_time: float = 1.0
@export var idle_time: float = 0.9
@export var idle_time_phase2: float = 0.7
@export var idle_time_phase3: float = 0.5
@export var keep_distance: float = 56.0
@export var drift_speed_mult: float = 0.5
@export var shift_time: float = 1.2
@export var phase3_threshold: float = 0.33
@export var phase3_telegraph_mult: float = 0.85  ## 第三階段的預警再 × 這個(和 phase2_telegraph_mult 相乘)
@export var phase3_speed_mult: float = 1.25      ## 第三階段的動作速度再 × 這個
@export_group("衝刺斬")
@export var dash_telegraph: float = 0.85
@export var dash_speed: float = 210.0
@export var dash_width: float = 18.0             ## 紅線寬度 = 打中範圍
@export var dash_overshoot: float = 26.0
@export var dash_max_distance: float = 160.0
@export var dash_recover: float = 0.8
@export_group("劍氣")
@export var shadow_slash: ProjectileData = SHADOW_SLASH
@export var slash_telegraph: float = 0.8
@export var slash_count: int = 1
@export var slash_count_phase2: int = 3
@export var slash_step_deg: float = 26.0
@export var slash_recover: float = 0.5
@export_group("劍鞘護盾(第二階段起)")
@export var shield_hp: int = 60                  ## 同伴要打掉這麼多才破盾
@export var shield_raise_time: float = 0.8
@export var shield_regen_time: float = 9.0
@export var shield_max_time: float = 14.0
@export var shield_solo_time: float = 5.0
@export var break_stun_time: float = 3.0
@export_group("舊頭目的幻影(第三階段)")
@export var echo_enemies: Array[StringName] = [&"echo_black_knight", &"echo_green_knight"]
@export var echo_telegraph: float = 1.0
@export var echo_every: int = 5
@export var echo_offset: float = 46.0

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"dash": 0, &"slash": 0, &"shield": 0, &"echo": 0}
var shield_up: bool = false
var shield_left: int = 0
var shield_breaks: int = 0
var blocked_hits: int = 0
var fled: bool = false
var fleeing: bool = false

var _phase_left: float = 0.0
var _tell_total: float = 1.0
var _move_index: int = 0
var _after_shift: StringName = &""
var _ring_left: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN
var _dash_length: float = 0.0
var _dash_traveled: float = 0.0
var _dash_hit: Array[Node2D] = []
var _slash_dirs: Array[Vector2] = []
var _slash_lengths: Array[float] = []
var _marks: Array[Node2D] = []
var _echo_points: Array[Vector2] = []
var _shield_time: float = 0.0
var _shield_cooldown_left: float = 0.0
var _stun_dizzy: Node2D
var _style: DamageNumber.Style = DamageNumber.Style.NORMAL
var _hit_from: Vector2 = Vector2.INF
var _clang_ready_at: float = 0.0
var _flee_from: Vector2 = Vector2.ZERO
var _flee_to: Vector2 = Vector2.ZERO


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"guard"
	_play(&"guard", true)
	_flare(CombatFx.feel().trauma_boss_roar * 0.6)


func _is_enraging() -> bool:
	return phase == Phase.SHIFT or phase == Phase.SHIELD_RAISE or phase == Phase.FLEE


## 預警秒數:第三階段再 × phase3_telegraph_mult。
func _tell_time(base: float) -> float:
	return super(base) * (phase3_telegraph_mult if boss_phase >= 3 else 1.0)


func _speed_mult() -> float:
	return super() * (phase3_speed_mult if boss_phase >= 3 else 1.0)


func _ai(delta: float) -> void:
	_phase_left -= delta
	_tick_shield(delta)
	match phase:
		Phase.INTRO:
			desired_velocity = Vector2.ZERO
			_face_target()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.IDLE:
			_drift()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.DASH_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"dash"
			_set_marks_progress(_progress())
			if sprite != null:
				sprite.position = _sprite_base_offset - _dash_dir * 2.0 + Vector2(sin(_phase_left * 70.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_start_dash()
		Phase.DASH:
			var speed := scaled_speed(dash_speed) * _speed_mult()
			desired_velocity = _dash_dir * speed
			facing = _dash_dir
			anim_state = &"dash"
			_dash_traveled += speed * delta
			for victim in victims():
				if not _dash_hit.has(victim) and global_position.distance_to(victim.global_position) <= dash_width * 0.5 + radius_of(victim):
					_dash_hit.append(victim)
					victim.call(&"take_damage", data.contact_damage)
			if _dash_traveled >= _dash_length or get_slide_collision_count() > 0:
				_end_dash()
		Phase.DASH_RECOVER, Phase.SLASH_RECOVER:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if _phase_left <= 0.0:
				_go_idle()
		Phase.SLASH_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"slash"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_release_slash()
		Phase.SHIFT:
			desired_velocity = Vector2.ZERO
			anim_state = &"guard"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 70.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 50.0, 0.45, Color(SCABBARD, 0.8), 2.0)
			if _phase_left <= 0.0:
				_end_shift()
		Phase.SHIELD_RAISE:
			desired_velocity = Vector2.ZERO
			anim_state = &"guard"
			queue_redraw()
			if _phase_left <= 0.0:
				_go_idle()
		Phase.STUNNED:
			desired_velocity = Vector2.ZERO
			anim_state = &"hurt"
			if _phase_left <= 0.0:
				_end_break_stun()
		Phase.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"summon"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_call_echoes()


func _progress() -> float:
	return 1.0 - _phase_left / maxf(_tell_total, 0.001)


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


func _drift() -> void:
	anim_state = &"idle"
	if target == null:
		desired_velocity = Vector2.ZERO
		return
	_face_target()
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := Vector2.ZERO
	if dist > keep_distance + 16.0:
		dir = to_target.normalized()
	elif dist < keep_distance - 16.0:
		dir = -to_target.normalized()
	else:
		dir = to_target.normalized().orthogonal() * (1.0 if int(_age / 2.0) % 2 == 0 else -1.0)
	if not CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 12.0):
		dir = (Layout.ARENA_RECT.get_center() - global_position).normalized()
	desired_velocity = dir * data.move_speed * drift_speed_mult * _speed_mult()
	anim_state = &"run"


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	if not duel and boss_phase >= 2 and not shield_up and _shield_cooldown_left <= 0.0:
		raise_shield()
		return
	if not duel and boss_phase >= 3 and alive_summons() == 0 and n % echo_every == 0:
		_start_echoes()
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > dash_max_distance * 0.8 or n % 3 != 1:
		_start_dash_tell()
	else:
		_start_slash()


func _go_idle() -> void:
	phase = Phase.IDLE
	var t := idle_time
	if boss_phase >= 3:
		t = idle_time_phase3
	elif boss_phase >= 2:
		t = idle_time_phase2
	_phase_left = rest(t)
	anim_state = &"idle"
	if sprite != null:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


func _begin_tell(next: Phase, base: float, anim: StringName) -> void:
	_clear_marks()
	phase = next
	_tell_total = _tell_time(base)
	_phase_left = _tell_total
	anim_state = anim
	_play(anim, true)
	Sfx.play(&"boss_warning", -4.0)


func _set_marks_progress(p: float) -> void:
	for mark in _marks:
		if is_instance_valid(mark) and mark is AttackTelegraph:
			(mark as AttackTelegraph).progress = p


func _add_mark(mark: AttackTelegraph, at: Vector2 = Vector2.INF) -> void:
	add_child(mark)
	if at != Vector2.INF:
		mark.global_position = at
	_marks.append(mark)


func _clear_marks() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()


# --- 衝刺斬 ---------------------------------------------------------------------

func _start_dash_tell() -> void:
	moves_started[&"dash"] += 1
	var to_target := target.global_position - global_position
	_dash_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	facing = _dash_dir
	var to_edge := CombatMath.distance_to_rect_edge(global_position, _dash_dir, CombatMath.arena_bounds(arena_margin))
	_dash_length = minf(minf(to_target.length() + dash_overshoot, dash_max_distance), to_edge)
	_begin_tell(Phase.DASH_TELL, dash_telegraph, &"dash")
	if sprite != null:
		sprite.pause()
	_add_mark(AttackTelegraph.make_line(_dash_dir, maxf(_dash_length, 8.0), dash_width))


func _start_dash() -> void:
	_clear_marks()
	phase = Phase.DASH
	_dash_traveled = 0.0
	_dash_hit.clear()
	if sprite != null:
		sprite.position = _sprite_base_offset
		sprite.play()
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 6), true)
	CombatFx.sfx(&"whoosh", &"swing")


func _end_dash() -> void:
	phase = Phase.DASH_RECOVER
	_phase_left = rest(dash_recover)
	desired_velocity = Vector2.ZERO
	_play(&"slash", true)
	CombatFx.spawn(self, &"hit_spark", global_position + _dash_dir * 10.0, _dash_dir.angle(), Vector2.ONE, Color(SCABBARD, 0.9))
	CombatFx.trauma(self, 0.2)


# --- 劍氣 -----------------------------------------------------------------------

func current_slash_count() -> int:
	return slash_count_phase2 if boss_phase >= 2 else slash_count


## 在距離 distance 的地方,相鄰兩道劍氣之間「角色中心可以站的空隙」有多寬(像素)。
func slash_gap_at(distance: float, victim_radius: float = 6.0) -> float:
	return 2.0 * distance * sin(deg_to_rad(slash_step_deg) * 0.5) - 2.0 * (shadow_slash.hit_radius + victim_radius)


func _start_slash() -> void:
	if shadow_slash == null:
		_go_idle()
		return
	moves_started[&"slash"] += 1
	_begin_tell(Phase.SLASH_TELL, slash_telegraph, &"slash")
	if sprite != null:
		sprite.pause()
	var to_target := target.global_position - global_position
	var aim := to_target.normalized() if to_target.length() > 0.5 else facing
	facing = aim
	_slash_dirs.clear()
	_slash_lengths.clear()
	var n := maxi(1, current_slash_count())
	var step := deg_to_rad(slash_step_deg)
	for i in n:
		var dir := aim.rotated((float(i) - float(n - 1) * 0.5) * step)
		var length := EnemyProjectile.travel_length(global_position, dir, shadow_slash.max_range)
		_slash_dirs.append(dir)
		_slash_lengths.append(length)
		_add_mark(AttackTelegraph.make_line(dir, length, shadow_slash.telegraph_width()))


func _release_slash() -> void:
	_clear_marks()
	phase = Phase.SLASH_RECOVER
	_phase_left = rest(slash_recover)
	if sprite != null:
		sprite.play()
	var dmg := scaled_damage(shadow_slash.damage) if shadow_slash.damage > 0 else data.contact_damage
	for i in _slash_dirs.size():
		EnemyProjectile.launch(self, shadow_slash, global_position, _slash_dirs[i], _slash_lengths[i], dmg,
				projectile_speed_mult(), self)
	CombatFx.sfx(&"whoosh", &"swing")


# --- 劍鞘護盾 -------------------------------------------------------------------

## 張開劍鞘護盾(第二階段起)。舉劍 shield_raise_time 秒(無敵)後繼續出招,護盾一直罩著。
func raise_shield() -> void:
	moves_started[&"shield"] += 1
	_clear_marks()
	shield_up = true
	shield_left = shield_hp
	_shield_time = 0.0
	phase = Phase.SHIELD_RAISE
	_phase_left = shield_raise_time
	_play(&"guard", true)
	CombatFx.ring(self, global_position, 6.0, 30.0, 0.4, Color(SCABBARD, 0.9), 2.0)
	CombatFx.sfx(&"magic", &"boss_warning")
	_say(tr(&"BOSS_MORDRED_SHIELD"), 1.2, self)
	# 同伴喊一聲「交給我們!」:告訴玩家要靠同伴破盾。
	for node in get_tree().get_nodes_in_group(COMPANION_GROUP):
		if node is Node2D:
			_say(tr(&"COMPANION_SHIELD_CALL"), 1.2, node as Node2D)
			break
	queue_redraw()


func has_companions() -> bool:
	return is_inside_tree() and get_tree().get_node_count_in_group(COMPANION_GROUP) > 0


func _tick_shield(delta: float) -> void:
	if not shield_up:
		if _shield_cooldown_left > 0.0 and phase != Phase.STUNNED:
			_shield_cooldown_left -= delta
		return
	_shield_time += delta
	var limit := shield_max_time if has_companions() else shield_solo_time
	if _shield_time >= limit:
		_drop_shield(false)
	queue_redraw()


## 護盾消失。broken = true:被同伴打破(暈眩);false:時間到了自己消失。
func _drop_shield(broken: bool) -> void:
	if not shield_up:
		return
	shield_up = false
	shield_left = 0
	_shield_cooldown_left = shield_regen_time
	BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.3), BitsScatter.Kind.CHIP, SHARD_COLORS,
			16 if broken else 8)
	if broken:
		shield_breaks += 1
		_cancel_attack()
		phase = Phase.STUNNED
		_phase_left = break_stun_time
		_play(&"hurt", true)
		if _stun_dizzy == null:
			_stun_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55) + _sprite_base_offset)
		CombatFx.trauma(self, CombatFx.feel().trauma_boss_roar * 0.6)
		CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
		CombatFx.ring(self, global_position, 6.0, 48.0, 0.5, Color(SCABBARD, 0.95), 2.0)
		CombatFx.sfx(&"shield_break", &"crit")
	queue_redraw()


func _end_break_stun() -> void:
	if _stun_dizzy != null and is_instance_valid(_stun_dizzy):
		_stun_dizzy.queue_free()
	_stun_dizzy = null
	_go_idle()


func is_break_stunned() -> bool:
	return phase == Phase.STUNNED


func hit(amount: int, from_position: Vector2, knockback_speed: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> void:
	_style = style
	_hit_from = from_position
	super(amount, from_position, knockback_speed, style)
	_style = DamageNumber.Style.NORMAL
	_hit_from = Vector2.INF


## 護盾:只有同伴的攻擊(Style.ALLY)削弱護盾;其他的「鏘!」一聲擋下。
## 第一戰:逃走前不會被打倒(生命最少留 1,降到 flee_threshold 就逃走)。
func take_damage(amount: int) -> void:
	var style := _style
	_style = DamageNumber.Style.NORMAL
	if amount <= 0 or state != State.ACTIVE or is_invulnerable():
		super(amount)
		return
	if shield_up:
		_number_style = DamageNumber.Style.NORMAL
		var from := _hit_from if _hit_from != Vector2.INF else global_position + facing * 10.0
		if style == DamageNumber.Style.ALLY:
			shield_left -= amount
			clang_fx(from, SCABBARD)
			CombatFx.damage_number(self, amount, number_anchor(), DamageNumber.Style.ALLY)
			if shield_left <= 0:
				_drop_shield(true)
		else:
			blocked_hits += 1
			if _age >= _clang_ready_at:
				_clang_ready_at = _age + 0.3
				clang_fx(from, SCABBARD)
		queue_redraw()
		return
	if duel and not fled:
		amount = mini(amount, hp - 1)
		if amount <= 0:
			return
	super(amount)


# --- 階段 -----------------------------------------------------------------------

func _on_damaged(amount: int) -> void:
	super(amount)
	if duel:
		if not fleeing and hp > 0 and float(hp) <= float(max_hp) * flee_threshold:
			start_flee()
		return
	if boss_phase == 2 and hp > 0 and float(hp) <= float(max_hp) * phase3_threshold:
		boss_phase = 3
		EventBus.boss_phase_changed.emit(3)
		_shift(&"echo")


func _enter_phase_two() -> void:
	_shift(&"slash" if duel else &"shield")


func _shift(next: StringName) -> void:
	if fleeing:
		return
	_cancel_attack()
	phase = Phase.SHIFT
	_phase_left = shift_time
	_after_shift = next
	_ring_left = 0.0
	_hitstop_left = 0.0
	_play(&"guard", true)
	set_glow(SCABBARD, 0.3)
	_flare(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _end_shift() -> void:
	var next := _after_shift
	_after_shift = &""
	if sprite != null:
		sprite.position = _sprite_base_offset
	if target == null:
		_go_idle()
	elif next == &"shield" and not shield_up:
		raise_shield()
	elif next == &"echo":
		_start_echoes()
	elif next == &"slash":
		_start_slash()
	else:
		_go_idle()


func _flare(trauma_amount: float) -> void:
	CombatFx.sfx(&"mordred_shout", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 46.0, 0.5, Color(SCABBARD, 0.85), 2.0)
	CombatFx.ring(self, global_position, 4.0, 30.0, 0.4, Color(STEEL, 0.8), 1.0)


# --- 舊頭目的幻影(第三階段) ---------------------------------------------------------

func _start_echoes() -> void:
	moves_started[&"echo"] += 1
	_begin_tell(Phase.SUMMON_TELL, echo_telegraph, &"summon")
	_echo_points.clear()
	for i in echo_enemies.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		_echo_points.append(CombatMath.clamp_to_arena(global_position + Vector2(side * echo_offset, 10.0), 16.0))
	for point in _echo_points:
		_add_mark(AttackTelegraph.make_circle(11.0, AttackTelegraph.MAGIC), point)


func _call_echoes() -> void:
	_clear_marks()
	for i in mini(echo_enemies.size(), _echo_points.size()):
		var point: Array[Vector2] = [_echo_points[i]]
		summon_at(echo_enemies[i], point)
	CombatFx.sfx(&"magic", &"boss_roar", -4.0)
	phase = Phase.SLASH_RECOVER
	_phase_left = rest(0.4)


# --- 第一戰:逃走 -----------------------------------------------------------------

## 生命剩一半:說一句話,往場地上方跑掉(無敵)。手下跟著撤退。
func start_flee() -> void:
	if fleeing:
		return
	fleeing = true
	_cancel_attack()
	_clear_marks()
	_drop_summons()
	if retreat_others_on_flee:
		for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
			if node != self and node is EnemyBase and not node is BossBase:
				(node as EnemyBase).retreat()
	phase = Phase.FLEE
	_phase_left = flee_time
	_flee_from = global_position
	_flee_to = Vector2(clampf(global_position.x, Layout.ARENA_RECT.position.x + 20.0, Layout.ARENA_RECT.end.x - 20.0),
			Layout.ARENA_RECT.position.y - 30.0)
	_play(&"guard", true)
	_say(tr(&"BOSS_MORDRED_FLEE"), flee_time, self)
	CombatFx.ring(self, global_position, 6.0, 40.0, 0.45, Color(SCABBARD, 0.85), 2.0)
	CombatFx.sfx(&"mordred_shout", &"boss_roar", -4.0)


func _tick_boss(delta: float) -> bool:
	if phase == Phase.FLEE:
		_tick_flee(delta)
		return true
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * (5.0 if boss_phase == 2 else 7.0))
		set_glow(SCABBARD, 0.08 + 0.08 * pulse + (0.2 if phase == Phase.SHIFT else 0.0))
	return false


## 逃走:先停一下(說話),再衝向場地上方,淡出;時間到就離開 enemy 群組(掉經驗與寶箱在他逃走的地方)。
func _tick_flee(delta: float) -> void:
	_phase_left -= delta
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	var t := 1.0 - clampf(_phase_left / maxf(flee_time, 0.001), 0.0, 1.0)
	if t >= 0.4:
		var k := (t - 0.4) / 0.6
		global_position = _flee_from.lerp(_flee_to, k * k)
		facing = Vector2.UP
		_play(&"dash")
		if sprite != null:
			sprite.modulate = Color(tint, 1.0 - k)
	if _phase_left <= 0.0:
		_finish_flee()


func _finish_flee() -> void:
	fled = true
	global_position = _flee_from
	EventBus.boss_hp_changed.emit(0, max_hp)
	defeated = true
	_defeat_left = 0.0
	die()


func is_fleeing() -> bool:
	return fleeing


# --- 共用 -----------------------------------------------------------------------

func _say(text: String, lifetime: float, who: Node2D) -> void:
	if who == null or not who.is_inside_tree():
		return
	var bubble := SpeechBubble.new()
	bubble.text = text
	bubble.lifetime = lifetime
	var size: Variant = who.get(&"_frame_size")
	var h := (size as Vector2).y if size is Vector2 else 24.0
	bubble.position = Vector2(0, -h * 0.55)
	who.add_child(bubble)


func _uses_separation() -> bool:
	return phase == Phase.IDLE or phase == Phase.DASH_RECOVER or phase == Phase.SLASH_RECOVER


func _is_committed() -> bool:
	return phase in [Phase.DASH_TELL, Phase.DASH, Phase.SLASH_TELL, Phase.SHIFT, Phase.SHIELD_RAISE, Phase.SUMMON_TELL,
			Phase.FLEE, Phase.STUNNED]


func _cancel_attack() -> void:
	super()
	if phase == Phase.SUMMON_TELL:
		_call_echoes()
		return
	_clear_marks()
	if phase in [Phase.DASH_TELL, Phase.DASH, Phase.SLASH_TELL]:
		_go_idle()
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


## 吠叫震不動劍鞘護盾與暈眩中的他(暈眩已經在了)。
func stun(duration: float) -> void:
	if shield_up or phase == Phase.STUNNED or fleeing:
		return
	super(duration)


func _on_defeat_started() -> void:
	_clear_marks()
	shield_up = false
	_play(&"down", true)


## 真正倒下的一刻:第一戰(逃走)只留下一團影子霧;最終戰單膝跪下(DefeatPose)。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	if _stun_dizzy != null and is_instance_valid(_stun_dizzy):
		_stun_dizzy.queue_free()
	_drop_summons()
	if fled:
		BitsScatter.burst(self, global_position + Vector2(0, -12), BitsScatter.Kind.MIST, MIST_COLORS, 8)
		return
	DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint, visual_scale, SCABBARD)
	CombatFx.ring(self, global_position, 6.0, 56.0, 0.6, Color(SCABBARD, 0.9), 2.0)
	CombatFx.ring(self, global_position, 4.0, 80.0, 0.7, Color(STEEL, 0.6), 1.0)
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.5)


func _draw_under() -> void:
	if defeated:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, _frame_size.x * 0.34 + pulse * 2.0, Color(SCABBARD, 0.1 + 0.05 * pulse + 0.05 * float(boss_phase - 1)))
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	super()
	if not shield_up or defeated or state != State.ACTIVE:
		return
	# 劍鞘護盾:罩住全身的紫色泡泡;外圈的弧 = 護盾還剩多少。
	var center := Vector2(0, -_frame_size.y * 0.2) + _sprite_base_offset
	var r := _frame_size.x * 0.5
	var pulse := 0.5 + 0.5 * sin(_age * 6.0)
	draw_circle(center, r, Color(SCABBARD, 0.16 + 0.06 * pulse))
	draw_arc(center, r, 0.0, TAU, 28, Color(SCABBARD.lightened(0.3), 0.6 + 0.2 * pulse), 1.0)
	var left := clampf(float(shield_left) / float(maxi(1, shield_hp)), 0.0, 1.0)
	draw_arc(center, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * left, 28, Color(1, 1, 1, 0.85), 2.0)
