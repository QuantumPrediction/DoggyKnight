class_name LanternWispEnemy
extends EnemyBase
## 提燈鬼火(v2.7 AW5,第六章 6-2 起,16×16):提著小燈籠的鬼火,很脆、會逃跑,幫附近的敵人回復。
## 數值在 data/enemies/lantern_wisp.tres,節奏在本場景的屬性欄。
##
## - 逃跑:離金毛 flee_distance 以內就往遠離金毛的方向飄(避開牆角);否則靠近附近的同伴(其他敵人)。
## - 回復:每 heal_interval 秒,燈籠亮起來(heal 動畫、腳下一圈綠光慢慢變大 heal_charge_time 秒),
##   然後放出回復光:heal_radius 以內的敵人回復最大生命的 heal_fraction(至少 heal_min),頭上冒綠色光點。
##   頭目與中頭目不回復(heal_bosses = false),頭目戰不會拖太長。
## - 優先目標:金毛自動攻擊時,攻擊範圍內有鬼火就先打它(is_priority_target)。
## - 倒下:燈籠的火「噗」地熄掉,冒一小團暖色的煙(BitsScatter.MIST),不是受傷。

enum Phase { FLOAT, CHARGE }

const HEAL := Color(0.55, 1.0, 0.6)
const SMOKE_COLORS: Array[Color] = [Color(1.0, 0.9, 0.6, 0.85), Color(0.75, 1.0, 0.75, 0.8)]

@export_group("飄")
@export var float_height: float = 6.0
@export var flee_distance: float = 72.0
@export var flee_speed_mult: float = 1.2
@export var ally_radius: float = 90.0            ## 往這個範圍內的同伴靠過去
@export var ally_stop: float = 26.0              ## 離同伴的中心這麼近就不再靠
@export_group("回復")
@export var heal_interval: float = 4.0
@export var first_heal_min: float = 1.5
@export var first_heal_max: float = 2.5
@export var heal_charge_time: float = 0.6
@export var heal_radius: float = 52.0
@export var heal_fraction: float = 0.25
@export var heal_min: int = 3
@export var heal_bosses: bool = false

var phase: Phase = Phase.FLOAT
var heals: int = 0                               ## 放出回復光的次數
var healed_total: int = 0

var _phase_left: float = 0.0
var _heal_left: float = 2.0
var _wobble: float = 0.0


func is_priority_target() -> bool:
	return state == State.ACTIVE


func _on_ready() -> void:
	_wobble = rng.randf() * TAU
	_sprite_base_offset = Vector2(0, -float_height)


func _on_activated() -> void:
	phase = Phase.FLOAT
	_heal_left = rest(rng.randf_range(first_heal_min, first_heal_max))


func _ai(delta: float) -> void:
	_sprite_base_offset = Vector2(0, -float_height + roundf(sin(_age * 3.0 + _wobble) * 1.5))
	if sprite != null:
		sprite.position = _sprite_base_offset
	match phase:
		Phase.FLOAT:
			_float_around()
			_heal_left -= delta
			if _heal_left <= 0.0:
				_start_charge()
		Phase.CHARGE:
			desired_velocity = Vector2.ZERO
			anim_state = &"heal"
			_phase_left -= delta
			queue_redraw()
			if _phase_left <= 0.0:
				_release_heal()


func _float_around() -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	var dir := Vector2.ZERO
	var speed := data.move_speed
	if player != null and global_position.distance_to(player.global_position) < flee_distance:
		dir = _escape_direction((global_position - player.global_position).normalized())
		speed *= flee_speed_mult
	else:
		var ally := _nearest_ally()
		if ally != null and global_position.distance_to(ally.global_position) > ally_stop:
			dir = (ally.global_position - global_position).normalized()
	if dir.length() > 0.1:
		dir = dir.rotated(sin(_age * 2.0 + _wobble) * 0.35)
		facing = dir
	desired_velocity = dir * speed
	anim_state = &"run" if desired_velocity.length() > 1.0 else &"idle"


func _nearest_ally() -> Node2D:
	var best: Node2D = null
	var best_d := ally_radius
	for node in _enemies_cached():
		var e := node as EnemyBase
		if e == null or e == self or e is LanternWispEnemy or e.state != State.ACTIVE:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _escape_direction(away: Vector2) -> Vector2:
	var best := away
	var best_score := -INF
	for angle: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.6, -1.6]:
		var dir := away.rotated(angle)
		var inside := CombatMath.arena_bounds(arena_margin).has_point(global_position + dir * 16.0)
		var score := dir.dot(away) + (0.0 if inside else -3.0)
		if score > best_score:
			best_score = score
			best = dir
	return best


func _start_charge() -> void:
	phase = Phase.CHARGE
	_phase_left = heal_charge_time
	desired_velocity = Vector2.ZERO
	_play(&"heal", true)


## 這一刻 heal_radius 內可以回復的敵人。
func heal_targets() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var e := node as EnemyBase
		if e == null or e == self or e.state != State.ACTIVE:
			continue
		if e is BossBase and not heal_bosses:
			continue
		if global_position.distance_to(e.global_position) <= heal_radius:
			result.append(e)
	return result


func _release_heal() -> void:
	phase = Phase.FLOAT
	heals += 1
	_heal_left = rest(heal_interval)
	for e in heal_targets():
		var amount := maxi(heal_min, roundi(float(e.max_hp) * heal_fraction))
		var got := e.heal(amount)
		if got > 0:
			healed_total += got
			CombatFx.spawn(self, &"hit_spark", e.number_anchor(), 0.0, Vector2.ONE * 0.7, HEAL)
			CombatFx.ring(self, e.global_position, 2.0, 10.0, 0.3, Color(HEAL, 0.8), 1.0)
	CombatFx.ring(self, global_position, 4.0, heal_radius, 0.45, Color(HEAL, 0.7), 2.0, true)
	CombatFx.particles(self, &"sparkle", global_position + _sprite_base_offset, false)
	CombatFx.sfx(&"heal", &"magic", -8.0)
	queue_redraw()


func _cancel_attack() -> void:
	super()
	if phase == Phase.CHARGE:
		phase = Phase.FLOAT
		_heal_left = rest(heal_interval) * 0.5


func _uses_separation() -> bool:
	return phase == Phase.FLOAT


func _draw() -> void:
	super()
	if phase == Phase.CHARGE and state == State.ACTIVE:
		# 回復光在聚集:腳下一圈綠光慢慢變大(不是危險預警,所以不是紅色)。
		var t := 1.0 - clampf(_phase_left / maxf(heal_charge_time, 0.001), 0.0, 1.0)
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, heal_radius * t, 0.0, TAU, 24, Color(HEAL, 0.5), 1.0)
		draw_circle(Vector2.ZERO, 6.0 + 3.0 * t, Color(HEAL, 0.25))
		draw_set_transform(Vector2.ZERO)


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.MIST, SMOKE_COLORS, 6)
