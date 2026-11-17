class_name BulldogCompanion
extends CharacterBody2D
## 貝德維爾的鬥牛犬(A8)。合約(DEV_PLAN 4.4):群組 "companion"。
##
## - 平時跟在金毛身邊;金毛附近有敵人時,走向離自己最近的敵人,貼近後舉盾("guard" 動畫)。
## - 舉盾時:挑釁範圍內的敵人改打牠(敵人看 is_taunting() 與 taunt_radius),受到的傷害減 80%,
##   每隔一段時間用盾撞一下(6 點傷害)。
## - 牠不會倒下:累積受到一定傷害後暈眩 3 秒(冒星星、不挑釁),然後自己站起來。
## - 離金毛太遠時一定先回到金毛身邊。
##
## M3 打磨(AP8,有個性):
## - 舉盾時頭上冒「汪!」對話泡泡(有冷卻,不會一直冒)。
## - 跟著跑時一蹦一跳。
## - 過關(level_completed)時跳起歡呼(有 victory 動畫就用),冒愛心。
## - 盾撞敵人時跳出淡藍色的傷害數字。慢動作時動作跟著變慢。
##
## v2.6(AV8):和蘭斯洛特同時在場時互相推開(CompanionSpacing),不會疊在一起。
##
## v2.3(AS1、AS5):舉盾時擋得住箭、劍氣、乾草叉(投射物碰到盾就呼叫 block_projectile()):
## 「鏘!」一聲、盾發亮、火花與光圈、頭上冒「鏘!」,不受傷也不累積暈眩。

enum Mode { FOLLOW, APPROACH, GUARD, DAZED }

const COMPANION_GROUP: StringName = &"companion"
const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const GUARD_COLOR := Color(0.55, 0.8, 1.0, 0.6)

@export_group("移動")
@export var move_speed: float = 55.0
@export var sprint_mult: float = 1.6             ## 離目標很遠時跑快一點
@export var sprint_distance: float = 48.0
@export var follow_distance: float = 16.0
@export var accel: float = 700.0
@export var body_radius: float = 7.0
@export_group("舉盾")
@export var engage_radius: float = 72.0          ## 只理會金毛附近這個範圍內的敵人
@export var leash_radius: float = 100.0          ## 離金毛超過這個距離就先回去
@export var guard_distance: float = 5.0          ## 與敵人身體之間的距離小於這個就舉盾
@export var guard_min_time: float = 0.6
@export var taunt_radius: float = 44.0
@export var guard_reduction: float = 0.8
@export_group("盾撞")
@export var bump_damage: int = 6
@export var bump_interval: float = 0.9
@export var bump_reach: float = 8.0
@export var bump_knockback: float = 70.0
@export_group("暈眩")
@export var daze_threshold: float = 24.0         ## 累積受到這麼多傷害就暈眩
@export var daze_time: float = 3.0
@export var hurt_anim_time: float = 0.2
@export_group("個性")
@export var woof_cooldown: float = 2.5           ## 「汪!」泡泡的最短間隔
@export var woof_time: float = 0.9
@export var hop_height: float = 2.0              ## 跑步時一蹦一跳的高度
@export var hop_rate: float = 9.0
@export var cheer_hop_height: float = 5.0
@export var cheer_interval: float = 0.55
@export_group("擋投射物(AS1、AS5)")
@export var block_reach: float = 5.0             ## 舉盾時,投射物離身體邊緣這麼近就被擋下
@export var clang_cooldown: float = 0.35         ## 「鏘!」泡泡的最短間隔
@export var block_flash_time: float = 0.25
@export_group("和其他同伴保持距離(v2.6)")
@export var spacing_gap: float = 4.0             ## 和其他同伴的身體之間至少留這麼多像素
@export var spacing_speed: float = 40.0

var data: CompanionData
var companion_id: StringName = &"bulldog"
var mode: Mode = Mode.FOLLOW
var daze_meter: float = 0.0
var damage_taken_total: int = 0
var times_dazed: int = 0
var bumps: int = 0
var facing: Vector2 = Vector2.RIGHT
var sprite: AnimatedSprite2D

