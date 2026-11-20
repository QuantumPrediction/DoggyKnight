class_name SnowmanEliteBoss
extends BossBase
## 中頭目雪人隊長(v2.7 AW3,5-4):雪人放大 1.5 倍,一次丟三顆雪球(落點左右散開,每顆都有影子)。
## 動作和雪人兵一樣(SnowmanBrain),數值在 data/enemies/snowman_elite_tuning.tres;生命在 data/enemies/snowman_elite.tres。
## 共同的頭目行為(boss_appeared、血條、倒下演出、召喚)在 BossBase。
##
## - 召喚:每 summon_every 次拋雪球(場上的雪人兵少於 max_summons_alive 時)堆出 2 個雪人兵(紫色魔法圈預警)。
## - 半血:停下吹口哨(無敵、藍光、鏡頭震動、手機震動),馬上堆出雪人兵;之後預警 × phase2_telegraph_mult,
##   一次丟五顆。
## - 倒下:坐在地上(DefeatPose 播 hurt 的最後一格),頭上的帽子歪掉;雪花飛散,叫來的雪人兵一起散掉。

enum Mode { INTRO, FIGHT, WHISTLE, SUMMON_TELL }

const DEFAULT_TUNING: SnowmanTuning = preload("res://data/enemies/snowman_elite_tuning.tres")
const FROST := Color(0.6, 0.85, 1.0)

@export var tuning: SnowmanTuning = DEFAULT_TUNING
@export_group("出場")
@export var intro_time: float = 0.8
@export_group("召喚")
@export var summon_enemy: StringName = &"snowman"
@export var summon_count: int = 2
@export var summon_telegraph: float = 1.0
@export var summon_offset: float = 34.0
@export var summon_every: int = 4                ## 每幾次拋雪球召喚一次
@export var max_summons_alive: int = 2
@export_group("第二階段")
@export var whistle_time: float = 0.9
@export var extra_balls_phase2: int = 2

var brain: SnowmanBrain
var mode: Mode = Mode.INTRO
var summons_called: int = 0

var _mode_left: float = 0.0
var _ring_left: float = 0.0
var _summon_points: Array[Vector2] = []
var _summon_marks: Array[AttackTelegraph] = []
var _last_throws: int = 0


func _on_ready() -> void:
	brain = SnowmanBrain.new(self, tuning)
	brain.on_ready()


func _on_activated() -> void:
	super()
	mode = Mode.INTRO
	_mode_left = intro_time
	anim_state = &"throw"
	_whistle(CombatFx.feel().trauma_boss_roar * 0.5)


func _is_enraging() -> bool:
	return mode == Mode.WHISTLE


func _ai(delta: float) -> void:
	match mode:
		Mode.INTRO:
			desired_velocity = Vector2.ZERO
			_mode_left -= delta
			if _mode_left <= 0.0:
				mode = Mode.FIGHT
				brain.on_activated()
		Mode.FIGHT:
			brain.ai(delta)
			if brain.throws != _last_throws and brain.phase == SnowmanBrain.Phase.MOVE:
				_last_throws = brain.throws
				if brain.throws % summon_every == 0 and alive_summons() < max_summons_alive:
					_start_summon()
		Mode.WHISTLE:
			desired_velocity = Vector2.ZERO
			anim_state = &"throw"
			_mode_left -= delta
			if sprite != null:
				sprite.position = _sprite_base_offset + Vector2(sin(_mode_left * 70.0) * 1.0, 0).round()
			_ring_left -= delta
			if _ring_left <= 0.0:
				_ring_left = 0.3
				CombatFx.ring(self, global_position, 8.0, 44.0, 0.4, Color(FROST, 0.75), 2.0)
			if _mode_left <= 0.0:
				if sprite != null:
					sprite.position = _sprite_base_offset
				_start_summon()
		Mode.SUMMON_TELL:
			desired_velocity = Vector2.ZERO
			anim_state = &"throw"
			_mode_left -= delta
			var p := 1.0 - _mode_left / maxf(_tell_time(summon_telegraph), 0.001)
			for mark in _summon_marks:
				if is_instance_valid(mark):
					mark.progress = p
			if _mode_left <= 0.0:
				_summon()


func _enter_phase_two() -> void:
	_cancel_attack()
	brain.tell_mult = phase2_telegraph_mult
	brain.extra_balls = extra_balls_phase2
	mode = Mode.WHISTLE
	_mode_left = whistle_time
	_ring_left = 0.0
	_hitstop_left = 0.0
	set_glow(FROST, 0.3)
	_whistle(CombatFx.feel().trauma_boss_roar)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	CombatFx.particles(self, &"shockwave", global_position, true, true)


func _whistle(trauma_amount: float) -> void:
	CombatFx.sfx(&"snowman_whistle", &"boss_roar")
	CombatFx.trauma(self, trauma_amount)
	CombatFx.ring(self, global_position, 6.0, 40.0, 0.45, Color(FROST, 0.85), 2.0)


func _start_summon() -> void:
	mode = Mode.SUMMON_TELL
	_mode_left = _tell_time(summon_telegraph)
	_clear_summon_marks()
	_summon_points.clear()
	for i in summon_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		_summon_points.append(CombatMath.clamp_to_arena(global_position + Vector2(side * summon_offset, 8.0), 10.0))
	for point in _summon_points:
		var mark := AttackTelegraph.make_arrival_circle(8.0, AttackTelegraph.MAGIC)
		add_child(mark)
		mark.global_position = point
		_summon_marks.append(mark)
	Sfx.play(&"boss_warning", -4.0)


func _summon() -> void:
	_clear_summon_marks()
	summons_called += summon_at(summon_enemy, _summon_points)
	mode = Mode.FIGHT
	brain.phase = SnowmanBrain.Phase.MOVE
	_last_throws = brain.throws


func _clear_summon_marks() -> void:
	for mark in _summon_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_summon_marks.clear()


func _tick_boss(_delta: float) -> bool:
	if boss_phase >= 2:
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		set_glow(FROST, 0.08 + 0.08 * pulse + (0.2 if mode == Mode.WHISTLE else 0.0))
	return false


func _cancel_attack() -> void:
	super()
	if brain != null:
		brain.cancel()
	if mode == Mode.SUMMON_TELL:
		_summon()


func _is_committed() -> bool:
	return mode != Mode.FIGHT or (brain != null and brain.is_committed())


func _uses_separation() -> bool:
	return mode == Mode.FIGHT and (brain == null or brain.uses_separation())


func _on_defeat_started() -> void:
	_clear_summon_marks()
	if brain != null:
		brain.fizzle()
	_play(&"hurt", true)


func _on_died() -> void:
	if sprite != null:
		sprite.visible = false
	queue_redraw()
	_death_left = minf(_death_left, 0.05)
	if brain != null:
		brain.fizzle()
	DefeatPose.leave(self, sprite.sprite_frames if sprite != null else null, facing.x < 0.0, tint, visual_scale, FROST, &"hurt")
	BitsScatter.burst(self, global_position + Vector2(0, -10), BitsScatter.Kind.SNOW, SnowmanEnemy.SNOW_COLORS, 22)
	CombatFx.particles(self, &"snow_burst", global_position, false, true)
	CombatFx.ring(self, global_position, 4.0, 40.0, 0.45, Color(FROST, 0.9), 2.0)
	CombatFx.trauma(self, CombatFx.feel().trauma_boss_defeat * 0.4)
	_drop_summons()
