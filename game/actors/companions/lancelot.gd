class_name LancelotCompanion
extends CharacterBody2D
## 蘭斯洛特(v2.6 AV8,柴犬長槍騎士)。合約(DEV_PLAN 4.4、4.13):群組 "companion";
## data/companions/lancelot.tres;LevelData.companions 可以同時有鬥牛犬與蘭斯洛特。
##
## - 平時跟在金毛身邊,站在另一位同伴(鬥牛犬)的另一邊;和其他同伴、金毛互相推開(CompanionSpacing),不會疊在一起。
## - 每約 dash_interval(3)秒,金毛附近有敵人時,向最近的敵人突刺(dash 動畫、很快地直衝過去),
##   刺中就造成傷害並擊退(淡藍色傷害數字),然後跑回金毛身邊。頭上偶爾冒「看槍!」。
## - 不會倒下(同鬥牛犬的規則):累積受到一定傷害後暈眩 daze_time 秒(冒星星),然後自己站起來。
## - 過關(level_completed)時回到金毛身邊跳起歡呼、冒愛心。慢動作時動作跟著變慢。

enum Mode { FOLLOW, DASH, RETURN, DAZED }

const COMPANION_GROUP: StringName = &"companion"
const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const LANCE := Color(0.95, 0.85, 0.55)

@export_group("移動")
@export var move_speed: float = 60.0
@export var sprint_mult: float = 1.6
@export var sprint_distance: float = 44.0
@export var follow_offset: Vector2 = Vector2(17, 6)   ## 站在金毛的哪裡(x 會依另一位同伴的位置左右對調)
@export var accel: float = 800.0
@export var body_radius: float = 6.0
@export var spacing_gap: float = 4.0             ## 和其他同伴、金毛的身體之間至少留這麼多像素
@export var spacing_speed: float = 45.0
@export var leash_radius: float = 110.0          ## 離金毛超過這個距離就先回去
@export_group("突刺")
@export var dash_interval: float = 3.0
@export var engage_radius: float = 80.0          ## 只突刺金毛附近這個範圍內的敵人
@export var dash_reach: float = 96.0             ## 離自己這麼遠以內的敵人才突刺
@export var dash_speed: float = 210.0
@export var dash_damage: int = 9
@export var dash_knockback: float = 90.0
@export var hit_reach: float = 4.0               ## 槍尖碰到敵人身體邊緣多近就算刺中
@export var dash_pause: float = 0.15             ## 刺中後停一下
@export_group("暈眩")
@export var daze_threshold: float = 24.0
@export var daze_time: float = 3.0
@export var hurt_anim_time: float = 0.2
@export_group("個性")
@export var shout_cooldown: float = 4.0
@export var shout_time: float = 0.8
@export var hop_height: float = 2.0
@export var hop_rate: float = 10.0
@export var cheer_hop_height: float = 5.0

var data: CompanionData
var companion_id: StringName = &"lancelot"
var mode: Mode = Mode.FOLLOW
var facing: Vector2 = Vector2.RIGHT
var sprite: AnimatedSprite2D
var dashes: int = 0
var dash_hits: int = 0
var times_dazed: int = 0
var damage_taken_total: int = 0
var daze_meter: float = 0.0
var celebrating: bool = false

var _dash_timer: float = 0.0
var _dash_target: Node2D
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_traveled: float = 0.0
var _pause_left: float = 0.0
var _daze_left: float = 0.0
var _hurt_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(6, 6)
var _age: float = 0.0
var _shout_ready_at: float = 0.0
var _bubble: SpeechBubble
var _side: float = 1.0


func setup(p_data: CompanionData) -> void:
	data = p_data
	if data != null and data.id != &"":
		companion_id = data.id


func _ready() -> void:
	add_to_group(COMPANION_GROUP)
	sprite = $Sprite as AnimatedSprite2D
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.COMPANION
	collision_mask = Layers.ARENA
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		_frame_size = frames.get_frame_texture(&"idle", 0).get_size()
	_arena_margin = CombatMath.sprite_margin(_frame_size, body_radius)
	_dash_timer = dash_interval * 0.5
	EventBus.level_completed.connect(_on_level_completed)
	_play(&"idle")


