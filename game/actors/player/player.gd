class_name GoldiePlayer
extends CharacterBody2D
## 金毛騎士:A1 移動、A2 停下自動攻擊、A3 活力與受擊、A9 忠誠度與必殺技、A10 能力把戲。
##
## 合約(DEV_PLAN 4.4、4.9):
## - 根節點 CharacterBody2D,在群組 "player";take_damage(amount)、heal(amount)。
## - 數值每次都從 GameState.player_stats 讀(把戲會在關卡中改變它)。
## - 傷害 = attack_damage × (1 + GameState.next_level_bonus);受到的傷害 × damage_taken_mult。
## - 活力存在 GameState.vigor,每次改變發 vigor_changed;進場時也發一次。
## - 活力歸零:趴下睡覺(sleep 動畫 + 暈眩星星),只發一次 player_downed,之後不能操作。
## - 忠誠度:打中敵人累積,發 loyalty_changed;滿了且收到 ultimate_requested → 必殺技,發 ultimate_used。
## - 能力類把戲:進場時依 GameState.active_tricks 重建;關卡中聽 trick_chosen 多疊一層。

const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"
const DEFAULT_TUNING: PlayerTuning = preload("res://data/player/goldie_tuning.tres")
const DEFAULT_ABILITY_TUNING: AbilityTuning = preload("res://data/player/ability_tuning.tres")
const SPIN_VISUAL_TIME := 0.3
const HOP_TIME := 0.18
const POWER_TINT := Color(1.0, 0.85, 0.4)

@export var tuning: PlayerTuning = DEFAULT_TUNING
@export var ability_tuning: AbilityTuning = DEFAULT_ABILITY_TUNING

var abilities: AbilitySet
var loyalty: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var invuln_left: float = 0.0             ## 剩餘無敵秒數(測試可直接設為 0)
var swing_count: int = 0                 ## 揮劍次數(含揮空)
var last_swing_damage: int = 0
var last_swing_hits: int = 0
var ultimate_count: int = 0

var sprite: AnimatedSprite2D
var joystick: TouchJoystick

var _downed: bool = false
var _override_active: bool = false
var _override_vector: Vector2 = Vector2.ZERO
var _attack_cooldown: float = 0.0
var _windup_left: float = -1.0
var _attack_target: Node2D
var _hitstop_left: float = 0.0
var _blink_left: float = 0.0
var _hurt_anim_left: float = 0.0
var _attack_anim_left: float = 0.0
var _footstep_timer: float = 0.0
var _spin_left: float = 0.0
var _hop_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(6, 6)


func _ready() -> void:
	sprite = $Sprite as AnimatedSprite2D
	joystick = get_node_or_null(^"JoystickLayer/Joystick") as TouchJoystick
	add_to_group(PLAYER_GROUP)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.PLAYER
	collision_mask = Layers.ARENA
	_frame_size = _sprite_size()
	_arena_margin = CombatMath.sprite_margin(_frame_size, tuning.body_radius)
	if joystick != null:
		joystick.configure(tuning)
	abilities = AbilitySet.new(self, ability_tuning)
	abilities.rebuild(GameState.active_tricks)
	EventBus.trick_chosen.connect(_on_trick_chosen)
	EventBus.ultimate_requested.connect(_on_ultimate_requested)
	_play(&"idle")
	if GameState.vigor > GameState.player_stats.max_vigor:
		GameState.vigor = GameState.player_stats.max_vigor
	_emit_vigor()
	_emit_loyalty()


func _physics_process(delta: float) -> void:
	if _downed:
		velocity = Vector2.ZERO
		return
	_tick_feedback(delta)
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		if _hitstop_left <= 0.0:
			sprite.speed_scale = 1.0
		return
	var stats := GameState.player_stats
	var input := get_move_input()
	var target_velocity := input * stats.move_speed
	var ramp_time := tuning.accel_time if input != Vector2.ZERO else tuning.decel_time
	var rate := stats.move_speed / maxf(ramp_time, 0.001)
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()
	global_position = CombatMath.clamp_to_bounds(global_position, _arena_margin)
	var moving := input != Vector2.ZERO
	if moving:
		facing = input
	_update_attack(delta, moving)
	abilities.update(delta)
	_update_visuals(delta)


