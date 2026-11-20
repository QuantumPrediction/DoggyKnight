class_name MorganaBoss
extends BossBase
## 摩根娜(v2.6 AV7,最終頭目 3-6,64×64):紫斗篷、新月法杖的魔法師,三個階段。
## 數值在 data/enemies/morgana.tres,光球在 data/enemies/projectiles/moon_orb.tres,節奏在本場景的屬性欄。
## 共同的頭目行為(boss_appeared、血條、倒下演出、召喚)在 BossBase;第三階段由這裡加上。
##
## 平時飄在空中,和金毛保持 keep_min 至 keep_max 的距離。招式(每招都有預警並播 boss_warning):
## 1. 瞬間移動:目的地先亮月光圈(teleport_telegraph 0.7 秒),她在原地慢慢淡出,然後在圈中出現
##    (圈內的角色被月光彈開、受一點傷)。金毛貼太近時她比較常用這招拉開距離。
## 2. 狐火雨:金毛腳下和附近亮起 5 至 8 個預警圈(第一階段 5、第二 6、第三 8),依次填滿,
##    填滿時一團狐火落下(FallingFlame)。
## 3. 扇形月光球:fan_count 條扇形預警線(方向鎖定),之後沿線射出 moon_orb,線之間留有空隙。
## 第二階段(66% 起):召喚 2 個鏡像分身(morgana_clone,一下就打散,只會射較弱的單顆光球)。
## 第三階段(33% 起):加入旋轉的月光束——先畫紅線(起點)與淡淡的扇形(會掃過的範圍),
##   之後光束從紅線開始慢慢轉過扇形(站在扇形外、或繞著她跑就躲得開)。
## 換階段:停下施法(無敵)、月光圈、鏡頭震動、手機震動,然後立刻用新招。
## 倒下:坐在地上(down,DefeatPose 留在場上,不是受傷),分身一起散掉,還沒落下的狐火熄掉。

enum Phase { INTRO, IDLE, DRIFT, TELEPORT_TELL, RAIN_TELL, FAN_TELL, CLONE_TELL, BEAM_TELL, BEAM,
		RECOVER, SHIFT }

const MOON_ORB: ProjectileData = preload("res://data/enemies/projectiles/moon_orb.tres")
const VIOLET := Color(0.72, 0.42, 1.0)
const MOON := Color(1.0, 0.32, 0.58)             ## 月光圈(瞬間移動的落點,會彈開角色:紅色系)
const MOONLIGHT := Color(0.8, 0.85, 1.0)

@export_group("節奏")
@export var intro_time: float = 1.2
@export var idle_time: float = 0.9
@export var idle_time_phase2: float = 0.7
@export var idle_time_phase3: float = 0.55
@export var drift_speed_mult: float = 0.6       ## 等下一招時飄的速度(× 移動速度)
@export var keep_min: float = 66.0
@export var keep_max: float = 100.0
@export var float_height: float = 6.0
@export var shift_time: float = 1.2              ## 換階段時停下施法(無敵)的秒數
@export var phase3_threshold: float = 0.33       ## 生命降到這個比例進入第三階段(第二階段的門檻是 phase2_threshold)
@export_group("瞬間移動")
@export var teleport_telegraph: float = 0.7
@export var teleport_radius: float = 16.0        ## 月光圈半徑 = 出現時彈開的範圍
@export var teleport_damage: int = 8
@export var teleport_min: float = 62.0           ## 落點離目標的距離
@export var teleport_max: float = 95.0
@export var teleport_recover: float = 0.45
@export var too_close: float = 40.0              ## 目標比這個近:下一招多半是瞬間移動
@export_group("狐火雨")
@export var rain_counts: PackedInt32Array = PackedInt32Array([5, 6, 8])   ## 第一、二、三階段
@export var rain_telegraph: float = 0.95
@export var rain_stagger: float = 0.12           ## 每個圈比前一個晚這麼多秒填滿
@export var rain_radius: float = 12.0
@export var rain_spread: float = 56.0            ## 落點在目標附近多遠以內
@export var rain_spacing: float = 20.0           ## 落點之間至少相隔多遠
@export var rain_damage: int = 11
@export var rain_recover: float = 0.6
@export_group("扇形月光球")
@export var moon_orb: ProjectileData = MOON_ORB
@export var fan_count: int = 5
@export var fan_step_deg: float = 24.0
@export var fan_telegraph: float = 0.85
@export var fan_recover: float = 0.5
@export_group("鏡像分身(第二階段)")
@export var clone_enemy: StringName = &"morgana_clone"
@export var clone_count: int = 2
@export var clone_telegraph: float = 0.8
@export var clone_offset: float = 64.0
@export var clone_every: int = 4                 ## 分身都被打散後,每幾招再叫一次
@export_group("月光束(第三階段)")
@export var beam_every: int = 3                  ## 第三階段每幾招一次
@export var beam_telegraph: float = 1.0
@export var beam_width: float = 10.0
@export var beam_sweep_deg: float = 150.0        ## 一共轉多少度
@export var beam_speed_deg: float = 55.0         ## 每秒轉幾度(繞著她跑比光束快)
@export var beam_lead_deg: float = 30.0          ## 起點在目標前面多少度
@export var beam_damage: int = 13
@export var beam_recover: float = 0.8

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"teleport": 0, &"rain": 0, &"fan": 0, &"clone": 0, &"beam": 0}
var teleports_done: int = 0
var beam_angle: float = 0.0                       ## 目前光束的角度(弧度)

