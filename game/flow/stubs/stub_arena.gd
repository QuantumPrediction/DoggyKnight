extends Node2D
## 戰鬥場地的替身(B 線用,讓流程現在就能玩)。正式版:game/combat/arena.tscn(A 線)。
##
## 方法與正式版相同(DEV_PLAN 4.4、4.9):
##   spawn_enemy(enemy_id, at) -> Node、get_spawn_points() -> Array[Vector2]、clear()、
##   spawn_companion(companion_id) -> Node、set_background(scene)、get_player() -> Node2D
## 內含:地面邊界、置中的 Camera2D、主角替身(放在 Layout.PLAYER_START)。
##
## 操作(手機與桌面相同,滑鼠等同觸控):
## - 按住任意位置拖曳 → 金毛移動(只認第一根手指);放手 → 停下自動攻擊。
## - 點一下敵人 → 敵人立即倒下(沙盒用的捷徑)。
##
## 另有給測試與沙盒用的 debug_kill_all()、debug_down_player()。

const PlayerScript := preload("res://game/flow/stubs/stub_player.gd")
const EnemyScript := preload("res://game/flow/stubs/stub_enemy.gd")
const CompanionScript := preload("res://game/flow/stubs/stub_companion.gd")

const JOYSTICK_RADIUS: float = 20.0
const JOYSTICK_DEADZONE: float = 3.0
const TAP_SLOP: float = 6.0

## 出生點:場地邊緣一圈(遊戲世界座標)。
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(18, 84), Vector2(62, 84), Vector2(118, 84), Vector2(162, 84),
	Vector2(12, 140), Vector2(168, 140), Vector2(12, 200), Vector2(168, 200),
	Vector2(18, 284), Vector2(162, 284),
]

var _background_holder: Node2D
var _enemies: Node2D
var _companions: Node2D
var _player: CharacterBody2D
var _joystick: Node2D
var _touch_index: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	_background_holder = Node2D.new()
	_background_holder.name = "Background"
	_background_holder.z_index = -10
	add_child(_background_holder)
	_build_walls()
	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_companions = Node2D.new()
	_companions.name = "Companions"
	add_child(_companions)
	_player = PlayerScript.new()
	_player.name = "Player"
	_player.position = Layout.PLAYER_START
	add_child(_player)
	_joystick = Node2D.new()
	_joystick.name = "Joystick"
	_joystick.z_index = 20
	_joystick.draw.connect(_draw_joystick)
	add_child(_joystick)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = SafeArea.GAME_CENTER
	add_child(camera)
	camera.make_current()


# --- 合約方法 ---

func spawn_enemy(enemy_id: StringName, at: Vector2) -> Node:
	var enemy: Node2D = EnemyScript.new()
	enemy.name = "%s_%d" % [enemy_id, _enemies.get_child_count()]
	enemy.call(&"configure", enemy_id, self)
	enemy.position = at.clamp(Layout.ARENA_RECT.position, Layout.ARENA_RECT.end)
	_enemies.add_child(enemy)
	return enemy


func get_spawn_points() -> Array[Vector2]:
	return SPAWN_POINTS.duplicate()


func clear() -> void:
	for enemy in _enemies.get_children():
		enemy.remove_from_group(&"enemy")
		enemy.queue_free()


func spawn_companion(companion_id: StringName) -> Node:
	var companion: Node2D = CompanionScript.new()
	companion.name = String(companion_id)
	companion.call(&"configure", companion_id, self)
	companion.position = Layout.PLAYER_START + CompanionScript.FOLLOW_OFFSET
	_companions.add_child(companion)
	return companion


func set_background(scene: PackedScene) -> void:
	for child in _background_holder.get_children():
		child.queue_free()
	if scene != null:
		_background_holder.add_child(scene.instantiate())


func get_player() -> Node2D:
	return _player


# --- 測試與沙盒用 ---

## 讓場上所有敵人立即倒下(會照常發 enemy_died 與 exp_collected)。傳回倒下的數目。
func debug_kill_all() -> int:
	var count := 0
	for enemy in _enemies.get_children():
		if enemy.is_in_group(&"enemy"):
			enemy.call(&"die")
			count += 1
	return count


func debug_down_player() -> void:
	_player.call(&"force_down")


func get_enemy_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for enemy in _enemies.get_children():
		if enemy.is_in_group(&"enemy"):
			result.append(enemy)
	return result


# --- 觸控 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_release_touch()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var enemy := _enemy_at(_to_world(touch.position))
			if enemy != null:
				enemy.call(&"die")
				get_viewport().set_input_as_handled()
				return
			if _touch_index < 0:
				_touch_index = touch.index
				_touch_origin = touch.position
				_touch_current = touch.position
		elif touch.index == _touch_index:
			_release_touch()
		_update_direction()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_touch_current = drag.position
			_update_direction()


func _release_touch() -> void:
	_touch_index = -1
	if _player != null:
		_player.set(&"direction", Vector2.ZERO)
	if _joystick != null:
		_joystick.queue_redraw()


func _update_direction() -> void:
	var drag := _touch_current - _touch_origin
	var dir := drag.normalized() if _touch_index >= 0 and drag.length() > JOYSTICK_DEADZONE else Vector2.ZERO
	_player.set(&"direction", dir)
	_joystick.queue_redraw()


func _to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _enemy_at(world_position: Vector2) -> Node2D:
	for enemy in get_enemy_nodes():
		var node := enemy as Node2D
		if node.global_position.distance_to(world_position) <= float(node.get(&"radius")) + TAP_SLOP:
			return node
	return null


func _draw_joystick() -> void:
	if _touch_index < 0:
		return
	var origin := _to_world(_touch_origin)
	var knob := origin + (_touch_current - _touch_origin).limit_length(JOYSTICK_RADIUS)
	_joystick.draw_arc(origin, JOYSTICK_RADIUS, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
	_joystick.draw_circle(knob, 6.0, Color(1, 1, 1, 0.6))


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Layers.ARENA
	walls.collision_mask = 0
	var r := Layout.ARENA_RECT
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in corners.size():
		var shape := SegmentShape2D.new()
		shape.a = corners[i]
		shape.b = corners[(i + 1) % corners.size()]
		var collider := CollisionShape2D.new()
		collider.shape = shape
		walls.add_child(collider)
	add_child(walls)
