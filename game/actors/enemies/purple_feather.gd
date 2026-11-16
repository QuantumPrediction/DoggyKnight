class_name PurpleFeather
extends Node2D
## 稻草人隊長倒下時,帽子上那根紫色羽毛(摩根娜的羽毛,故事伏筆,見 docs/STORY.md 的 l4_after)
## 慢慢地左右搖擺、飄落到地上,落地後微微發著紫光,一直留到這一關結束(場地 clear() 時移除)。
## 程式畫的羽毛(C 線之後可以換成圖)。飄落時在特效層(畫在角色之上,看得清楚),落地後移到地面層。
## 慢動作時跟著變慢。

const GROUP: StringName = &"combat_fx"
const QUILL := Color("f2e6ff")
const VANE := Color("9a4fd8")
const VANE_DARK := Color("5e2a96")
const GLOW := Color(0.75, 0.45, 1.0)

var ground_y: float = 0.0                 ## 落地的世界 y 座標
var fall_speed: float = 15.0              ## 往下飄的速度(像素/秒)
var sway: float = 7.0                     ## 左右搖擺的幅度
var sway_rate: float = 2.4
var landed: bool = false

var _age: float = 0.0
var _start_x: float = 0.0
var _land_age: float = 0.0


static func drop(host: Node, from: Vector2, p_ground_y: float) -> PurpleFeather:
	if host == null or not host.is_inside_tree():
		return null
	var feather := PurpleFeather.new()
	feather.ground_y = p_ground_y
	CombatFx.layer_for(host).add_child(feather)
	feather.global_position = from
	feather._start_x = from.x
	return feather


func _ready() -> void:
	add_to_group(GROUP)
	if _start_x == 0.0:
		_start_x = global_position.x


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if not landed:
		var y := global_position.y + fall_speed * delta
		# 像真的羽毛:往一邊盪的時候慢一點,盪到兩端時往下掉快一點。
		var swing := sin(_age * sway_rate)
		y += absf(swing) * fall_speed * 0.4 * delta
		global_position = Vector2(_start_x + swing * sway, y)
		rotation = cos(_age * sway_rate) * 0.55
		if global_position.y >= ground_y:
			_land()
	else:
		_land_age += delta
		rotation = lerp_angle(rotation, 1.35, clampf(delta * 6.0, 0.0, 1.0))
	queue_redraw()


func _land() -> void:
	landed = true
	global_position.y = ground_y
	var ground := CombatFx.layer_for(self, true)
	if ground != null and ground != get_parent():
		reparent(ground)
	CombatFx.particles(self, &"sparkle", global_position, true, true)


func _draw() -> void:
	# 淡淡的紫光(落地後慢慢脈動)。
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	var glow_a := 0.18 + 0.12 * pulse
	draw_circle(Vector2.ZERO, 6.0 + pulse, Color(GLOW, glow_a * (0.6 if landed else 1.0)))
	# 羽毛:中間一根白色羽軸,兩邊紫色的羽片(上寬下窄)。
	var vane := PackedVector2Array([
		Vector2(0, -6), Vector2(2, -5), Vector2(3, -2), Vector2(2, 2), Vector2(1, 4),
		Vector2(0, 4), Vector2(-1, 2), Vector2(-2, -2), Vector2(-2, -5),
	])
	draw_colored_polygon(vane, VANE)
	draw_line(Vector2(-1, -4), Vector2(-1, 2), VANE_DARK, 1.0)
	draw_line(Vector2(0, -6), Vector2(0, 7), QUILL, 1.0)
	draw_rect(Rect2(1, -4, 1, 1), Color(1, 1, 1, 0.8))
