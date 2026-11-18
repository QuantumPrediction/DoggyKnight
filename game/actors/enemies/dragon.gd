class_name DragonBoss
extends BossBase
## 紅龍與白龍(v2.7 AW4,第五章雙頭目 5-6,64×64):圓滾滾的兩條龍,吵了一千年的架。
## 同一個腳本,element 決定是哪一條:red_dragon.tscn(火)與 white_dragon.tscn(冰)。
## 數值在 data/enemies/red_dragon.tres、white_dragon.tres;火球在 data/enemies/projectiles/fireball.tres,
## 冰刺在 ice_shard.tres;節奏在場景的屬性欄。共同的頭目行為(boss_appeared、倒下演出)在 BossBase。
##
## 兩條龍同時在場、各有自己的生命:
## - 配對:生成時找場上另一條龍當搭檔。頭目血條顯示「紅龍與白龍」(boss_appeared(&"twin_dragons")),
##   生命是兩條加起來(boss_hp_changed 的 current、maximum 都是合計),一條坐下後血條剩下另一條的部分。
##   只有一條龍時(無盡試煉)顯示自己的名字和生命。
## - 輪流:搭檔正在預警、吐息或剛出完招喘氣時,自己先等一下,不會兩條同時預警(手機上看得清楚、躲得開)。
## - 紅龍(火):火焰吐息(扇形紅色預警,填滿後噴火,BreathCone)與火球(拋物線,落點先出現影子)。
## - 白龍(冰):冰霜吐息(扇形紅色預警)與冰刺環(放射的預警線,之後沿線射出 ice_shard,
##   線與線之間離白龍越遠空隙越大)。
## - 一條的生命歸零:播 sulk 坐下生悶氣(不是受傷;DefeatPose 留在場上,頭上冒「哼!」),離開 enemy 群組;
##   另一條 roar 大吼(無敵、鏡頭震動、手機震動、boss_phase_changed(2))後暴怒:更快、預警較短
##   (phase2_telegraph_mult,仍有完整預警)、休息較短、火球與冰刺更多。兩條都坐下才過關。

enum Element { FIRE, ICE }
enum Phase { INTRO, IDLE, BREATH_TELL, BREATH, VOLLEY_TELL, RING_TELL, RECOVER, ROAR }

const FIREBALL: ProjectileData = preload("res://data/enemies/projectiles/fireball.tres")
const ICE_SHARD: ProjectileData = preload("res://data/enemies/projectiles/ice_shard.tres")
const TWIN_ID: StringName = &"twin_dragons"
const FIRE := Color(1.0, 0.45, 0.25)
const ICE := Color(0.6, 0.88, 1.0)
const STEAM := Color(1, 1, 1, 0.9)

@export var element: Element = Element.FIRE
@export_group("節奏")
@export var intro_time: float = 1.0
@export var idle_time: float = 1.8
@export var idle_time_enraged: float = 1.2
@export var home_offset: Vector2 = Vector2(-56, -44)   ## 平時待在目標的哪裡(白龍的 x 相反);暴怒後不分左右
@export var drift_speed_mult: float = 0.7
@export var float_height: float = 4.0
@export var turn_wait: float = 0.35              ## 搭檔正在預警時,先等這麼久再看
@export var roar_time: float = 1.2               ## 搭檔坐下後大吼(無敵)的秒數
@export var enraged_rest_mult: float = 1.0
@export_group("吐息")
@export var breath_telegraph: float = 0.95
@export var breath_radius: float = 60.0          ## 扇形預警 = 打中範圍
@export var breath_half_angle_deg: float = 28.0
@export var breath_time: float = 0.5
@export var breath_damage: int = 11
@export var breath_recover: float = 0.8
@export var breath_close: float = 40.0           ## 目標比這個近時,下一招多半是吐息
@export_group("火球(紅龍)")
@export var fireball: ProjectileData = FIREBALL
@export var volley_count: int = 3
@export var volley_count_enraged: int = 4
@export var volley_delay: float = 0.5            ## 影子出現到火球吐出的秒數
@export var volley_spread: float = 48.0
@export var volley_spacing: float = 28.0
@export var volley_recover: float = 0.6
@export_group("冰刺環(白龍)")
@export var ice_shard: ProjectileData = ICE_SHARD
@export var ring_count: int = 10
@export var ring_count_enraged: int = 12
@export var ring_telegraph: float = 0.85
@export var ring_recover: float = 0.6

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"breath": 0, &"volley": 0, &"ring": 0}
var partner: DragonBoss
var enraged: bool = false
var sulked: bool = false

