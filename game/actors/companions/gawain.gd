class_name GawainCompanion
extends CharacterBody2D
## 高文(v2.7 AW7,聖伯納山之騎士):合約(DEV_PLAN 4.4、4.14):群組 "companion";data/companions/gawain.tres。
##
## - 平時跟在金毛身邊(左右其中一邊,和蘭斯洛特一左一右,CompanionSpacing.side_of);和其他同伴、金毛互相推開。
## - 每約 slam_interval(4)秒,金毛附近有敵人時,扛著大鐵鎚跑過去(rush),舉起鐵鎚(slam_windup)再砸在地上:
##   slam_radius 以內的敵人受傷(淡藍色的同伴傷害數字)、被彈開,並短暫震暈 slam_stun 秒(頭上冒星星);
##   地面震波、塵土、鏡頭輕震。頭上偶爾冒「嘿呀!」。之後跑回金毛身邊。
## - 不會倒下(同鬥牛犬的規則):累積受到一定傷害後暈眩 daze_time 秒,然後自己站起來。
## - 過關(level_completed)時回到金毛身邊跳起歡呼、冒愛心。慢動作時動作跟著變慢。

enum Mode { FOLLOW, RUSH, SLAM, RETURN, DAZED }

const COMPANION_GROUP: StringName = &"companion"
const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const HAMMER := Color(1.0, 0.8, 0.5)

@export_group("移動")
@export var move_speed: float = 52.0
@export var sprint_mult: float = 1.6
@export var sprint_distance: float = 44.0
@export var follow_offset: Vector2 = Vector2(19, 2)   ## 站在金毛的哪裡(x 依 CompanionSpacing.side_of 左右對調)
@export var accel: float = 700.0
@export var body_radius: float = 7.0
@export var spacing_gap: float = 4.0
@export var spacing_speed: float = 40.0
@export var leash_radius: float = 110.0
@export_group("大鐵鎚")
@export var slam_interval: float = 4.0
@export var engage_radius: float = 76.0          ## 只砸金毛附近這個範圍內的敵人
@export var slam_reach: float = 90.0             ## 離自己這麼遠以內的敵人才跑過去
@export var rush_speed: float = 140.0
@export var rush_max_time: float = 0.9
@export var slam_windup: float = 0.25
@export var slam_radius: float = 26.0
@export var slam_damage: int = 12
@export var slam_knockback: float = 60.0
@export var slam_stun: float = 0.6
@export var slam_pause: float = 0.35
@export_group("暈眩")
@export var daze_threshold: float = 30.0
@export var daze_time: float = 3.0
@export var hurt_anim_time: float = 0.2
@export_group("個性")
@export var shout_cooldown: float = 5.0
@export var shout_time: float = 0.8
@export var hop_height: float = 1.5
@export var hop_rate: float = 8.0
@export var cheer_hop_height: float = 4.0

var data: CompanionData
var companion_id: StringName = &"gawain"
var mode: Mode = Mode.FOLLOW
var facing: Vector2 = Vector2.RIGHT
var sprite: AnimatedSprite2D
var slams: int = 0
var slam_hits: int = 0
var times_dazed: int = 0
var damage_taken_total: int = 0
var daze_meter: float = 0.0
var celebrating: bool = false

var _slam_timer: float = 0.0
var _mode_left: float = 0.0
var _target_enemy: Node2D
var _slam_at: Vector2 = Vector2.ZERO
var _impacted: bool = false
var _daze_left: float = 0.0
var _hurt_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(7, 7)
var _age: float = 0.0
var _side: float = 1.0
var _shout_ready_at: float = 0.0
var _bubble: SpeechBubble


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
	_slam_timer = slam_interval * 0.5
	EventBus.level_completed.connect(_on_level_completed)
	_play(&"idle")


## v2.7 隊形(CompanionSpacing):站在金毛的左邊或右邊。
func formation_role() -> StringName:
	return CompanionSpacing.SIDE


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
		Mode.RUSH:
			desired = _rush(delta)
		Mode.SLAM:
			_mode_left -= delta
			if _mode_left <= 0.0:
				if not _impacted:
					_impacted = true
					_impact()
					_mode_left = slam_pause
				else:
					_target_enemy = null
					mode = Mode.RETURN
		_:
			desired = _follow(delta, player)
			desired += CompanionSpacing.push(self, body_radius, spacing_gap) * spacing_speed
	if mode == Mode.RUSH:
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


