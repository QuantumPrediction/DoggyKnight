class_name KrakenBoss
extends BossBase
## 章魚王(v2.7 AW2,第四章頭目 4-6,64×64):珊瑚紅色、戴貝殼王冠的大章魚(其實只是肚子餓)。
## 數值在 data/enemies/kraken.tres;泡泡在 data/enemies/projectiles/bubble.tres,墨汁在 ink_blob.tres;
## 節奏在本場景的屬性欄。共同的頭目行為(boss_appeared、血條、倒下演出、召喚)在 BossBase。
##
## 待在場地上方,慢慢左右飄著跟著金毛。招式(每招都有預警並播 boss_warning):
## 1. 觸手:從場地左邊、右邊或下面伸進來,先畫一條長長的紅線(經過金毛現在的位置),
##    tentacle_telegraph 秒後觸手沿線拍下(TentacleSlam)。往旁邊走開就躲得掉。
##    第二階段連續兩次(第二次換一個方向、重新瞄準,也有完整預警)。
## 2. 墨汁:噴出 ink_count 團墨汁(LobbedShot),落點先出現影子;落地後留下一小片暗區,幾秒後消失(InkPuddle)。
## 3. 扇形泡泡:bubble_count 條扇形預警線(方向鎖定),之後沿線吐出慢慢飄的泡泡,線之間有空隙。
## 4. 召喚(第二階段):兩個紫色魔法圈,之後叫出 2 隻電電水母。
## 半血:停下大叫(無敵、鏡頭震動、手機震動),之後預警 × phase2_telegraph_mult、觸手連續兩次。
## 倒下:軟趴趴地趴在地上嘟嘴(down,DefeatPose 留在場上),冒一大串泡泡;叫來的水母一起散掉。

enum Phase { INTRO, IDLE, TENTACLE, INK_TELL, BUBBLE_TELL, SUMMON_TELL, RECOVER, ROAR }

const BUBBLE: ProjectileData = preload("res://data/enemies/projectiles/bubble.tres")
const INK_BLOB: ProjectileData = preload("res://data/enemies/projectiles/ink_blob.tres")
const CORAL := Color(1.0, 0.45, 0.4)
const SEA := Color(0.6, 0.85, 1.0)
const BUBBLE_COLORS: Array[Color] = [Color(0.8, 0.95, 1.0, 0.9), Color(0.6, 0.85, 1.0, 0.9), Color(1.0, 0.8, 0.8, 0.9)]

@export_group("節奏")
@export var intro_time: float = 1.0
@export var idle_time: float = 1.0
@export var idle_time_phase2: float = 0.7
@export var home_depth: float = 44.0             ## 待在戰鬥區上緣之下幾像素
@export var drift_speed_mult: float = 0.6
@export var roar_time: float = 1.2               ## 半血時大叫(無敵)的秒數
@export_group("觸手")
@export var tentacle_telegraph: float = 1.0
@export var tentacle_second_telegraph: float = 0.85
@export var tentacle_width: float = 18.0         ## 紅線寬度 = 打中範圍
@export var tentacle_damage: int = 15
@export var tentacles_phase2: int = 2
@export var tentacle_recover: float = 0.7
@export_group("墨汁")
@export var ink: ProjectileData = INK_BLOB
@export var ink_count: int = 3
@export var ink_count_phase2: int = 4
@export var ink_delay: float = 0.5               ## 影子出現到墨汁噴出的秒數(× 第二階段與難度)
@export var ink_spread: float = 40.0
@export var ink_spacing: float = 24.0
@export var ink_puddle_time: float = 4.0
@export var ink_recover: float = 0.6
@export_group("扇形泡泡")
@export var bubble: ProjectileData = BUBBLE
@export var bubble_count: int = 5
@export var bubble_step_deg: float = 22.0
@export var bubble_telegraph: float = 0.85
@export var bubble_recover: float = 0.5
@export_group("召喚(第二階段)")
@export var summon_enemy: StringName = &"jellyfish"
@export var summon_count: int = 2
@export var summon_telegraph: float = 1.0
@export var max_summons_alive: int = 3
@export var summon_every: int = 4
@export var summon_offset: float = 40.0

