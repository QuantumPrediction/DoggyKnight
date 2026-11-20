class_name StoryArt
extends RefCounted
## High-resolution presentation resources. Logical combat dimensions remain unchanged.

const ROOT := "res://assets/illustrated/"
const WORLDS: Array = [
	["sword_stone", "wheat_field", "meadow", "farm_fence", "crow_forest", "bridge"],
	["castle_town", "castle_courtyard", "royal_library", "castle_wall", "magic_garden", "green_chapel"],
	["misty_lake", "fairy_forest", "stone_circle", "crystal_cave", "morgana_tower", "tower_top"],
	["golden_beach", "sea_cliffs", "pirate_ship", "coral_reef", "sunken_city", "sunken_palace"],
	["snowfield", "ice_cave", "hot_springs", "avalanche_pass", "volcano", "dragon_nest"],
	["camlann_field", "shadow_camp", "occupied_town", "throne_hall", "avalon_gate", "avalon_hill"],
]
const CHAPTER_COLORS: Array[Color] = [Color("d7ba65"), Color("92aeaa"), Color("80bdc3"), Color("dca77c"), Color("a5c7d7"), Color("c98b66")]
const CAST: Dictionary = {
	"bulldog": ["party_sheet", 0], "lancelot": ["party_sheet", 1],
	"tristan": ["party_sheet", 2], "gawain": ["party_sheet", 3],
	"scarecrow": ["foes_meadow", 0], "scarecrow_archer": ["foes_meadow", 0],
	"crow": ["foes_meadow", 1], "armored_husk": ["foes_meadow", 2], "gargoyle": ["foes_meadow", 3],
	"spellbook": ["foes_magic", 0], "shadow_wolf": ["foes_magic", 1],
	"foxfire": ["foes_magic", 2], "jellyfish": ["foes_magic", 3],
	"crab": ["foes_elements", 0], "snowman": ["foes_elements", 1],
	"salamander": ["foes_elements", 2], "shadow_knight": ["foes_elements", 3],
	"black_knight": ["bosses_royal", 0], "green_knight": ["bosses_royal", 1],
	"morgana": ["bosses_royal", 2], "kraken": ["bosses_royal", 3],
	"red_dragon": ["bosses_avalon", 0], "white_dragon": ["bosses_avalon", 1],
	"mordred": ["bosses_avalon", 2], "scarecrow_captain": ["bosses_avalon", 3],
	"merlin": ["story_cast", 0], "lady_lake": ["story_cast", 1],
	"lantern_wisp": ["story_cast", 2], "chest": ["story_cast", 3],
}
const TRICKS: Array[String] = ["fetch", "sit", "shake", "wag", "bark", "spin", "pounce", "roll", "dig", "sniff", "play_dead", "zoomies", "high_five", "tornado_tail", "lion_roar", "meteor_pounce"]
const FX: Dictionary = {"slash": 0, "ultimate_slash": 1, "hit_spark": 2, "exp_orb": 3, "arrow": 4, "pitchfork": 4, "fireball": 5, "ice_shard": 6, "music_note": 7, "magic_orb": 8, "moon_orb": 8, "fox_flame": 9, "snowball": 10, "bubble": 11, "ink_blob": 12, "thorn": 13, "snack": 14, "shadow_slash": 15}
const UI: Dictionary = {"icon_heart": 0, "icon_paw": 1, "icon_exp": 2, "icon_snack": 3, "icon_pause": 4, "star_full": 5, "star_empty": 6, "ultimate": 7, "icon_sound_on": 8, "icon_sound_off": 8, "icon_music_on": 9, "icon_music_off": 9, "icon_vibrate_on": 10, "icon_vibrate_off": 10, "next_arrow": 11, "icon_wave": 12, "icon_boss": 13, "icon_trophy": 14}
const STORY: Array = [
	["prologue_1", "prologue_2", "prologue_3", "prologue_4", "ending_1", "ending_2", "ending_3", "teaser_1"],
	["c2_prologue_1", "c2_prologue_2", "c2_ending_1", "c2_ending_2", "c2_ending_3", "teaser_2"],
	["c3_prologue_1", "c3_prologue_2", "c3_ending_1", "c3_ending_2", "c3_ending_3", "teaser_3"],
	["c4_prologue_1", "c4_prologue_2", "c4_ending_1", "c4_ending_2", "c4_ending_3", "teaser_4"],
	["c5_prologue_1", "c5_prologue_2", "c5_ending_1", "c5_ending_2", "c5_ending_3", "teaser_5"],
	["c6_prologue_1", "c6_prologue_2", "c6_ending_1", "c6_ending_2", "c6_ending_3", "c6_ending_4"],
]
static var _textures: Dictionary = {}
static var _cells: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := ROOT + id + ".png"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id] as Texture2D