var _phase_left: float = 0.0
var _tell_total: float = 1.0
var _move_index: int = 0
var _after_shift: StringName = &""
var _ring_left: float = 0.0
var _teleport_to: Vector2 = Vector2.ZERO
var _fan_dirs: Array[Vector2] = []
var _fan_lengths: Array[float] = []
var _marks: Array[Node2D] = []
var _flames: Array[FallingFlame] = []
var _clone_points: Array[Vector2] = []
var _beam: MoonBeam
var _beam_sign: float = 1.0
var _beam_turned: float = 0.0
var _beam_hit: Array[Node2D] = []


func _on_ready() -> void:
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"cast"
	_play(&"cast", true)
	_moon_flare(CombatFx.feel().trauma_boss_roar * 0.6)


func _is_enraging() -> bool:
	return phase == Phase.SHIFT


func _ai(delta: float) -> void:
	_phase_left -= delta
	_float()
	match phase:
		Phase.INTRO:
			desired_velocity = Vector2.ZERO
			_face_target()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.IDLE, Phase.DRIFT:
			# 等下一招時慢慢飄,保持距離。
			_drift()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.TELEPORT_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"teleport"
			var p := _progress()
			_set_marks_progress(p)
			if sprite != null:
				sprite.modulate = Color(tint, 1.0 - 0.75 * p)
			if _phase_left <= 0.0:
				_arrive()
		Phase.RAIN_TELL, Phase.FAN_TELL, Phase.CLONE_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				match phase:
					Phase.RAIN_TELL:
						_start_recover(rain_recover)
					Phase.FAN_TELL:
						_release_fan()
					Phase.CLONE_TELL:
						_call_clones()
		Phase.BEAM_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_start_beam()
		Phase.BEAM:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			_tick_beam(delta)
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				_go_idle()
		Phase.SHIFT:
			desired_velocity = Vector2.ZERO
			anim_state = &"cast"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 70.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 56.0, 0.45, Color(VIOLET, 0.8), 2.0)
			if _phase_left <= 0.0:
				_end_shift()


func _progress() -> float:
	return 1.0 - _phase_left / maxf(_tell_total, 0.001)


func _float() -> void:
	if phase == Phase.SHIFT:
		return
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 2.0) * 1.5))
	if sprite != null:
		sprite.position = _sprite_base_offset


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	var dist := global_position.distance_to(target.global_position)
	if boss_phase >= 2 and alive_summons() == 0 and n % clone_every == 0:
		_start_clones()
	elif boss_phase >= 3 and n % beam_every == beam_every - 1:
		_start_beam_tell()
	elif dist < too_close and n % 2 == 0:
		_start_teleport()
	else:
		match n % 4:
			0:
				_start_fan()
			1, 3:
				_start_teleport()
			_:
				_start_rain()


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
		sprite.modulate = tint
		if not sprite.is_playing():
			sprite.play()


func _start_recover(seconds: float) -> void:
	_clear_marks()
	phase = Phase.RECOVER
	_phase_left = rest(seconds)
	anim_state = &"idle"


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


## 慢慢飄,保持距離。
func _drift() -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	_face_target()
	var dir := Vector2.ZERO
	if dist < keep_min:
		dir = -to_target.normalized()
	elif dist > keep_max:
		dir = to_target.normalized()
	else:
		dir = to_target.normalized().orthogonal()
	if not CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 12.0):
		dir = (Layout.ARENA_RECT.get_center() - global_position).normalized()
	desired_velocity = dir * data.move_speed * drift_speed_mult * _speed_mult()
	anim_state = &"run"


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


func _begin_tell(next: Phase, base: float, anim: StringName) -> void:
	_clear_marks()
	phase = next
	_tell_total = _tell_time(base)
	_phase_left = _tell_total
	anim_state = anim
	_play(anim, true)
	Sfx.play(&"boss_warning", -4.0)


