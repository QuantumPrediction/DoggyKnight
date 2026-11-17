extends TestCase
## v2.6 三章合約(DEV_PLAN 4.13、docs/STORY.md 第 9 至 13 節):新角色圖、背景、頭像、插畫、GameState 與 LevelData 新欄位。
## 佔位版由整合工作階段放好;C 線原地替換正式美術後,這個測試必須仍然通過。

## 代號:[必要動畫, 最小格子, 最大格子]
const SPRITES: Dictionary = {
	"gargoyle": [[&"idle", &"run", &"attack", &"hurt", &"swoop", &"stone"], 24, 40],
	"spellbook": [[&"idle", &"run", &"attack", &"hurt", &"cast"], 16, 32],
	"foxfire": [[&"idle", &"run", &"attack", &"hurt", &"burst"], 12, 24],
	"shadow_wolf": [[&"idle", &"run", &"attack", &"hurt", &"dash", &"down"], 24, 40],
	"green_knight": [[&"idle", &"run", &"attack", &"hurt", &"whip", &"summon", &"hat_off", &"down"], 48, 64],
	"morgana": [[&"idle", &"run", &"attack", &"hurt", &"cast", &"teleport", &"down"], 48, 64],
	"lancelot": [[&"idle", &"run", &"attack", &"hurt", &"dash"], 24, 32],
	"lady_lake": [[&"idle", &"run", &"cast"], 24, 32],
}
const BACKGROUNDS: Array[String] = ["castle_town", "castle_courtyard", "royal_library", "castle_wall",
		"magic_garden", "green_chapel", "misty_lake", "fairy_forest", "stone_circle", "crystal_cave",
		"morgana_tower", "tower_top"]
const PORTRAITS: Dictionary = {
	"lancelot": ["normal", "happy", "serious", "surprised"],
	"gargoyle": ["normal"],
	"green_knight": ["normal"],
	"lady_lake": ["normal", "smile", "worried"],
	"morgana_true": ["normal", "angry", "sad", "smile"],
}
const ILLUSTRATIONS: Array[String] = ["c2_prologue_1", "c2_prologue_2", "c2_ending_1", "c2_ending_2",
		"c2_ending_3", "teaser_2", "c3_prologue_1", "c3_prologue_2", "c3_ending_1", "c3_ending_2", "c3_ending_3"]


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


func test_chapter_fields() -> void:
	assert_true("chapters_cleared" in GameState, "GameState.chapters_cleared")
	assert_true("music" in LevelData.new(), "LevelData.music")
	for i in range(9, 15):
		assert_ne(tr("STORY_TIP_%02d" % i), "STORY_TIP_%02d" % i, "失敗提示 %d" % i)