var _phase_left: float = 0.0
var _tell_total: float = 1.0
var _move_index: int = 0
var _ring_left: float = 0.0
var _partner_max: int = 0
var _breath_dir: Vector2 = Vector2.DOWN
var _breath_hit: Array[Node2D] = []
var _marks: Array[Node2D] = []
var _ring_dirs: Array[Vector2] = []
var _ring_lengths: Array[float] = []
var _ring_turn: float = 0.0
var _shots: Array[LobbedShot] = []
var _pair_check_left: float = 0.0


func _on_ready() -> void:
	_sprite_base_offset = Vector2(0, -float_height)
	find_partner()


func is_fire() -> bool:
	return element == Element.FIRE


## 找場上另一條還沒有搭檔的龍(另一種元素)。找到就互相記住對方的最大生命(血條合計用)。
func find_partner() -> void:
	if has_partner() or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var other := node as DragonBoss
		if other == null or other == self or other.element == element or other.defeated:
			continue
		if other.has_partner():
			continue
		partner = other
		other.partner = self
		_partner_max = other.max_hp
		other._partner_max = max_hp
		return


func has_partner() -> bool:
	return _partner_max > 0


## 搭檔還在打(沒有坐下)。
func partner_active() -> bool:
	return partner != null and is_instance_valid(partner) and partner.is_inside_tree() and not partner.defeated


func partner_hp() -> int:
	if partner != null and is_instance_valid(partner) and not partner.defeated:
		return partner.hp
	return 0


func boss_bar_id() -> StringName:
	return TWIN_ID if has_partner() else super()


## 頭目血條:兩條龍的生命加起來(一條坐下後,那一條算 0)。
func emit_hp() -> void:
	if has_partner():
		EventBus.boss_hp_changed.emit(hp + partner_hp(), max_hp + _partner_max)
	else:
		EventBus.boss_hp_changed.emit(hp, max_hp)


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"roar"
	_play(&"roar", true)
	_puff(CombatFx.feel().trauma_boss_roar * 0.5)


func _is_enraging() -> bool:
	return phase == Phase.ROAR


func _ai(delta: float) -> void:
	_phase_left -= delta
	_float()
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
		Phase.BREATH_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"breath"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_start_breath()
		Phase.BREATH:
			desired_velocity = Vector2.ZERO
			anim_state = &"breath"
			_breathe_hits()
			if _phase_left <= 0.0:
				_start_recover(breath_recover)
		Phase.VOLLEY_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			if _phase_left <= 0.0:
				_start_recover(volley_recover)
		Phase.RING_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_release_ring()
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if _phase_left <= 0.0:
				_go_idle()
		Phase.ROAR:
			desired_velocity = Vector2.ZERO
			anim_state = &"roar"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 70.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 56.0, 0.45, Color(_color(), 0.8), 2.0)
			if _phase_left <= 0.0:
				_go_idle()
				_phase_left = 0.2


func _progress() -> float:
	return 1.0 - _phase_left / maxf(_tell_total, 0.001)


func _color() -> Color:
	return FIRE if is_fire() else ICE


func _float() -> void:
	if phase == Phase.ROAR:
		return
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 2.2 + (0.0 if is_fire() else 1.7)) * 1.5))
	if sprite != null:
		sprite.position = _sprite_base_offset


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


## 慢慢飄到目標的斜上方(紅龍在左、白龍在右;暴怒後不分左右)。
func _drift() -> void:
	anim_state = &"idle"
	if target == null:
		desired_velocity = Vector2.ZERO
		return
	_face_target()
	var offset := home_offset
	if not is_fire():
		offset.x = -offset.x
	if enraged or not has_partner():
		offset.x = 0.0 if absf(target.global_position.x - global_position.x) < 30.0 else offset.x * 0.5
	var home := CombatMath.clamp_to_bounds(target.global_position + offset, arena_margin)
	var to_home := home - global_position
	if to_home.length() < 4.0:
		desired_velocity = Vector2.ZERO
		return
	desired_velocity = to_home.normalized() * data.move_speed * drift_speed_mult * _speed_mult()
	anim_state = &"run"


# --- 選招與輪流 -------------------------------------------------------------------

## 正在預警或吐息。
func is_telling() -> bool:
	return phase in [Phase.BREATH_TELL, Phase.BREATH, Phase.VOLLEY_TELL, Phase.RING_TELL]


## 搭檔正在預警、吐息或剛出完招喘氣:自己先等(兩條輪流出招,中間有空檔)。
func _partner_busy() -> bool:
	return partner_active() and (partner.is_telling() or partner.phase == Phase.RECOVER)


func _next_move() -> void:
	if _partner_busy():
		phase = Phase.IDLE
		_phase_left = turn_wait
		return
	var n := _move_index
	_move_index += 1
	var dist := global_position.distance_to(target.global_position)
	if (dist < breath_close and n % 3 != 2) or n % 2 == 0:
		_start_breath_tell()
	elif is_fire():
		_start_volley()
	else:
		_start_ring()


