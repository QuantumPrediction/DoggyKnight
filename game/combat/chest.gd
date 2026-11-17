class_name TreasureChest
extends Node2D
## 寶箱(AV2,DEV_PLAN 4.12)。精英、中頭目、頭目必掉;一般敵人極少機率掉(luck 提高)。
## 從敵人身上彈出來落地(揚起塵土),腳下發光、頭上有光柱,一閃一閃很顯眼;金毛碰到就打開:
## 播 open 動畫、chest_open 音效、光點與光圈,發 EventBus.chest_collected(tier)(B 線給獎勵)。
## 場上沒有敵人一小段時間後(或過關時),寶箱自己滑向金毛,獎勵不會因為換關而漏掉。
## 圖:assets/sprites/chest/chest_frames.tres(idle、open;C 線原地替換)。數值在 data/enemies/loot_tuning.tres。

const GROUP: StringName = &"chest"
const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"

enum Phase { POP, IDLE, MAGNET, OPEN }

var tier: int = 0                         ## 0 普通、1 精英、2 頭目
var random_drop: bool = false             ## 一般敵人隨機掉的(計入 max_random_chests)
var phase: Phase = Phase.IDLE
var opened: bool = false
var tuning: LootTuning

var _sprite: AnimatedSprite2D
var _pop_left: float = 0.0
var _pop_from: Vector2 = Vector2.ZERO
var _pop_to: Vector2 = Vector2.ZERO
var _speed: float = 0.0
var _no_enemy_time: float = 0.0
var _linger_left: float = 0.0
var _age: float = 0.0
var _sparkle_left: float = 0.0
var _force_magnet: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if tuning == null:
		tuning = Loot.tuning()
	_sprite = get_node_or_null(^"Sprite") as AnimatedSprite2D
	if _sprite != null:
		_sprite.modulate = _tint()
		_sprite.offset = Vector2(0, -8)
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle"):
			_sprite.play(&"idle")
	EventBus.level_completed.connect(_on_level_completed)
	_age = randf() * TAU


## 從 from 彈到附近(仍在戰鬥區內)。
func pop_from(from: Vector2) -> void:
	_pop_from = from
	var dir := Vector2.from_angle(randf() * TAU)
	_pop_to = CombatMath.clamp_to_arena(from + dir * randf_range(4.0, 10.0), 10.0)
	_pop_left = tuning.chest_pop_time if tuning != null else 0.35
	phase = Phase.POP
	global_position = from


func is_open() -> bool:
	return opened


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	queue_redraw()
	match phase:
		Phase.POP:
			_pop_left = maxf(0.0, _pop_left - delta)
			var t := 1.0 - _pop_left / maxf(tuning.chest_pop_time, 0.001)
			global_position = _pop_from.lerp(_pop_to, t)
			if _sprite != null:
				_sprite.position.y = -sin(PI * t) * tuning.chest_pop_height
			if _pop_left <= 0.0:
				phase = Phase.IDLE
				if _sprite != null:
					_sprite.position.y = 0.0
					_sprite.scale = Vector2(1.2, 0.8)
				CombatFx.particles(self, &"footstep_dust", global_position, true)
		Phase.IDLE, Phase.MAGNET:
			_tick_waiting(delta)
		Phase.OPEN:
			_linger_left -= delta
			if _sprite != null and _linger_left < 0.25:
				_sprite.modulate.a = clampf(_linger_left / 0.25, 0.0, 1.0)
			if _linger_left <= 0.0:
				queue_free()