# --- 合約方法 ------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if _downed or amount <= 0 or invuln_left > 0.0:
		return
	var final := CombatMath.damage_taken(amount, GameState.player_stats)
	GameState.vigor = maxi(0, GameState.vigor - final)
	EventBus.player_damaged.emit(final)
	_emit_vigor()
	Sfx.play(&"hurt")
	CombatFx.spawn(self, &"hit_spark", global_position + Vector2(0, -_frame_size.y * 0.4), 0.0,
			Vector2.ONE, Color(1.0, 0.95, 0.55))
	if GameState.vigor <= 0:
		_go_down()
		return
	invuln_left = tuning.invuln_time
	_blink_left = tuning.invuln_time
	_hurt_anim_left = tuning.hurt_anim_time
	_cancel_windup()


func heal(amount: int) -> void:
	if amount <= 0 or _downed:
		return
	GameState.vigor = mini(GameState.player_stats.max_vigor, GameState.vigor + amount)
	_emit_vigor()


func is_downed() -> bool:
	return _downed


# --- 移動輸入 ------------------------------------------------------------------

## 目前的移動方向(長度 0 或 1)。
func get_move_input() -> Vector2:
	if _override_active:
		return _override_vector
	return joystick.get_vector() if joystick != null else Vector2.ZERO


## 測試與自動試玩用:用程式代替搖桿。
func set_move_override(direction: Vector2) -> void:
	_override_active = true
	_override_vector = direction.normalized() if direction.length() > 0.001 else Vector2.ZERO


func clear_move_override() -> void:
	_override_active = false
	_override_vector = Vector2.ZERO


# --- 自動攻擊(A2) --------------------------------------------------------------

func _update_attack(delta: float, moving: bool) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if moving:
		if _windup_left >= 0.0:
			_cancel_windup()
		return
	if _windup_left >= 0.0:
		_windup_left -= delta
		if _is_valid_target(_attack_target):
			_face_toward(_attack_target.global_position)
		if _windup_left <= 0.0:
			_swing()
		return
	if _attack_cooldown <= 0.0 and _has_enemies():
		_start_windup()


func _start_windup() -> void:
	var stats := GameState.player_stats
	_attack_target = _nearest_enemy(stats.attack_range * tuning.target_search_mult)
	if _attack_target != null:
		_face_toward(_attack_target.global_position)
	_windup_left = tuning.attack_windup
	_play(&"attack", true)
	sprite.pause()
	# 蓄力:身體壓扁、往後縮一點。
	sprite.scale = Vector2(1.12, 0.88)
	sprite.position = -facing.normalized()


func _cancel_windup() -> void:
	if _windup_left < 0.0:
		return
	_windup_left = -1.0
	_attack_target = null
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	_play(&"idle")


func _swing() -> void:
	_windup_left = -1.0
	var stats := GameState.player_stats
	if _is_valid_target(_attack_target):
		_face_toward(_attack_target.global_position)
	_attack_target = null
	var half_angle := deg_to_rad(tuning.attack_arc_degrees) * 0.5
	var hits := _enemies_in_sector(stats.attack_range, half_angle)
	var mult := abilities.on_swing_landed() if not hits.is_empty() else 1.0
	var damage := CombatMath.player_damage(stats, GameState.next_level_bonus, mult)
	swing_count += 1
	last_swing_hits = hits.size()
	last_swing_damage = damage if not hits.is_empty() else 0
	_attack_cooldown = maxf(0.0, stats.attack_interval - tuning.attack_windup)

	# 揮劍:身體拉長、往前衝一點,弧光朝目標。
	sprite.scale = Vector2(0.9, 1.1)
	sprite.position = facing.normalized() * 2.0
	sprite.play(&"attack")
	_attack_anim_left = tuning.attack_anim_time
	var power := mult > 1.0
	var slash := CombatFx.spawn(self, &"slash", global_position + facing.normalized() * 10.0, facing.angle(),
			Vector2.ONE * (1.35 if power else 1.0), POWER_TINT if power else Color.WHITE)
	if slash != null:
		slash.flip_v = facing.x < 0.0
	Sfx.play(&"swing")
	if hits.is_empty():
		return
	Sfx.play(&"hit")
	for enemy in hits:
		_strike(enemy, damage, tuning.knockback_speed)
		if enemy.has_method(&"apply_hitstop"):
			enemy.call(&"apply_hitstop", tuning.hitstop_time)
	add_loyalty(tuning.loyalty_per_hit * hits.size())
	_hitstop_left = tuning.hitstop_time
	sprite.speed_scale = 0.0


