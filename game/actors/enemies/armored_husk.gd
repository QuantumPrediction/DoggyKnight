class_name HuskEnemy
extends EnemyBase
## 空盔甲兵(AS2):重裝。數值在 data/enemies/armored_husk.tres(生命 70、傷害 12、速度 22、經驗 4),
## 動作節奏在本場景的屬性欄。和黑騎士一樣是被魔法驅動的空盔甲(藍色魔法)。
##
## - 不會被擊退(knockback_mult = 0);吠叫只震懾一半時間(stun_resist)。
## - 慢慢走近目標;大約每 bash_interval(4)秒用盾衝撞一次:地上畫出紅色預警線 bash_telegraph
##   (0.6)秒,然後沿著線衝約 bash_distance(60)像素,碰到的角色都會被撞到(各一次)。
##   衝撞後喘一口氣(最好的反擊時機);撞到牆會頭昏一下(冒星星)。
## - 衝撞用近戰的進攻名額(AS7);後段關卡會跟同伴一起夾擊。
## - 倒下時:盔甲散開(較小的 ArmorRemains)、一縷藍色火光(MagicWisp)飛走,盔甲幾秒後淡出。

enum Phase { APPROACH, TELEGRAPH, BASH, RECOVER }

const REMAINS_SCRIPT: GDScript = preload("res://game/actors/enemies/armor_remains.gd")
const MAGIC_BLUE := Color(0.45, 0.75, 1.0)

@export_group("衝撞")
@export var bash_interval: float = 4.0           ## 兩次衝撞之間的秒數(× 難度)
@export var first_bash_min: float = 1.2
@export var first_bash_max: float = 2.2
@export var bash_trigger_range: float = 64.0     ## 目標中心在這個距離內才衝撞
@export var bash_telegraph: float = 0.6
@export var bash_distance: float = 60.0
@export var bash_speed: float = 170.0
@export var bash_recover: float = 0.9
@export var wall_bonk_time: float = 1.3
@export var hold_distance: float = 10.0          ## 走到離目標身體這麼近就停下(等衝撞冷卻)
@export_group("重裝")
@export var stun_resist: float = 0.5             ## 吠叫的震懾時間 × (1 − 這個值)

var phase: Phase = Phase.APPROACH
var bashes_started: int = 0

var _phase_left: float = 0.0
var _cooldown_left: float = 0.0
var _bash_dir: Vector2 = Vector2.LEFT
var _bash_length: float = 60.0
var _bash_traveled: float = 0.0
var _bash_into_wall: bool = false
var _bash_hit: Array[Node2D] = []
var _bash_total: float = 0.6


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_activated() -> void:
	phase = Phase.APPROACH
	_cooldown_left = rng.randf_range(first_bash_min, first_bash_max)


func stun(duration: float) -> void:
	super(duration * (1.0 - stun_resist))


func _tick_custom(_delta: float) -> bool:
	queue_redraw()
	return false


func _ai(delta: float) -> void:
	match phase:
		Phase.APPROACH:
			_cooldown_left -= delta
			_approach()
		Phase.TELEGRAPH:
			desired_velocity = Vector2.ZERO
			_phase_left -= delta
			if _telegraph != null:
				_telegraph.progress = 1.0 - _phase_left / maxf(_bash_total, 0.001)
			# 蓄力:往後縮、發抖。
			if sprite != null:
				sprite.position = _sprite_base_offset - _bash_dir * 1.5 + Vector2(sin(_phase_left * 80.0) * 0.5, 0)
			if _phase_left <= 0.0:
				_begin_bash()
		Phase.BASH:
			anim_state = &"dash"
			var speed := scaled_speed(bash_speed)
			desired_velocity = _bash_dir * speed
			_bash_traveled += speed * delta
			for victim in victims():
				if not _bash_hit.has(victim) and global_position.distance_to(victim.global_position) <= body_radius + radius_of(victim) + 1.0:
					_bash_hit.append(victim)
					victim.call(&"take_damage", data.contact_damage)
			if _bash_traveled >= _bash_length:
				_end_bash()
		Phase.RECOVER:
			desired_velocity = Vector2.ZERO
			anim_state = &"idle"
			_phase_left -= delta
			if _phase_left <= 0.0:
				_clear_dizzy()
				phase = Phase.APPROACH


func _approach() -> void:
	if target == null:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > 0.01:
		facing = to_target / dist
	if _cooldown_left <= 0.0 and dist <= bash_trigger_range and claim_attack_slot():
		_start_bash(to_target)
		return
	if dist - radius_of(target) - body_radius <= hold_distance:
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		return
	desired_velocity = facing * data.move_speed
	anim_state = &"run"