var phase: Phase = Phase.INTRO
var moves_started: Dictionary = {&"tentacle": 0, &"ink": 0, &"bubble": 0, &"summon": 0}
var tentacles_struck: int = 0

var _phase_left: float = 0.0
var _tell_total: float = 1.0
var _move_index: int = 0
var _tentacles_left: int = 0
var _last_side: int = -1
var _ring_left: float = 0.0
var _marks: Array[Node2D] = []
var _bubble_dirs: Array[Vector2] = []
var _bubble_lengths: Array[float] = []
var _summon_points: Array[Vector2] = []
var _slams: Array[TentacleSlam] = []
var _shots: Array[LobbedShot] = []


func _on_activated() -> void:
	super()
	phase = Phase.INTRO
	_phase_left = intro_time
	anim_state = &"summon"
	_play(&"summon", true)
	_bellow(CombatFx.feel().trauma_boss_roar * 0.6)


func _is_enraging() -> bool:
	return phase == Phase.ROAR


func _ai(delta: float) -> void:
	_phase_left -= delta
	match phase:
		Phase.INTRO:
			desired_velocity = Vector2.ZERO
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.IDLE:
			_drift()
			if _phase_left <= 0.0 and target != null:
				_next_move()
		Phase.TENTACLE:
			desired_velocity = Vector2.ZERO
			anim_state = &"slam"
			if _phase_left <= 0.0:
				if _tentacles_left > 0 and target != null:
					_strike_tentacle(true)
				else:
					_start_recover(tentacle_recover)
		Phase.INK_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"ink"
			if _phase_left <= 0.0:
				_start_recover(ink_recover)
		Phase.BUBBLE_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_release_bubbles()
		Phase.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"summon"
			_set_marks_progress(_progress())
			if _phase_left <= 0.0:
				_summon()
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			if _phase_left <= 0.0:
				_go_idle()
		Phase.ROAR:
			desired_velocity = Vector2.ZERO
			anim_state = &"summon"
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_phase_left * 60.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 56.0, 0.45, Color(CORAL, 0.75), 2.0)
			if _phase_left <= 0.0:
				if sprite != null:
					sprite.position = _sprite_base_offset
				_start_tentacles()


func _progress() -> float:
	return 1.0 - _phase_left / maxf(_tell_total, 0.001)


## 在上方慢慢左右飄,跟著目標的 x。
func _drift() -> void:
	anim_state = &"idle"
	if target == null:
		desired_velocity = Vector2.ZERO
		return
	var home := Vector2(target.global_position.x, Layout.ARENA_RECT.position.y + home_depth)
	home = CombatMath.clamp_to_bounds(home, arena_margin)
	var to_home := home - global_position
	if to_home.length() < 3.0:
		desired_velocity = Vector2.ZERO
		return
	desired_velocity = to_home.normalized() * data.move_speed * drift_speed_mult * _speed_mult()
	anim_state = &"run"
	if absf(to_home.x) > 1.0:
		facing = Vector2(signf(to_home.x), 0)


# --- 選招 -----------------------------------------------------------------------

func _next_move() -> void:
	var n := _move_index
	_move_index += 1
	if boss_phase >= 2 and n % summon_every == summon_every - 1 and alive_summons() < max_summons_alive:
		_start_summon()
		return
	match n % 4:
		0, 3:
			_start_tentacles()
		1:
			_start_bubbles()
		_:
			_start_ink()


func _go_idle() -> void:
	phase = Phase.IDLE
	_phase_left = rest(idle_time_phase2 if boss_phase >= 2 else idle_time)
	anim_state = &"idle"
	if sprite != null:
		sprite.position = _sprite_base_offset
		if not sprite.is_playing():
			sprite.play()


func _start_recover(seconds: float) -> void:
	_clear_marks()
	phase = Phase.RECOVER
	_phase_left = rest(seconds)
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


# --- 觸手 -----------------------------------------------------------------------

func _start_tentacles() -> void:
	moves_started[&"tentacle"] += 1
	_tentacles_left = tentacles_phase2 if boss_phase >= 2 else 1
	_strike_tentacle(false)


