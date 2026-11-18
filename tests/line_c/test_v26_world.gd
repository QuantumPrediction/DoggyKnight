extends TestCase
## v2.6 C 世界(DEV_PLAN 第 19 節 CW1 至 CW6):新背景的規格、標題的選章、依章的失敗提示與結算文字、新音樂。

const NEW_BACKGROUNDS: Array[String] = ["castle_town", "castle_courtyard", "royal_library", "castle_wall",
		"magic_garden", "green_chapel", "misty_lake", "fairy_forest", "stone_circle", "crystal_cave",
		"morgana_tower", "tower_top"]
const BG_ORIGIN: Vector2 = Vector2(-62, -88)

var _nodes: Array[Node] = []
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {"chapter": GameState.chapter, "chapters_cleared": GameState.chapters_cleared,
			"chapter_cleared": GameState.chapter_cleared, "difficulty": GameState.difficulty, "mode": GameState.mode}


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for k: String in _saved:
		GameState.set(k, _saved[k])


func _image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _palette() -> Dictionary:
	var img := _image("res://assets/palette.png")
	var colors := {}
	for x in range(0, img.get_width(), 8):
		colors[img.get_pixel(x, 0).to_html(false)] = true
	return colors


func _title(cleared: int, legacy: bool = false) -> Control:
	GameState.chapters_cleared = 0 if legacy else cleared
	GameState.chapter_cleared = cleared >= 1
	var t := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	add_child(t)
	_nodes.append(t)
	t.call(&"setup", false)
	return t


# --------------------------------------------------------------------------
# CW2 背景
# --------------------------------------------------------------------------

