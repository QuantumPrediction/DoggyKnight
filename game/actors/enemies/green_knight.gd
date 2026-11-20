class_name GreenKnightBoss
extends BossBase
## 綠騎士(v2.6 AV6,第二章頭目 2-6,64×64):戴圓灌木葉子帽、愛笑的大騎士。
## 數值在 data/enemies/green_knight.tres(藤鞭傷害 = 接觸傷害),荊棘在 data/enemies/projectiles/thorn.tres,
## 節奏在本場景的屬性欄。共同的頭目行為(boss_appeared、血條、倒下演出、召喚)在 BossBase。
##
## 招式(每招都有預警並播 boss_warning):
## 1. 藤鞭:朝目標畫一條長長的紅線(方向鎖定),填滿時藤鞭沿線甩出去(身體碰到紅線就打中)。
##    第二階段連續兩次(第二次重新瞄準,也有完整預警)。
## 2. 荊棘環:地上畫出 thorn_count(8;第二階段 thorn_count_phase2)條放射的預警線,之後沿線射出荊棘;
##    每次轉半格,線與線之間離綠騎士越遠空隙越大(往外走就躲得開)。
## 3. 召喚:兩個紫色魔法圈,之後叫出 2 隻稻草人兵。
## 半血:播 hat_off——葉子帽掉到地上(LeafHat,可愛、不是受傷),停下來笑一下(無敵、鏡頭震動、手機震動),
##   之後速度 +25%(phase2_speed_mult)、藤鞭連續兩次。
## 倒下:單膝跪下(down),留在場上笑著(DefeatPose),叫來的稻草人兵一起倒下。
## 帽子掉下之後,有 `<動畫>_bare`(C 線的沒戴帽子版本:idle_bare、run_bare、attack_bare、hurt_bare、
## whip_bare、summon_bare)就播那個,沒有就播原本的動畫(_play 統一處理)。

enum Phase { INTRO, IDLE, CHASE, WHIP_TELL, WHIP_RECOVER, THORN_TELL, THORN_RECOVER, SUMMON_TELL,
		SUMMON_RECOVER, HAT_OFF }

const THORN: ProjectileData = preload("res://data/enemies/projectiles/thorn.tres")
const GREEN := Color(0.45, 0.85, 0.35)
const LEAF_COLORS: Array[Color] = [Color("4f9a34"), Color("2f6a24"), Color("9fdc62")]

@export_group("節奏")
@export var intro_time: float = 1.0              ## 冒出地面後大笑的秒數(不攻擊)
@export var idle_time: float = 0.9
@export var idle_time_phase2: float = 0.6
@export var chase_time: float = 1.2
@export var hat_off_time: float = 1.3            ## 半血時帽子掉下、停下來笑(無敵)的秒數
@export_group("藤鞭")
@export var whip_telegraph: float = 0.9
@export var whip_second_telegraph: float = 0.7   ## 第二階段第二鞭的預警(× 第二階段與難度倍數)
@export var whip_length: float = 120.0
@export var whip_width: float = 14.0             ## 預警線寬度 = 打中範圍
@export var whip_recover: float = 0.6
@export var whips_phase2: int = 2                ## 第二階段一次甩幾鞭
@export_group("荊棘環")
@export var thorn: ProjectileData = THORN
@export var thorn_count: int = 8
@export var thorn_count_phase2: int = 11
@export var thorn_telegraph: float = 0.85
@export var thorn_recover: float = 0.6
@export var thorn_close: float = 48.0            ## 目標比這個近時,較常用荊棘環(把貼身的金毛逼開)
@export_group("召喚")
@export var summon_enemy: StringName = &"scarecrow"
@export var summon_count: int = 2
@export var summon_telegraph: float = 1.0
@export var summon_recover: float = 0.5
@export var max_summons_alive: int = 3
@export var summon_every: int = 4
@export var summon_offset: float = 34.0

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"whip": 0, &"thorn": 0, &"summon": 0}
var hat_on: bool = true
var whips_released: int = 0

var _phase_left: float = 0.0
var _move_index: int = 0
var _whips_left: int = 0
var _whip_dir: Vector2 = Vector2.DOWN
var _whip_len: float = 100.0
var _thorn_dirs: Array[Vector2] = []
var _thorn_lengths: Array[float] = []
var _thorn_lines: Array[AttackTelegraph] = []
var _thorn_turn: float = 0.0
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []
var _laugh_ring_left: float = 0.0
var _tell_total: float = 1.0


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"summon"
	_play(&"summon", true)
	_laugh(CombatFx.feel().trauma_boss_roar * 0.6)


