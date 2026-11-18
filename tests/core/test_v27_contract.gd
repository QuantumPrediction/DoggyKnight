extends TestCase
## v2.7 六章合約(DEV_PLAN 4.14、docs/STORY.md 第 14 至 18 節):新角色圖、背景、頭像、插畫、投射物、章數常數。
## 佔位版由整合工作階段放好;C 線原地替換正式美術後,這個測試必須仍然通過。

## 代號:[必要動畫, 最小格子, 最大格子]
const SPRITES: Dictionary = {
	"crab": [[&"idle", &"run", &"attack", &"hurt", &"guard"], 16, 32],
	"jellyfish": [[&"idle", &"run", &"attack", &"hurt", &"zap"], 16, 32],
	"kraken": [[&"idle", &"run", &"attack", &"hurt", &"slam", &"ink", &"summon", &"down"], 48, 64],
	"snowman": [[&"idle", &"run", &"attack", &"hurt", &"throw"], 16, 32],
	"salamander": [[&"idle", &"run", &"attack", &"hurt", &"dash"], 16, 32],
	"red_dragon": [[&"idle", &"run", &"attack", &"hurt", &"breath", &"roar", &"sulk"], 48, 64],
	"white_dragon": [[&"idle", &"run", &"attack", &"hurt", &"breath", &"roar", &"sulk"], 48, 64],
	"shadow_knight": [[&"idle", &"run", &"attack", &"hurt", &"guard", &"down"], 24, 40],
	"lantern_wisp": [[&"idle", &"run", &"attack", &"hurt", &"heal"], 12, 24],
	"mordred": [[&"idle", &"run", &"attack", &"hurt", &"dash", &"slash", &"guard", &"summon", &"down"], 40, 64],
	"tristan": [[&"idle", &"run", &"attack", &"hurt", &"play"], 24, 32],
	"gawain": [[&"idle", &"run", &"attack", &"hurt", &"slam"], 24, 40],
}
const BACKGROUNDS: Array[String] = ["golden_beach", "sea_cliffs", "pirate_ship", "coral_reef", "sunken_city",
		"sunken_palace", "snowfield", "ice_cave", "hot_springs", "avalanche_pass", "volcano", "dragon_nest",
		"camlann_field", "shadow_camp", "occupied_town", "throne_hall", "avalon_gate", "avalon_hill"]
const PORTRAITS: Dictionary = {
	"tristan": ["normal", "happy", "serious", "surprised"],
	"gawain": ["normal", "happy", "serious"],
	"kraken": ["normal"],
	"red_dragon": ["normal"],
	"white_dragon": ["normal"],
	"mordred": ["normal", "smirk", "angry", "sad"],
}
const ILLUSTRATIONS: Array[String] = ["teaser_3", "c4_prologue_1", "c4_prologue_2", "c4_ending_1", "c4_ending_2",
		"c4_ending_3", "teaser_4", "c5_prologue_1", "c5_prologue_2", "c5_ending_1", "c5_ending_2", "c5_ending_3",
		"teaser_5", "c6_prologue_1", "c6_prologue_2", "c6_ending_1", "c6_ending_2", "c6_ending_3", "c6_ending_4"]
const PROJECTILES: Array[String] = ["bubble", "ink_blob", "music_note", "snowball", "fireball", "ice_shard",
		"shadow_slash", "tentacle"]


func test_chapter_count_is_six() -> void:
	assert_eq(GameState.CHAPTER_COUNT, 6, "GameState.CHAPTER_COUNT")
	for n in range(1, GameState.CHAPTER_COUNT + 1):
		assert_ne(tr("CHAPTER_%d" % n), "CHAPTER_%d" % n, "第 %d 章有章名" % n)


func test_new_sprites_have_required_animations_and_size() -> void:
	for id: String in SPRITES:
		var path := "res://assets/sprites/%s/%s_frames.tres" % [id, id]
		var frames := load(path) as SpriteFrames
		assert_not_null(frames, path)
		if frames == null:
			continue
		for anim: StringName in SPRITES[id][0]:
			assert_true(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "%s 有動畫 %s" % [id, anim])
		var size := frames.get_frame_texture(&"idle", 0).get_size()
		assert_true(size.x >= SPRITES[id][1] and size.x <= SPRITES[id][2] and size.y >= SPRITES[id][1]
				and size.y <= SPRITES[id][2], "%s 的格子 %s 在 %d 至 %d 之間" % [id, size, SPRITES[id][1], SPRITES[id][2]])


func test_new_backgrounds_are_node2d_scenes() -> void:
	for bg in BACKGROUNDS:
		var scene := load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene
		assert_not_null(scene, bg)
		if scene != null:
			var node := scene.instantiate()
			assert_true(node is Node2D, "%s 的根節點是 Node2D" % bg)
			node.free()


func test_new_portraits_and_illustrations() -> void:
	for speaker: String in PORTRAITS:
		assert_ne(tr("SPEAKER_" + speaker.to_upper()), "SPEAKER_" + speaker.to_upper(), "%s 有名牌" % speaker)
		for expression: String in PORTRAITS[speaker]:
			var path := "res://assets/portraits/%s/%s.png" % [speaker, expression]
			assert_true(ResourceLoader.exists(path), path)
			if ResourceLoader.exists(path):
				assert_eq((load(path) as Texture2D).get_size(), Vector2(48, 48), "%s 是 48×48" % path)
	for id in ILLUSTRATIONS:
		var path := "res://assets/story/%s.png" % id
		assert_true(ResourceLoader.exists(path), path)
		if ResourceLoader.exists(path):
			assert_eq((load(path) as Texture2D).get_size(), Vector2(160, 120), "%s 是 160×120" % path)


func test_projectiles_and_tips() -> void:
	for fx_name in PROJECTILES:
		var frames := load("res://assets/fx/%s/%s_frames.tres" % [fx_name, fx_name]) as SpriteFrames
		assert_not_null(frames, fx_name)
		if frames != null:
			assert_true(frames.has_animation(&"default") and frames.get_frame_count(&"default") > 0, "%s 的 default" % fx_name)
	for i in range(15, 21):
		assert_ne(tr("STORY_TIP_%02d" % i), "STORY_TIP_%02d" % i, "失敗提示 %d" % i)