## 從邊緣伸一條觸手(經過目標現在的位置)。second = 第二次(預警較短、換方向)。
func _strike_tentacle(second: bool) -> void:
	_tentacles_left -= 1
	var side := _pick_side(second)
	var lane := TentacleSlam.lane_through(target.global_position if target != null else Layout.PLAYER_START, side)
	var tell_seconds := _tell_time(tentacle_second_telegraph if second else tentacle_telegraph)
	var slam := TentacleSlam.strike(self, lane[0], lane[1], lane[2], tentacle_width, tell_seconds,
			scaled_damage(tentacle_damage))
	if slam != null:
		_slams.append(slam)
	tentacles_struck += 1
	phase = Phase.TENTACLE
	_tell_total = tell_seconds
	# 等觸手拍下(加一點點)再出下一條或休息:同一時間只有一條觸手在預警。
	_phase_left = tell_seconds + 0.2
	anim_state = &"slam"
	_play(&"slam", true)
	Sfx.play(&"boss_warning", -4.0)
	CombatFx.ring(self, global_position, 4.0, 30.0, 0.35, Color(CORAL, 0.8), 2.0)


## 觸手從哪一邊來:第一次看目標在哪一半(從近的一邊);第二次換成和上一次不同方向(橫的換直的)。
func _pick_side(second: bool) -> int:
	var side := 0
	if second:
		side = 2 if _last_side != 2 else (0 if rng.randf() < 0.5 else 1)
	elif target != null:
		side = 0 if target.global_position.x < Layout.ARENA_RECT.get_center().x else 1
		if rng.randf() < 0.3:
			side = 2
	_last_side = side
	return side


func _prune_slams() -> void:
	var alive: Array[TentacleSlam] = []
	for s in _slams:
		if is_instance_valid(s):
			alive.append(s)
	_slams = alive


# --- 墨汁 -----------------------------------------------------------------------

func current_ink_count() -> int:
	return ink_count_phase2 if boss_phase >= 2 else ink_count


func _start_ink() -> void:
	if ink == null or target == null:
		_go_idle()
		return
	moves_started[&"ink"] += 1
	_begin_tell(Phase.INK_TELL, ink_delay, &"ink")
	var points := pick_ink_points(current_ink_count())
	var dmg := scaled_damage(ink.damage) if ink.damage > 0 else data.contact_damage
	_prune_shots()
	for i in points.size():
		var shot := LobbedShot.lob(self, ink, global_position + Vector2(0, -6), points[i], dmg,
				_tell_time(ink_delay) + 0.1 * float(i), 0.55, projectile_speed_mult(), 46.0)
		if shot != null:
			shot.splash = &"ink"
			shot.puddle_time = ink_puddle_time
			_shots.append(shot)
	CombatFx.sfx(&"ink", &"magic", -4.0)


## 墨汁的落點:第一團在目標腳下,其他在附近(彼此至少相隔 ink_spacing)。
func pick_ink_points(count: int) -> Array[Vector2]:
	var center := target.global_position if target != null else Layout.ARENA_RECT.get_center()
	var r := ink.hit_radius if ink != null else 10.0
	var points: Array[Vector2] = [CombatMath.clamp_to_arena(center, r)]
	var tries := 0
	while points.size() < count and tries < 60:
		tries += 1
		var p := CombatMath.clamp_to_arena(center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(ink_spacing, ink_spread), r)
		var ok := true
		for q in points:
			if q.distance_to(p) < ink_spacing:
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


# --- 扇形泡泡 -------------------------------------------------------------------

## 在距離 distance 的地方,相鄰兩顆泡泡之間「角色中心可以站的空隙」有多寬(像素)。
func bubble_gap_at(distance: float, victim_radius: float = 6.0) -> float:
	return 2.0 * distance * sin(deg_to_rad(bubble_step_deg) * 0.5) - 2.0 * (bubble.hit_radius + victim_radius)


func _start_bubbles() -> void:
	if target == null or bubble == null:
		_go_idle()
		return
	moves_started[&"bubble"] += 1
	_begin_tell(Phase.BUBBLE_TELL, bubble_telegraph, &"attack")
	var to_target := target.global_position - global_position
	var aim := to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	_bubble_dirs.clear()
	_bubble_lengths.clear()
	var n := maxi(1, bubble_count)
	var step := deg_to_rad(bubble_step_deg)
	for i in n:
		var dir := aim.rotated((float(i) - float(n - 1) * 0.5) * step)
		var length := EnemyProjectile.travel_length(global_position, dir, bubble.max_range)
		_bubble_dirs.append(dir)
		_bubble_lengths.append(length)
		_add_mark(AttackTelegraph.make_line(dir, length, bubble.telegraph_width()))


