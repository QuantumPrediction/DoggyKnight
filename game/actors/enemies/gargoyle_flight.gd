class_name GargoyleFlight
extends RefCounted
## 石像鬼的飛行、俯衝與變成石頭(v2.6 AV1)。石像鬼(GargoyleEnemy)與中頭目石像鬼統領
## (GargoyleEliteBoss)共用這一套,數值在 GargoyleTuning。
##
## 盤旋(HOVER)→ 紅線預警(TELL,方向鎖定)→ 沿直線俯衝(SWOOP)→ 落地喘氣(RECOVER,最好打)→ 飛回盤旋。
## 約每 stone_interval 秒(盤旋或喘氣時計時)變成石頭(STONE)stone_time 秒:落到地上、播 stone、
## 打不動(受擊「鏘!」)、推不動、不會被吠叫震懾。預警或俯衝途中不會變石頭(看到的預警一定會出手)。

enum Phase { HOVER, TELL, SWOOP, RECOVER, STONE }

const STONE_GREY := Color(0.72, 0.72, 0.78)
const CHIP_COLORS: Array[Color] = [Color("8d8b99"), Color("b4b2bf"), Color("5f5d6b")]

var host: EnemyBase
var tuning: GargoyleTuning
var phase: Phase = Phase.HOVER
var swoops_started: int = 0
var stones: int = 0
var clangs: int = 0
var tell_mult: float = 1.0                      ## 頭目第二階段:預警 × 這個
var speed_mult: float = 1.0                     ## 頭目第二階段:俯衝速度 × 這個
var chain_swoops: int = 0                       ## 落地後立刻再俯衝幾次(頭目第二階段)

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _stone_left: float = 4.0
var _orbit: float = 0.0
var _orbit_sign: float = 1.0
var _dir: Vector2 = Vector2.DOWN
var _length: float = 0.0
var _traveled: float = 0.0
var _hit: Array[Node2D] = []
var _height: float = 0.0
var _tell_total: float = 0.7
var _clang_ready_at: float = 0.0
var _chain_left: int = 0
var _age: float = 0.0


func _init(p_host: EnemyBase, p_tuning: GargoyleTuning) -> void:
	host = p_host
	tuning = p_tuning if p_tuning != null else GargoyleTuning.new()


func on_ready() -> void:
	_orbit = host.rng.randf() * TAU
	_orbit_sign = 1.0 if host.rng.randf() < 0.5 else -1.0
	_height = tuning.fly_height
	_apply_height()


func on_activated() -> void:
	phase = Phase.HOVER
	_cooldown_left = host.rest(host.rng.randf_range(tuning.first_swoop_min, tuning.first_swoop_max))
	_stone_left = _next_stone_interval() * host.rng.randf_range(0.6, 1.0)


func is_stone() -> bool:
	return phase == Phase.STONE


func is_committed() -> bool:
	return phase == Phase.TELL or phase == Phase.STONE


func uses_separation() -> bool:
	return phase == Phase.HOVER or phase == Phase.RECOVER


func height() -> float:
	return _height


