extends Node2D
## 同伴(鬥牛犬)的替身。正式版:game/actors/companions/bulldog.tscn(A 線)。
## 群組 "companion";跟在金毛身邊,偶爾咬一下附近的敵人(6 點傷害)。

const FOLLOW_OFFSET: Vector2 = Vector2(-16, 6)
const FOLLOW_SPEED: float = 55.0
const ATTACK_RANGE: float = 22.0
const ATTACK_INTERVAL: float = 1.0
const ATTACK_DAMAGE: int = 6

var companion_id: StringName = &"bulldog"
var arena: Node

var _sprite: AnimatedSprite2D
var _cooldown: float = 0.0


func configure(id: StringName, arena_node: Node) -> void:
	companion_id = id
	arena = arena_node


func _ready() -> void:
	add_to_group(&"companion")
	_sprite = AnimatedSprite2D.new()
	var path := "res://assets/sprites/%s/%s_frames.tres" % [companion_id, companion_id]
	if ResourceLoader.exists(path):
		_sprite.sprite_frames = load(path) as SpriteFrames
		_sprite.play(&"idle")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	var player: Node2D = arena.call(&"get_player") if arena != null else null
	if player == null:
		return
	var target := player.global_position + FOLLOW_OFFSET
	var to_target := target - global_position
	if to_target.length() > 2.0:
		global_position += to_target.limit_length(FOLLOW_SPEED * delta)
		_sprite.flip_h = to_target.x < 0.0
		if _sprite.sprite_frames != null:
			_sprite.play(&"run")
	elif _sprite.sprite_frames != null:
		_sprite.play(&"idle")
	_cooldown -= delta
	if _cooldown <= 0.0:
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var enemy := node as Node2D
			if enemy != null and enemy.global_position.distance_to(global_position) <= ATTACK_RANGE:
				enemy.call(&"take_damage", ATTACK_DAMAGE)
				_cooldown = ATTACK_INTERVAL
				break