func _strike(enemy: Node2D, damage: int, knockback: float) -> void:
	var spark_at := enemy.global_position.lerp(global_position, 0.35)
	if enemy.has_method(&"hit"):
		enemy.call(&"hit", damage, global_position, knockback)
	else:
		enemy.call(&"take_damage", damage)
	CombatFx.spawn(self, &"hit_spark", spark_at, randf() * TAU)


# --- 忠誠度與必殺技(A9) --------------------------------------------------------

func add_loyalty(amount: float) -> void:
	if _downed or amount <= 0.0:
		return
	var before := loyalty
	loyalty = minf(tuning.loyalty_max, loyalty + amount)
	if loyalty != before:
		_emit_loyalty()


func can_use_ultimate() -> bool:
	return not _downed and loyalty >= tuning.loyalty_max


## 王者之劍:以金毛為中心的大範圍斬擊。忠誠度未滿時不做任何事,傳回 false。
func use_ultimate() -> bool:
	if not can_use_ultimate():
		return false
	loyalty = 0.0
	ultimate_count += 1
	_windup_left = -1.0
	var damage := CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus,
			tuning.ultimate_damage_mult)
	var targets := _enemies_in_radius(tuning.ultimate_radius)
	invuln_left = maxf(invuln_left, tuning.ultimate_invuln_time)
	Sfx.play(&"ultimate")
	var size := tuning.ultimate_radius * 2.0
	var fx_frames := CombatFx.frames(&"ultimate_slash")
	var fx_scale := 2.5
	if fx_frames != null and fx_frames.get_frame_count(&"default") > 0:
		fx_scale = size / maxf(1.0, fx_frames.get_frame_texture(&"default", 0).get_width())
	CombatFx.spawn(self, &"ultimate_slash", global_position, 0.0, Vector2.ONE * fx_scale)
	CombatFx.ring(self, global_position, 8.0, tuning.ultimate_radius, 0.4, Color(1.0, 0.86, 0.35, 0.95), 3.0)
	CombatFx.ring(self, global_position, 4.0, tuning.ultimate_radius * 0.8, 0.18, Color(1, 1, 1, 0.5), 1.0, false, true)
	CombatFx.shake(self, 3.0, 0.3)
	sprite.scale = Vector2(0.85, 1.2)
	_play(&"attack", true)
	_attack_anim_left = 0.35
	for enemy in targets:
		_strike(enemy, damage, tuning.ultimate_knockback_speed)
		if enemy.has_method(&"apply_hitstop"):
			enemy.call(&"apply_hitstop", tuning.ultimate_hitstop_time)
	_emit_loyalty()
	EventBus.ultimate_used.emit()
	return true


func _on_ultimate_requested() -> void:
	use_ultimate()


# --- 能力把戲的宿主方法(A10,見 trick_ability.gd) ----------------------------------

func ability_targets(radius: float) -> Array[Node2D]:
	return _enemies_in_radius(radius)


func ability_base_damage(multiplier: float) -> int:
	return CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus, multiplier)


func ability_hit(target: Node2D, damage: int, knockback: float) -> void:
	if not _is_valid_target(target):
		return
	_strike(target, damage, knockback)
	add_loyalty(tuning.loyalty_per_hit)


func ability_stun(target: Node2D, duration: float) -> void:
	if _is_valid_target(target) and target.has_method(&"stun"):
		target.call(&"stun", duration)


func ability_visual(kind: StringName, radius: float) -> void:
	match kind:
		&"spin":
			_spin_left = SPIN_VISUAL_TIME
			CombatFx.ring(self, global_position, 6.0, radius, 0.25, Color(1, 1, 1, 0.9), 2.0)
			for i in 4:
				var dir := Vector2.from_angle(TAU * float(i) / 4.0 + PI / 4.0)
				CombatFx.spawn(self, &"slash", global_position + dir * radius * 0.6, dir.angle() + PI / 2.0)
			Sfx.play(&"swing")
		&"bark":
			_hop_left = HOP_TIME
			CombatFx.ring(self, global_position, 4.0, radius, 0.35, Color(1.0, 0.92, 0.45, 0.9), 2.0)
			CombatFx.ring(self, global_position, 2.0, radius * 0.6, 0.25, Color(1.0, 0.92, 0.45, 0.7), 1.0)


func _on_trick_chosen(trick_id: StringName) -> void:
	if abilities.add_trick(trick_id):
		CombatFx.ring(self, global_position, 2.0, 16.0, 0.3, Color(1.0, 0.95, 0.6, 0.9), 1.0)


# --- 找敵人 ---------------------------------------------------------------------

func _has_enemies() -> bool:
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if _is_valid_target(node as Node2D):
			return true
	return false


