class_name TouchJoystick
extends Node2D
## 浮動虛擬搖桿(A1)。放在 CanvasLayer 之下,所以畫在螢幕座標。
##
## - 按住任意位置 → 搖桿在手指下出現;拖曳 → 移動方向;放手 → 立刻消失、停下。
## - 只認第一根手指:搖桿使用中時,其他手指按下或放開都不影響。
## - 手指拉出底座時,底座跟著手指走(轉向不必把手指拉回來)。
## - 在群組 "ui_touch_blocker" 的可見 Control 範圍內「開始」的觸控一律不理會
##   (必殺技按鈕、暫停按鈕等)。觸控座標與 Control 的全域範圍都是畫面座標。
## - 遊戲暫停或失去焦點時自動放開,避免恢復後角色自己走。

const BLOCKER_GROUP: StringName = &"ui_touch_blocker"
const BASE_COLOR := Color(1, 1, 1, 0.16)
const RING_COLOR := Color(1, 1, 1, 0.5)
const KNOB_COLOR := Color(1, 1, 1, 0.7)

var radius: float = 18.0
var deadzone: float = 2.5
var full_speed_ratio: float = 0.85
var follow: bool = true
var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			release()

var _index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func configure(tuning: PlayerTuning) -> void:
	radius = tuning.joystick_radius
	deadzone = tuning.joystick_deadzone
	full_speed_ratio = tuning.joystick_full_speed_ratio
	follow = tuning.joystick_follow


## 拖距決定移速。外圈提前到達全速，拇指不用一直壓在底座最外緣。
func get_vector() -> Vector2:
	if _index < 0:
		return Vector2.ZERO
	var drag := _current - _origin
	var distance := drag.length()
	if distance <= deadzone:
		return Vector2.ZERO
	var full_speed_distance := radius * full_speed_ratio
	if distance >= full_speed_distance:
		return drag.normalized()
	var strength := inverse_lerp(deadzone, full_speed_distance, distance)
	return drag.normalized() * strength


func is_active() -> bool:
	return _index >= 0


func get_touch_index() -> int:
	return _index


func release() -> void:
	if _index < 0:
		return
	_index = -1
	queue_redraw()


## 這個畫面座標是否在擋住搖桿的介面元件之內。
static func is_blocked(tree: SceneTree, screen_pos: Vector2) -> bool:
	for node in tree.get_nodes_in_group(BLOCKER_GROUP):
		var control := node as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_pos):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	handle_input(event)


## 處理一個觸控事件(測試可直接呼叫)。
func handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and not touch.canceled:
			if _index >= 0:
				return
			if is_inside_tree() and is_blocked(get_tree(), touch.position):
				return
			_index = touch.index
			_origin = touch.position
			_current = touch.position
			queue_redraw()
		elif touch.index == _index:
			release()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _index:
		_current = drag.position
		var offset := _current - _origin
		if follow and offset.length() > radius:
			_origin = _current - offset.normalized() * radius
		queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			release()


func _draw() -> void:
	if _index < 0:
		return
	draw_circle(_origin, radius, BASE_COLOR)
	draw_arc(_origin, radius, 0.0, TAU, 32, RING_COLOR, 1.0)
	var knob := _origin + (_current - _origin).limit_length(radius)
	draw_circle(knob, 6.0, KNOB_COLOR)
