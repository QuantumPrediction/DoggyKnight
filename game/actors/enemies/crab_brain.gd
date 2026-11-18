class_name CrabBrain
extends RefCounted
## 螃蟹海盜的動作(v2.7 AW1)。螃蟹(CrabEnemy)與中頭目寄居蟹將軍(CrabEliteBoss)共用,數值在 CrabTuning。
##
## 橫著走(SCUTTLE)→ 張開鉗子預警(TELL,扇形、方向鎖定)→ 夾(打中扇形內的角色)→ 喘氣(PANT,反擊時機)→ 再橫著走。
## - 橫著走:走到目標的左邊或右邊,左右走得很快、上下比較慢,像螃蟹一樣橫著碎步。
## - 舉鉗子(guard):橫著走而且離目標 guard_range 以內時,鉗子舉在前面:受到的傷害 × guard_damage_mult
##   (幾乎打不痛,冒「鏘!」),也推不動。張開鉗子預警、喘氣的時候不舉鉗子(打得痛)。
## - 同時出手的螃蟹受場地的近戰名額限制;拿不到名額就舉著鉗子在旁邊橫著走。

enum Phase { SCUTTLE, TELL, PANT }

const SWEAT := Color(0.6, 0.85, 1.0)

var host: EnemyBase
var tuning: CrabTuning
var phase: Phase = Phase.SCUTTLE
var guarding: bool = false
var pinches: int = 0                            ## 開始預警的次數
var pinches_landed: int = 0                     ## 夾到角色的次數
var guarded_hits: int = 0
var tell_mult: float = 1.0                      ## 頭目第二階段:預警 × 這個
var extra_pinches: int = 0                      ## 頭目第二階段:一輪多夾幾下

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _tell_total: float = 0.6
var _dir: Vector2 = Vector2.LEFT
var _side: float = 1.0
var _age: float = 0.0
var _clang_ready_at: float = 0.0
var _chain_left: int = 0


func _init(p_host: EnemyBase, p_tuning: CrabTuning) -> void:
	host = p_host
	tuning = p_tuning if p_tuning != null else CrabTuning.new()


func on_ready() -> void:
	_side = 1.0 if host.rng.randf() < 0.5 else -1.0


func on_activated() -> void:
	phase = Phase.SCUTTLE
	_cooldown_left = host.rest(host.rng.randf_range(tuning.first_pinch_min, tuning.first_pinch_max))


func is_committed() -> bool:
	return phase == Phase.TELL


func uses_separation() -> bool:
	return phase == Phase.SCUTTLE


func is_panting() -> bool:
	return phase == Phase.PANT