# --- 瞬間移動 -------------------------------------------------------------------

func _start_teleport() -> void:
	moves_started[&"teleport"] += 1
	_teleport_to = pick_teleport_point()
	_begin_tell(Phase.TELEPORT_TELL, teleport_telegraph, &"teleport")
	_add_mark(AttackTelegraph.make_circle(teleport_radius, MOON), _teleport_to)
	CombatFx.ring(self, _teleport_to, 2.0, teleport_radius + 6.0, 0.4, Color(MOONLIGHT, 0.8), 1.0, true)


## 落點:離目標 teleport_min 至 teleport_max,在場內,離現在的位置也有一段距離。
func pick_teleport_point() -> Vector2:
	var center := target.global_position if target != null else Layout.ARENA_RECT.get_center()
	var bounds := CombatMath.arena_bounds(arena_margin + Vector2(4, 4))
	var best := CombatMath.clamp_to_bounds(center + Vector2(0, -teleport_min), arena_margin)
	var best_score := -INF
	for i in 12:
		var a := rng.randf() * TAU
		var point := center + Vector2.from_angle(a) * rng.randf_range(teleport_min, teleport_max)
		if not bounds.has_point(point):
			continue
		var score := point.distance_to(global_position) + rng.randf() * 20.0
		if score > best_score:
			best_score = score
			best = point
	return best


func _arrive() -> void:
	_clear_marks()
	teleports_done += 1
	var from := global_position
	global_position = _teleport_to
	if sprite != null:
		sprite.modulate = tint
	_play(&"teleport", true)
	var damage := scaled_damage(teleport_damage)
	for victim in victims():
		var offset := victim.global_position - global_position
		if offset.length() <= teleport_radius + 2.0:
			victim.call(&"take_damage", damage)
	CombatFx.ring(self, from, 4.0, 22.0, 0.3, Color(VIOLET, 0.7), 1.0)
	CombatFx.ring(self, global_position, 4.0, teleport_radius + 8.0, 0.35, Color(MOONLIGHT, 0.95), 2.0, true)
	CombatFx.particles(self, &"sparkle", global_position + _sprite_base_offset, false)
	CombatFx.sfx(&"teleport", &"magic")
	_face_target()
	_start_recover(teleport_recover)


# --- 狐火雨 ---------------------------------------------------------------------

func current_rain_count() -> int:
	if rain_counts.is_empty():
		return 5
	return rain_counts[clampi(boss_phase - 1, 0, rain_counts.size() - 1)]


func _start_rain() -> void:
	moves_started[&"rain"] += 1
	_begin_tell(Phase.RAIN_TELL, rain_telegraph, &"cast")
	var points := pick_rain_points(current_rain_count())
	var damage := scaled_damage(rain_damage)
	var tell_each := _tell_time(rain_telegraph)
	_prune_flames()
	for i in points.size():
		var flame := FallingFlame.drop(self, points[i], damage, rain_radius, tell_each, rain_stagger * float(i))
		if flame != null:
			_flames.append(flame)
	_phase_left = minf(_phase_left, tell_each * 0.6)
	_tell_total = maxf(_phase_left, 0.001)
	CombatFx.ring(self, global_position, 4.0, 30.0, 0.4, Color(VIOLET, 0.8), 2.0)


## 狐火的落點:第一個在目標腳下,其他在附近(彼此至少相隔 rain_spacing,都在場內)。
func pick_rain_points(count: int) -> Array[Vector2]:
	var center := target.global_position if target != null else Layout.ARENA_RECT.get_center()
	var points: Array[Vector2] = [CombatMath.clamp_to_arena(center, rain_radius)]
	var tries := 0
	while points.size() < count and tries < 80:
		tries += 1
		var p := CombatMath.clamp_to_arena(center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rain_spacing, rain_spread), rain_radius)
		var ok := true
		for q in points:
			if q.distance_to(p) < rain_spacing:
				ok = false
				break
		if ok:
			points.append(p)
	return points


func _prune_flames() -> void:
	var alive: Array[FallingFlame] = []
	for f in _flames:
		if is_instance_valid(f) and f.is_pending():
			alive.append(f)
	_flames = alive


func _fizzle_flames() -> void:
	for f in _flames:
		if is_instance_valid(f):
			f.fizzle()
	_flames.clear()


# --- 扇形月光球 ------------------------------------------------------------------