func _release_bubbles() -> void:
	_start_recover(bubble_recover)
	_play(&"attack", true)
	var dmg := scaled_damage(bubble.damage) if bubble.damage > 0 else data.contact_damage
	for i in _bubble_dirs.size():
		EnemyProjectile.launch(self, bubble, global_position, _bubble_dirs[i], _bubble_lengths[i], dmg,
				projectile_speed_mult(), self)
	CombatFx.sfx(&"bubble", &"whoosh", -4.0)


# --- 召喚 -----------------------------------------------------------------------

func _start_summon() -> void:
	moves_started[&"summon"] += 1
	_begin_tell(Phase.SUMMON_TELL, summon_telegraph, &"summon")
	_summon_points.clear()
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		_summon_points.append(CombatMath.clamp_to_arena(global_position + Vector2(side * summon_offset, 30.0), 12.0))
	for point in _summon_points:
		_add_mark(AttackTelegraph.make_circle(9.0, AttackTelegraph.MAGIC), point)


func _summon() -> void:
	_clear_marks()
	summon_at(summon_enemy, _summon_points)
	_start_recover(0.4)


# --- 第二階段 -------------------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	phase = Phase.ROAR
	_phase_left = roar_time
	_ring_left = 0.0
	_hitstop_left = 0.0
	_play(&"summon", true)
	set_glow(CORAL, 0.3)
	_bellow(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)
	BitsScatter.burst(self, global_position + Vector2(0, -20), BitsScatter.Kind.BUBBLE, BUBBLE_COLORS, 12)


func _bellow(trauma_amount: float) -> void:
	CombatFx.sfx(&"kraken_roar", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 52.0, 0.5, Color(SEA, 0.85), 2.0)
	CombatFx.ring(self, global_position, 4.0, 36.0, 0.4, Color(CORAL, 0.8), 1.0)


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(CORAL, 0.08 + 0.08 * pulse + (0.2 if phase == Phase.ROAR else 0.0))
	return false


func _uses_separation() -> bool:
	return phase == Phase.IDLE or phase == Phase.RECOVER


func _is_committed() -> bool:
	return phase in [Phase.TENTACLE, Phase.INK_TELL, Phase.BUBBLE_TELL, Phase.SUMMON_TELL, Phase.ROAR]


## 被吠叫震懾:還沒射出的泡泡預警取消;已經伸出來的觸手與墨汁照樣落下(預警已經畫出來了)。
func _cancel_attack() -> void:
	super()
	_tentacles_left = 0
	if phase == Phase.SUMMON_TELL:
		_summon()
		return
	_clear_marks()
	if phase in [Phase.TENTACLE, Phase.INK_TELL, Phase.BUBBLE_TELL]:
		_go_idle()


func _fizzle_all() -> void:
	_prune_slams()
	for s in _slams:
		s.cancel()
	_slams.clear()
	_prune_shots()
	for s in _shots:
		s.fizzle()
	_shots.clear()


func _on_defeat_started() -> void:
	_clear_marks()
	_fizzle_all()
	_play(&"down", true)


## 真正倒下的一刻:趴在地上嘟嘴(DefeatPose),冒一大串泡泡。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	_fizzle_all()
	DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint, visual_scale, SEA)
	BitsScatter.burst(self, global_position + Vector2(0, -16), BitsScatter.Kind.BUBBLE, BUBBLE_COLORS, 22)
	CombatFx.particles(self, &"bubble_pop", global_position, false, true)
	CombatFx.ring(self, global_position, 6.0, 56.0, 0.6, Color(SEA, 0.9), 2.0)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.4)
	_drop_summons()


func _draw_under() -> void:
	if not defeated:
		# 腳下一圈淡淡的水光;第二階段變成珊瑚紅。
		var pulse := 0.5 + 0.5 * sin(_age * 3.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.36 + pulse * 2.0, Color(SEA if boss_phase < 2 else CORAL, 0.12 + 0.06 * pulse))
		draw_set_transform(Vector2.ZERO)