func _is_enraging() -> bool:
	return phase == Phase.HAT_OFF


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
			if to_target.length() <= whip_length * 0.7 or _phase_left <= 0.0:
				_start_whip(whips_phase2 if boss_phase >= 2 else 1)
		Phase.WHIP_TELL:
			desired_velocity = Vector2.ZERO
			_update_tell()
			if sprite != null:
				sprite.position = _sprite_base_offset - _whip_dir * 2.0 + Vector2(sin(_phase_left * 70.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_lash()
		Phase.THORN_TELL:
			desired_velocity = Vector2.ZERO
			var p := 1.0 - _phase_left / maxf(_tell_time(thorn_telegraph), 0.001)
			for line in _thorn_lines:
				if is_instance_valid(line):
					line.progress = p
			if _phase_left <= 0.0:
				_release_thorns()
		Phase.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			var p := 1.0 - _phase_left / maxf(_tell_time(summon_telegraph), 0.001)
			for mark in _summon_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _phase_left <= 0.0:
				_summon()
		Phase.WHIP_RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				if _whips_left > 0 and target != null:
					_start_whip(_whips_left, true)
				else:
					_go_idle()
		Phase.THORN_RECOVER, Phase.SUMMON_RECOVER:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0:
				_go_idle()
		Phase.HAT_OFF:
			desired_velocity = Vector2.ZERO
			anim_state = &"hat_off"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 60.0) * 1.0, 0).round()
			_laugh_ring_left -= delta
			if _laugh_ring_left <= 0.0:
				_laugh_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 50.0, 0.4, Color(GREEN, 0.7), 2.0)
			if _phase_left <= 0.0:
				_go_idle()


## 帽子掉下之後改播 `<動畫>_bare`(有的話)。
func _play(anim: StringName, restart: bool = false) -> void:
	super(bare_animation(anim), restart)


## anim 在現在的樣子(有沒有戴帽子)要播哪一個動畫。
func bare_animation(anim: StringName) -> StringName:
	if hat_on or sprite == null or sprite.sprite_frames == null:
		return anim
	var bare := StringName(String(anim) + "_bare")
	return bare if sprite.sprite_frames.has_animation(bare) else anim


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	var dist := global_position.distance_to(target.global_position)
	if n % summon_every == summon_every - 1 and alive_summons() < max_summons_alive:
		_start_summon()
	elif dist < thorn_close and n % 2 == 1:
		_start_thorns()
	elif dist <= whip_length - 10.0:
		_start_whip(whips_phase2 if boss_phase >= 2 else 1)
	elif n % 2 == 0:
		_start_thorns()
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


func _update_tell() -> void:
	if _telegraph != null:
		_telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)


func _face_target() -> void:
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()


# --- 藤鞭 -----------------------------------------------------------------------

## 開始藤鞭的預警。count = 這一輪一共甩幾鞭;second = 第二鞭(預警較短)。
func _start_whip(count: int, second: bool = false) -> void:
	if target == null:
		_go_idle()
		return
	if not second:
		moves_started[&"whip"] += 1
	_whips_left = maxi(0, count - 1)
	var to_target := target.global_position - global_position
	_whip_dir = to_target.normalized() if to_target.length() > 0.5 else facing
	facing = _whip_dir
	_whip_len = minf(whip_length, CombatMath.distance_to_rect_edge(global_position, _whip_dir, Layout.ARENA_RECT.grow(-2.0)))
	phase = Phase.WHIP_TELL
	_tell_total = _tell_time(whip_second_telegraph if second else whip_telegraph)
	_phase_left = _tell_total
	anim_state = &"whip"
	_play(&"whip", true)
	if sprite != null:
		sprite.pause()
	_show_telegraph(AttackTelegraph.make_line(_whip_dir, _whip_len, whip_width))
	Sfx.play(&"boss_warning", -4.0)


## 藤鞭甩出去:預警線範圍內(身體碰到線)的角色受傷。
func _lash() -> void:
	_clear_telegraph()
	whips_released += 1
	phase = Phase.WHIP_RECOVER
	_phase_left = rest(whip_recover) * (0.5 if _whips_left > 0 else 1.0)
	if sprite != null:
		sprite.position = _sprite_base_offset
		_play(&"whip")
		sprite.play()
	var end := global_position + _whip_dir * _whip_len
	for victim in victims():
		if EnemyProjectile.segment_distance(global_position, end, victim.global_position) <= whip_width * 0.5 + radius_of(victim):
			victim.call(&"take_damage", data.contact_damage)
	VineLash.lash(self, global_position, _whip_dir, _whip_len, whip_width)
	CombatFx.trauma(self, 0.25)
	CombatFx.sfx(&"whip", &"whoosh")


# --- 荊棘環 ---------------------------------------------------------------------

func current_thorn_count() -> int:
	return thorn_count_phase2 if boss_phase >= 2 else thorn_count