func _start_bash(to_target: Vector2) -> void:
	phase = Phase.TELEGRAPH
	bashes_started += 1
	_bash_dir = to_target.normalized() if to_target.length() > 0.01 else facing
	facing = _bash_dir
	var to_edge := CombatMath.distance_to_rect_edge(global_position, _bash_dir, CombatMath.arena_bounds(arena_margin))
	_bash_length = minf(bash_distance, to_edge)
	_bash_into_wall = to_edge <= bash_distance
	_bash_total = tell(bash_telegraph)
	_phase_left = _bash_total
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"
	# 預警線的寬度 = 盔甲的身體(碰到就被撞到)。
	_show_telegraph(AttackTelegraph.make_line(_bash_dir, _bash_length + body_radius, body_radius * 2.0 + 2.0))
	CombatFx.sfx(&"husk_clank", &"", -2.0)
	_call_pincer(target)


func _begin_bash() -> void:
	_clear_telegraph()
	phase = Phase.BASH
	_bash_traveled = 0.0
	_bash_hit.clear()
	if sprite != null:
		sprite.position = _sprite_base_offset
	_play(&"dash", true)
	CombatFx.sfx(&"whoosh", &"swing", -3.0)


func _end_bash() -> void:
	desired_velocity = Vector2.ZERO
	release_attack_slot()
	phase = Phase.RECOVER
	_cooldown_left = rest(bash_interval)
	_phase_left = rest(bash_recover)
	anim_state = &"idle"
	CombatFx.spawn(self, &"dust", global_position + _bash_dir * body_radius, 0.0, Vector2.ONE * 1.3, Color.WHITE, true)
	if _bash_into_wall:
		# 撞到牆:頭昏一下,冒星星(反擊的好機會)。
		_phase_left = rest(wall_bonk_time)
		CombatFx.trauma(self, CombatFx.feel().trauma_boss_bonk * 0.5)
		CombatFx.sfx(&"husk_clank", &"hit", -2.0)
		if _dizzy == null:
			_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55) + _sprite_base_offset)


## 夾擊:同伴開始預警時,冷卻快好、目標在衝撞距離內就一起衝。
func join_attack(victim: Node2D) -> bool:
	if state != State.ACTIVE or phase != Phase.APPROACH or is_stunned() or victim == null or target != victim:
		return false
	if _cooldown_left > 1.0 or global_position.distance_to(victim.global_position) > bash_trigger_range:
		return false
	if not claim_attack_slot():
		return false
	_cooldown_left = 0.0
	_start_bash(victim.global_position - global_position)
	return true


func is_attacking_target(victim: Node2D) -> bool:
	return (phase == Phase.TELEGRAPH or phase == Phase.BASH) and target == victim


func _is_committed() -> bool:
	return phase == Phase.TELEGRAPH or phase == Phase.BASH


func _uses_separation() -> bool:
	return phase == Phase.APPROACH or phase == Phase.RECOVER


func _cancel_attack() -> void:
	super()
	if phase == Phase.TELEGRAPH or phase == Phase.BASH:
		phase = Phase.RECOVER
		_phase_left = rest(bash_recover) * 0.5
		_cooldown_left = maxf(_cooldown_left, rest(bash_interval) * 0.5)
	release_attack_slot()
	if sprite != null and state != State.SPAWNING:
		sprite.position = _sprite_base_offset


func _on_damaged(_amount: int) -> void:
	# 盔甲被打中:藍白色的小火花。
	CombatFx.spawn(self, &"hit_spark", global_position + Vector2(rng.randf_range(-4, 4), -_frame_size.y * 0.2),
			rng.randf() * TAU, Vector2.ONE * 0.7, Color(0.75, 0.9, 1.0))


## 倒下:盔甲散開、藍色火光飛走。
func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	_death_left = minf(_death_left, 0.05)
	var remains := REMAINS_SCRIPT.new() as Node2D
	remains.call(&"configure_small")
	remains.set(&"flip", facing.x < 0.0)
	remains.set(&"sprite_frames", sprite.sprite_frames if sprite != null else null)
	CombatFx.layer_for(self, true).add_child(remains)
	remains.global_position = global_position
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 1.6, Color.WHITE, true)
	CombatFx.ring(self, global_position, 3.0, body_radius + 12.0, 0.3, Color(MAGIC_BLUE, 0.85), 1.5)
	MagicWisp.spawn(self, global_position + Vector2(0, -_frame_size.y * 0.3), MAGIC_BLUE, -1.0 if facing.x > 0.0 else 1.0)
	CombatFx.sfx(&"husk_clank", &"", -1.0)


func _draw() -> void:
	super()
	if state != State.ACTIVE:
		return
	# 腳下淡淡的藍色魔法光(被魔法驅動的空盔甲)。
	var pulse := 0.5 + 0.5 * sin(_age * 4.0)
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, _frame_size.x * 0.34 + pulse, 0.0, TAU, 18, Color(MAGIC_BLUE, 0.25 + 0.2 * pulse), 1.0)
	draw_set_transform(Vector2.ZERO)