func is_slamming() -> bool:
	return mode == Mode.RUSH or mode == Mode.SLAM


func _daze() -> void:
	mode = Mode.DAZED
	_daze_left = daze_time
	daze_meter = 0.0
	times_dazed += 1
	_target_enemy = null
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))


func _recover() -> void:
	mode = Mode.FOLLOW
	_slam_timer = 0.0
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null


func celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	_target_enemy = null
	if mode == Mode.RUSH:
		mode = Mode.RETURN
	CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6), false, true)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


# --- 跟隨與大鐵鎚 -----------------------------------------------------------------

func _follow(delta: float, player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	_side = CompanionSpacing.side_of(self, player)
	var spot := CombatMath.clamp_to_bounds(player.global_position + Vector2(follow_offset.x * _side, follow_offset.y), _arena_margin)
	var to_spot := spot - global_position
	var dist := to_spot.length()
	if mode == Mode.RETURN and dist <= 6.0:
		mode = Mode.FOLLOW
	if not celebrating:
		_slam_timer += delta
		if _slam_timer >= slam_interval and global_position.distance_to(player.global_position) <= leash_radius:
			var enemy := _pick_enemy(player)
			if enemy != null:
				_start_rush(enemy)
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
		if d <= slam_reach and d < best_distance:
			best = enemy
			best_distance = d
	return best


func _start_rush(enemy: Node2D) -> void:
	mode = Mode.RUSH
	_slam_timer = 0.0
	_mode_left = rush_max_time
	_target_enemy = enemy
	_play(&"run", true)
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 4), true)


## 扛著鐵鎚跑向敵人;夠近(或跑太久)就舉起鐵鎚。
func _rush(delta: float) -> Vector2:
	_mode_left -= delta
	if not _is_valid_enemy(_target_enemy):
		_target_enemy = null
		mode = Mode.RETURN
		return Vector2.ZERO
	var to_enemy := _target_enemy.global_position - global_position
	var reach := slam_radius * 0.5 + EnemyBase.radius_of(_target_enemy)
	if to_enemy.length() <= reach or _mode_left <= 0.0:
		_start_slam()
		return Vector2.ZERO
	facing = to_enemy.normalized()
	return facing * rush_speed


func _start_slam() -> void:
	mode = Mode.SLAM
	slams += 1
	_impacted = false
	_mode_left = slam_windup
	_slam_at = global_position + Vector2(facing.x * 6.0, 2.0)
	_play(&"slam", true)
	if _age >= _shout_ready_at:
		_shout_ready_at = _age + shout_cooldown
		_say(tr(&"COMPANION_GAWAIN_SHOUT"), shout_time)


## 鐵鎚砸下去:範圍內的敵人受傷、被彈開、短暫震暈。
func _impact() -> void:
	var at := _slam_at
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_enemy(enemy):
			continue
		if at.distance_to(enemy.global_position) > slam_radius + EnemyBase.radius_of(enemy):
			continue
		slam_hits += 1
		if enemy.has_method(&"hit"):
			enemy.call(&"hit", slam_damage, at, slam_knockback, DamageNumber.Style.ALLY)
		else:
			enemy.call(&"take_damage", slam_damage)
		if enemy.has_method(&"stun") and _is_valid_enemy(enemy):
			enemy.call(&"stun", slam_stun)
	CombatFx.ring(self, at, 4.0, slam_radius + 4.0, 0.3, Color(HAMMER, 0.9), 2.0, true)
	CombatFx.particles(self, &"shockwave", at, true)
	CombatFx.spawn(self, &"dust", at, 0.0, Vector2.ONE * 1.4, Color.WHITE, true)
	CombatFx.trauma(self, 0.15)
	CombatFx.sfx(&"hammer", &"hit", -4.0)


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
	elif mode == Mode.SLAM:
		_play(&"slam")
	elif velocity.length() > 4.0:
		_play(&"run")
	else:
		_play(&"idle")


func _update_bounce(delta: float) -> void:
	var y := 0.0
	if celebrating and velocity.length() <= 4.0 and mode != Mode.DAZED:
		y = -absf(sin(_age * 5.0)) * cheer_hop_height
	elif (mode == Mode.FOLLOW or mode == Mode.RETURN) and velocity.length() > 4.0:
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