func _start_thorns() -> void:
	if thorn == null:
		_go_idle()
		return
	moves_started[&"thorn"] += 1
	phase = Phase.THORN_TELL
	_phase_left = _tell_time(thorn_telegraph)
	anim_state = &"attack"
	_play(&"attack", true)
	if sprite != null:
		sprite.pause()
	_clear_thorn_lines()
	_thorn_dirs.clear()
	_thorn_lengths.clear()
	var n := maxi(1, current_thorn_count())
	var step := TAU / float(n)
	_thorn_turn = fmod(_thorn_turn + step * 0.5, TAU)
	for i in n:
		var dir := Vector2.from_angle(_thorn_turn + step * float(i))
		var length := EnemyProjectile.travel_length(global_position, dir, thorn.max_range)
		_thorn_dirs.append(dir)
		_thorn_lengths.append(length)
		var line := AttackTelegraph.make_line(dir, length, thorn.telegraph_width())
		add_child(line)
		_thorn_lines.append(line)
	Sfx.play(&"boss_warning", -4.0)


func _release_thorns() -> void:
	_clear_thorn_lines()
	phase = Phase.THORN_RECOVER
	_phase_left = rest(thorn_recover)
	if sprite != null:
		sprite.play()
	var dmg := scaled_damage(thorn.damage) if thorn.damage > 0 else data.contact_damage
	for i in _thorn_dirs.size():
		EnemyProjectile.launch(self, thorn, global_position, _thorn_dirs[i], _thorn_lengths[i], dmg,
				projectile_speed_mult(), self)
	CombatFx.ring(self, global_position, 6.0, 30.0, 0.3, Color(GREEN, 0.9), 2.0, true)
	CombatFx.sfx(&"whoosh", &"swing")


func _clear_thorn_lines() -> void:
	for line in _thorn_lines:
		if is_instance_valid(line):
			line.queue_free()
	_thorn_lines.clear()


# --- 召喚 -----------------------------------------------------------------------

func _start_summon() -> void:
	moves_started[&"summon"] += 1
	phase = Phase.SUMMON_TELL
	_phase_left = _tell_time(summon_telegraph)
	anim_state = &"summon"
	_play(&"summon", true)
	_clear_summon_marks()
	_summon_points.clear()
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := Vector2(side * summon_offset, 10.0 + floorf(float(i) * 0.5) * 16.0)
		_summon_points.append(CombatMath.clamp_to_arena(global_position + offset, 10.0))
	for point in _summon_points:
		var mark := AttackTelegraph.make_arrival_circle(8.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_summon_marks.append(mark)
	_laugh(0.2)


func _summon() -> void:
	_clear_summon_marks()
	phase = Phase.SUMMON_RECOVER
	_phase_left = rest(summon_recover)
	anim_state = &"idle"
	summon_at(summon_enemy, _summon_points)


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


func _laugh(trauma_amount: float) -> void:
	CombatFx.sfx(&"green_knight_laugh", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 44.0, 0.45, Color(GREEN, 0.85), 2.0)


func _uses_separation() -> bool:
	return not (phase in [Phase.WHIP_TELL, Phase.THORN_TELL, Phase.SUMMON_TELL, Phase.HAT_OFF])


func _is_committed() -> bool:
	return phase in [Phase.WHIP_TELL, Phase.THORN_TELL, Phase.SUMMON_TELL]


# --- 第二階段:帽子掉下來 -------------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	phase = Phase.HAT_OFF
	_phase_left = hat_off_time
	_laugh_ring_left = 0.0
	_hitstop_left = 0.0
	hat_on = false
	_play(&"hat_off", true)
	var feel := CombatFx.feel()
	CombatFx.trauma(self, feel.trauma_boss_roar)
	CombatFx.haptic(feel.haptic_boss_slam)
	CombatFx.sfx(&"green_knight_laugh", &"boss_roar")
	LeafHat.drop(self, _frame_size.y * 0.75, -1.0 if facing.x < 0.0 else 1.0)
	BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.45), BitsScatter.Kind.LEAF, LEAF_COLORS, 12)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(GREEN, 0.08 + 0.08 * pulse + (0.15 if phase == Phase.HAT_OFF else 0.0))
	return false


func _cancel_attack() -> void:
	super()
	_clear_thorn_lines()
	_clear_summon_marks()
	_whips_left = 0
	if phase in [Phase.WHIP_TELL, Phase.THORN_TELL, Phase.SUMMON_TELL]:
		_go_idle()
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


func _on_defeat_started() -> void:
	_clear_thorn_lines()
	_clear_summon_marks()
	_play(&"down", true)


## 真正倒下的一刻:留下單膝跪下的綠騎士(DefeatPose),葉子飛散。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint, visual_scale, GREEN)
	BitsScatter.burst(self, global_position + Vector2(0, -_frame_size.y * 0.3), BitsScatter.Kind.LEAF, LEAF_COLORS, 18)
	CombatFx.ring(self, global_position, 6.0, 50.0, 0.5, Color(GREEN, 0.9), 2.0)
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.4)
	_drop_summons()


func _draw_under() -> void:
	if boss_phase >= 2 and not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.36 + pulse * 2.0, Color(GREEN, 0.14 + 0.1 * pulse))
		draw_set_transform(Vector2.ZERO)
