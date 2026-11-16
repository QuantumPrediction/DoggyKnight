class_name ScreenTint
extends Node2D
## 蓋住整個戰鬥畫面(世界座標,不蓋 HUD)的一層顏色:必殺技的變暗、打倒頭目的白光閃。
## 淡入 fade_in 秒 → 維持 → 最後 fade_out 秒淡出,總長 duration 秒後自己刪除。
## 必殺技時另外畫一道從天而降的光柱(pillar_at),光柱在暗幕之上、金毛之下。
## 由 CombatFx.tint() 放在場地根節點,z_index 由呼叫者決定(暗幕 8:在角色之上、金毛之下)。

const GROUP: StringName = &"combat_fx"
const COVER := Rect2(-240, -260, 660, 840)       ## 比任何手機畫面都大(場地在世界原點)

var color: Color = Color(0, 0, 0, 0.5)
var duration: float = 0.8
var fade_in: float = 0.08
var fade_out: float = 0.3
var pillar: bool = false
var pillar_at: Vector2 = Vector2.ZERO
var pillar_width: float = 14.0
var pillar_color: Color = Color(1.0, 0.9, 0.5)

var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func strength() -> float:
	if _age < fade_in:
		return _age / maxf(fade_in, 0.001)
	return clampf((duration - _age) / maxf(fade_out, 0.001), 0.0, 1.0)


func _draw() -> void:
	var s := strength()
	draw_rect(COVER, Color(color, color.a * s))
	if not pillar:
		return
	# 光柱:先變粗再變細;中間白、兩邊金,頂端在畫面外。
	var grow := clampf(_age / 0.12, 0.0, 1.0)
	var w := pillar_width * grow * (0.6 + 0.4 * s)
	var top := COVER.position.y
	var bottom := pillar_at.y + 4.0
	var outer := Color(pillar_color, 0.35 * s)
	var mid := Color(pillar_color, 0.7 * s)
	var core := Color(1, 1, 1, 0.9 * s)
	draw_rect(Rect2(pillar_at.x - w * 0.5, top, w, bottom - top), outer)
	draw_rect(Rect2(pillar_at.x - w * 0.3, top, w * 0.6, bottom - top), mid)
	draw_rect(Rect2(pillar_at.x - maxf(1.0, w * 0.12), top, maxf(2.0, w * 0.24), bottom - top), core)
	# 腳下的光圈。
	draw_set_transform(pillar_at + Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w * 1.1, outer)
	draw_circle(Vector2.ZERO, w * 0.6, mid)
	draw_set_transform(Vector2.ZERO)