## 在距離 distance 的地方,相鄰兩顆月光球之間「角色中心可以站的空隙」有多寬(像素)。
func fan_gap_at(distance: float, victim_radius: float = 6.0) -> float:
	return 2.0 * distance * sin(deg_to_rad(fan_step_deg) * 0.5) - 2.0 * (moon_orb.hit_radius + victim_radius)


func _start_fan() -> void:
	if target == null or moon_orb == null:
		_go_idle()
		return
	moves_started[&"fan"] += 1
	_begin_tell(Phase.FAN_TELL, fan_telegraph, &"attack")
	var to_target := target.global_position - global_position
	var aim := to_target.normalized() if to_target.length() > 0.5 else facing
	facing = aim
	_fan_dirs.clear()
	_fan_lengths.clear()
	var n := maxi(1, fan_count)
	var step := deg_to_rad(fan_step_deg)
	for i in n:
		var dir := aim.rotated((float(i) - float(n - 1) * 0.5) * step)
		var length := EnemyProjectile.travel_length(global_position, dir, moon_orb.max_range)
		_fan_dirs.append(dir)
		_fan_lengths.append(length)
		_add_mark(AttackTelegraph.make_line(dir, length, moon_orb.telegraph_width()))


func _release_fan() -> void:
	_start_recover(fan_recover)
	_play(&"attack", true)
	var dmg := scaled_damage(moon_orb.damage) if moon_orb.damage > 0 else data.contact_damage
	for i in _fan_dirs.size():
		EnemyProjectile.launch(self, moon_orb, global_position, _fan_dirs[i], _fan_lengths[i], dmg,
				projectile_speed_mult(), self)
	CombatFx.sfx(&"magic", &"whoosh")


# --- 鏡像分身 -------------------------------------------------------------------

func _start_clones() -> void:
	moves_started[&"clone"] += 1
	_begin_tell(Phase.CLONE_TELL, clone_telegraph, &"cast")
	_clone_points.clear()
	var center := target.global_position if target != null else Layout.ARENA_RECT.get_center()
	for i in clone_count:
		var a := (-PI * 0.75 if i % 2 == 0 else -PI * 0.25) + rng.randf_range(-0.3, 0.3)
		_clone_points.append(CombatMath.clamp_to_arena(center + Vector2.from_angle(a) * clone_offset, 14.0))
	for point in _clone_points:
		_add_mark(AttackTelegraph.make_arrival_circle(10.0, AttackTelegraph.MAGIC), point)


func _call_clones() -> void:
	_clear_marks()
	summon_at(clone_enemy, _clone_points)
	CombatFx.sfx(&"teleport", &"magic")
	_start_recover(0.4)


# --- 月光束(第三階段) ------------------------------------------------------------

func _start_beam_tell() -> void:
	if target == null:
		_go_idle()
		return
	moves_started[&"beam"] += 1
	_begin_tell(Phase.BEAM_TELL, beam_telegraph, &"cast")
	_beam_sign = 1.0 if rng.randf() < 0.5 else -1.0
	var to_target := (target.global_position - global_position).angle()
	beam_angle = to_target + _beam_sign * deg_to_rad(beam_lead_deg)
	var sweep := deg_to_rad(beam_sweep_deg)
	var reach := _beam_length(Vector2.from_angle(beam_angle))
	# 淡淡的扇形 = 光束會掃過的範圍;紅線 = 光束的起點。
	var area := AttackTelegraph.make_sector(260.0, Vector2.from_angle(beam_angle - _beam_sign * sweep * 0.5), sweep * 0.5)
	area.modulate.a = 0.45
	_add_mark(area)
	_add_mark(AttackTelegraph.make_line(Vector2.from_angle(beam_angle), reach, beam_width))


func _beam_length(dir: Vector2) -> float:
	return maxf(20.0, CombatMath.distance_to_rect_edge(global_position, dir, Layout.ARENA_RECT.grow(-1.0)))


func _start_beam() -> void:
	_clear_marks()
	phase = Phase.BEAM
	_beam_turned = 0.0
	_beam_hit.clear()
	_beam = MoonBeam.new()
	_beam.width = beam_width
	CombatFx.layer_for(self).add_child(_beam)
	_beam.global_position = global_position
	_update_beam_node()
	CombatFx.trauma(self, 0.3)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.sfx(&"moon_beam", &"magic")


func _tick_beam(delta: float) -> void:
	var step := deg_to_rad(beam_speed_deg) * _speed_mult() * delta
	_beam_turned += step
	beam_angle -= _beam_sign * step
	_update_beam_node()
	var dir := Vector2.from_angle(beam_angle)
	var end := global_position + dir * _beam_length(dir)
	var damage := scaled_damage(beam_damage)
	for victim in victims():
		if _beam_hit.has(victim):
			continue
		if EnemyProjectile.segment_distance(global_position, end, victim.global_position) <= beam_width * 0.5 + radius_of(victim):
			_beam_hit.append(victim)
			victim.call(&"take_damage", damage)
	if _beam_turned >= deg_to_rad(beam_sweep_deg):
		_end_beam()
		_start_recover(beam_recover)


