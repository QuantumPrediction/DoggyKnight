extends TestCase
## 故事合約(DEV_PLAN 4.11、docs/STORY.md):文字鍵、頭像、插畫、新角色圖、對白框。

const STORY_DOC := "res://docs/STORY.md"
const PORTRAITS: Dictionary = {
	"goldie": ["normal", "happy", "surprised", "serious", "tired"],
	"bulldog": ["normal", "happy", "serious"],
	"merlin": ["normal", "surprised", "proud", "worried"],
	"black_knight": ["normal"],
	"morgana": ["smirk"],
	"scarecrow_captain": ["angry"],
	"crow": ["normal"],
}
const ILLUSTRATIONS: Array[String] = ["prologue_1", "prologue_2", "prologue_3", "prologue_4",
		"ending_1", "ending_2", "ending_3", "teaser_1"]
## 代號:[必要動畫, 最小格子, 最大格子]
const NEW_SPRITES: Dictionary = {
	"scarecrow_archer": [[&"idle", &"run", &"attack", &"hurt", &"aim"], 16, 24],
	"armored_husk": [[&"idle", &"run", &"attack", &"hurt", &"dash", &"down"], 16, 24],
	"scarecrow_captain": [[&"idle", &"run", &"attack", &"hurt", &"throw", &"rally", &"down"], 24, 40],
	"merlin": [[&"idle", &"run", &"cast"], 16, 24],
}
const PROJECTILES: Array[String] = ["arrow", "sword_wave", "pitchfork"]

var _box: Node


func after_each() -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	GameState.story_seen = {}


## docs/STORY.md 的對白表格裡出現的每個鍵,都要在 i18n/story.csv 有文字。
func test_every_story_key_in_the_script_has_text() -> void:
	var file := FileAccess.open(STORY_DOC, FileAccess.READ)
	assert_not_null(file, "docs/STORY.md 存在")
	if file == null:
		return
	var regex := RegEx.create_from_string("\\| (STORY_[A-Z0-9_]+) \\| ([a-z_]+) \\|")
	var count := 0
	for m in regex.search_all(file.get_as_text()):
		count += 1
		var key := m.get_string(1)
		assert_ne(tr(key), key, "%s 有文字" % key)
		var speaker := m.get_string(2)
		if speaker != "narrator":
			assert_ne(tr("SPEAKER_" + speaker.to_upper()), "SPEAKER_" + speaker.to_upper(), "%s 有名牌" % speaker)
	assert_true(count >= 60, "腳本至少 60 句(實際 %d)" % count)
	for i in range(1, 9):
		assert_ne(tr("STORY_TIP_%02d" % i), "STORY_TIP_%02d" % i, "失敗提示 %d" % i)


func test_story_csv_rows_have_exactly_two_columns() -> void:
	var file := FileAccess.open("res://i18n/story.csv", FileAccess.READ)
	var line_no := 0
	while file != null and not file.eof_reached():
		var row := file.get_csv_line()
		line_no += 1
		if row.size() == 1 and row[0].is_empty():
			continue
		assert_eq(row.size(), 2, "story.csv 第 %d 行只有兩欄(文字裡用全形「,」)" % line_no)


func test_portraits_and_illustrations_exist() -> void:
	for speaker: String in PORTRAITS:
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


func test_new_sprites_have_required_animations() -> void:
	for code: String in NEW_SPRITES:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		assert_not_null(frames, code)
		if frames == null:
			continue
		for anim: StringName in NEW_SPRITES[code][0]:
			assert_true(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "%s.%s" % [code, anim])
		var size := frames.get_frame_texture(&"idle", 0).get_size()
		assert_true(size.x >= NEW_SPRITES[code][1] and size.x <= NEW_SPRITES[code][2], "%s 格子 %s" % [code, size])
	for fx_name in PROJECTILES:
		var frames := load("res://assets/fx/%s/%s_frames.tres" % [fx_name, fx_name]) as SpriteFrames
		assert_true(frames != null and frames.has_animation(&"default"), fx_name)


func _script(id: StringName, count: int) -> DialogueScript:
	var script := DialogueScript.new()
	script.id = id
	for i in count:
		var line := DialogueLine.new()
		line.speaker = &"merlin" if i % 2 == 0 else &"goldie"
		line.expression = &"normal"
		line.text_key = "STORY_L1_AFTER_0%d" % (i + 1)
		script.lines.append(line)
	return script


func test_dialogue_box_plays_advances_and_reports() -> void:
	_box = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate()
	assert_true(_box is CanvasLayer, "對白框的根節點是 CanvasLayer")
	add_child(_box)
	var started := watch_signal(EventBus.dialogue_started)
	var ended := watch_signal(EventBus.dialogue_finished)
	var done := [false]
	var run := func() -> void:
		await _box.play(_script(&"test_story", 3))
		done[0] = true
	run.call()
	await wait_frames(1)
	assert_true(_box.is_active())
	assert_eq(started.count, 1)
	assert_eq(started.last_args(), [&"test_story"])
	_box.advance()
	_box.advance()
	assert_false(done[0], "三句只按了兩下,還沒完")
	_box.advance()
	await wait_frames(1)
	assert_true(done[0], "play() 在最後一句之後返回")
	assert_eq(ended.count, 1)
	assert_true(GameState.story_seen.has(&"test_story"), "記進 story_seen")


func test_dialogue_box_skip() -> void:
	_box = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate()
	add_child(_box)
	var ended := watch_signal(EventBus.dialogue_finished)
	var done := [false]
	var run := func() -> void:
		await _box.play(_script(&"skip_me", 5))
		done[0] = true
	run.call()
	await wait_frames(1)
	_box.skip()
	await wait_frames(1)
	assert_true(done[0])
	assert_false(_box.is_active())
	assert_eq(ended.count, 1)
