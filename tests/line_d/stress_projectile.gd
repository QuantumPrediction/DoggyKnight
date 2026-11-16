extends Area2D
## 壓力測試用的替身投射物(DEV_PLAN 16 DS4)。A 線的投射物系統(箭、劍氣、乾草叉)還沒合併時,
## 用它模擬同樣的負擔:先畫 aim_sec 秒的紅色預警線,再直線飛出;碰到主角或同伴、或飛出場地就消失。
## 不造成傷害(只量效能)。圖用 assets/fx/<arrow|sword_wave|pitchfork>/*_frames.tres 的 default 動畫。

signal finished()

var velocity: Vector2 = Vector2.ZERO
var aim_left: float = 0.0
var life: float = 3.0
var hits: int = 0

var _telegraph: Line2D
var _sprite: AnimatedSprite2D


func setup(frames: SpriteFrames, from: Vector2, to: Vector2, speed: float, aim_sec: float, max_range: float) -> void:
	position = from
	var direction := (to - from).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	velocity = direction * speed
	rotation = direction.angle()
	aim_left = aim_sec
	life = aim_sec + max_range / maxf(speed, 1.0)
	collision_layer = Layers.ENEMY_ATTACK
	collision_mask = Layers.PLAYER | Layers.COMPANION
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	if frames != null and frames.has_animation(&"default"):
		_sprite.play(&"default")
	_sprite.visible = false
	add_child(_sprite)
	_telegraph = Line2D.new()
	_telegraph.width = 1.0
	_telegraph.default_color = Color(1, 0.25, 0.2, 0.6)
	_telegraph.points = PackedVector2Array([Vector2.ZERO, Vector2(minf(max_range, 160.0), 0)])
	add_child(_telegraph)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if aim_left > 0.0:
		aim_left -= delta
		_telegraph.default_color.a = 0.35 + 0.4 * (1.0 - aim_left)
		if aim_left <= 0.0:
			_telegraph.visible = false
			_sprite.visible = true
		return
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		_done()


func _on_body_entered(_body: Node) -> void:
	if aim_left > 0.0:
		return
	hits += 1
	_done()


func _done() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()
