class_name CrabEliteBoss
extends BossBase
## 中頭目寄居蟹將軍(v2.7 AW1,4-4):螃蟹放大 1.5 倍,背著大貝殼(殼更硬:舉鉗子時傷害 × 0.1)。
## 動作和螃蟹一樣(CrabBrain),數值在 data/enemies/crab_elite_tuning.tres;生命在 data/enemies/crab_elite.tres。
## 共同的頭目行為(boss_appeared、血條、倒下演出、召喚)在 BossBase。
##
## - 出場:從沙裡冒出(無敵)後揮一揮鉗子(鏡頭震動)才開始橫著走。
## - 半血:停下舉起雙鉗(無敵、橘光、鏡頭震動、手機震動)→ 兩個紫色魔法圈 → 叫出 2 隻螃蟹;
##   之後預警 × phase2_telegraph_mult,一輪連續夾兩下(每一下都有完整預警)。叫來的螃蟹都倒下後,
##   每 resummon_every 輪再叫一次。
## - 倒下:翻過來坐在地上生悶氣(DefeatPose 播 hurt 的最後一格),冒一大串泡泡,叫來的螃蟹一起散掉。

enum Mode { INTRO, FIGHT, ROAR, SUMMON_TELL }

const DEFAULT_TUNING: CrabTuning = preload("res://data/enemies/crab_elite_tuning.tres")
const SHELL := Color(1.0, 0.6, 0.35)

@export var tuning: CrabTuning = DEFAULT_TUNING
@export_group("出場")
@export var intro_time: float = 0.8
@export_group("第二階段")
@export var roar_time: float = 0.9
@export var summon_enemy: StringName = &"crab"
@export var summon_count: int = 2
@export var summon_telegraph: float = 1.0
@export var summon_offset: float = 34.0
@export var extra_pinches_phase2: int = 1
@export var resummon_every: int = 3              ## 叫來的螃蟹都倒下後,每幾輪夾擊再叫一次

var brain: CrabBrain
var mode: Mode = Mode.INTRO
var summons_called: int = 0

var _mode_left: float = 0.0
var _ring_left: float = 0.0
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []
var _hit_from: Vector2 = Vector2.INF
var _turns_since_summon: int = 0
var _last_pinches: int = 0


func _on_ready() -> void:
	brain = CrabBrain.new(self, tuning)
	brain.on_ready()


func _on_activated() -> void:
	super()
	mode = Mode.INTRO
	_mode_left = intro_time
	anim_state = &"guard"
	_flex(CombatFx.feel().trauma_boss_roar * 0.5)


func _is_enraging() -> bool:
	return mode == Mode.ROAR


func is_guarding() -> bool:
	return brain != null and brain.guarding and mode == Mode.FIGHT and not defeated


func _ai(delta: float) -> void:
	match mode:
		Mode.INTRO:
			desired_velocity = Vector2.ZERO
			anim_state = &"guard"
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.FIGHT
				brain.on_activated()
		Mode.FIGHT:
			brain.ai(delta)
			if brain.pinches != _last_pinches:
				_last_pinches = brain.pinches
				_turns_since_summon += 1
			if boss_phase >= 2 and brain.phase == CrabBrain.Phase.SCUTTLE and alive_summons() == 0 \
					and _turns_since_summon >= resummon_every:
				_start_summon()
		Mode.ROAR:
			desired_velocity = Vector2.ZERO
			anim_state = &"guard"
			_mode_left -= delta
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_mode_left * 70.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 46.0, 0.4, Color(SHELL, 0.75), 2.0)
			if _mode_left <= 0.0:
				_start_summon()
		Mode.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"guard"
			_mode_left -= delta
			var p := 1.0 - _mode_left / maxf(_tell_time(summon_telegraph), 0.001)
			for mark in _summon_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _mode_left <= 0.0:
				_summon()


# --- 殼與鉗子 ---------------------------------------------------------------------

func hit(amount: int, from_position: Vector2, knockback_speed: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> void:
	_hit_from = from_position
	super(amount, from_position, knockback_speed, style)
	_hit_from = Vector2.INF


func take_damage(amount: int) -> void:
	if is_guarding() and state == State.ACTIVE:
		var from := _hit_from
		if from == Vector2.INF:
			var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
			from = player.global_position if player != null else global_position - facing
		amount = brain.filter_damage(amount, from)
	super(amount)


# --- 第二階段:舉起雙鉗、召喚 ---------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	brain.tell_mult = phase2_telegraph_mult
	brain.extra_pinches = extra_pinches_phase2
	mode = Mode.ROAR
	_mode_left = roar_time
	_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(SHELL, 0.3)
	_flex(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _flex(trauma_amount: float) -> void:
	CombatFx.sfx(&"crab_snip", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 40.0, 0.45, Color(SHELL, 0.85), 2.0)


func _start_summon() -> void:
	mode = Mode.SUMMON_TELL
	_mode_left = _tell_time(summon_telegraph)
	_turns_since_summon = 0
	brain.cancel()
	_clear_summon_marks()
	_summon_points.clear()
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := Vector2(side * summon_offset, 6.0 + floorf(float(i) * 0.5) * 16.0)
		_summon_points.append(CombatMath.clamp_to_arena(global_position + offset, 10.0))
	for point in _summon_points:
		var mark := AttackTelegraph.make_circle(8.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_summon_marks.append(mark)
	Sfx.play(&"boss_warning", -4.0)


func _summon() -> void:
	_clear_summon_marks()
	summons_called += summon_at(summon_enemy, _summon_points)
	mode = Mode.FIGHT
	brain.on_activated()


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(SHELL, 0.08 + 0.08 * pulse + (0.2 if mode == Mode.ROAR else 0.0))
	return false


func _cancel_attack() -> void:
	super()
	if brain != null:
		brain.cancel()
	if mode == Mode.SUMMON_TELL:
		# 召喚不會被打斷(魔法圈已經畫出來了):直接叫出來。
		_summon()


func is_attacking_target(victim: Node2D) -> bool:
	return target == victim and brain != null and brain.phase == CrabBrain.Phase.TELL


func _is_committed() -> bool:
	return mode != Mode.FIGHT or (brain != null and brain.is_committed())


func _uses_separation() -> bool:
	return mode == Mode.FIGHT and (brain == null or brain.uses_separation())


func _draw() -> void:
	super()
	if brain != null and state == State.ACTIVE and not defeated:
		brain.draw(self, _frame_size)


func _on_defeat_started() -> void:
	_clear_summon_marks()
	_play(&"hurt", true)


func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint, visual_scale,
			Color(0.75, 0.9, 1.0), &"hurt")
	BitsScatter.burst(self, global_position + Vector2(0, -8), BitsScatter.Kind.BUBBLE, CrabEnemy.BUBBLE_COLORS, 18)
	CombatFx.particles(self, &"bubble_pop", global_position, false, true)
	CombatFx.ring(self, global_position, 4.0, 40.0, 0.45, Color(SHELL, 0.9), 2.0)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.4)
	_drop_summons()