func test_new_backgrounds_follow_the_scene_rules() -> void:
	var pal := _palette()
	var need := Rect2(-10, -60, 200, 440)
	for bg in NEW_BACKGROUNDS:
		var node := (load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate() as Node2D
		var image := node.get_node_or_null(^"Image") as Sprite2D
		assert_not_null(image, "%s 有烘焙好的背景圖" % bg)
		if image != null:
			assert_true(Rect2(image.position, image.texture.get_size()).encloses(need), "%s 蓋滿延伸畫面" % bg)
		var fg := node.get_node_or_null(^"Foreground") as Node2D
		assert_true(fg != null and fg.z_index >= 50 and not fg.z_as_relative, "%s 有最上層的前景" % bg)
		var shadows := node.get_node_or_null(^"Shadows")
		assert_true(shadows != null and shadows.get_script() != null, "%s 有角色投影" % bg)
		var particles := 0
		var animated := 0
		for c in node.find_children("*", "", true, false):
			if c is CPUParticles2D:
				particles += (c as CPUParticles2D).amount
			elif c is GPUParticles2D or c is Light2D:
				assert_true(false, "%s 不用 GPU 粒子或 Light2D(%s)" % [bg, c.name])
			elif c is AnimatedSprite2D:
				animated += 1
			elif c is CanvasModulate:
				var m := (c as CanvasModulate).color
				assert_true(m.r * 0.3 + m.g * 0.59 + m.b * 0.11 >= 0.85, "%s 的氣氛色不會太暗" % bg)
		assert_true(particles <= 100, "%s 的環境粒子不超過 100 個(%d)" % [bg, particles])
		assert_true(animated >= 3, "%s 有會動的細節(%d)" % [bg, animated])
		node.free()
		# 背景圖只用調色盤;前景不蓋住戰鬥區
		var img := _image("res://assets/backgrounds/%s.png" % bg)
		var bad := {}
		for y in range(0, img.get_height(), 2):
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and not pal.has(c.to_html(false)):
					bad[c.to_html(false)] = true
		assert_true(bad.is_empty(), "%s 只用調色盤:%s" % [bg, bad.keys().slice(0, 4)])
		var fg_img := _image("res://assets/backgrounds/%s_fg.png" % bg)
		var arena := Rect2(Layout.ARENA_RECT.position - Vector2(2, 36), Layout.ARENA_RECT.size + Vector2(4, 44))
		var covered := 0
		for y in range(int(arena.position.y), int(arena.end.y)):
			for x in range(int(arena.position.x), int(arena.end.x)):
				var p := Vector2(x, y) - BG_ORIGIN
				if fg_img.get_pixel(int(p.x), int(p.y)).a > 0.0:
					covered += 1
		assert_eq(covered, 0, "%s 的前景不蓋住戰鬥區" % bg)


func test_arena_floors_are_calm() -> void:
	# 戰鬥區的地面:最多的兩個顏色佔八成以上(安靜,角色與預警先被看到)
	for bg in NEW_BACKGROUNDS + ["bridge"]:
		var img := _image("res://assets/backgrounds/%s.png" % bg)
		var counts := {}
		var total := 0
		for y in range(Layout.ARENA_RECT.position.y + 12, Layout.ARENA_RECT.end.y - 12, 2):
			for x in range(Layout.ARENA_RECT.position.x + 12, Layout.ARENA_RECT.end.x - 12, 2):
				var p := Vector2(x, y) - BG_ORIGIN
				var key := img.get_pixel(int(p.x), int(p.y)).to_html(false)
				counts[key] = int(counts.get(key, 0)) + 1
				total += 1
		var values: Array = counts.values()
		values.sort()
		values.reverse()
		var top2: int = values[0] + (values[1] if values.size() > 1 else 0)
		assert_true(float(top2) / total >= 0.8, "%s 的戰鬥區地面夠安靜(前兩色佔 %.0f%%)" % [bg, 100.0 * top2 / total])


# --------------------------------------------------------------------------
# CW3 標題與選章
# --------------------------------------------------------------------------

func test_chapter_select_hidden_before_clearing() -> void:
	var t := _title(0)
	assert_false((t.get("chapter_select") as Control).visible, "還沒打完第一章:沒有選章")
	var seen: Array[int] = []
	t.connect("new_game_pressed", func() -> void: seen.append(GameState.chapter))
	GameState.chapter = 3
	(t.get("new_game_button") as Button).pressed.emit()
	assert_eq(seen, [1] as Array[int], "沒有選章時一律第一章")


func test_chapter_select_unlocks_up_to_the_next_chapter() -> void:
	var t := _title(1)
	assert_true((t.get("chapter_select") as Control).visible, "打完第一章:出現選章")
	assert_eq(t.get("selected_chapter"), 2, "預設選最高已開啟的章")
	assert_eq((t.get("chapter_label") as Label).text, tr("CHAPTER_2"))
	t.call(&"select_chapter", 3)
	assert_true(t.call(&"is_chapter_locked", 3), "第三章還沒開啟")
	assert_true((t.get("chapter_lock") as Control).visible, "未開啟的章顯示鎖頭")
	assert_true((t.get("new_game_button") as Button).disabled, "未開啟的章不能開始")
	t.call(&"select_chapter", 1)
	assert_false((t.get("chapter_lock") as Control).visible)
	assert_false((t.get("new_game_button") as Button).disabled)
	assert_true((t.get("prev_chapter_button") as Button).disabled, "第一章已經是最前面")


func test_new_game_sets_the_chapter_before_emitting() -> void:
	var t := _title(2)
	t.call(&"select_chapter", 3)
	assert_false(t.call(&"is_chapter_locked", 3), "打完第二章:第三章開啟")
	var seen: Array[int] = []
	t.connect("new_game_pressed", func() -> void: seen.append(GameState.chapter))
	(t.get("new_game_button") as Button).pressed.emit()
	assert_true(t.call(&"is_difficulty_open"), "通關後先選難度")
	(t.get("normal_button") as Button).pressed.emit()
	assert_eq(seen, [3] as Array[int], "發 new_game_pressed 時 GameState.chapter 已是 3")


func test_legacy_save_counts_as_chapter_one_cleared() -> void:
	var t := _title(1, true)
	assert_true((t.get("chapter_select") as Control).visible, "舊存檔(只有 chapter_cleared)也能選第二章")
	assert_eq(t.get("selected_chapter"), 2)


func test_title_backdrop_follows_the_highest_unlocked_chapter() -> void:
	var textures: Array[Texture2D] = []
	for cleared in [0, 1, 2]:
		var t := _title(cleared)
		assert_eq(t.get("backdrop_chapter"), mini(cleared + 1, GameState.CHAPTER_COUNT))
		textures.append((t.get_node(^"Backdrop") as TextureRect).texture)
		assert_eq((t.get_node(^"SwordGlint") as CanvasItem).visible, cleared == 0, "石中劍閃光只在第一章的背景")
	assert_ne(textures[0], textures[1], "第二章換成城堡")
	assert_ne(textures[1], textures[2], "第三章換成湖上高塔")


func test_chapter_select_fits_small_screen_with_notch() -> void:
	SafeArea.simulate_notch = true
	var t := _title(2)
	await wait_frames(2)
	var safe := SafeArea.get_safe_rect()
	for name in ["prev_chapter_button", "next_chapter_button"]:
		var b: Button = t.get(name)
		assert_true(b.size.x >= UiKit.MIN_TOUCH and b.size.y >= UiKit.MIN_TOUCH, "%s 夠大" % name)
		assert_true(safe.encloses(Rect2(b.global_position, b.size)), "%s 在安全區內" % name)
	var row := t.get("chapter_select") as Control
	var buttons := Rect2((t.get("continue_button") as Control).global_position, Vector2.ONE)
	assert_true(row.global_position.y + row.size.y <= buttons.position.y or not (t.get("continue_button") as Control).visible,
			"選章列在按鈕上方,不重疊")
	SafeArea.simulate_notch = false


# --------------------------------------------------------------------------
# CW6 失敗提示與結算文字
# --------------------------------------------------------------------------

func test_failure_tips_follow_the_chapter() -> void:
	var failure: GDScript = load("res://ui/screens/failure.gd")
	var one: Array = failure.call(&"tips_for_chapter", 1)
	var two: Array = failure.call(&"tips_for_chapter", 2)
	var three: Array = failure.call(&"tips_for_chapter", 3)
	assert_eq(one, [1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(two, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13], "第二章:1 至 10 與 13")
	assert_eq(three.size(), 14, "第三章:全部 14 句")
	for n: int in three:
		assert_ne(tr("STORY_TIP_%02d" % n), "STORY_TIP_%02d" % n)
	GameState.chapter = 2
	for i in 40:
		var k: int = failure.call(&"_pick_tip")
		assert_true(two.has(k), "第二章不會抽到 %d" % k)


func test_results_name_the_chapter() -> void:
	var r := (load("res://ui/screens/results.tscn") as PackedScene).instantiate() as Control
	add_child(r)
	_nodes.append(r)
	r.call(&"setup", {"level_id": "2-6", "level_name": "LEVEL_2_6", "time_sec": 60.0, "kills": 5, "is_final": true,
			"level_index": 5, "level_count": 6})
	assert_eq((r.get("title_label") as Label).text, tr("UI_CHAPTER_END") % tr("UI_CHAPTER_SHORT_2"))
	assert_eq((r.get("progress_label") as Label).text, tr("UI_CHAPTER_PROGRESS_N") % [tr("UI_CHAPTER_SHORT_2"), 6, 6])
	assert_false((r.get("title_label") as Label).text.contains(tr("UI_CHAPTER_SHORT_1")), "不寫死第一章")
	r.call(&"setup", {"level_id": "3-6", "level_name": "LEVEL_3_6", "time_sec": 60.0, "kills": 5, "is_final": true,
			"game_complete": false})
	assert_eq((r.get("title_label") as Label).text, tr("UI_CHAPTER_END") % tr("UI_CHAPTER_SHORT_3"),
			"v2.7:打完第三章是「第三章 完」,不是全劇終")
	GameState.chapter = 3
	r.call(&"setup", {"level_name": "LEVEL_3_2", "time_sec": 60.0, "kills": 5, "level_index": 1, "level_count": 6})
	assert_eq((r.get("progress_label") as Label).text, tr("UI_CHAPTER_PROGRESS_N") % [tr("UI_CHAPTER_SHORT_3"), 2, 6],
			"沒有 level_id 時用 GameState.chapter")


# --------------------------------------------------------------------------
# CW5 音樂
# --------------------------------------------------------------------------

func test_chapter_music_loops() -> void:
	for id: StringName in [&"field_2", &"boss_2", &"field_3", &"boss_3"]:
		assert_true(Music.has_track(id), "%s 有音樂檔" % id)
		var s := load("res://assets/music/%s.wav" % id) as AudioStreamWAV
		if s == null:
			continue
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s 無縫循環" % id)
		assert_eq(s.format, AudioStreamWAV.FORMAT_QOA, "%s 用 QOA" % id)
		assert_true(s.get_length() >= 20.0, "%s 夠長" % id)