func _go_idle() -> void:
	phase = Phase.IDLE
	_phase_left = _rest_time(idle_time_enraged if enraged else idle_time)
	anim_state = &"idle"
	if sprite != null:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


func _rest_time(seconds: float) -> float:
	return rest(seconds) * (enraged_rest_mult if enraged else 1.0)


func _start_recover(seconds: float) -> void:
	_clear_marks()
	phase = Phase.RECOVER
	_phase_left = _rest_time(seconds)
	anim_state = &"idle"


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


func _add_mark(mark: AttackTelegraph) -> void:
	add_child(mark)
	_marks.append(mark)


func _clear_marks() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()


# --- 吐息 -----------------------------------------------------------------------

func _start_breath_tell() -> void:
	moves_started[&"breath"] += 1
	var to_target := target.global_position - global_position
	_breath_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	facing = _breath_dir
	_begin_tell(Phase.BREATH_TELL, breath_telegraph, &"breath")
	if sprite != null:
		sprite.pause()
	_add_mark(AttackTelegraph.make_sector(breath_radius, _breath_dir, deg_to_rad(breath_half_angle_deg)))


func _start_breath() -> void:
	_clear_marks()
	phase = Phase.BREATH
	_phase_left = breath_time
	_breath_hit.clear()
	if sprite != null:
		sprite.play()
	BreathCone.blow(self, global_position, _breath_dir, breath_radius, deg_to_rad(breath_half_angle_deg), breath_time,
			not is_fire())
	CombatFx.trauma(self, 0.2)
	CombatFx.sfx(&"fire_breath" if is_fire() else &"ice_breath", &"whoosh")
	_breathe_hits()


## 吐息期間,扇形內(和預警同一個範圍)的角色各受一次傷。
func _breathe_hits() -> void:
	var damage := scaled_damage(breath_damage)
	var half := deg_to_rad(breath_half_angle_deg)
	for victim in victims():
		if _breath_hit.has(victim):
			continue
		var r := radius_of(victim)
		if CombatMath.in_sector(global_position, _breath_dir, victim.global_position, breath_radius + r * 0.5, half, r + 2.0):
			_breath_hit.append(victim)
			victim.call(&"take_damage", damage)


# --- 火球(紅龍) -------------------------------------------------------------------

func current_volley_count() -> int:
	return volley_count_enraged if enraged else volley_count


func _start_volley() -> void:
	if fireball == null:
		_go_idle()
		return
	moves_started[&"volley"] += 1
	_begin_tell(Phase.VOLLEY_TELL, volley_delay, &"attack")
	var dmg := scaled_damage(fireball.damage) if fireball.damage > 0 else data.contact_damage
	var points := pick_volley_points(current_volley_count())
	_prune_shots()
	for i in points.size():
		var shot := LobbedShot.lob(self, fireball, global_position + Vector2(0, -8), points[i], dmg,
				_tell_time(volley_delay) + 0.08 * float(i), 0.55, projectile_speed_mult(), 44.0)
		if shot != null:
			shot.splash = &"fire"
			_shots.append(shot)


func pick_volley_points(count: int) -> Array[Vector2]:
	var center := target.global_position if target != null else Layout.ARENA_RECT.get_center()
	var r := fireball.hit_radius
	var points: Array[Vector2] = [CombatMath.clamp_to_arena(center, r)]
	var tries := 0
	while points.size() < count and tries < 60:
		tries += 1
		var p := CombatMath.clamp_to_arena(center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(volley_spacing, volley_spread), r)
		var ok := true
		for q in points:
			if q.distance_to(p) < volley_spacing:
				ok = false
				break
		if ok:
			points.append(p)
	return points


func _prune_shots() -> void:
	var alive: Array[LobbedShot] = []
	for s in _shots:
		if is_instance_valid(s) and s.is_pending():
			alive.append(s)
	_shots = alive


# --- 冰刺環(白龍) -----------------------------------------------------------------

func current_ring_count() -> int:
	return ring_count_enraged if enraged else ring_count


func _start_ring() -> void:
	if ice_shard == null:
		_go_idle()
		return
	moves_started[&"ring"] += 1
	_begin_tell(Phase.RING_TELL, ring_telegraph, &"attack")
	_ring_dirs.clear()
	_ring_lengths.clear()
	var n := maxi(1, current_ring_count())
	var step := TAU / float(n)
	_ring_turn = fmod(_ring_turn + step * 0.5, TAU)
	for i in n:
		var dir := Vector2.from_angle(_ring_turn + step * float(i))
		var length := EnemyProjectile.travel_length(global_position, dir, ice_shard.max_range)
		_ring_dirs.append(dir)
		_ring_lengths.append(length)
		_add_mark(AttackTelegraph.make_line(dir, length, ice_shard.telegraph_width()))


