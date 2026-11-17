extends "res://tests/line_b/flow_test_base.gd"
## BS1、BS7:data/story/*.tres 與 docs/STORY.md 第 5 節逐句一致;六關與第一章接上正確的段落。
## v2.6(BV2):第 12 節的第二、三章段落也一樣逐句核對;十八關與三章都接上自己那一章的段落。
## STORY.md 改了之後,用 tests/line_b/tools/build_story.tscn 重新產生資料檔。

const StoryDoc := preload("res://tests/line_b/story_doc.gd")
const STORY_DIR: String = "res://data/story/"
## docs/STORY.md 第 5 節(第一章)的段落(依次序)。
const CHAPTER_1_IDS: Array[String] = ["prologue", "l1_before", "l1_after", "l2_before", "l2_after", "camp1",
		"l3_before", "l3_after", "l4_before", "l4_after", "camp2", "l5_before", "l5_after", "l6_before",
		"l6_after", "teaser"]
const SPEAKERS: Array[String] = ["goldie", "bulldog", "merlin", "black_knight", "morgana", "scarecrow_captain",
		"crow", "narrator",
		# v2.6(docs/STORY.md 第 10 節)
		"lancelot", "gargoyle", "green_knight", "lady_lake", "morgana_true"]
const CHAPTER_COUNT: int = 3


## 第 n 章的段落 id(依 docs/STORY.md 的次序):第一章是第 5 節;第 N 章(N ≥ 2)是第 12 節的
## cN_prologue、cNl1_before、cNl1_after、cNl2_before、cNl2_after、cN_camp1、……、cNl6_after、cN_teaser。
static func chapter_script_ids(n: int) -> Array[String]:
	if n == 1:
		return CHAPTER_1_IDS.duplicate()
	var ids: Array[String] = ["c%d_prologue" % n]
	for m in range(1, 7):
		ids.append("c%dl%d_before" % [n, m])
		ids.append("c%dl%d_after" % [n, m])
		if m == 2 or m == 4:
			ids.append("c%d_camp%d" % [n, 1 if m == 2 else 2])
	ids.append("c%d_teaser" % n)
	return ids


static func all_script_ids() -> Array[String]:
	var ids: Array[String] = []
	for n in range(1, CHAPTER_COUNT + 1):
		ids.append_array(chapter_script_ids(n))
	return ids


## 第 n 章第 m 關開打前 / 過關後的段落 id。
static func level_script_id(n: int, m: int, after: bool) -> String:
	var part := "after" if after else "before"
	return "l%d_%s" % [m, part] if n == 1 else "c%dl%d_%s" % [n, m, part]


func _load_script(id: String) -> DialogueScript:
	var path := STORY_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as DialogueScript


func test_story_md_has_the_expected_scripts() -> void:
	var doc := StoryDoc.parse()
	var ids: Array = doc.keys()
	assert_eq(ids, all_script_ids() as Array, "STORY.md 第 5 節與第 12 節的段落與次序(三章)")
	assert_eq(all_script_ids().size(), 16 * CHAPTER_COUNT, "每章 16 段")
	var per_chapter: Array[int] = []
	for n in range(1, CHAPTER_COUNT + 1):
		var total := 0
		for id in chapter_script_ids(n):
			total += (doc.get(id, []) as Array).size()
		per_chapter.append(total)
	assert_true(per_chapter[0] >= 60, "第一章至少 60 句(實際 %d)" % per_chapter[0])
	for n in range(2, CHAPTER_COUNT + 1):
		assert_true(per_chapter[n - 1] >= 50, "第 %d 章至少 50 句(實際 %d)" % [n, per_chapter[n - 1]])


func test_every_script_matches_story_md_line_by_line() -> void:
	var doc := StoryDoc.parse()
	for id: String in doc:
		var script := _load_script(id)
		assert_not_null(script, "data/story/%s.tres 存在" % id)
		if script == null:
			continue
		assert_eq(script.id, StringName(id), "%s 的 id" % id)
		assert_true(script.skippable, "%s 可以略過" % id)
		var expected: Array = doc[id]
		assert_eq(script.lines.size(), expected.size(), "%s 的句數" % id)
		for i in mini(script.lines.size(), expected.size()):
			var line := script.lines[i]
			var want: Dictionary = expected[i]
			var where := "%s 第 %d 句" % [id, i + 1]
			assert_not_null(line, where)
			if line == null:
				continue
			assert_eq(line.text_key, want["key"], where + " 的鍵")
			assert_eq(line.speaker, StringName(want["speaker"]), where + " 的說話者")
			assert_eq(line.expression, StringName(want["expression"]), where + " 的表情")
			var picture := line.illustration.resource_path if line.illustration != null else ""
			assert_eq(picture, want["illustration_path"], where + " 的插畫(空白 = 沿用上一句)")