func _physics_process(delta: float) -> void:
	var ts := CombatFx.time_scale
	delta *= ts
	sprite.speed_scale = ts
	_age += delta
	_hurt_left = maxf(0.0, _hurt_left - delta)
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	var desired := Vector2.ZERO
	match mode:
		Mode.DAZED:
			_daze_left -= delta
			if _daze_left <= 0.0:
				_recover()
		Mode.DASH:
			desired = _dash(delta)
		_:
			desired = _follow(delta, player)
			desired += CompanionSpacing.push(self, body_radius, spacing_gap) * spacing_speed
	if mode == Mode.DASH:
		velocity = desired
	else:
		velocity = velocity.move_toward(desired, accel * delta)
	var real_velocity := velocity
	velocity *= ts
	move_and_slide()
	velocity = real_velocity
	global_position = CombatMath.clamp_to_bounds(global_position, _arena_margin)
	_update_animation()
	_update_bounce(delta)


# --- 合約與狀態 -------------------------------------------------------------------

## 不會倒下:累積受到 daze_threshold 傷害就暈眩一下。
func take_damage(amount: int) -> void:
	if amount <= 0 or mode == Mode.DAZED:
		return
	damage_taken_total += amount
	daze_meter += amount
	_hurt_left = hurt_anim_time
	CombatFx.spawn(self, &"hit_spark", global_position + Vector2(0, -_frame_size.y * 0.3), 0.0,
			Vector2.ONE * 0.8, Color(1.0, 0.95, 0.55))
	if daze_meter >= daze_threshold:
		_daze()


func is_dazed() -> bool:
	return mode == Mode.DAZED


func is_dashing() -> bool:
	return mode == Mode.DASH


func _daze() -> void:
	mode = Mode.DAZED
	_daze_left = daze_time
	daze_meter = 0.0
	times_dazed += 1
	_dash_target = null
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))


func _recover() -> void:
	mode = Mode.FOLLOW
	_dash_timer = 0.0
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null


func celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	_dash_target = null
	if mode == Mode.DASH:
		mode = Mode.RETURN
	CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6), false, true)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


# --- 跟隨與突刺 -------------------------------------------------------------------

## 跟在金毛身邊(另一位同伴的另一邊);突刺準備好就找敵人。
func _follow(delta: float, player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var other := CompanionSpacing.other_side(self, player)
	if other != 0.0:
		_side = -other
	var spot := CombatMath.clamp_to_bounds(player.global_position + Vector2(follow_offset.x * _side, follow_offset.y), _arena_margin)
	var to_spot := spot - global_position
	var dist := to_spot.length()
	if mode == Mode.RETURN and dist <= 6.0:
		mode = Mode.FOLLOW
	if not celebrating:
		_dash_timer += delta
		if _dash_timer >= dash_interval and global_position.distance_to(player.global_position) <= leash_radius:
			var enemy := _pick_enemy(player)
			if enemy != null:
				_start_dash(enemy)
				return velocity
	if dist <= 2.0:
		var to_player := player.global_position - global_position
		if absf(to_player.x) > 1.0:
			facing = Vector2(signf(to_player.x), 0)
		return Vector2.ZERO
	facing = to_spot / dist
	var speed := move_speed * (sprint_mult if dist > sprint_distance or mode == Mode.RETURN else 1.0)
	return facing * minf(speed, dist * 8.0)


func _pick_enemy(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_enemy(enemy) or player.global_position.distance_to(enemy.global_position) > engage_radius:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= dash_reach and d < best_distance:
			best = enemy
			best_distance = d
	return best


func _start_dash(enemy: Node2D) -> void:
	mode = Mode.DASH
	dashes += 1
	_dash_timer = 0.0
	_dash_target = enemy
	_dash_traveled = 0.0
	_pause_left = 0.0
	var to_enemy := enemy.global_position - global_position
	_dash_dir = to_enemy.normalized() if to_enemy.length() > 0.5 else facing
	facing = _dash_dir
	_play(&"dash", true)
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 4), true)
	CombatFx.sfx(&"whoosh", &"swing", -6.0)
	if _age >= _shout_ready_at:
		_shout_ready_at = _age + shout_cooldown
		_say(tr(&"COMPANION_LANCELOT_SHOUT"), shout_time)