## 每一格(EnemyBase._ai)。
func ai(delta: float) -> void:
	_age += delta
	match phase:
		Phase.HOVER:
			_set_height(tuning.fly_height, delta)
			_hover(delta)
			_cooldown_left -= delta
			_stone_left -= delta
			if _stone_left <= 0.0:
				start_stone()
			elif _cooldown_left <= 0.0 and host.target != null:
				start_tell()
		Phase.TELL:
			_set_height(tuning.fly_height + 2.0, delta)
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"attack"
			_phase_left -= delta
			if host._telegraph != null:
				host._telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if host.sprite != null:
				host.sprite.position = host._sprite_base_offset - _dir * 1.5 + Vector2(sin(_phase_left * 70.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_start_swoop()
		Phase.SWOOP:
			_set_height(1.0, delta * 3.0)
			var speed := host.scaled_speed(tuning.swoop_speed) * speed_mult
			host.desired_velocity = _dir * speed
			host.facing = _dir
			host.anim_state = &"swoop"
			_traveled += speed * delta
			_check_hits()
			if _traveled >= _length or host.get_slide_collision_count() > 0:
				_land()
		Phase.RECOVER:
			_set_height(0.0, delta * 2.0)
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"idle"
			_phase_left -= delta
			_stone_left -= delta
			if _phase_left <= 0.0:
				if _chain_left > 0 and host.target != null:
					_chain_left -= 1
					start_tell(true)
				else:
					phase = Phase.HOVER
		Phase.STONE:
			_set_height(0.0, delta * 4.0)
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"stone"
			_phase_left -= delta
			if _phase_left <= 0.0:
				_wake_from_stone()


func _hover(delta: float) -> void:
	var target := host.target
	host.anim_state = &"run"
	if target == null:
		host.desired_velocity = Vector2.ZERO
		host.anim_state = &"idle"
		return
	_orbit += _orbit_sign * tuning.orbit_speed * delta
	var spot := target.global_position + Vector2.from_angle(_orbit) * tuning.hover_distance
	var bounds := CombatMath.arena_bounds(host.arena_margin)
	if not bounds.has_point(spot):
		# 盤旋點跑到場外:換方向繞。
		_orbit_sign = -_orbit_sign
		spot = CombatMath.clamp_to_bounds(spot, host.arena_margin)
	var to_spot := spot - host.global_position
	host.desired_velocity = (to_spot * 3.0).limit_length(host.data.move_speed)
	var to_target := target.global_position - host.global_position
	if to_target.length() > 1.0:
		host.facing = to_target.normalized()


# --- 俯衝 -----------------------------------------------------------------------

## 開始紅線預警(方向在這一刻鎖定)。chained = 落地後接著的第二次俯衝。
func start_tell(chained: bool = false) -> void:
	var target := host.target
	if target == null:
		phase = Phase.HOVER
		return
	if not chained:
		_chain_left = chain_swoops
	var to_target := target.global_position - host.global_position
	_dir = to_target.normalized() if to_target.length() > 0.5 else Vector2.DOWN
	var to_edge := CombatMath.distance_to_rect_edge(host.global_position, _dir, CombatMath.arena_bounds(host.arena_margin))
	_length = minf(minf(to_target.length() + tuning.swoop_overshoot, tuning.swoop_max_distance), to_edge)
	phase = Phase.TELL
	swoops_started += 1
	_tell_total = host.tell(tuning.swoop_telegraph) * tell_mult
	_phase_left = _tell_total
	host.facing = _dir
	host._play(&"attack", true)
	host._show_telegraph(AttackTelegraph.make_line(_dir, _length, tuning.hit_radius * 2.0))
	CombatFx.sfx(&"gargoyle_screech", &"boss_warning", -8.0)


func _start_swoop() -> void:
	host._clear_telegraph()
	phase = Phase.SWOOP
	_traveled = 0.0
	_hit.clear()
	if host.sprite != null:
		host.sprite.position = host._sprite_base_offset
	host._play(&"swoop", true)
	CombatFx.sfx(&"whoosh", &"swing", -4.0)


func _check_hits() -> void:
	for victim in host.victims():
		if _hit.has(victim):
			continue
		if host.global_position.distance_to(victim.global_position) <= tuning.hit_radius + EnemyBase.radius_of(victim):
			_hit.append(victim)
			victim.call(&"take_damage", host.data.contact_damage)


func _land() -> void:
	phase = Phase.RECOVER
	_phase_left = host.rest(tuning.recover_time)
	_cooldown_left = host.rest(host.rng.randf_range(tuning.swoop_cooldown_min, tuning.swoop_cooldown_max))
	host.desired_velocity = Vector2.ZERO
	CombatFx.spawn(host, &"dust", host.global_position, 0.0, Vector2.ONE, Color.WHITE, true)


## 被吠叫震懾等打斷:預警取消(俯衝已經開始的話照樣落地)。
func cancel() -> void:
	if phase == Phase.TELL or phase == Phase.SWOOP:
		phase = Phase.RECOVER
		_phase_left = host.rest(tuning.recover_time)
		_cooldown_left = maxf(_cooldown_left, host.rest(tuning.swoop_cooldown_min))
		_chain_left = 0
	if host.sprite != null:
		host.sprite.position = host._sprite_base_offset


# --- 變成石頭 -------------------------------------------------------------------

func start_stone() -> void:
	phase = Phase.STONE
	stones += 1
	_phase_left = tuning.stone_time
	_chain_left = 0
	host.desired_velocity = Vector2.ZERO
	host._clear_telegraph()
	host._play(&"stone", true)
	var feet := host.global_position + Vector2(0, host._frame_size.y * 0.3)
	CombatFx.spawn(host, &"dust", feet, 0.0, Vector2.ONE * 1.2, STONE_GREY, true)
	CombatFx.particles(host, &"stone_bits", feet, true)
	CombatFx.sfx(&"husk_clank", &"hit", -6.0)


func _wake_from_stone() -> void:
	phase = Phase.HOVER
	_stone_left = _next_stone_interval()
	_cooldown_left = maxf(_cooldown_left, host.rest(0.5))
	BitsScatter.burst(host, host.global_position + Vector2(0, -host._frame_size.y * 0.2), BitsScatter.Kind.CHIP,
			CHIP_COLORS, 5)


func _next_stone_interval() -> float:
	var j := tuning.stone_jitter
	return tuning.stone_interval * host.rng.randf_range(1.0 - j, 1.0 + j)


## 石頭時被打中:「鏘!」、火花,不受傷。
func clang() -> void:
	clangs += 1
	var at := host.global_position + host._sprite_base_offset + Vector2(0, -host._frame_size.y * 0.15)
	CombatFx.spawn(host, &"hit_spark", at, host.rng.randf() * TAU, Vector2.ONE * 0.9, Color(0.85, 0.9, 1.0))
	CombatFx.sfx(&"husk_clank", &"hit", -4.0)
	if _age >= _clang_ready_at and host.is_inside_tree():
		_clang_ready_at = _age + tuning.clang_cooldown
		var bubble := SpeechBubble.new()
		bubble.text = host.tr(&"ENEMY_STONE_CLANG")
		bubble.lifetime = 0.6
		bubble.position = Vector2(0, -host._frame_size.y * 0.55)
		host.add_child(bubble)


# --- 高度 -----------------------------------------------------------------------

func _set_height(target_height: float, delta: float) -> void:
	_height = move_toward(_height, target_height, 30.0 * delta)
	_apply_height()


func _apply_height() -> void:
	host._sprite_base_offset = Vector2(0, -_height)
	if host.sprite != null and phase != Phase.TELL:
		host.sprite.position = host._sprite_base_offset
	if host._dizzy != null and is_instance_valid(host._dizzy):
		host._dizzy.position = Vector2(0, -host._frame_size.y * 0.55) + host._sprite_base_offset
