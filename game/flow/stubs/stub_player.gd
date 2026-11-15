extends CharacterBody2D
## 金毛的替身(只給 B 線的替身場地用)。正式版:game/actors/player/player.tscn(A 線)。
##
## 行為(依 DEV_PLAN 第 8 節的初始數值,讀 GameState.player_stats,所以把戲會即時生效):
## - 場地把觸控方向交給 direction;拖曳時以 move_speed 移動。
## - 停下時,每 attack_interval 秒打一下攻擊範圍內最近的敵人,
##   傷害 = attack_damage × (1 + next_level_bonus)(DEV_PLAN 4.9)。
## - take_damage():傷害 × damage_taken_mult,短暫無敵並閃爍;活力歸零就趴下睡著,發 player_downed。
## 合約:群組 "player",take_damage(amount)、heal(amount)。進場時發一次 vigor_changed。

const INVULNERABLE_TIME: float = 0.8
const FRAMES: String = "res://assets/sprites/goldie/goldie_frames.tres"
const SLASH_FRAMES: String = "res://assets/fx/slash/slash_frames.tres"

var direction: Vector2 = Vector2.ZERO
var downed: bool = false

var _cooldown: float = 0.0
var _invulnerable: float = 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.PLAYER
	collision_mask = Layers.ARENA
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	if ResourceLoader.exists(FRAMES):
		_sprite.sprite_frames = load(FRAMES) as SpriteFrames
		_sprite.play(&"idle")
	add_child(_sprite)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)


func _physics_process(delta: float) -> void:
	if downed:
		velocity = Vector2.ZERO
		return
	var stats := GameState.player_stats
	velocity = direction * stats.move_speed
	move_and_slide()
	_cooldown -= delta
	if _invulnerable > 0.0:
		_invulnerable -= delta
		_sprite.visible = _invulnerable <= 0.0 or int(_invulnerable * 20.0) % 2 == 0
	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0
	if velocity != Vector2.ZERO:
		_play(&"run")
		return
	if _cooldown <= 0.0:
		var target := _nearest_enemy(stats.attack_range)
		if target != null:
			_attack(target, stats)
			return
	if _sprite.animation != &"attack" or not _sprite.is_playing():
		_play(&"idle")


func take_damage(amount: int) -> void:
	if downed or _invulnerable > 0.0:
		return
	var damage := maxi(1, roundi(amount * GameState.player_stats.damage_taken_mult))
	GameState.vigor = maxi(0, GameState.vigor - damage)
	EventBus.player_damaged.emit(damage)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)
	Sfx.play(&"hurt")
	_invulnerable = INVULNERABLE_TIME
	if GameState.vigor <= 0:
		_fall_asleep()


## 測試與沙盒用:不理會無敵時間,直接把活力打到 0。
func force_down() -> void:
	_invulnerable = 0.0
	take_damage(GameState.vigor * 1000 + 1000)


func heal(amount: int) -> void:
	GameState.vigor = mini(GameState.player_stats.max_vigor, GameState.vigor + amount)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)


func _fall_asleep() -> void:
	downed = true
	_sprite.visible = true
	_play(&"sleep")
	EventBus.player_downed.emit()


func _attack(target: Node2D, stats: StatBlock) -> void:
	_cooldown = stats.attack_interval
	_sprite.flip_h = target.global_position.x < global_position.x
	_play(&"attack", true)
	Sfx.play(&"swing")
	_spawn_slash(target.global_position)
	var damage := roundi(stats.attack_damage * (1.0 + GameState.next_level_bonus))
	target.call(&"take_damage", damage)


func _nearest_enemy(attack_range: float) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method(&"take_damage"):
			continue
		var reach := attack_range + float(enemy.get(&"radius") if enemy.get(&"radius") != null else 0.0)
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= reach and distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _spawn_slash(at: Vector2) -> void:
	if not ResourceLoader.exists(SLASH_FRAMES):
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = load(SLASH_FRAMES) as SpriteFrames
	fx.top_level = true
	fx.global_position = (global_position + at) * 0.5
	fx.z_index = 5
	add_child(fx)
	fx.play(&"default")
	var tween := fx.create_tween()
	tween.tween_interval(0.25)
	tween.tween_callback(fx.queue_free)


func _play(anim: StringName, restart: bool = false) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if restart or _sprite.animation != anim:
		_sprite.play(anim)