var _target_enemy: Node2D
var _mode_time: float = 0.0
var _bump_timer: float = 0.0
var _daze_left: float = 0.0
var _hurt_left: float = 0.0
var _bump_anim_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(7, 7)
var _age: float = 0.0
var woofs: int = 0
var celebrating: bool = false
var _woof_ready_at: float = 0.0
var _cheer_left: float = 0.0
var _cheer_t: float = -1.0
var _bubble: SpeechBubble
var blocks: int = 0                              ## 擋下幾個投射物
var _clang_ready_at: float = 0.0
var _block_flash_left: float = 0.0


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
	EventBus.level_completed.connect(_on_level_completed)
	_play(&"idle")


func _physics_process(delta: float) -> void:
	var ts := CombatFx.time_scale
	delta *= ts
	sprite.speed_scale = ts
	_age += delta
	_mode_time += delta
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_bump_anim_left = maxf(0.0, _bump_anim_left - delta)
	if _block_flash_left > 0.0:
		_block_flash_left = maxf(0.0, _block_flash_left - delta)
		queue_redraw()
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	var desired := Vector2.ZERO
	if mode == Mode.DAZED:
		_daze_left -= delta
		if _daze_left <= 0.0:
			_recover()
	else:
		_think(player)
		desired = _act(delta, player)
		if mode == Mode.FOLLOW or mode == Mode.APPROACH:
			# v2.6:和蘭斯洛特同時在場時互不重疊。
			desired += CompanionSpacing.push(self, body_radius, spacing_gap, false) * spacing_speed
	velocity = velocity.move_toward(desired, accel * delta)
	var real_velocity := velocity
	velocity *= ts
	move_and_slide()
	velocity = real_velocity
	global_position = CombatMath.clamp_to_bounds(global_position, _arena_margin)
	_update_animation()
	_update_bounce(delta)
	if mode == Mode.GUARD:
		queue_redraw()


# --- 合約與狀態 -------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if amount <= 0 or mode == Mode.DAZED:
		return
	var reduced := float(amount) * (1.0 - guard_reduction) if mode == Mode.GUARD else float(amount)
	var final := maxi(1, roundi(reduced))
	damage_taken_total += final
	daze_meter += final
	_hurt_left = hurt_anim_time
	CombatFx.spawn(self, &"hit_spark", global_position + Vector2(0, -_frame_size.y * 0.3), 0.0,
			Vector2.ONE * 0.8, GUARD_COLOR if mode == Mode.GUARD else Color(1.0, 0.95, 0.55))
	if daze_meter >= daze_threshold:
		_daze()


func is_taunting() -> bool:
	return mode == Mode.GUARD


func is_dazed() -> bool:
	return mode == Mode.DAZED


func _daze() -> void:
	_set_mode(Mode.DAZED)
	_daze_left = daze_time
	daze_meter = 0.0
	times_dazed += 1
	_target_enemy = null
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))
	queue_redraw()


func _recover() -> void:
	_set_mode(Mode.FOLLOW)
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	_mode_time = 0.0
	if new_mode == Mode.GUARD:
		_bump_timer = bump_interval * 0.5
		woof()
	queue_redraw()


## 頭上冒「汪!」(有冷卻)。傳回有沒有冒出來。
func woof() -> bool:
	if _age < _woof_ready_at or not is_inside_tree():
		return false
	_woof_ready_at = _age + woof_cooldown
	woofs += 1
	_say(tr(&"COMPANION_BULLDOG_WOOF"), woof_time)
	return true