func _nearest_enemy(max_distance: float) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_target(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position) - _radius_of(enemy)
		if d <= max_distance and d < best_distance:
			best = enemy
			best_distance = d
	return best


func _enemies_in_radius(radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if _is_valid_target(enemy) and global_position.distance_to(enemy.global_position) - _radius_of(enemy) <= radius:
			result.append(enemy)
	return result


func _enemies_in_sector(attack_range: float, half_angle: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var dir := facing.normalized()
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_target(enemy):
			continue
		var r := _radius_of(enemy)
		if CombatMath.in_sector(global_position, dir, enemy.global_position, attack_range + r, half_angle,
				tuning.close_hit_distance + r):
			result.append(enemy)
	return result


func _is_valid_target(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if not enemy.is_in_group(ENEMY_GROUP):
		return false
	return not enemy.has_method(&"is_targetable") or bool(enemy.call(&"is_targetable"))


static func _radius_of(node: Node) -> float:
	var r: Variant = node.get(&"body_radius")
	return float(r) if r != null else 6.0


func _face_toward(point: Vector2) -> void:
	var dir := point - global_position
	if dir.length() > 0.5:
		facing = dir.normalized()


# --- 表現 -----------------------------------------------------------------------

func _tick_feedback(delta: float) -> void:
	if invuln_left > 0.0:
		invuln_left = maxf(0.0, invuln_left - delta)
	if _blink_left > 0.0:
		_blink_left = maxf(0.0, _blink_left - delta)
		sprite.visible = _blink_left <= 0.0 or int(_blink_left / tuning.blink_interval) % 2 == 0
	elif not sprite.visible:
		sprite.visible = true


func _update_visuals(delta: float) -> void:
	_hurt_anim_left = maxf(0.0, _hurt_anim_left - delta)
	_attack_anim_left = maxf(0.0, _attack_anim_left - delta)
	if absf(facing.x) > 0.05:
		sprite.flip_h = facing.x < 0.0
	# 蓄力時維持壓扁的姿勢,其他時候慢慢回復原狀。
	if _windup_left < 0.0:
		sprite.scale = sprite.scale.move_toward(Vector2.ONE, delta * 2.5)
		var hop := Vector2.ZERO
		if _hop_left > 0.0:
			_hop_left = maxf(0.0, _hop_left - delta)
			hop = Vector2(0, -3.0 * sin(PI * _hop_left / HOP_TIME))
			sprite.position = hop
		else:
			sprite.position = sprite.position.move_toward(hop, delta * 30.0)
	if _spin_left > 0.0:
		_spin_left = maxf(0.0, _spin_left - delta)
		sprite.rotation = TAU * (1.0 - _spin_left / SPIN_VISUAL_TIME) * (-1.0 if sprite.flip_h else 1.0)
	elif sprite.rotation != 0.0:
		sprite.rotation = 0.0

	if _hurt_anim_left > 0.0:
		_play(&"hurt")
	elif _windup_left >= 0.0 or _attack_anim_left > 0.0:
		pass
	elif velocity.length() > 4.0:
		_play(&"run")
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = tuning.footstep_interval
			CombatFx.spawn(self, &"dust", global_position + Vector2(0, _frame_size.y * 0.4), 0.0,
					Vector2.ONE * 0.75, Color(1, 1, 1, 0.7), true)
	else:
		_play(&"idle")


func _go_down() -> void:
	_downed = true
	invuln_left = 0.0
	_blink_left = 0.0
	_windup_left = -1.0
	_hitstop_left = 0.0
	velocity = Vector2.ZERO
	sprite.visible = true
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.speed_scale = 1.0
	if joystick != null:
		joystick.enabled = false
	_play(&"sleep")
	_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))
	EventBus.player_downed.emit()


func _play(anim: StringName, restart: bool = false) -> void:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if sprite.animation != anim or restart:
		sprite.play(anim)
		if restart:
			sprite.set_frame_and_progress(0, 0.0)
	elif not sprite.is_playing() and frames.get_animation_loop(anim):
		sprite.play(anim)


func _sprite_size() -> Vector2:
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		return frames.get_frame_texture(&"idle", 0).get_size()
	return Vector2(24, 24)


func _emit_vigor() -> void:
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)


func _emit_loyalty() -> void:
	EventBus.loyalty_changed.emit(loyalty, tuning.loyalty_max)


func _draw() -> void:
	# 腳下的影子,讓位置一眼看得清楚。
	var w := _frame_size.x * 0.32
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
