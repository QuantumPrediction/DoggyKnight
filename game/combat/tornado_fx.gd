class_name TornadoFx
extends Node2D
## 旋風尾(進化把戲 tornado_tail)的持續畫面:三道風一直繞著金毛轉,外圈有淡淡的氣旋與飛舞的葉子。
## 掛在金毛身上(z 比金毛低一層,不會蓋住金毛);角度由 TornadoTailAbility.angle 推進。
## 全部用程式畫、不平滑,像素清晰。

const WIND := Color(0.82, 0.97, 1.0, 0.85)
const WIND_DIM := Color(0.7, 0.9, 1.0, 0.3)
const LEAF := Color(0.55, 0.85, 0.4, 0.95)
const STREAKS := 3

var ability: TornadoTailAbility
var radius: float = 30.0
var _pulse: float = 0.0


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_pulse += delta * CombatFx.time_scale
	queue_redraw()


func _draw() -> void:
	var a := ability.angle if ability != null else _pulse * 7.0
	var r := radius
	# 淡淡的氣旋(地上的圈,稍微壓扁,看起來在地上)。
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.6))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, WIND_DIM, 1.0)
	draw_arc(Vector2.ZERO, r * 0.62, a * 0.5, a * 0.5 + PI * 1.2, 20, WIND_DIM, 1.0)
	# 三道繞身的風:每道是一段越來越細的弧。
	for i in STREAKS:
		var start := a + TAU * float(i) / float(STREAKS)
		var wobble := 1.0 + 0.08 * sin(_pulse * 9.0 + float(i) * 2.0)
		draw_arc(Vector2.ZERO, r * 0.86 * wobble, start, start + 1.1, 10, WIND, 2.0)
		draw_arc(Vector2.ZERO, r * 0.86 * wobble, start + 1.1, start + 1.7, 6, Color(WIND, 0.45), 1.0)
		# 被捲起來的葉子。
		var leaf_at := Vector2.from_angle(start + 1.2) * r * 0.86 * wobble
		draw_rect(Rect2(leaf_at.round(), Vector2(2, 1)), LEAF)
	draw_set_transform(Vector2.ZERO)
