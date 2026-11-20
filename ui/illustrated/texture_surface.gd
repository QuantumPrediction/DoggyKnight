extends Control
const TITLE_FONT: Font = preload("res://assets/fonts/StorySerif.otf")
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
				_kind = "image"
				_tex = StoryArt.actor("goldie", 4)
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
			var font := TITLE_FONT
			var title := "金毛騎士"
			var fs := mini(26, int(_last_size.x / 4.5))
			var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2((_last_size.x - width) * 0.5, _last_size.y * 0.62)
			draw_string_outline(font, pos + Vector2(0, 1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color("152c28"))
			draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f5d68b"))
			var caption := "G O L D E N   K N I G H T"
			var sw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
			draw_string(font, Vector2((_last_size.x - sw) * 0.5, _last_size.y - 3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("f2e6c4"))

static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(2)
	b.anti_aliasing = true
	return b