static func cell(id: String, column: int, row: int, columns: int = 4, rows: int = 4) -> Texture2D:
	var key := "%s/%d/%d/%d/%d" % [id, column, row, columns, rows]
	if not _cells.has(key):
		var sheet := texture(id)
		if sheet == null:
			return null
		var dim := sheet.get_size() / Vector2(columns, rows)
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		# Fractional grid dimensions are intentional: generated PNG sizes need not divide evenly.
		tex.region = Rect2(Vector2(column, row) * dim + Vector2.ONE, dim - Vector2.ONE * 2)
		if id == "bosses_avalon":
			# This atlas has uneven authored row gutters. Exclude the next character's plume.
			var cuts: Array[float] = [0.0, 0.235, 0.47, 0.715, 1.0]
			tex.region.position.y = sheet.get_height() * cuts[row] + 1
			tex.region.size.y = sheet.get_height() * (cuts[row + 1] - cuts[row]) - 2
		tex.filter_clip = true
		_cells[key] = tex
	return _cells[key] as Texture2D

static func actor(code: String, pose: int = 0) -> Texture2D:
	if code == "camp_goldie" or code == "scarecrow_archer":
		return cell("extra_cast", clampi(pose, 0, 3), 1 if code == "camp_goldie" else 0, 4, 2)
	if code.begins_with("fx:"):
		var i: int = FX.get(code.trim_prefix("fx:"), 0)
		return cell("fx_sheet", i % 4, i / 4)
	if code == "goldie":
		return cell("hero_sheet", pose % 4, pose / 4, 4, 2)
	if not CAST.has(code):
		return null
	var entry: Array = CAST[code]
	return cell(entry[0], clampi(pose, 0, 3), entry[1])

static func world(chapter: int, level: int) -> Texture2D:
	return cell("chapter_%d" % clampi(chapter, 1, 6), level % 3, level / 3, 3, 2)

static func ui_icon(id: String) -> Texture2D:
	var normalized := id.replace("star_big_", "star_").replace("star_small_", "star_")
	if not UI.has(normalized):
		return null
	var i: int = UI[normalized]
	return cell("ui_icons", i % 4, i / 4)

static func world_id(id: String) -> Vector2i:
	for c in WORLDS.size():
		var i: int = WORLDS[c].find(id)
		if i >= 0:
			return Vector2i(c + 1, i)
	return Vector2i.ZERO

static func story(id: String) -> Texture2D:
	for c in STORY.size():
		var index: int = STORY[c].find(id)
		if index >= 0:
			return cell("story_%d" % (c + 1), index % 4, index / 4, 4, 2)
	return null

static func actor_id(frames: SpriteFrames) -> String:
	if frames == null:
		return ""
	var path := frames.resource_path
	if path.is_empty():
		var names := frames.get_animation_names()
		if not names.is_empty() and frames.get_frame_count(names[0]) > 0:
			var tex := frames.get_frame_texture(names[0], 0) as AtlasTexture
			if tex != null and tex.atlas != null:
				path = tex.atlas.resource_path
	if path.contains("camp_goldie_tail"):
		return "hide_tail"
	if path.contains("camp_goldie"):
		return "camp_goldie"
	if path.begins_with("res://assets/sprites/"):
		return path.trim_prefix("res://assets/sprites/").get_slice("/", 0)
	if path.begins_with("res://assets/fx/"):
		var code := path.trim_prefix("res://assets/fx/").get_slice("/", 0)
		if FX.has(code):
			return "fx:" + code
	return ""

static func pose(code: String, anim: StringName, frame: int) -> int:
	if code == "goldie":
		if anim in [&"down", &"sleep", &"rest", &"blink"]:
			return 7
		if anim in [&"victory", &"happy", &"celebrate"]:
			return 6
		if anim == &"run":
			return 2 + frame % 2
		if anim in [&"attack", &"ultimate"]:
			return 4 + mini(1, frame)
		return frame % 2
	if anim == &"run" or anim == &"dash":
		return 1 + frame % 2
	if anim in [&"attack", &"guard", &"slam", &"cast", &"play", &"throw", &"breath", &"roar", &"slash", &"heal", &"zap", &"ink", &"summon", &"open"]:
		return 3
	return 0
