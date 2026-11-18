class_name TristanCompanion
extends CharacterBody2D
## 崔斯坦(v2.7 AW7,柯基吟遊騎士):合約(DEV_PLAN 4.4、4.14):群組 "companion";data/companions/tristan.tres。
##
## - 保持距離:站在金毛「遠離最近敵人」的那一邊(CompanionSpacing.back_spot),和其他同伴、金毛互相推開,不重疊。
## - 每約 note_interval(1.5)秒,附近有敵人時停下彈豎琴(play),朝最近的敵人射出一個音符
##   (AllyProjectile,data/companions/music_note.tres:會稍微追著目標;淡藍色的同伴傷害數字)。頭上偶爾冒「啦啦啦!」。
## - 不會倒下(同鬥牛犬的規則):累積受到一定傷害後暈眩 daze_time 秒(冒星星),然後自己站起來。
## - 過關(level_completed)時回到金毛身邊跳起歡呼、冒愛心。慢動作時動作跟著變慢。

enum Mode { FOLLOW, PLAY, DAZED }

const COMPANION_GROUP: StringName = &"companion"
const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const MUSIC_NOTE: ProjectileData = preload("res://data/companions/music_note.tres")
const NOTE := Color(0.7, 0.9, 1.0)

@export_group("移動")
@export var move_speed: float = 58.0
@export var sprint_mult: float = 1.6
@export var sprint_distance: float = 44.0
@export var back_distance: float = 22.0          ## 站在金毛遠離敵人那一邊多遠
@export var accel: float = 800.0
@export var body_radius: float = 6.0
@export var spacing_gap: float = 4.0
@export var spacing_speed: float = 45.0
@export var leash_radius: float = 110.0
@export_group("音符")
@export var projectile: ProjectileData = MUSIC_NOTE
@export var note_interval: float = 1.5
@export var note_range: float = 120.0            ## 離自己這麼遠以內的敵人才射
@export var engage_radius: float = 130.0         ## 只射金毛附近這個範圍內的敵人
@export var note_damage: int = 5
@export var note_knockback: float = 18.0
@export var note_homing: float = 3.5             ## 追著目標轉的速度(弧度/秒)
@export var play_time: float = 0.3               ## 彈豎琴到音符飛出去的秒數
@export_group("暈眩")
@export var daze_threshold: float = 24.0
@export var daze_time: float = 3.0
@export var hurt_anim_time: float = 0.2
@export_group("個性")
@export var shout_cooldown: float = 5.0
@export var shout_time: float = 0.8
@export var hop_height: float = 2.0
@export var hop_rate: float = 10.0
@export var cheer_hop_height: float = 5.0

var data: CompanionData
var companion_id: StringName = &"tristan"
var mode: Mode = Mode.FOLLOW
var facing: Vector2 = Vector2.RIGHT
var sprite: AnimatedSprite2D
var notes: int = 0
var times_dazed: int = 0
var damage_taken_total: int = 0
var daze_meter: float = 0.0
var celebrating: bool = false

var _note_timer: float = 0.0
var _play_left: float = 0.0
var _play_target: Node2D
var _daze_left: float = 0.0
var _hurt_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(6, 6)
var _age: float = 0.0
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
	_note_timer = note_interval * 0.5
	EventBus.level_completed.connect(_on_level_completed)
	_play(&"idle")


## v2.7 隊形(CompanionSpacing):站在金毛後面(遠離敵人)。
func formation_role() -> StringName:
	return CompanionSpacing.BACK


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
		Mode.PLAY:
			_play_left -= delta
			if _play_left <= 0.0:
				_release_note()
		_:
			desired = _follow(delta, player)
	if mode != Mode.DAZED:
		desired += CompanionSpacing.push(self, body_radius, spacing_gap) * spacing_speed
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


func _daze() -> void:
	mode = Mode.DAZED
	_daze_left = daze_time
	daze_meter = 0.0
	times_dazed += 1
	_play_target = null
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))


func _recover() -> void:
	mode = Mode.FOLLOW
	_note_timer = 0.0
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null


func celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	_play_target = null
	if mode == Mode.PLAY:
		mode = Mode.FOLLOW
	CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6), false, true)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


# --- 跟隨與音符 -------------------------------------------------------------------

func _follow(delta: float, player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var spot := CombatMath.clamp_to_bounds(CompanionSpacing.back_spot(self, player, back_distance), _arena_margin)
	if celebrating:
		spot = CombatMath.clamp_to_bounds(player.global_position + Vector2(0, 14), _arena_margin)
	var to_spot := spot - global_position
	var dist := to_spot.length()
	if not celebrating:
		_note_timer += delta
		if _note_timer >= note_interval and global_position.distance_to(player.global_position) <= leash_radius:
			var enemy := _pick_enemy(player)
			if enemy != null:
				_start_play(enemy)
				return Vector2.ZERO
	if dist <= 2.0:
		var target := _pick_enemy(player)
		var look := (target.global_position if target != null else player.global_position) - global_position
		if absf(look.x) > 1.0:
			facing = Vector2(signf(look.x), 0)
		return Vector2.ZERO
	facing = to_spot / dist
	var speed := move_speed * (sprint_mult if dist > sprint_distance else 1.0)
	return facing * minf(speed, dist * 8.0)


func _pick_enemy(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_enemy(enemy) or player.global_position.distance_to(enemy.global_position) > engage_radius:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= note_range and d < best_distance:
			best = enemy
			best_distance = d
	return best


func _start_play(enemy: Node2D) -> void:
	mode = Mode.PLAY
	_note_timer = 0.0
	_play_left = play_time
	_play_target = enemy
	var to := enemy.global_position - global_position
	if absf(to.x) > 1.0:
		facing = Vector2(signf(to.x), 0)
	_play(&"play", true)


func _release_note() -> void:
	mode = Mode.FOLLOW
	if not _is_valid_enemy(_play_target):
		_play_target = null
		return
	notes += 1
	var from := global_position + Vector2(facing.x * 6.0, -6.0)
	AllyProjectile.shoot(self, projectile, from, _play_target, note_damage, note_knockback, note_homing, self)
	CombatFx.ring(self, from, 1.0, 6.0, 0.2, Color(NOTE, 0.8), 1.0)
	CombatFx.sfx(&"harp", &"magic", -10.0)
	_play_target = null
	if _age >= _shout_ready_at:
		_shout_ready_at = _age + shout_cooldown
		_say(tr(&"COMPANION_TRISTAN_SHOUT"), shout_time)


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
	elif mode == Mode.PLAY:
		_play(&"play")
	elif velocity.length() > 4.0:
		_play(&"run")
	else:
		_play(&"idle")


func _update_bounce(delta: float) -> void:
	var y := 0.0
	if celebrating and velocity.length() <= 4.0 and mode != Mode.DAZED:
		y = -absf(sin(_age * 6.0)) * cheer_hop_height
	elif mode == Mode.FOLLOW and velocity.length() > 4.0:
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
