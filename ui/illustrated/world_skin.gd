extends Node2D
var chapter: int = 1
var level: int = 0
var _time: float = 0.0
var _texture: Texture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture = StoryArt.world(chapter, level)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if _texture == null:
		return
	# The playable rectangle is 0..180 / 52..304. Illustration props sit outside it.
	draw_rect(Rect2(-220, -240, 620, 800), Color("172726"))
	draw_texture_rect(_texture, Rect2(-12, -44, 204, 408), false)
	var tint := StoryArt.CHAPTER_COLORS[chapter - 1]
	# Sparse atmospheric motes; never cover the central danger indicators.
	for i in 12:
		var x := fmod(float(i * 37) + _time * (1.5 if chapter != 5 else 4.0), 208.0) - 14.0
		var y := fmod(float(i * 53) + _time * (8.0 if chapter == 5 else -2.0) + 4000.0, 352.0) - 16.0
		var alpha := 0.12 + 0.18 * (sin(_time * 1.6 + float(i)) * 0.5 + 0.5)
		if chapter == 5:
			draw_circle(Vector2(x, y), 0.5, Color(0.85, 0.95, 1.0, alpha), true, -1, true)
		else:
			draw_circle(Vector2(x, y), 0.4, Color(tint, alpha), true, -1, true)
