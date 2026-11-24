extends Control
const TITLE_FONT: Font = preload("res://assets/fonts/StoryDisplay.tres")
const CAPTION_FONT: Font = preload("res://assets/fonts/StorySerif.otf")
## Re-skins existing controls without changing their layout, signals or hit targets.
var _source: Control
var _path: String = ""
var _kind: String = ""
var _tex: Texture2D
var _last_size := Vector2.ZERO
var _code: String = ""

func _ready() -> void:
	_source = get_parent() as Control
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	if _source == null:
		return
	var original: Texture2D
	if _source is TextureButton:
		var button := _source as TextureButton
		original = button.texture_pressed if button.is_pressed() and button.texture_pressed != null else button.texture_normal
	else:
		original = _source.get("texture") as Texture2D
	var path := original.resource_path if original != null else ""
	if path != _path:
		_path = path
		_kind = ""
		_tex = null
		_code = path.get_file().get_basename()
		if path.begins_with("res://assets/portraits/"):
			_code = path.trim_prefix("res://assets/portraits/").get_slice("/", 0)
			var emotion := path.get_file().get_basename()
			var pose := 0
			if _code == "goldie":
				pose = 6 if emotion == "happy" else (7 if emotion == "tired" else (4 if emotion == "serious" else 0))
			elif emotion in ["serious", "angry", "proud"]:
				pose = 3
			_tex = StoryArt.actor("morgana" if _code == "morgana_true" else _code, pose)
			_kind = "portrait" if _tex != null else ""
		elif path.begins_with("res://assets/icons/tricks/"):
			var index := StoryArt.TRICKS.find(_code)
			if index >= 0:
				_tex = StoryArt.cell("trick_icons", index % 4, index / 4)
				_kind = "image" if _tex != null else ""
		elif path.begins_with("res://assets/story/"):
			_tex = StoryArt.story(_code)
			_kind = "image" if _tex != null else ""
		elif path.begins_with("res://assets/ui/title_bg"):
			_tex = StoryArt.texture("title_art")
			_kind = "cover"
		elif path.begins_with("res://assets/ui/"):
			_tex = StoryArt.ui_icon(_code)
			if _tex != null:
				_kind = "image"
			elif _code.begins_with("ultimate_"):
				_kind = "ultimate"
				_tex = StoryArt.ui_icon("ultimate")
			elif _code == "cutin_goldie":
				_kind = "cutin"
				_tex = StoryArt.motion_pose(GameState.hero_class, 5)
			elif _code in ["logo", "logo_2x"]:
				_kind = "logo"
			elif _code in ["dialogue_panel", "panel", "page_frame", "portrait_frame", "name_plate", "hud_plate", "panel_dark", "ribbon", "ribbon_gold"]:
				_kind = "frame"
			elif _code.begins_with("cloud_"):
				_kind = "hidden"
		_source.self_modulate.a = 0.0 if not _kind.is_empty() else 1.0
		queue_redraw()
	if _last_size != _source.size:
		_last_size = _source.size
		size = _last_size
		queue_redraw()

func _draw() -> void:
	if _kind.is_empty() or _last_size.x <= 0:
		return
	var rect := Rect2(Vector2.ZERO, _last_size)
	match _kind:
		"ultimate":
			draw_style_box(_box(Color("193b3a"), Color("e2bc70")), rect)
			draw_texture_rect(_tex, rect.grow(-2), false, Color("d4b888") if _code.ends_with("pressed") else Color.WHITE)
		"image":
			if _tex != null:
				draw_texture_rect(_tex, rect, false)
		"cutin":
			if _tex != null:
				var source := _tex.get_size()
				var fitted := source * minf(rect.size.x / source.x, rect.size.y / source.y)
				draw_texture_rect(_tex, Rect2(rect.get_center() - fitted * 0.5, fitted), false)
		"cover":
			if _tex != null:
				draw_texture_rect(_tex, rect, false)
		"portrait":
			draw_style_box(_box(Color("e6d5af"), Color("96754b")), rect)
			if _tex != null:
				# Authored full-body portraits keep weapons and breed silhouettes readable.
				draw_texture_rect(_tex, rect.grow(-2), false, Color("271d40") if _code == "morgana" else Color.WHITE)
		"frame":
			var dark := _code in ["hud_plate", "panel_dark", "name_plate", "ribbon", "ribbon_gold"]
			var paper := Color("f0dfb9")
			var ink := Color("1a302f")
			if _code in ["portrait_frame", "page_frame"]:
				draw_style_box(_box(Color(0, 0, 0, 0), Color("b79960")), rect)
			else:
				draw_style_box(_box(ink if dark else paper, Color("b79960")), rect)
			if rect.size.x > 32 and rect.size.y > 16:
				var line := Color("a18752")
				line.a = 0.6
				draw_rect(rect.grow(-2.5), line, false, 0.4)
		"logo":
			_draw_wordmark(rect)


func _draw_wordmark(rect: Rect2) -> void:
	# Both logo resources use this cover imprint. Work in the larger logo's coordinates.
	draw_set_transform(rect.position, 0.0, rect.size / Vector2(106, 29))
	var ink := Color("213b35")
	var foil := Color("ffe9a6")
	var title := tr("GAME_TITLE")
	var title_width := TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
	var baseline := Vector2(0.5 * (106.0 - title_width), 18.2)
	draw_string_outline(TITLE_FONT, baseline + Vector2(0, 0.8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, 2, ink)
	draw_string(TITLE_FONT, baseline + Vector2(0, 0.7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("b77a39"))
	draw_string(TITLE_FONT, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, foil)

	var ribbon := PackedVector2Array([Vector2(5, 20), Vector2(101, 20), Vector2(97, 24.5),
			Vector2(101, 29), Vector2(5, 29), Vector2(9, 24.5)])
	draw_colored_polygon(ribbon, ink)
	draw_line(Vector2(10, 24.5), Vector2(13, 24.5), Color("bfa06d"), 0.65, true)
	draw_line(Vector2(93, 24.5), Vector2(96, 24.5), Color("bfa06d"), 0.65, true)
	draw_string(CAPTION_FONT, Vector2(0, 26.8), tr("UI_GAME_TITLE_EN"),
			HORIZONTAL_ALIGNMENT_CENTER, 106, 8, Color("fff2ca"))


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(2)
	b.anti_aliasing = true
	return b
