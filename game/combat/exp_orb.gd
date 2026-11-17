class_name ExpOrb
extends Node2D
## 經驗珠(A7)。敵人倒下時彈出來,金毛靠近(GameState.player_stats.pickup_radius,每格即時讀取)
## 就被吸過去;碰到時發 EventBus.exp_collected(原始值),播 pickup 音效。exp_mult 由 B 線套用。
## 場上沒有敵人一小段時間後,所有經驗珠自動飛向金毛(不必在清場後到處撿)。
## M3 打磨:被吸過去時拖著一條發光的尾巴;慢動作時跟著變慢。

const GROUP: StringName = &"exp_orb"
const PLAYER_GROUP: StringName = &"player"
const TRAIL_POINTS := 5
const TRAIL_COLOR := Color(0.75, 1.0, 0.8)

@export var value: int = 1
@export var pop_time: float = 0.25               ## 彈出動作的秒數(這段時間不能撿)
@export var pop_distance_min: float = 5.0
@export var pop_distance_max: float = 12.0
@export var pop_height: float = 6.0
@export var magnet_accel: float = 420.0
@export var magnet_max_speed: float = 170.0
@export var collect_distance: float = 5.0
@export var auto_collect_delay: float = 0.8      ## 場上沒有敵人多久後自動吸過去;< 0 關閉

var collected: bool = false
var trail_color: Color = TRAIL_COLOR

var _pop_left: float = 0.0
var _pop_from: Vector2 = Vector2.ZERO
var _pop_to: Vector2 = Vector2.ZERO
var _magnet: bool = false
var _speed: float = 0.0
var _age: float = 0.0
var _no_enemy_time: float = 0.0
var _trail: PackedVector2Array = PackedVector2Array()
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group(GROUP)
	_age = randf() * TAU


## 從 from 彈到附近隨機一點(仍在戰鬥區內)。
func pop_from(from: Vector2) -> void:
	_pop_from = from
	var dir := Vector2.from_angle(randf() * TAU)
	_pop_to = CombatMath.clamp_to_arena(from + dir * randf_range(pop_distance_min, pop_distance_max), 4.0)
	_pop_left = pop_time
	global_position = from


func is_popping() -> bool:
	return _pop_left > 0.0


func _physics_process(delta: float) -> void:
	if collected:
		return
	delta *= CombatFx.time_scale
	_age += delta
	if _pop_left > 0.0:
		_pop_left = maxf(0.0, _pop_left - delta)
		var t := 1.0 - _pop_left / maxf(pop_time, 0.001)
		global_position = _pop_from.lerp(_pop_to, t)
		_sprite.position.y = -sin(PI * t) * pop_height
		return
	_sprite.position.y = -1.0 - sin(_age * 4.0)
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null or (player.has_method(&"is_downed") and bool(player.call(&"is_downed"))):
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if not _magnet and dist <= GameState.player_stats.pickup_radius:
		_magnet = true
	if not _magnet and auto_collect_delay >= 0.0:
		_no_enemy_time = _no_enemy_time + delta if not get_tree().has_group(&"enemy") else 0.0
		if _no_enemy_time >= auto_collect_delay:
			_magnet = true
	if not _magnet:
		return
	_speed = minf(magnet_max_speed, _speed + magnet_accel * delta)
	var step := _speed * delta
	if dist <= collect_distance or step >= dist:
		collect()
		return
	_trail.append(global_position)
	if _trail.size() > TRAIL_POINTS:
		_trail.remove_at(0)
	global_position += to_player / dist * step
	queue_redraw()


func _draw() -> void:
	# 被吸過去時的尾巴:越舊的點越淡、越細。
	if _trail.size() < 2:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in _trail.size():
		points.append((_trail[i] - global_position).round() + _sprite.position)
		colors.append(Color(trail_color, 0.15 + 0.6 * float(i) / float(_trail.size())))
	points.append(_sprite.position)
	colors.append(Color(trail_color, 0.85))
	draw_polyline_colors(points, colors, 1.0)


func collect() -> void:
	if collected:
		return
	collected = true
	remove_from_group(GROUP)
	EventBus.exp_collected.emit(value)
	Sfx.play(&"pickup")
	CombatFx.spawn(self, &"hit_spark", global_position, 0.0, Vector2.ONE * 0.6, Color(0.7, 1.0, 0.8))
	queue_free()
