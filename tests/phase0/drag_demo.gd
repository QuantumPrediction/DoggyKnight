extends Node2D
## Phase 0 最小可執行場景:只為證明專案能跑。A 線之後會寫正式的主角、搖桿與場地。
##
## 操作:按住任意位置拖曳 → 金毛移動;放手 → 停下。
## 桌面測試:滑鼠等同觸控;Esc = Android 返回鍵(暫停/繼續);N = 模擬瀏海;
## 視窗失去焦點 = 切到背景(自動暫停)。暫停時點一下畫面繼續。

const ARENA_RECT := Rect2(2, 72, 176, 224)    # 11×14 格,上方留給 HUD
const TILE := 16
const JOYSTICK_RADIUS := 20.0
const JOYSTICK_DEADZONE := 3.0

const GRASS_A := Color("6fae4f")
const GRASS_B := Color("64a246")
const FOREST := Color("2f5d3a")
const SAFE_LINE := Color(1, 1, 1, 0.35)
const GAME_LINE := Color(1, 0.85, 0.3, 0.5)

var _player: CharacterBody2D
var _sprite: AnimatedSprite2D
var _overlay: Node2D
var _touch_index: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_current: Vector2 = Vector2.ZERO
var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_overlay()
	EventBus.app_backgrounded.connect(_set_paused.bind(true))
	EventBus.back_requested.connect(func() -> void: _set_paused(not _paused))
	get_viewport().size_changed.connect(_overlay.queue_redraw)


func _physics_process(_delta: float) -> void:
	if _paused:
		return
	var drag := _touch_current - _touch_origin
	if _touch_index >= 0 and drag.length() > JOYSTICK_DEADZONE:
		_player.velocity = drag.normalized() * GameState.player_stats.move_speed
	else:
		_player.velocity = Vector2.ZERO
	_player.move_and_slide()
	if _player.velocity.x != 0.0:
		_sprite.flip_h = _player.velocity.x < 0.0
	_sprite.play(&"run" if _player.velocity != Vector2.ZERO else &"idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _paused:
			if touch.pressed:
				_set_paused(false)
			return
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index      # 只認第一根手指
			_touch_origin = touch.position
			_touch_current = touch.position
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
		_overlay.queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_touch_current = drag.position
			_overlay.queue_redraw()
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_N:
		SafeArea.simulate_notch = not SafeArea.simulate_notch
		_overlay.queue_redraw()


func _set_paused(value: bool) -> void:
	_paused = value
	_touch_index = -1
	_player.velocity = Vector2.ZERO
	if value:
		_sprite.pause()
	else:
		_sprite.play()
	_overlay.queue_redraw()


func _build_world() -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	ground.draw.connect(_draw_ground.bind(ground))
	add_child(ground)

	var walls := StaticBody2D.new()
	walls.name = "ArenaWalls"
	walls.collision_layer = Layers.ARENA
	walls.collision_mask = 0
	var r := ARENA_RECT
	for segment: PackedVector2Array in [
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)]),
		PackedVector2Array([Vector2(r.end.x, r.position.y), r.end]),
		PackedVector2Array([r.end, Vector2(r.position.x, r.end.y)]),
		PackedVector2Array([Vector2(r.position.x, r.end.y), r.position]),
	]:
		var shape := SegmentShape2D.new()
		shape.a = segment[0]
		shape.b = segment[1]
		var collider := CollisionShape2D.new()
		collider.shape = shape
		walls.add_child(collider)
	add_child(walls)

	_player = CharacterBody2D.new()
	_player.name = "PlaceholderGoldie"
	_player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player.collision_layer = Layers.PLAYER
	_player.collision_mask = Layers.ARENA
	_player.position = ARENA_RECT.get_center()
	_player.add_to_group(&"player")
	var body := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	body.shape = circle
	_player.add_child(body)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	_sprite.play(&"idle")
	_player.add_child(_sprite)
	add_child(_player)

	var camera := Camera2D.new()
	camera.position = SafeArea.GAME_CENTER   # 遊戲區置中,延伸部分顯示場地背景
	add_child(camera)
	camera.make_current()


func _draw_ground(ground: Node2D) -> void:
	ground.draw_rect(Rect2(-200, -200, 580, 720), FOREST)
	var cols := int(ARENA_RECT.size.x) / TILE
	var rows := int(ARENA_RECT.size.y) / TILE
	for y in rows:
		for x in cols:
			var color := GRASS_A if (x + y) % 2 == 0 else GRASS_B
			ground.draw_rect(Rect2(ARENA_RECT.position + Vector2(x * TILE, y * TILE), Vector2(TILE, TILE)), color)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	add_child(layer)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)


func _draw_overlay() -> void:
	_overlay.draw_rect(SafeArea.get_game_rect(), GAME_LINE, false, 1.0)
	_overlay.draw_rect(SafeArea.get_safe_rect().grow(-0.5), SAFE_LINE, false, 1.0)
	if _touch_index >= 0:
		_overlay.draw_arc(_touch_origin, JOYSTICK_RADIUS, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
		var knob := _touch_origin + (_touch_current - _touch_origin).limit_length(JOYSTICK_RADIUS)
		_overlay.draw_circle(knob, 6.0, Color(1, 1, 1, 0.6))
	if _paused:
		var screen := SafeArea.get_screen_size()
		_overlay.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.45))
		var c := screen * 0.5
		_overlay.draw_rect(Rect2(c + Vector2(-9, -12), Vector2(6, 24)), Color.WHITE)
		_overlay.draw_rect(Rect2(c + Vector2(3, -12), Vector2(6, 24)), Color.WHITE)
