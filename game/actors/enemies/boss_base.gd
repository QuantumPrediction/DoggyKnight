class_name BossBase
extends EnemyBase
## 頭目與中頭目的共同基底(黑騎士、稻草人隊長)。
##
## - 出場:announce() 發 boss_appeared(id)(v2.3,HUD 的頭目血條顯示名字)與 boss_hp_changed,只發一次;
##   開打時(_on_activated)再發 boss_phase_changed(1) 與 boss_hp_changed。
## - 每次受傷發 boss_hp_changed;生命降到 phase2_threshold:boss_phase = 2、發 boss_phase_changed(2)、
##   呼叫 _enter_phase_two()(子類別:怒吼或吶喊、加快)。
## - 第二階段:預警 × phase2_telegraph_mult(_tell_time)、動作速度 × phase2_speed_mult(_speed_mult);
##   兩者都再乘上難度(EnemyBase.tell、scaled_speed)。
## - 吠叫的震懾時間 × (1 − stun_resist);難度另由 spawn_enemy 套用(頭目的生命用 boss_hp_mult)。
## - 召喚的小怪記在 _summons(summon_at);頭目倒下時一起倒下(驅動牠們的魔法消失了)。
## - 倒下演出(AP5):生命歸零 → 白光、慢動作、heavy 震動;搖晃、閃白、裂縫透出魔法光
##   feel.boss_defeat_time × defeat_time_scale 秒(仍在 enemy 群組、無敵、不能被瞄準,用真實時間計時)
##   → 真正倒下(離開群組、發 enemy_died、子類別 _on_died() 的碎片)。B 線因此在約 1 秒後才過關。
##
## 子類別覆寫:_tick_boss(delta)、_enter_phase_two()、_is_enraging()、_on_defeat_started()、
## _draw_under()(畫在影子之前),以及 EnemyBase 的 _ai、_on_activated(要呼叫 super())、_on_died。

@export_group("頭目")
@export var phase2_threshold: float = 0.5
@export var phase2_telegraph_mult: float = 0.7
@export var phase2_speed_mult: float = 1.3
@export var stun_resist: float = 0.5             ## 被吠叫震懾的時間減半
@export var defeat_time_scale: float = 1.0       ## 倒下演出秒數 = feel.boss_defeat_time × 這個
@export var defeat_slowmo_scale: float = 1.0     ## 慢動作秒數 = feel.boss_slowmo_time × 這個(0 = 不放慢動作)
@export var defeat_impact: float = 1.0           ## 倒下時鏡頭震動與白光的強度倍數
@export var defeat_light: Color = Color(0.8, 0.55, 1.0)   ## 倒下時裂縫透出的魔法光(摩根娜的紫色)

var boss_phase: int = 1
var defeated: bool = false                       ## 生命歸零,正在播倒下演出(或已經倒下)
var appeared: bool = false                       ## 已經發過 boss_appeared

var _summons: Array[Node] = []
var _defeat_left: float = -1.0
var _defeat_total: float = 0.85
var _defeat_puff_left: float = 0.0


## 出場宣告(只發一次):boss_appeared 與 boss_hp_changed。
func announce() -> void:
	if appeared:
		return
	appeared = true
	EventBus.boss_appeared.emit(boss_bar_id())
	emit_hp()


## HUD 頭目血條顯示的名字(boss_appeared 的 id;HUD 用 tr("ENEMY_" + 大寫))。雙龍改成合在一起的名字。
func boss_bar_id() -> StringName:
	return data.id if data != null else StringName(name.to_snake_case())


## 發 boss_hp_changed(頭目血條)。雙龍改成兩條龍的生命加起來。
func emit_hp() -> void:
	EventBus.boss_hp_changed.emit(hp, max_hp)


func begin_spawn(duration: float = -1.0) -> void:
	if state == State.DYING:
		return
	announce()
	super(duration)


func _on_activated() -> void:
	announce()
	EventBus.boss_phase_changed.emit(boss_phase)
	emit_hp()


## 無敵:出場時、怒吼(_is_enraging)時、倒下演出時。這時受到的傷害一律無效。
func is_invulnerable() -> bool:
	return state == State.SPAWNING or defeated or _is_enraging()


func _is_enraging() -> bool:
	return false


func is_targetable() -> bool:
	return super() and not is_invulnerable()


func stun(duration: float) -> void:
	if defeated:
		return
	super(duration * (1.0 - stun_resist))


func apply_hitstop(duration: float) -> void:
	if defeated:
		return
	super(duration)


## 預警秒數:× 難度,第二階段再 × phase2_telegraph_mult。
func _tell_time(base: float) -> float:
	return tell(base) * (phase2_telegraph_mult if boss_phase >= 2 else 1.0)


## 第二階段的動作速度倍數(不含難度;資料裡的 move_speed 已經乘過難度)。
func _speed_mult() -> float:
	return phase2_speed_mult if boss_phase >= 2 else 1.0


# --- 生命與第二階段 -----------------------------------------------------------------

func _on_damaged(_amount: int) -> void:
	emit_hp()
	if boss_phase == 1 and hp > 0 and float(hp) <= float(max_hp) * phase2_threshold:
		boss_phase = 2
		EventBus.boss_phase_changed.emit(2)
		_enter_phase_two()


func _enter_phase_two() -> void:
	pass


func _on_healed(_amount: int) -> void:
	emit_hp()


# --- 召喚 -----------------------------------------------------------------------