func _tick_waiting(delta: float) -> void:
	if _sprite != null:
		_sprite.scale = _sprite.scale.move_toward(Vector2.ONE, delta * 3.0)
	# 偶爾冒一顆光點。
	_sparkle_left -= delta
	if _sparkle_left <= 0.0:
		_sparkle_left = 1.1 - 0.25 * float(tier)
		CombatFx.particles(self, &"sparkle", global_position + Vector2(randf_range(-6, 6), -14))
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null or (player.has_method(&"is_downed") and bool(player.call(&"is_downed"))):
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist <= tuning.chest_open_distance:
		open()
		return
	if phase == Phase.IDLE:
		if _force_magnet:
			phase = Phase.MAGNET
		elif tuning.chest_auto_collect_delay >= 0.0:
			_no_enemy_time = _no_enemy_time + delta if not get_tree().has_group(ENEMY_GROUP) else 0.0
			if _no_enemy_time >= tuning.chest_auto_collect_delay:
				phase = Phase.MAGNET
	if phase != Phase.MAGNET:
		return
	_speed = minf(tuning.chest_magnet_max_speed, _speed + tuning.chest_magnet_accel * delta)
	var step := _speed * delta
	if step >= dist - tuning.chest_open_distance:
		global_position = player.global_position - to_player / maxf(dist, 0.001) * (tuning.chest_open_distance - 0.5)
		open()
		return
	global_position += to_player / dist * step


## 打開寶箱(只會發一次 chest_collected)。
func open() -> void:
	if opened:
		return
	opened = true
	phase = Phase.OPEN
	remove_from_group(GROUP)
	_linger_left = tuning.chest_open_linger if tuning != null else 0.7
	if _sprite != null:
		_sprite.position = Vector2.ZERO
		_sprite.scale = Vector2(1.15, 0.9)
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"open"):
			_sprite.play(&"open")
	CombatFx.sfx(&"chest_open", &"pickup")
	CombatFx.haptic(&"medium" if tier > 0 else &"light")
	var top := global_position + Vector2(0, -10)
	CombatFx.particles(self, &"sparkle", top, false, true)
	CombatFx.particles(self, &"star_burst", top, false, tier > 0)
	if tier >= 2:
		CombatFx.particles(self, &"confetti", top, false, true)
	var glow := _glow()
	CombatFx.ring(self, global_position + Vector2(0, -6), 3.0, 18.0 + 6.0 * float(tier), 0.4, Color(glow, 0.95), 2.0)
	CombatFx.ring(self, global_position + Vector2(0, -6), 2.0, 12.0, 0.25, Color(1, 1, 1, 0.5), 1.0, false, true)
	EventBus.chest_collected.emit(tier)


func _on_level_completed(_level_id: StringName) -> void:
	_force_magnet = true


func _glow() -> Color:
	var colors := tuning.chest_glow_colors if tuning != null else ([] as Array[Color])
	if colors.is_empty():
		return Color(1.0, 0.9, 0.5, 0.6)
	return colors[clampi(tier, 0, colors.size() - 1)]


func _tint() -> Color:
	var colors := tuning.chest_tints if tuning != null else ([] as Array[Color])
	if colors.is_empty():
		return Color.WHITE
	return colors[clampi(tier, 0, colors.size() - 1)]


func _draw() -> void:
	# 腳下的光與頭上的光柱(打開後光柱散開淡出)。全部用程式畫,不會被 C 線換圖影響。
	var glow := _glow()
	var pulse := 0.75 + 0.25 * sin(_age * 4.0)
	var fade := 1.0
	if phase == Phase.OPEN:
		fade = clampf(_linger_left / maxf(tuning.chest_open_linger, 0.001), 0.0, 1.0)
	var lift := _sprite.position.y if _sprite != null else 0.0
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 13.0 + 2.0 * float(tier), Color(glow, glow.a * 0.5 * pulse * fade))
	draw_circle(Vector2.ZERO, 8.0, Color(glow, glow.a * 0.8 * pulse * fade))
	draw_set_transform(Vector2.ZERO)
	if phase == Phase.POP:
		return
	var beam_w := 6.0 + 2.0 * float(tier)
	var beam_h := 34.0 + 10.0 * float(tier)
	if phase == Phase.OPEN:
		beam_w += 10.0 * (1.0 - fade)
	var beam := Rect2(Vector2(-beam_w * 0.5, -beam_h + lift - 4.0), Vector2(beam_w, beam_h))
	draw_rect(_snap(beam), Color(glow, 0.18 * pulse * fade))
	draw_rect(_snap(beam.grow_individual(-beam_w * 0.3, 0, -beam_w * 0.3, 0)), Color(1, 1, 1, 0.12 * pulse * fade))


static func _snap(rect: Rect2) -> Rect2:
	return Rect2(rect.position.round(), rect.size.round())
