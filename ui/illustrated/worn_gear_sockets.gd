extends RefCounted
## Near shoulder, weapon fitting and weapon angle (clockwise from upright).
## Coordinates are in the 256 × 192 paintings, before the sprite's mirror and breath.
## Sword and unobstructed bow poses also record the blade tip or lower nock (sixth/seventh fields).
const POSES := {
	"knight": {
		"side": [[123, 86, 127, 120, 115, 175, 144], [122, 86, 131, 120, 113, 181, 143], [123, 86, 131, 119, 111, 184, 140], [127, 79, 134, 108, 110, 184, 127],
			[123, 88, 133, 113, 117, 179, 141], [122, 87, 130, 115, 116, 179, 138], [125, 86, 131, 113, 112, 182, 136], [123, 75, 129, 109, 119, 174, 135]],
		"vertical": [[99, 81, 87, 113, 213, 65, 151], [89, 89, 73, 116, 218, 50, 149], [96, 75, 73, 100, 225, 49, 134], [99, 86, 89, 116, 213, 73, 149],
			[131, 78, 150, 115, 150, 167, 142], [131, 77, 157, 114, 154, 170, 139], [127, 68, 152, 105, 151, 171, 128], [130, 81, 155, 115, 151, 169, 140]],
		"settle": [[95, 88, 81, 130, 204, 65, 164], [97, 90, 81, 127, 203, 68, 159], [128, 82, 153, 125, 155, 170, 158], [129, 84, 156, 127, 157, 168, 160]],
		"action": [[118, 83, 123, 126, 116, 180, 157], [120, 80, 89, 46, 52, 133, 14], [145, 89, 192, 91, 90, 248, 93], [129, 88, 167, 120, 121, 215, 149],
			[117, 87, 121, 131, 117, 184, 158]],
		"reaction": [[118, 82, 122, 125, 116, 180, 155], [122, 77, 132, 123, 147, 166, 174], [107, 130, 124, 165, 89, 178, 164]],
	},
	"mage": {
		"side": [[119, 91, 183, 107, 77], [117, 93, 183, 109, 77], [126, 86, 184, 99, 75], [122, 79, 180, 91, 78],
			[121, 90, 179, 101, 78], [126, 95, 182, 103, 75], [130, 90, 183, 102, 80], [125, 78, 183, 92, 76]],
		"vertical": [[98, 85, 84, 73, -49], [95, 90, 88, 71, -37], [100, 80, 73, 70, -47], [100, 88, 90, 80, -25],
			[135, 80, 159, 66, 20], [130, 85, 160, 78, 15], [130, 74, 159, 65, 14], [131, 86, 159, 74, 15]],
		"settle": [[99, 94, 91, 86, -8], [98, 91, 91, 73, -4], [130, 84, 155, 78, 9], [131, 83, 155, 74, 5]],
		"action": [[109, 92, 182, 142, 123], [102, 88, 173, 79, 74], [123, 86, 208, 75, 71], [129, 86, 206, 91, 78],
			[108, 88, 183, 146, 123]],
		"reaction": [[104, 88, 182, 143, 120], [126, 85, 190, 55, 40], [111, 139, 181, 164, 83]],
	},
	"archer": {
		"side": [[122, 84, 181, 64, 10, 154, 131], [129, 90, 181, 69, 17, 149, 136], [132, 81, 183, 60, 6], [129, 80, 186, 61, 10, 163, 121],
			[126, 77, 183, 64, 13, 148, 131], [124, 82, 182, 64, 13, 153, 129], [119, 77, 185, 60, 16, 161, 124], [125, 85, 182, 66, 7]],
		"vertical": [[98, 91, 165, 65, 17], [100, 95, 162, 78, 18], [99, 80, 153, 54, 19], [101, 90, 159, 70, 15],
			[129, 81, 79, 59, -22], [130, 86, 84, 61, -22, 88, 126], [128, 75, 80, 55, -21], [131, 84, 83, 70, -25]],
		"settle": [[99, 94, 156, 67, 12], [95, 88, 154, 67, 13], [131, 86, 78, 69, -20], [131, 84, 83, 65, -20]],
		"action": [[112, 87, 168, 73, 16], [104, 78, 163, 28, -12, 174, 139], [109, 75, 159, 26, -17, 174, 140], [112, 83, 173, 47, -5, 159, 147],
			[110, 83, 168, 75, 13]],
		"reaction": [[110, 82, 167, 66, 8], [121, 79, 173, 43, 17, 168, 149], [108, 139, 190, 161, 81, 101, 172]],
	},
}

static func locate(hero: String, texture: Texture2D) -> Array:
	var tile := texture as AtlasTexture
	if tile == null or tile.atlas == null or tile.region.size != StoryArt.HERO_TILE or not POSES.has(hero):
		return []
	var sheet := tile.atlas.resource_path.get_file().get_basename()
	var col := int(tile.region.position.x / StoryArt.HERO_TILE.x)
	var row := int(tile.region.position.y / StoryArt.HERO_TILE.y)
	var poses: Dictionary = POSES[hero]
	if sheet == hero:
		var index := row * 3 + col
		# Base tiles 1–4 are retired side runs. They are not displayed by the live motion clock.
		if index == 0 or index >= 5:
			return poses.action[0 if index == 0 else index - 4]
	elif sheet == "stride_" + hero:
		return poses.side[row * 4 + col]
	elif sheet == "vertical_" + hero:
		return poses.vertical[row * 4 + col]
	elif sheet == "settle_" + hero:
		return poses.settle[row * 2 + col]
	elif sheet == "reactions" and row == HeroClasses.IDS.find(StringName(hero)):
		return poses.reaction[col]
	return []