func test_lines_have_text_portraits_and_pictures() -> void:
	for id in all_script_ids():
		var script := _load_script(id)
		if script == null:
			continue
		for i in script.lines.size():
			var line := script.lines[i]
			var where := "%s 第 %d 句" % [id, i + 1]
			assert_true(SPEAKERS.has(String(line.speaker)), where + " 的說話者 %s" % line.speaker)
			assert_ne(tr(line.text_key), line.text_key, where + " 有文字(i18n/story.csv)")
			if line.speaker == &"narrator":
				assert_not_null(line.illustration, where + ":旁白一定有插畫")
				assert_eq(line.expression, &"", where + ":旁白沒有頭像")
			else:
				var portrait := "res://assets/portraits/%s/%s.png" % [line.speaker, line.expression]
				assert_true(ResourceLoader.exists(portrait), where + " 的頭像 " + portrait)


func test_levels_and_chapter_use_the_right_scripts() -> void:
	for n in range(1, CHAPTER_COUNT + 1):
		var chapter := load(CHAPTER_PATH % n) as ChapterData
		assert_eq(chapter.level_count(), 6, "第 %d 章六關" % n)
		for m in range(1, 7):
			var level := chapter.get_level(m - 1)
			var before := level_script_id(n, m, false)
			var after := level_script_id(n, m, true)
			assert_not_null(level.story_before, "%s 有開打前的對白" % level.id)
			assert_not_null(level.story_after, "%s 有過關後的對白" % level.id)
			if level.story_before != null:
				assert_eq(level.story_before.id, StringName(before), "%s 的 story_before" % level.id)
				assert_eq(level.story_before.resource_path, STORY_DIR + before + ".tres")
			if level.story_after != null:
				assert_eq(level.story_after.id, StringName(after), "%s 的 story_after" % level.id)
				assert_eq(level.story_after.resource_path, STORY_DIR + after + ".tres")
		var prologue := "prologue" if n == 1 else "c%d_prologue" % n
		var teaser := "teaser" if n == 1 else "c%d_teaser" % n
		assert_not_null(chapter.prologue, "第 %d 章有開場繪本" % n)
		assert_not_null(chapter.teaser, "第 %d 章有預告" % n)
		if chapter.prologue != null:
			assert_eq(chapter.prologue.id, StringName(prologue))
		if chapter.teaser != null:
			assert_eq(chapter.teaser.id, StringName(teaser))
		# D 線的營地讀這些檔案(DEV_PLAN 4.11、4.13)
		for camp in [1, 2]:
			var id := "camp%d" % camp if n == 1 else "c%d_camp%d" % [n, camp]
			var script := _load_script(id)
			assert_not_null(script, "%s.tres 存在" % id)
			if script != null:
				assert_eq(script.id, StringName(id))


func test_real_dialogue_box_has_the_contract() -> void:
	var scene := FlowParts.optional_scene(FlowParts.DIALOGUE)
	if scene == null:
		return          # C 線的對白框不存在:流程略過全部故事
	var node := scene.instantiate()
	assert_true(node is CanvasLayer, "對白框的根節點是 CanvasLayer")
	for method: StringName in [&"play", &"advance", &"skip", &"is_active"]:
		assert_true(node.has_method(method), "對白框有 %s()" % method)
	node.free()


func test_stand_in_dialogue_box_has_the_same_contract() -> void:
	var box := (FlowParts.scene_for(FlowParts.DIALOGUE, true)).instantiate() as CanvasLayer
	add_child(box)
	assert_eq(box.layer, 40)
	assert_eq(box.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_true(box.is_in_group(&"dialogue_box"))
	var started := watch_signal(EventBus.dialogue_started)
	var ended := watch_signal(EventBus.dialogue_finished)
	var done := [false]
	var run := func() -> void:
		await box.play(_load_script("l2_after"))
		done[0] = true
	run.call()
	assert_true(box.is_active())
	assert_eq(started.last_args(), [&"l2_after"])
	box.advance()
	assert_false(done[0], "兩句只點了一下")
	box.advance()
	assert_true(done[0])
	assert_false(box.is_active())
	assert_eq(ended.last_args(), [&"l2_after"])
	assert_true(GameState.story_seen.has(&"l2_after"), "記進 story_seen")
	box.queue_free()