func _release_ring() -> void:
	_start_recover(ring_recover)
	_play(&"attack", true)
	var dmg := scaled_damage(ice_shard.damage) if ice_shard.damage > 0 else data.contact_damage
	for i in _ring_dirs.size():
		EnemyProjectile.launch(self, ice_shard, global_position, _ring_dirs[i], _ring_lengths[i], dmg,
				projectile_speed_mult(), self)
	CombatFx.ring(self, global_position, 6.0, 30.0, 0.3, Color(ICE, 0.9), 2.0, true)
	CombatFx.sfx(&"ice", &"whoosh")


## 在距離 distance 的地方,相鄰兩根冰刺之間「角色中心可以站的空隙」有多寬(像素)。
func ring_gap_at(distance: float, victim_radius: float = 6.0) -> float:
	var step := TAU / float(maxi(1, current_ring_count()))
	return 2.0 * distance * sin(step * 0.5) - 2.0 * (ice_shard.hit_radius + victim_radius)


# --- 坐下生悶氣與暴怒 -------------------------------------------------------------------

## 生命歸零:搭檔還在打時,倒下演出短一點、不放慢動作(戰鬥還沒結束)。
func die() -> void:
	if not defeated and partner_active():
		defeat_slowmo_scale = 0.0
		defeat_impact = 0.35
		defeat_time_scale = 0.5
	super()


func _on_defeat_started() -> void:
	sulked = true
	_clear_marks()
	_fizzle_shots()
	_play(&"sulk", true)
	if partner_active():
		partner.on_partner_sulked()
	emit_hp()


## 搭檔坐下了:大吼一聲(無敵),之後暴怒。
func on_partner_sulked() -> void:
	if defeated or enraged:
		return
	enraged = true
	boss_phase = 2
	EventBus.boss_phase_changed.emit(2)
	_cancel_attack()
	phase = Phase.ROAR
	_phase_left = roar_time
	_ring_left = 0.0
	_hitstop_left = 0.0
	_play(&"roar", true)
	set_glow(_color(), 0.3)
	_puff(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _puff(trauma_amount: float) -> void:
	CombatFx.sfx(&"dragon_roar", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 48.0, 0.5, Color(_color(), 0.85), 2.0)


## 自己的第二階段只由搭檔坐下觸發(phase2_threshold = 0)。
func _enter_phase_two() -> void:
	pass


func _tick_boss(delta: float) -> bool:
	if not has_partner():
		_pair_check_left -= delta
		if _pair_check_left <= 0.0:
			_pair_check_left = 0.5
			find_partner()
			if has_partner() and appeared:
				EventBus.boss_appeared.emit(boss_bar_id())
				emit_hp()
	if enraged:
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		set_glow(_color(), 0.1 + 0.1 * pulse + (0.2 if phase == Phase.ROAR else 0.0))
	return false


func _uses_separation() -> bool:
	return phase == Phase.IDLE or phase == Phase.RECOVER or phase == Phase.INTRO


func _is_committed() -> bool:
	return is_telling() or phase == Phase.ROAR


func _cancel_attack() -> void:
	super()
	_clear_marks()
	for s in _shots:
		if is_instance_valid(s):
			s.cancel()
	if is_telling():
		_go_idle()


func _fizzle_shots() -> void:
	_prune_shots()
	for s in _shots:
		s.fizzle()
	_shots.clear()


## 真正坐下的一刻:留下坐著生悶氣的龍(DefeatPose 播 sulk),頭上冒「哼!」與一縷白煙。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	_fizzle_shots()
	var pose := DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint,
			visual_scale, _color(), &"sulk")
	if pose != null:
		var bubble := SpeechBubble.new()
		bubble.text = tr(&"BOSS_DRAGON_SULK")
		bubble.lifetime = 1.4
		bubble.position = Vector2(0, -_frame_size.y * 0.45)
		pose.add_child(bubble)
	var puff := CombatFx.spawn(self, &"dust", global_position + Vector2(0, -_frame_size.y * 0.4), 0.0, Vector2.ONE * 1.2,
			STEAM, false, 0.8)
	if puff != null:
		puff.drift = Vector2(0, -16.0)
		puff.fade_out = true
	CombatFx.ring(self, global_position, 6.0, 44.0, 0.5, Color(_color(), 0.9), 2.0)
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)


func _draw_under() -> void:
	if not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 3.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.34 + pulse * 2.0, Color(_color(), 0.1 + 0.06 * pulse + (0.08 if enraged else 0.0)))
		draw_set_transform(Vector2.ZERO)
