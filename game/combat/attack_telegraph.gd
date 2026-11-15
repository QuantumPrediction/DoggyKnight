class_name AttackTelegraph
extends Node2D
## 攻擊預警(DEV_PLAN 4.9:預警圈與預警線由 A 線用程式畫)。
##
## 紅色半透明:外框表示攻擊範圍,裡面的顏色隨 progress(0 至 1)填滿,
## 填滿就是即將命中。最後一小段會閃爍,讓玩家知道「現在要閃」。
## 掛在攻擊者身上(z_index -1:畫在角色腳下)。

enum Shape { CIRCLE, SECTOR, LINE }

const DANGER := Color(1.0, 0.2, 0.16)
const DUST := Color(0.93, 0.85, 0.7)
const MAGIC := Color(0.72, 0.42, 1.0)
const FLASH_FROM := 0.82                  ## progress 超過這個值就開始閃

var shape: Shape = Shape.CIRCLE
var radius: float = 16.0
var direction: Vector2 = Vector2.RIGHT
var half_angle: float = PI / 3.0
var length: float = 40.0
var width: float = 12.0
var color: Color = DANGER
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


static func make_circle(r: float, tint: Color = DANGER) -> AttackTelegraph:
	var t := AttackTelegraph.new()
	t.shape = Shape.CIRCLE
	t.radius = r
	t.color = tint
	return t


static func make_sector(r: float, dir: Vector2, half: float) -> AttackTelegraph:
	var t := AttackTelegraph.new()
	t.shape = Shape.SECTOR
	t.radius = r
	t.direction = dir.normalized()
	t.half_angle = half
	return t


static func make_line(dir: Vector2, line_length: float, w: float) -> AttackTelegraph:
	var t := AttackTelegraph.new()
	t.shape = Shape.LINE
	t.direction = dir.normalized()
	t.length = line_length
	t.width = w
	return t


func _ready() -> void:
	z_index = -1
	add_to_group(&"combat_fx")


func _draw() -> void:
	var flashing := progress >= FLASH_FROM and int(progress * 40.0) % 2 == 0
	var area := Color(color, 0.16)
	var fill := Color(color, 0.36 if not flashing else 0.55)
	var edge := Color(color.lightened(0.3), 0.75) if not flashing else Color(1, 1, 1, 0.85)
	match shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, radius, area)
			if progress > 0.0:
				draw_circle(Vector2.ZERO, radius * progress, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, maxi(16, int(radius)), edge, 1.0)
		Shape.SECTOR:
			draw_colored_polygon(_sector_points(radius), area)
			if progress > 0.0:
				draw_colored_polygon(_sector_points(maxf(1.0, radius * progress)), fill)
			var outline := _sector_points(radius)
			outline.append(outline[0])
			draw_polyline(outline, edge, 1.0)
		Shape.LINE:
			draw_set_transform(Vector2.ZERO, direction.angle())
			var half_w := width * 0.5
			draw_rect(Rect2(0, -half_w, length, width), area)
			if progress > 0.0:
				draw_rect(Rect2(0, -half_w, length * progress, width), fill)
			draw_rect(Rect2(0, -half_w, length, width), edge, false, 1.0)
			draw_set_transform(Vector2.ZERO)


func _sector_points(r: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var base := direction.angle()
	var steps := 10
	for i in steps + 1:
		var a := base - half_angle + 2.0 * half_angle * float(i) / float(steps)
		points.append(Vector2.from_angle(a) * r)
	return points
