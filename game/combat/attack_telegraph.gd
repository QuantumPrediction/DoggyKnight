class_name AttackTelegraph
extends Node2D
## 攻擊預警(DEV_PLAN 4.9:預警圈與預警線由 A 線用程式畫;AP7:脈動的地面圖案)。
##
## 紅色半透明的地面圖案:外框表示攻擊範圍,裡面的顏色隨 progress(0 至 1)填滿,填滿就是即將命中。
## - 整個圖案一直在「呼吸」(脈動),越接近命中脈動越快;
## - 圓圈:外框是轉動的虛線,還有一圈圈往中心收的波紋;扇形:波紋由攻擊者往外推;
##   直線:箭頭沿著衝鋒方向流動;
## - 最後一段(FLASH_FROM 之後)整個變亮、外框閃白,告訴玩家「現在要閃」。
## 掛在攻擊者身上(z_index -1:畫在角色腳下)。預警永遠是畫面上最顯眼的危險訊號,
## 其他特效放在地面層之下或很快消失,不會蓋住它。

enum Shape { CIRCLE, SECTOR, LINE }

const DANGER := Color(1.0, 0.2, 0.16)
const DUST := Color(0.93, 0.85, 0.7)
const MAGIC := Color(0.72, 0.42, 1.0)
const FLASH_FROM := 0.82                  ## progress 超過這個值就開始變亮、閃爍
const HOT := Color(1.0, 0.85, 0.55)       ## 快命中時混進去的亮色

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

var _time: float = 0.0


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


func _process(delta: float) -> void:
	# 脈動越接近命中越快(每秒 3 → 9 次)。
	_time += delta * lerpf(3.0, 9.0, progress)
	queue_redraw()


## 目前的脈動(0 至 1)。
func pulse() -> float:
	return 0.5 + 0.5 * sin(_time * TAU)


func is_hot() -> bool:
	return progress >= FLASH_FROM


## Use the rendered wedge itself, including its straight side edges and polygonal
## arc. A body entirely outside this warning cannot be hit by a marked sweep.
func intersects_sector_body(at: Vector2, body_radius: float) -> bool:
	if shape != Shape.SECTOR:
		return false
	var polygon := _sector_points(radius)
	for i in polygon.size():
		polygon[i] = global_transform * polygon[i]
	if Geometry2D.is_point_in_polygon(at, polygon):
		return true
	var radius_squared := maxf(0.0, body_radius) ** 2
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(at, polygon[i], polygon[(i + 1) % polygon.size()])
		if at.distance_squared_to(closest) <= radius_squared:
			return true
	return false


func _draw() -> void:
	var p := pulse()
	var hot := is_hot()
	var blink := hot and int(_time * 2.0) % 2 == 0
	var base := color.lerp(HOT, 0.35) if hot else color
	var area := Color(base, 0.12 + 0.08 * p + (0.08 if hot else 0.0))
	var fill := Color(base, lerpf(0.28, 0.5, progress) + (0.12 if blink else 0.0))
	var edge := Color(1, 1, 1, 0.9) if blink else Color(base.lightened(0.35), 0.6 + 0.3 * p)
	var ripple := Color(base.lightened(0.5), 0.25 + 0.35 * progress)
	match shape:
		Shape.CIRCLE:
			_draw_circle(area, fill, edge, ripple)
		Shape.SECTOR:
			_draw_sector(area, fill, edge, ripple)
		Shape.LINE:
			_draw_line(area, fill, edge, ripple)


func _draw_circle(area: Color, fill: Color, edge: Color, ripple: Color) -> void:
	draw_circle(Vector2.ZERO, radius, area)
	if progress > 0.0:
		draw_circle(Vector2.ZERO, radius * progress, fill)
	# 往中心收的波紋(像在聚力)。
	var wave := 1.0 - fmod(_time * 0.5, 1.0)
	if radius * wave > radius * progress + 1.0:
		draw_arc(Vector2.ZERO, radius * wave, 0.0, TAU, maxi(12, int(radius)), Color(ripple, ripple.a * wave), 1.0)
	# 外框:實線 + 外面一圈轉動的虛線。
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, maxi(16, int(radius * 1.2)), edge, 1.0)
	var dashes := clampi(int(radius / 3.0), 6, 18)
	var spin := _time * 0.35
	for i in dashes:
		var a := spin + TAU * float(i) / float(dashes)
		draw_arc(Vector2.ZERO, radius + 2.0, a, a + TAU / float(dashes) * 0.45, 3, Color(edge, edge.a * 0.7), 1.0)


func _draw_sector(area: Color, fill: Color, edge: Color, ripple: Color) -> void:
	draw_colored_polygon(_sector_points(radius), area)
	if progress > 0.0:
		draw_colored_polygon(_sector_points(maxf(1.0, radius * progress)), fill)
	# 由攻擊者往外推的波紋。
	var base := direction.angle()
	for k in 2:
		var wave := fmod(_time * 0.6 + float(k) * 0.5, 1.0)
		var r := radius * wave
		if r > radius * progress:
			draw_arc(Vector2.ZERO, r, base - half_angle, base + half_angle, 8, Color(ripple, ripple.a * (1.0 - wave)), 1.0)
	var outline := _sector_points(radius)
	outline.append(outline[0])
	draw_polyline(outline, edge, 1.0)


func _draw_line(area: Color, fill: Color, edge: Color, ripple: Color) -> void:
	draw_set_transform(Vector2.ZERO, direction.angle())
	var half_w := width * 0.5
	draw_rect(Rect2(0, -half_w, length, width), area)
	if progress > 0.0:
		draw_rect(Rect2(0, -half_w, length * progress, width), fill)
	# 沿著衝鋒方向流動的箭頭(>)。
	var spacing := maxf(8.0, width * 0.9)
	var shift := fmod(_time * spacing * 0.8, spacing)
	var arm := minf(half_w - 1.0, 4.0)
	var x := shift
	while x < length - 2.0:
		var a := Color(ripple, ripple.a * clampf(1.0 - x / maxf(length, 1.0) * 0.5, 0.3, 1.0))
		draw_line(Vector2(x - arm, -arm), Vector2(x, 0), a, 1.0)
		draw_line(Vector2(x - arm, arm), Vector2(x, 0), a, 1.0)
		x += spacing
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
