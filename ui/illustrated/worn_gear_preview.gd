class_name WornGearPreview
extends Control
## Uses the same idle painting, art coordinates and equipment layers as the arena.
const STANDING_FRAME := Rect2(12, 16, 205, 168)
var _appearance := WornGear.new()
var _painting: Texture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func set_appearance(hero: StringName, profile: Dictionary, chapter_level: int = -1) -> void:
	if chapter_level < 0:
		chapter_level = GameState.hero_level if hero == GameState.hero_class else 1
	_appearance.configure(hero, profile, chapter_level)
	_painting = StoryArt.motion_pose(StringName(_appearance.hero), 0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if _painting == null or size.x <= 0 or size.y <= 0:
		return
	var zoom := minf(size.x / STANDING_FRAME.size.x, size.y / STANDING_FRAME.size.y)
	var origin := (size - STANDING_FRAME.size * zoom) * 0.5 - STANDING_FRAME.position * zoom
	var rect := Rect2(origin, StoryArt.HERO_TILE * zoom)
	_appearance.draw_hero(self, _painting, rect)