## 盾擋下投射物(由 EnemyProjectile 呼叫):「鏘!」、火花、光圈、盾發亮。不受傷。
func block_projectile(projectile: Node2D) -> void:
	blocks += 1
	_block_flash_left = block_flash_time
	_bump_anim_left = maxf(_bump_anim_left, 0.12)
	var at := global_position
	if projectile != null and is_instance_valid(projectile):
		at = global_position.lerp(projectile.global_position, 0.6)
		var dir := projectile.global_position - global_position
		if dir.length() > 0.5:
			facing = dir.normalized()
	CombatFx.spawn(self, &"hit_spark", at, randf() * TAU, Vector2.ONE * 1.2, Color(0.85, 0.97, 1.0))
	CombatFx.ring(self, at, 2.0, 12.0, 0.22, Color(0.8, 0.95, 1.0, 0.9), 1.5)
	CombatFx.particles(self, &"sparkle", at, false, false)
	CombatFx.sfx(&"husk_clank", &"hit")
	CombatFx.trauma(self, 0.1)
	if _age >= _clang_ready_at:
		_clang_ready_at = _age + clang_cooldown
		_say(tr(&"COMPANION_BULLDOG_CLANG"), woof_time * 0.8)
	queue_redraw()


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


## 過關歡呼(AP8):不再理會敵人,回到金毛身邊跳起來。
func celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	_target_enemy = null
	if mode != Mode.DAZED:
		_set_mode(Mode.FOLLOW)
	_cheer_left = 0.15
	CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6), false, true)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


# --- 判斷與行動 -------------------------------------------------------------------

func _think(player: Node2D) -> void:
	if not is_instance_valid(_target_enemy):
		_target_enemy = null         # 場地 clear() 把牠移除了(已釋放的物件 != null 也是 false,所以直接檢查)
	if celebrating:
		_target_enemy = null
		_set_mode(Mode.FOLLOW)
		return
	if player != null and global_position.distance_to(player.global_position) > leash_radius:
		_target_enemy = null
		_set_mode(Mode.FOLLOW)
		return
	if mode == Mode.GUARD and _mode_time < guard_min_time and _is_valid_enemy(_target_enemy):
		return
	var enemy := _pick_enemy(player)
	if enemy == null:
		_target_enemy = null
		_set_mode(Mode.FOLLOW)
		return
	_target_enemy = enemy
	var gap := _gap_to(enemy)
	if gap <= guard_distance or (mode == Mode.GUARD and gap <= guard_distance + 8.0):
		_set_mode(Mode.GUARD)
	else:
		_set_mode(Mode.APPROACH)


func _act(delta: float, player: Node2D) -> Vector2:
	if (mode == Mode.APPROACH or mode == Mode.GUARD) and not _is_valid_enemy(_target_enemy):
		_set_mode(Mode.FOLLOW)
	match mode:
		Mode.APPROACH:
			var to_enemy := _target_enemy.global_position - global_position
			facing = to_enemy.normalized()
			return facing * move_speed * (sprint_mult if to_enemy.length() > sprint_distance else 1.0)
		Mode.GUARD:
			facing = (_target_enemy.global_position - global_position).normalized()
			_bump_timer += delta
			if _bump_timer >= bump_interval and _gap_to(_target_enemy) <= bump_reach:
				_bump()
			return Vector2.ZERO
		_:
			if player == null:
				return Vector2.ZERO
			var to_player := player.global_position - global_position
			var dist := to_player.length()
			if dist <= follow_distance + 4.0:
				return Vector2.ZERO
			facing = to_player / dist
			return facing * move_speed * (sprint_mult if dist > sprint_distance else 1.0)


func _bump() -> void:
	_bump_timer = 0.0
	bumps += 1
	_bump_anim_left = 0.2
	_play(&"attack", true)
	if _target_enemy.has_method(&"hit"):
		_target_enemy.call(&"hit", bump_damage, global_position, bump_knockback, DamageNumber.Style.ALLY)
	else:
		_target_enemy.call(&"take_damage", bump_damage)
	CombatFx.spawn(self, &"hit_spark", global_position.lerp(_target_enemy.global_position, 0.5), randf() * TAU,
			Vector2.ONE * 0.8)


