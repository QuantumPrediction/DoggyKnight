class_name ChapterStrip
extends Control
## 結算畫面的第一章進度條(C 線,CP5):一排小圓點,打過的關是金色,這一關是發亮的星,
## 還沒打的是暗紫色;頭目關的圓點畫成小盾牌。不攔觸控。

var count: int = 6
var current: int = 0          # 這一關(0 起算)
var best_stars: Array[int] = []

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 11)


func set_progress(index: int, total: int) -> void:
	count = maxi(1, total)
	current = clampi(index, 0, count - 1)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var gap := floorf((w - 12.0) / maxf(1.0, count - 1))
	var y := 5.0
	var x0 := floorf((w - gap * (count - 1)) * 0.5)
	draw_rect(Rect2(x0, y, gap * (count - 1), 1), PaletteColors.PLUM)
	if current > 0:
		draw_rect(Rect2(x0, y, gap * current, 1), PaletteColors.GOLD_D)
	for i in count:
		var cx := x0 + gap * i
		var r := Rect2(cx - 2, y - 2, 5, 5)
		if i < current:
			draw_rect(r, PaletteColors.GOLD)
			draw_rect(Rect2(cx - 1, y - 2, 3, 1), PaletteColors.GOLD_L)
		elif i == current:
			var pulse := 1.0 if fmod(_time, 0.8) < 0.4 else 0.0
			draw_rect(Rect2(cx - 3 - pulse, y - 3 - pulse, 7 + pulse * 2, 7 + pulse * 2), PaletteColors.INK)
			draw_rect(Rect2(cx - 2 - pulse, y - 2 - pulse, 5 + pulse * 2, 5 + pulse * 2), PaletteColors.YELLOW)
			draw_rect(Rect2(cx - 1, y - 1, 2, 1), PaletteColors.WHITE)
		else:
			draw_rect(r, PaletteColors.PLUM)
			draw_rect(Rect2(cx - 1, y - 1, 3, 3), PaletteColors.VIOLET)
		if i == count - 1:
			# 頭目關:畫一個小頭盔記號在上方
			draw_rect(Rect2(cx - 1, y - 6, 3, 2), PaletteColors.IRON)
			draw_rect(Rect2(cx - 1, y - 5, 3, 1), PaletteColors.ORANGE)
