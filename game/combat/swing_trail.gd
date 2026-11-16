class_name SwingTrail
extends Node2D
## 揮劍拖尾(AP3):以金毛為中心的弧形光帶,在 sweep_time 內由一端掃到另一端,尾巴漸漸變淡。
## clockwise 決定由上往下還是由下往上揮(金毛會上下交替)。用 1 像素的線畫,保持像素風。

const GROUP: StringName = &"combat_fx"
const SEGMENTS := 14

var facing_angle: float = 0.0
var arc: float = deg_to_rad(150.0)
var inner_radius: float = 8.0
var outer_radius: float = 26.0
var clockwise: bool = true
var color: Color = Color(1.0, 0.97, 0.85)
var sweep_time: float = 0.13
var fade_time: float = 0.12

var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= sweep_time + fade_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var head := clampf(_age / maxf(sweep_time, 0.001), 0.0, 1.0)
	var fade := clampf((_age - sweep_time) / maxf(fade_time, 0.001), 0.0, 1.0)
	var start := facing_angle - arc * 0.5
	var direction := 1.0 if clockwise else -1.0
	if not clockwise:
		start = facing_angle + arc * 0.5
	# 光帶由幾條同心弧組成:外圈最亮、最粗,裡面幾圈越來越淡。
	var bands: Array = [[outer_radius, 1.0, 2.0], [outer_radius - 2.0, 0.75, 1.0],
			[lerpf(inner_radius, outer_radius, 0.55), 0.4, 1.0]]
	for band: Array in bands:
		var r: float = band[0]
		var strength: float = band[1]
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in SEGMENTS + 1:
			var u := float(i) / float(SEGMENTS) * head
			var a := start + direction * arc * u
			points.append(Vector2.from_angle(a) * r)
			# 越接近劍尖(head)越亮;尾巴淡出。
			var along := u / maxf(head, 0.001)
			var c := Color(color, color.a * strength * along * along * (1.0 - fade))
			colors.append(c)
		if points.size() >= 2:
			draw_polyline_colors(points, colors, band[2])