func _pick_enemy(player: Node2D) -> Node2D:
	var center := player.global_position if player != null else global_position
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_enemy(enemy) or center.distance_to(enemy.global_position) > engage_radius:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_distance:
			best = enemy
			best_distance = d
	return best


## 參數用 Variant:敵人可能已被釋放(場地 clear() 時);已釋放的物件傳給有物件型別的參數會出錯。
func _is_valid_enemy(enemy: Variant) -> bool:
	if not is_instance_valid(enemy):
		return false
	var node := enemy as Node2D
	if node == null or not node.is_inside_tree() or not node.is_in_group(ENEMY_GROUP):
		return false
	return not node.has_method(&"is_targetable") or bool(node.call(&"is_targetable"))


func _gap_to(enemy: Node2D) -> float:
	var r: Variant = enemy.get(&"body_radius")
	return global_position.distance_to(enemy.global_position) - body_radius - (float(r) if r != null else 6.0)


# --- 表現 -----------------------------------------------------------------------

func _update_animation() -> void:
	if absf(facing.x) > 0.05:
		sprite.flip_h = facing.x < 0.0
	if mode == Mode.DAZED or _hurt_left > 0.0:
		_play(&"hurt")
	elif _bump_anim_left > 0.0:
		pass
	elif mode == Mode.GUARD:
		_play(&"guard")
	elif velocity.length() > 4.0:
		_play(&"run")
	elif celebrating and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"victory"):
		_play(&"victory")
	else:
		_play(&"idle")


## 一蹦一跳:跑步時小跳;過關時原地大跳(沒有 victory 動畫時)。
func _update_bounce(delta: float) -> void:
	var y := 0.0
	var squash := Vector2.ONE
	var has_victory := sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"victory")
	if celebrating and has_victory:
		pass        # victory 動畫(C 線)自己有跳躍,不再另外跳。
	elif celebrating and velocity.length() <= 4.0 and mode != Mode.DAZED:
		_cheer_left -= delta
		if _cheer_left <= 0.0 and _cheer_t < 0.0:
			_cheer_t = 0.0
			_cheer_left = cheer_interval
		if _cheer_t >= 0.0:
			_cheer_t += delta / 0.32
			y = -cheer_hop_height * sin(PI * minf(_cheer_t, 1.0))
			squash = Vector2(0.92, 1.1) if _cheer_t < 0.5 else Vector2.ONE
			if _cheer_t >= 1.0:
				_cheer_t = -1.0
				squash = Vector2(1.12, 0.88)
	elif mode != Mode.GUARD and mode != Mode.DAZED and velocity.length() > 4.0:
		y = -absf(sin(_age * hop_rate)) * hop_height
	sprite.position = Vector2(0, roundf(y))
	sprite.scale = sprite.scale.lerp(squash, clampf(delta * 18.0, 0.0, 1.0))


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
	var w := _frame_size.x * 0.32
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.25))
	if mode == Mode.GUARD:
		# 舉盾時腳下有一圈淡藍色的光,表示「我在擋」。
		var pulse := 0.5 + 0.5 * sin(_age * 8.0)
		draw_arc(Vector2.ZERO, w + 4.0 + pulse * 2.0, 0.0, TAU, 20, Color(GUARD_COLOR, 0.35 + 0.3 * pulse), 1.5)
	draw_set_transform(Vector2.ZERO)
	if _block_flash_left > 0.0:
		# 擋下投射物:盾的那一邊亮起一道白藍色的弧。
		var k := _block_flash_left / maxf(block_flash_time, 0.001)
		var a := facing.angle()
		var r := body_radius + block_reach
		draw_arc(Vector2(0, -2), r, a - 1.1, a + 1.1, 10, Color(0.9, 0.98, 1.0, 0.95 * k), 2.0)
		draw_arc(Vector2(0, -2), r + 3.0 * (1.0 - k), a - 0.8, a + 0.8, 8, Color(0.6, 0.85, 1.0, 0.6 * k), 1.0)
