class_name GargoyleEliteBoss
extends BossBase
## 中頭目石像鬼統領(v2.6 AV5,2-4):石像鬼放大 1.5 倍,生命高(data/enemies/gargoyle_elite.tres),
## 動作數值在 data/enemies/gargoyle_elite_tuning.tres(預警較長、俯衝較寬)。飛行、俯衝、變成石頭
## 和石像鬼一樣(GargoyleFlight)。共同的頭目行為(boss_appeared、血條、倒下演出)在 BossBase。
##
## - 出場:從地面冒出(無敵)後尖叫一聲(鏡頭震動)才開始盤旋。
## - 半血:停下尖叫(無敵、紫光、鏡頭震動、手機震動)→ 兩個紫色魔法圈 → 叫出 2 隻石像鬼;
##   之後預警 × phase2_telegraph_mult、俯衝速度 × phase2_speed_mult,落地後會再俯衝一次(各有完整預警)。
## - 倒下:碎成一大堆石屑,叫來的石像鬼一起碎掉。

enum Mode { INTRO, FLY, ROAR, SUMMON_TELL }

const DEFAULT_TUNING: GargoyleTuning = preload("res://data/enemies/gargoyle_elite_tuning.tres")
const PURPLE := Color(0.72, 0.42, 1.0)

@export var tuning: GargoyleTuning = DEFAULT_TUNING
@export_group("出場")
@export var intro_time: float = 0.8
@export_group("第二階段")
@export var roar_time: float = 1.0               ## 半血時尖叫(無敵)的秒數
@export var summon_enemy: StringName = &"gargoyle"
@export var summon_count: int = 2
@export var summon_telegraph: float = 1.0
@export var summon_offset: float = 36.0
@export var chain_swoops_phase2: int = 1         ## 第二階段落地後再俯衝幾次

var flight: GargoyleFlight
var mode: Mode = Mode.INTRO
var summons_called: int = 0

var _mode_left: float = 0.0
var _ring_left: float = 0.0
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []


func _on_ready() -> void:
	flight = GargoyleFlight.new(self, tuning)
	flight.on_ready()


func _on_activated() -> void:
	super()
	mode = Mode.INTRO
	_mode_left = intro_time
	anim_state = &"attack"
	_screech(CombatFx.feel().trauma_boss_roar * 0.6)


func _is_enraging() -> bool:
	return mode == Mode.ROAR


func _ai(delta: float) -> void:
	match mode:
		Mode.INTRO:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.FLY
				flight.on_activated()
		Mode.FLY:
			flight.ai(delta)
		Mode.ROAR:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_mode_left -= delta
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_mode_left * 80.0) * 1.5, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.28
				CombatFx.ring(self, global_position, 8.0, 50.0, 0.4, Color(PURPLE, 0.75), 2.0)
			if _mode_left <= 0.0:
				_start_summon()
		Mode.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"attack"
			_mode_left -= delta
			var p := 1.0 - _mode_left / maxf(_tell_time(summon_telegraph), 0.001)
			for mark in _summon_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _mode_left <= 0.0:
				_summon()


# --- 石頭 -----------------------------------------------------------------------

func is_stone() -> bool:
	return flight != null and mode == Mode.FLY and flight.is_stone()


func take_damage(amount: int) -> void:
	if is_stone() and state == State.ACTIVE and not defeated and amount > 0:
		_number_style = DamageNumber.Style.NORMAL
		flight.clang()
		return
	super(amount)


func stun(duration: float) -> void:
	if is_stone():
		return
	super(duration)


# --- 第二階段:尖叫、召喚 -----------------------------------------------------------

func _enter_phase_two() -> void:
	_cancel_attack()
	if flight.is_stone():
		flight.phase = GargoyleFlight.Phase.HOVER
	flight.tell_mult = phase2_telegraph_mult
	flight.speed_mult = phase2_speed_mult
	flight.chain_swoops = chain_swoops_phase2
	mode = Mode.ROAR
	_mode_left = roar_time
	_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(PURPLE, 0.35)
	_screech(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _screech(trauma_amount: float) -> void:
	CombatFx.sfx(&"gargoyle_screech", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 46.0, 0.45, Color(PURPLE, 0.8), 2.0)


func _start_summon() -> void:
	mode = Mode.SUMMON_TELL
	_mode_left = _tell_time(summon_telegraph)
	_clear_summon_marks()
	_summon_points.clear()
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := Vector2(side * summon_offset, -8.0 + floorf(float(i) * 0.5) * 16.0)
		_summon_points.append(CombatMath.clamp_to_arena(global_position + offset, 10.0))
	for point in _summon_points:
		var mark := AttackTelegraph.make_circle(9.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_summon_marks.append(mark)
	Sfx.play(&"boss_warning")


func _summon() -> void:
	_clear_summon_marks()
	summons_called += summon_at(summon_enemy, _summon_points)
	mode = Mode.FLY
	flight.phase = GargoyleFlight.Phase.HOVER
	flight._cooldown_left = rest(1.0)


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(PURPLE, 0.1 + 0.1 * pulse + (0.2 if mode == Mode.ROAR else 0.0))
	return false


func _cancel_attack() -> void:
	super()
	if flight != null:
		flight.cancel()
	if mode == Mode.SUMMON_TELL:
		# 召喚不會被打斷(魔法圈已經畫出來了):直接叫出來。
		_summon()


func _is_committed() -> bool:
	return mode != Mode.FLY or (flight != null and flight.is_committed())


func _uses_separation() -> bool:
	return mode == Mode.FLY and (flight == null or flight.uses_separation())


func _on_defeat_started() -> void:
	_clear_summon_marks()


func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	BitsScatter.burst(self, global_position + Vector2(0, -6), BitsScatter.Kind.CHIP, GargoyleFlight.CHIP_COLORS, 22, true)
	CombatFx.particles(self, &"stone_bits", global_position, true, true)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 2.6, GargoyleFlight.STONE_GREY, true)
	CombatFx.ring(self, global_position, 4.0, 44.0, 0.45, Color(PURPLE, 0.9), 2.0)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.5)
	CombatFx.sfx(&"husk_clank", &"hit")
	_drop_summons()


func _draw_under() -> void:
	if boss_phase >= 2 and not defeated:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, _frame_size.x * 0.4 + pulse * 2.0, Color(PURPLE, 0.16 + 0.12 * pulse))
		draw_set_transform(Vector2.ZERO)
