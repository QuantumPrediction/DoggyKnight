extends Node2D
## 場地背景的佔位版(DEV_PLAN 4.9)。C 線之後原地替換 assets/backgrounds/*.tscn。
##
## 合約:根節點是 Node2D,在世界座標畫出場地(Layout.ARENA_RECT)與周圍延伸區;
## 延伸區至少覆蓋 (-10,-60) 至 (190,380),讓長螢幕、寬螢幕都看不到空白。
## z_index 由場地(A 線)設定在角色之下。

@export_enum("meadow", "sword_stone", "bridge") var variant: String = "meadow"

const OUTER := Rect2(-120, -200, 420, 720)


func _draw() -> void:
	var arena := Layout.ARENA_RECT
	var outer_color := Color("2f5d3a")
	var tile_a := Color("6fae4f")
	var tile_b := Color("64a246")
	if variant == "bridge":
		outer_color = Color("2c5a7a")
		tile_a = Color("9a8f86")
		tile_b = Color("8c8178")
	draw_rect(OUTER, outer_color)
	var cols := int(arena.size.x) / Layout.TILE
	var rows := int(arena.size.y) / Layout.TILE
	for y in rows:
		for x in cols:
			var color := tile_a if (x + y) % 2 == 0 else tile_b
			draw_rect(Rect2(arena.position + Vector2(x, y) * Layout.TILE, Vector2.ONE * Layout.TILE), color)
	match variant:
		"sword_stone":
			var stone := Rect2(arena.get_center().x - 12, arena.position.y + 10, 24, 14)
			draw_rect(stone, Color("8a8f98"))
			draw_rect(Rect2(stone.get_center().x - 1, stone.position.y - 14, 2, 14), Color("e6e9ef"))
			draw_rect(Rect2(stone.get_center().x - 4, stone.position.y - 10, 8, 2), Color("d4a640"))
		"bridge":
			draw_rect(Rect2(arena.position.x - 4, arena.position.y, 4, arena.size.y), Color("5f554d"))
			draw_rect(Rect2(arena.end.x, arena.position.y, 4, arena.size.y), Color("5f554d"))