## 突刺:朝目標直衝(目標移動時微微轉向);刺中或衝太遠就回到金毛身邊。
func _dash(delta: float) -> Vector2:
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			mode = Mode.RETURN
		return Vector2.ZERO
	if _is_valid_enemy(_dash_target):
		var to_enemy := _dash_target.global_position - global_position
		if to_enemy.length() > 0.5:
			_dash_dir = _dash_dir.slerp(to_enemy.normalized(), clampf(delta * 8.0, 0.0, 1.0)).normalized()
		if to_enemy.length() - body_radius - EnemyBase.radius_of(_dash_target) <= hit_reach:
			_strike(_dash_target)
			return Vector2.ZERO
	_dash_traveled += dash_speed * delta
	if _dash_traveled >= dash_reach + 16.0 or not _is_valid_enemy(_dash_target):
		mode = Mode.RETURN
		_dash_target = null
		return Vector2.ZERO
	facing = _dash_dir
	return _dash_dir * dash_speed


func _strike(enemy: Node2D) -> void:
	dash_hits += 1
	_pause_left = dash_pause
	_dash_target = null
	if enemy.has_method(&"hit"):
		enemy.call(&"hit", dash_damage, global_position, dash_knockback, DamageNumber.Style.ALLY)
	else:
		enemy.call(&"take_damage", dash_damage)
	var at := global_position.lerp(enemy.global_position, 0.6)
	CombatFx.spawn(self, &"hit_spark", at, _dash_dir.angle(), Vector2.ONE * 0.9, LANCE)
	CombatFx.ring(self, at, 2.0, 10.0, 0.18, Color(LANCE, 0.8), 1.0)
	_play(&"attack", true)


func _is_valid_enemy(enemy: Variant) -> bool:
	if not is_instance_valid(enemy):
		return false
	var node := enemy as Node2D
	if node == null or not node.is_inside_tree() or not node.is_in_group(ENEMY_GROUP):
		return false
	return not node.has_method(&"is_targetable") or bool(node.call(&"is_targetable"))


func _say(text: String, lifetime: float) -> void:
	if not is_inside_tree():
		return
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = SpeechBubble.new()
	_bubble.text = text
	_bubble.lifetime = lifetime
	_bubble.position = Vector2(0, -_frame_size.y * 0.5)
	add_child(_bubble)


# --- 表現 -----------------------------------------------------------------------

func _update_animation() -> void:
	if absf(facing.x) > 0.05:
		sprite.flip_h = facing.x < 0.0
	if mode == Mode.DAZED or _hurt_left > 0.0:
		_play(&"hurt")
	elif mode == Mode.DASH:
		if _pause_left <= 0.0:
			_play(&"dash")
	elif velocity.length() > 4.0:
		_play(&"run")
	else:
		_play(&"idle")


func _update_bounce(delta: float) -> void:
	var y := 0.0
	if celebrating and velocity.length() <= 4.0 and mode != Mode.DAZED:
		y = -absf(sin(_age * 6.0)) * cheer_hop_height
	elif mode != Mode.DASH and mode != Mode.DAZED and velocity.length() > 4.0:
		y = -absf(sin(_age * hop_rate)) * hop_height
	sprite.position = Vector2(0, roundf(y))
	sprite.scale = sprite.scale.lerp(Vector2.ONE, clampf(delta * 18.0, 0.0, 1.0))


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


func _draw() -> void:
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, _frame_size.x * 0.3, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
