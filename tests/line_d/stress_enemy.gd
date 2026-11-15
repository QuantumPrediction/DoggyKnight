extends CharacterBody2D
## 壓力測試用的替身敵人(D9)。A 線的正式敵人還沒有時使用:
## 走向主角(替身),彼此碰撞推開,播放稻草人兵的 run 動畫。

const FRAMES_PATH: String = "res://assets/sprites/scarecrow/scarecrow_frames.tres"

var speed: float = 28.0
var target: Node2D
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.ENEMY
	collision_mask = Layers.ARENA | Layers.ENEMY
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	if ResourceLoader.exists(FRAMES_PATH):
		_sprite.sprite_frames = load(FRAMES_PATH) as SpriteFrames
		_sprite.play(&"run")
		_sprite.frame = randi() % maxi(1, _sprite.sprite_frames.get_frame_count(&"run"))
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var to_target := target.global_position - global_position
	velocity = to_target.normalized() * speed if to_target.length() > 10.0 else Vector2.ZERO
	move_and_slide()
	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0
