extends RefCounted
## Live item art, hero poses and prices sit over these painted, empty display cases.

const CABINETS: Texture2D = preload("res://assets/illustrated/equipment/atelier_cabinets.webp")
const EMBLEMS: Texture2D = preload("res://assets/illustrated/equipment/atelier_emblems.webp")
const CABINET_ROWS := {"common": 0, "epic": 1, "owned": 2}
const EMBLEM_CELLS := {"coins": 0, "gems": 1, "shards": 2, "weapon": 3, "armor": 4, "treasure_a": 5, "treasure_b": 5}

static func _tile(texture: Texture2D, columns: int, rows: int, index: int) -> AtlasTexture:
	var tile := AtlasTexture.new()
	var cell := texture.get_size() / Vector2(columns, rows)
	tile.atlas = texture
	tile.region = Rect2(Vector2(index % columns, floori(float(index) / columns)) * cell, cell)
	tile.filter_clip = true
	return tile

static func emblem(id: String) -> Texture2D:
	return _tile(EMBLEMS, 3, 2, EMBLEM_CELLS[id])

static func case_art(kind: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = _tile(CABINETS, 1, 3, CABINET_ROWS[kind])
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.set_meta(&"illustrated", true)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.clip_contents = true
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture

static func shelf(kind: String) -> TextureRect:
	var picture := case_art(kind)
	var tile := picture.texture as AtlasTexture
	var region := tile.region
	region.size.x *= 0.53
	tile.region = region
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return picture

static func place_exhibit(press: Control, art: Control) -> void:
	press.add_child(art)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.set_anchor_and_offset(SIDE_LEFT, 0.045, 0)
	art.set_anchor_and_offset(SIDE_RIGHT, 0.46, 0)
	art.set_anchor_and_offset(SIDE_TOP, 0.035, 0)
	art.set_anchor_and_offset(SIDE_BOTTOM, 0.89, 0)

static func caption(press: Control) -> VBoxContainer:
	var center := MarginContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	press.add_child(center)
	center.name = "Caption"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.set_anchor_and_offset(SIDE_LEFT, 0.47, 0)
	center.set_anchor_and_offset(SIDE_RIGHT, 1.0, -4)
	center.set_anchor_and_offset(SIDE_TOP, 0.0, 2)
	center.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -2)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 1)
	center.add_child(copy)
	return copy