func _update_beam_node() -> void:
	if _beam == null or not is_instance_valid(_beam):
		return
	var dir := Vector2.from_angle(beam_angle)
	_beam.global_position = global_position + _sprite_base_offset * 0.5
	_beam.direction = dir
	_beam.length = _beam_length(dir)


func _end_beam() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null


func is_beaming() -> bool:
	return phase == Phase.BEAM


# --- 階段 -----------------------------------------------------------------------

func _on_damaged(amount: int) -> void:
	super(amount)
	if boss_phase == 2 and hp > 0 and float(hp) <= float(max_hp) * phase3_threshold:
		boss_phase = 3
		EventBus.boss_phase_changed.emit(3)
		_enter_phase_three()


func _enter_phase_two() -> void:
	_shift(&"clone")


func _enter_phase_three() -> void:
	_shift(&"beam")


## 換階段:停下施法(無敵)、月光圈、鏡頭震動、手機震動;結束後立刻用 next 這一招。
func _shift(next: StringName) -> void:
	_cancel_attack()
	phase = Phase.SHIFT
	_phase_left = shift_time
	_after_shift = next
	_ring_left = 0.0
	_hitstop_left = 0.0
	_play(&"cast", true)
	set_glow(VIOLET, 0.3)
	_moon_flare(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _end_shift() -> void:
	var next := _after_shift
	_after_shift = &""
	if sprite != null:
		sprite.position = _sprite_base_offset
	if target == null:
		_go_idle()
	elif next == &"clone":
		_start_clones()
	elif next == &"beam":
		_start_beam_tell()
	else:
		_go_idle()


func _moon_flare(trauma_amount: float) -> void:
	CombatFx.sfx(&"morgana_laugh", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 50.0, 0.5, Color(MOONLIGHT, 0.85), 2.0)
	CombatFx.ring(self, global_position, 4.0, 34.0, 0.4, Color(VIOLET, 0.8), 1.0)


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * (5.0 if boss_phase == 2 else 7.0))
		var base := 0.1 if boss_phase == 2 else 0.18
		set_glow(VIOLET, base + 0.1 * pulse + (0.2 if phase == Phase.SHIFT else 0.0))
	return false


func _uses_separation() -> bool:
	return phase == Phase.IDLE or phase == Phase.DRIFT or phase == Phase.RECOVER


func _is_committed() -> bool:
	return phase in [Phase.TELEPORT_TELL, Phase.RAIN_TELL, Phase.FAN_TELL, Phase.CLONE_TELL, Phase.BEAM_TELL, Phase.BEAM]


func _cancel_attack() -> void:
	super()
	_clear_marks()
	_end_beam()
	if sprite != null:
		sprite.modulate = tint
	if phase in [Phase.TELEPORT_TELL, Phase.FAN_TELL, Phase.CLONE_TELL, Phase.BEAM_TELL, Phase.BEAM, Phase.RAIN_TELL]:
		_go_idle()


func _on_defeat_started() -> void:
	_clear_marks()
	_end_beam()
	_fizzle_flames()
	_play(&"down", true)


## 真正倒下的一刻:摩根娜坐在地上(DefeatPose),月光與紫色光點。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	_end_beam()
	_fizzle_flames()
	var frames := sprite.sprite_frames if sprite != null else null
	var pose := DefeatPose.leave(self, frames, facing.x < 0.0, tint, visual_scale, MOONLIGHT)
	if pose != null:
		pose.global_position = global_position
	CombatFx.ring(self, global_position, 6.0, 56.0, 0.6, Color(MOONLIGHT, 0.9), 2.0)
	CombatFx.ring(self, global_position, 4.0, 80.0, 0.7, Color(VIOLET, 0.6), 1.0)
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.5)
	_drop_summons()


func _exit_tree() -> void:
	_end_beam()


func _draw_under() -> void:
	if not defeated:
		# 飄在空中:腳下一圈淡淡的月光;第二、三階段更亮。
		var pulse := 0.5 + 0.5 * sin(_age * 3.0)
		var a := 0.1 + 0.06 * pulse + 0.06 * float(boss_phase - 1)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.34 + pulse * 2.0, Color(MOONLIGHT if boss_phase < 3 else VIOLET, a))
		draw_set_transform(Vector2.ZERO)