## 每一格(EnemyBase._ai)。
func ai(delta: float) -> void:
	_age += delta
	match phase:
		Phase.SCUTTLE:
			_cooldown_left -= delta
			_scuttle()
			if host.target != null and _cooldown_left <= 0.0 \
					and host.global_position.distance_to(host.target.global_position) <= tuning.pinch_start + host.body_radius \
					and host.claim_attack_slot():
				_chain_left = maxi(0, tuning.pinches_per_turn + extra_pinches - 1)
				start_tell()
		Phase.TELL:
			guarding = false
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"attack"
			_phase_left -= delta
			if host._telegraph != null:
				host._telegraph.progress = 1.0 - _phase_left / maxf(_tell_total, 0.001)
			if host.sprite != null:
				host.sprite.position = host._sprite_base_offset + Vector2(sin(_phase_left * 60.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_pinch()
		Phase.PANT:
			guarding = false
			host.desired_velocity = Vector2.ZERO
			host.anim_state = &"idle"
			_phase_left -= delta
			host.queue_redraw()
			if _phase_left <= 0.0:
				if _chain_left > 0 and host.target != null:
					_chain_left -= 1
					start_tell()
				else:
					_back_to_scuttle()


func _scuttle() -> void:
	var target := host.target
	if target == null:
		guarding = false
		host.desired_velocity = Vector2.ZERO
		host.anim_state = &"idle"
		return
	var to_target := target.global_position - host.global_position
	if absf(to_target.x) > 2.0:
		_side = -signf(to_target.x)
		host.facing = Vector2(signf(to_target.x), 0)
	var goal := target.global_position + Vector2(_side * (tuning.side_offset + host.body_radius), 0)
	var to_goal := goal - host.global_position
	var speed := host.data.move_speed
	var v := Vector2(clampf(to_goal.x / 6.0, -1.0, 1.0) * tuning.side_speed_mult,
			clampf(to_goal.y / 6.0, -1.0, 1.0) * tuning.forward_speed_mult + sin(_age * 12.0) * tuning.zigzag * 0.3)
	host.desired_velocity = v * speed
	guarding = to_target.length() <= tuning.guard_range + host.body_radius
	if guarding:
		host.anim_state = &"guard"
	else:
		host.anim_state = &"run" if host.desired_velocity.length() > 1.0 else &"idle"


func start_tell() -> void:
	var target := host.target
	var to_target := target.global_position - host.global_position if target != null else host.facing
	_dir = to_target.normalized() if to_target.length() > 0.5 else host.facing
	host.facing = _dir
	phase = Phase.TELL
	pinches += 1
	guarding = false
	_tell_total = host.tell(tuning.pinch_telegraph) * tell_mult
	_phase_left = _tell_total
	host.desired_velocity = Vector2.ZERO
	host._play(&"attack", true)
	if host.sprite != null:
		host.sprite.pause()
	host._show_telegraph(AttackTelegraph.make_sector(tuning.pinch_reach + host.body_radius, _dir,
			deg_to_rad(tuning.pinch_half_angle_deg)))
	host._call_pincer(target)
	CombatFx.sfx(&"crab_snip", &"swing", -8.0)


func _pinch() -> void:
	host._clear_telegraph()
	if host.sprite != null:
		host.sprite.position = host._sprite_base_offset
		host.sprite.play()
	var reach := tuning.pinch_reach + host.body_radius
	var landed := host.hit_victims_in_sector(host.global_position, _dir, reach, deg_to_rad(tuning.pinch_half_angle_deg),
			host.data.contact_damage)
	if landed > 0:
		pinches_landed += 1
	var at := host.global_position + _dir * reach * 0.7
	CombatFx.spawn(host, &"hit_spark", at, _dir.angle(), Vector2.ONE * 0.9, Color(1.0, 0.85, 0.7))
	CombatFx.ring(host, at, 2.0, 9.0, 0.18, Color(1.0, 0.7, 0.55, 0.9), 1.0)
	CombatFx.sfx(&"crab_snip", &"hit", -4.0)
	phase = Phase.PANT
	_phase_left = host.rest(tuning.pant_time) * (0.5 if _chain_left > 0 else 1.0)


func _back_to_scuttle() -> void:
	phase = Phase.SCUTTLE
	_cooldown_left = host.rest(host.rng.randf_range(tuning.pinch_cooldown_min, tuning.pinch_cooldown_max))
	host.release_attack_slot()
	host.queue_redraw()


## 舉著鉗子時傷害變小(並冒「鏘!」)。傳回實際的傷害。
func filter_damage(amount: int, from_position: Vector2) -> int:
	if not guarding or phase != Phase.SCUTTLE or amount <= 0:
		return amount
	guarded_hits += 1
	if _age >= _clang_ready_at:
		_clang_ready_at = _age + tuning.guard_clang_cooldown
		host.clang_fx(from_position, Color(1.0, 0.8, 0.6))
	return maxi(1, roundi(float(amount) * tuning.guard_damage_mult))


## 被吠叫震懾:收起鉗子,喘一下再回去橫著走。
func cancel() -> void:
	if phase == Phase.TELL:
		host._clear_telegraph()
		phase = Phase.PANT
		_chain_left = 0
		_phase_left = host.rest(tuning.pant_time) * 0.5
	guarding = false
	host.release_attack_slot()
	if host.sprite != null:
		host.sprite.position = host._sprite_base_offset
		if not host.sprite.is_playing():
			host.sprite.play()


## 喘氣時頭上冒的汗滴(畫在 host 的 _draw 裡)。
func draw(canvas: CanvasItem, frame_size: Vector2) -> void:
	if phase != Phase.PANT:
		return
	for i in 2:
		var t := fmod(_age * 1.6 + float(i) * 0.5, 1.0)
		var at := Vector2((-1.0 if i == 0 else 1.0) * frame_size.x * 0.3, -frame_size.y * 0.45 + t * 6.0)
		canvas.draw_circle(at.round(), 1.2, Color(SWEAT, 1.0 - t))
