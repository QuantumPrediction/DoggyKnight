class_name ElementArt
extends RefCounted
## One shared atlas for armory cards, choices and the live combat HUD.
const ATLAS: Texture2D = preload("res://assets/illustrated/equipment/element_runes.png")

static func icon(element: String) -> Texture2D:
	var index := EquipmentInventory.ELEMENTS.find(element)
	if index < 0:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	var cell := Vector2(ATLAS.get_width(), ATLAS.get_height()) / 2.0
	texture.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
	texture.filter_clip = true
	return texture

static func color(element: String) -> Color:
	return Color(str(EquipmentInventory.RULES.elements.get(element, {}).get("color", "b7c8bc")))