## 經場地的 spawn_enemy() 在每個點叫出一隻 enemy_id(也算在 enemy 群組)。傳回叫出幾隻。
func summon_at(enemy_id: StringName, points: Array[Vector2]) -> int:
	var count := 0
	for point in points:
		var spawned: Node = null
		if arena != null and is_instance_valid(arena) and arena.has_method(&"spawn_enemy"):
			spawned = arena.call(&"spawn_enemy", enemy_id, point)
		if spawned != null:
			_summons.append(spawned)
			count += 1
	return count


func alive_summons() -> int:
	var alive := 0
	for s in _summons:
		if is_instance_valid(s) and s.is_in_group(ENEMY_GROUP):
			alive += 1
	return alive


func _drop_summons() -> void:
	for s in _summons:
		if is_instance_valid(s) and s.has_method(&"die"):
			s.call(&"die")
	_summons.clear()


# --- 倒下演出 -------------------------------------------------------------------

func _tick_custom(delta: float) -> bool:
	if defeated:
		_tick_defeat()
		return true
	return _tick_boss(delta)


## 子類別每格的額外處理(第二階段的紅光)。傳回 true 表示這一格不跑一般的 AI 與移動。
func _tick_boss(_delta: float) -> bool:
	return false


## 生命歸零:先播倒下演出,defeat 秒後才真正倒下。
func die() -> void:
	if state == State.DYING:
		return
	var feel := CombatFx.feel()
	if defeated:
		if _defeat_left > 0.0:
			return
		super()
		return
	_defeat_total = feel.boss_defeat_time * defeat_time_scale
	if _defeat_total <= 0.0 or not is_inside_tree():
		defeated = true
		_drop_summons()
		super()
		return
	defeated = true
	_defeat_left = _defeat_total
	_defeat_puff_left = 0.0
	_cancel_attack()
	_clear_telegraph()
	_clear_dizzy()
	_hitstop_left = 0.0
	_stun_left = 0.0
	desired_velocity = Vector2.ZERO
	anim_state = &"hurt"
	_play(&"hurt", true)
	set_glow(Color.WHITE, 0.0)
	# 驅動牠們的魔法消失了:召喚的小怪立刻一起倒下。
	_drop_summons()
	CombatFx.haptic(feel.haptic_boss_defeat)
	CombatFx.trauma(self, feel.trauma_boss_defeat * defeat_impact)
	CombatFx.tint(self, Color(1, 1, 1, feel.boss_flash_alpha * defeat_impact), feel.boss_flash_time, 0.0,
			feel.boss_flash_time, 50)
	if defeat_slowmo_scale > 0.0:
		CombatFx.slow_motion(self, feel.boss_slowmo_scale, feel.boss_slowmo_time * defeat_slowmo_scale)
	CombatFx.sfx(&"crit", &"hit")
	CombatFx.particles(self, &"star_burst", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)
	_on_defeat_started()


func _on_defeat_started() -> void:
	pass


func is_defeat_playing() -> bool:
	return defeated and state != State.DYING


## 倒下演出:用真實時間計時(不受慢動作影響),所以一定在 defeat 秒後離開 enemy 群組。
func _tick_defeat() -> void:
	var real_delta := get_physics_process_delta_time()
	_defeat_left -= real_delta
	var t := defeat_progress()
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if sprite != null:
		# 搖晃越來越厲害,一閃一閃地發白。
		var amp := 0.5 + 1.5 * t
		sprite.position = _sprite_base_offset + Vector2(randf_range(-amp, amp), randf_range(-amp * 0.5, amp * 0.5)).round()
		sprite.speed_scale = CombatFx.time_scale
		var blink := int(t * 14.0) % 2 == 0
		_set_flash(0.75 if blink else 0.15)
	_defeat_puff_left -= real_delta
	if _defeat_puff_left <= 0.0:
		_defeat_puff_left = 0.12
		var at := global_position + Vector2(randf_range(-_frame_size.x * 0.4, _frame_size.x * 0.4),
				randf_range(-_frame_size.y * 0.5, 0.0))
		var puff := CombatFx.spawn(self, &"dust", at, 0.0, Vector2.ONE, Color(defeat_light, 0.9), false, 0.6)
		if puff != null:
			puff.drift = Vector2(0, -18.0)
			puff.fade_out = true
	queue_redraw()
	if _defeat_left <= 0.0:
		_defeat_left = 0.0
		die()


## 倒下演出的進度(0 至 1)。
func defeat_progress() -> float:
	return 1.0 - clampf(_defeat_left / maxf(_defeat_total, 0.001), 0.0, 1.0)


func _draw() -> void:
	if state == State.DYING:
		return
	_draw_under()
	super()
	if defeated:
		# 倒下演出:縫隙透出魔法光,越來越多、越來越長。
		var t := defeat_progress()
		var center := Vector2(0, -_frame_size.y * 0.15) + _sprite_base_offset
		var rays := 3 + int(t * 5.0)
		var reach := _frame_size.y * 0.3
		for i in rays:
			var a := float(i) * 2.399 + _age * 0.6
			var length := (reach + reach * 2.6 * t) * (0.7 + 0.3 * sin(float(i) * 1.7))
			var dir := Vector2.from_angle(a)
			draw_line(center, center + dir * length, Color(defeat_light, 0.55 + 0.35 * t), 2.0)
			draw_line(center, center + dir * length * 0.6, Color(1, 1, 1, 0.7 * t), 1.0)


func _draw_under() -> void:
	pass
