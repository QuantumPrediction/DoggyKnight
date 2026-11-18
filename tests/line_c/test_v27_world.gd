extends TestCase
## v2.7 C 世界(DEV_PLAN 第 20 節 CW7 至 CW10):18 張新背景的規格、選章到第六章與新的標題背景、
## 依章的失敗提示(1 至 20)、結算的「全劇終」只看 game_complete、六首新音樂。

const NEW_BACKGROUNDS: Array[String] = ["golden_beach", "sea_cliffs", "pirate_ship", "coral_reef", "sunken_city",
		"sunken_palace", "snowfield", "ice_cave", "hot_springs", "avalanche_pass", "volcano", "dragon_nest",
		"camlann_field", "shadow_camp", "occupied_town", "throne_hall", "avalon_gate", "avalon_hill"]
const BG_ORIGIN: Vector2 = Vector2(-62, -88)
const NEW_MUSIC: Array[StringName] = [&"field_4", &"boss_4", &"field_5", &"boss_5", &"field_6", &"boss_6"]

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


func _title(cleared: int) -> Control:
	GameState.chapters_cleared = cleared
	GameState.chapter_cleared = cleared >= 1
	var t := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	add_child(t)
	_nodes.append(t)
	t.call(&"setup", false)
	return t


# --------------------------------------------------------------------------
# CW7 背景
# --------------------------------------------------------------------------

func test_new_backgrounds_follow_the_scene_rules() -> void:
	var pal := _palette()
	var need := Rect2(-10, -60, 200, 440)
	var images := {}
	for bg in NEW_BACKGROUNDS:
		var node := (load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate() as Node2D
		assert_true(node is Node2D, "%s 的根節點是 Node2D" % bg)
		var image := node.get_node_or_null(^"Image") as Sprite2D
		assert_not_null(image, "%s 有烘焙好的背景圖" % bg)
		if image != null:
			assert_true(Rect2(image.position, image.texture.get_size()).encloses(need), "%s 蓋滿延伸畫面" % bg)
			assert_false(images.has(image.texture.resource_path), "%s 用自己的背景圖" % bg)
			images[image.texture.resource_path] = true
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
				assert_true((c as AnimatedSprite2D).sprite_frames.has_animation(&"default"), "%s 的 %s 有動畫" % [bg, c.name])
			elif c is CanvasModulate:
				var m := (c as CanvasModulate).color
				assert_true(m.r * 0.3 + m.g * 0.59 + m.b * 0.11 >= 0.85, "%s 的氣氛色不會太暗" % bg)
		assert_true(particles > 0 and particles <= 100, "%s 的環境粒子 1 至 100 個(%d)" % [bg, particles])
		assert_true(animated >= 3, "%s 有會動的細節(%d)" % [bg, animated])
		node.free()
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
	for bg in NEW_BACKGROUNDS:
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


func test_flying_foes_cast_shadows_on_the_ground() -> void:
	var consts := (load("res://assets/backgrounds/actor_shadows.gd") as GDScript).get_script_constant_map()
	var flyers: PackedStringArray = consts["FLYERS"]
	for code in ["jellyfish", "lantern_wisp"]:
		assert_true(flyers.has("/%s/" % code), "%s 的影子落在地上(會飛)" % code)


# --------------------------------------------------------------------------
# CW8 標題:選章到 CHAPTER_COUNT、第四至六章的背景
# --------------------------------------------------------------------------

func test_chapter_select_reaches_the_last_chapter() -> void:
	var t := _title(GameState.CHAPTER_COUNT - 1)
	assert_eq(t.get("selected_chapter"), GameState.CHAPTER_COUNT, "預設選最高已開啟的章")
	assert_false(t.call(&"is_chapter_locked", GameState.CHAPTER_COUNT), "打完第五章:第六章開啟")
	assert_eq((t.get("chapter_label") as Label).text, tr("CHAPTER_%d" % GameState.CHAPTER_COUNT))
	assert_true((t.get("next_chapter_button") as Button).disabled, "最後一章之後沒有下一章")
	t.call(&"select_chapter", GameState.CHAPTER_COUNT + 3)
	assert_eq(t.get("selected_chapter"), GameState.CHAPTER_COUNT, "選章不會超過 CHAPTER_COUNT")
	var seen: Array[int] = []
	t.connect("new_game_pressed", func() -> void: seen.append(GameState.chapter))
	(t.get("new_game_button") as Button).pressed.emit()
	(t.get("normal_button") as Button).pressed.emit()
	assert_eq(seen, [GameState.CHAPTER_COUNT] as Array[int], "發 new_game_pressed 時 GameState.chapter 已是 6")


func test_locked_chapters_up_to_six() -> void:
	var t := _title(3)
	assert_eq(t.get("selected_chapter"), 4)
	for n in range(5, GameState.CHAPTER_COUNT + 1):
		t.call(&"select_chapter", n)
		assert_true(t.call(&"is_chapter_locked", n), "第 %d 章還沒開啟" % n)
		assert_true((t.get("chapter_lock") as Control).visible)
		assert_true((t.get("new_game_button") as Button).disabled)
	var all_done := _title(GameState.CHAPTER_COUNT)
	assert_eq((all_done.get("_cleared_label") as Label).text, tr("UI_ALL_CHAPTERS_CLEARED"), "六章全破")


func test_title_backdrops_for_chapters_four_to_six() -> void:
	var textures: Array[Texture2D] = []
	for cleared in [2, 3, 4, 5, 6]:
		var t := _title(cleared)
		assert_eq(t.get("backdrop_chapter"), mini(cleared + 1, GameState.CHAPTER_COUNT))
		var tex := (t.get_node(^"Backdrop") as TextureRect).texture
		textures.append(tex)
		assert_eq(tex.get_size(), Vector2(304, 512), "標題背景 304×512")
	for n in range(4, GameState.CHAPTER_COUNT + 1):
		assert_true(ResourceLoader.exists("res://assets/ui/title_bg_%d.png" % n), "第 %d 章的標題背景" % n)
	assert_ne(textures[0], textures[1], "第四章換成海邊")
	assert_ne(textures[1], textures[2], "第五章換成雙龍雪山")
	assert_ne(textures[2], textures[3], "第六章換成阿瓦隆夕陽")
	assert_eq(textures[3], textures[4])


func test_chapter_select_fits_small_screen_with_notch_for_long_names() -> void:
	SafeArea.simulate_notch = true
	var t := _title(GameState.CHAPTER_COUNT)
	var safe := SafeArea.get_safe_rect()
	for n in range(1, GameState.CHAPTER_COUNT + 1):
		t.call(&"select_chapter", n)
		await wait_frames(2)
		var row := t.get("chapter_select") as Control
		assert_true(safe.encloses(Rect2(row.global_position, row.size)), "第 %d 章的選章列在安全區內" % n)
	SafeArea.simulate_notch = false


# --------------------------------------------------------------------------
# CW10 失敗提示與結算
# --------------------------------------------------------------------------

func test_failure_tips_by_chapter_cover_one_to_twenty() -> void:
	var failure: GDScript = load("res://ui/screens/failure.gd")
	var seen := {}
	for chapter in range(1, GameState.CHAPTER_COUNT + 1):
		var tips: Array = failure.call(&"tips_for_chapter", chapter)
		assert_false(tips.is_empty(), "第 %d 章有提示" % chapter)
		for n: int in tips:
			assert_true(n >= 1 and n <= 20)
			assert_ne(tr("STORY_TIP_%02d" % n), "STORY_TIP_%02d" % n, "提示 %d 有文字" % n)
			seen[n] = true
	for n in range(1, 21):
		assert_true(seen.has(n), "提示 %d 至少在一章出現" % n)
	var four: Array = failure.call(&"tips_for_chapter", 4)
	var five: Array = failure.call(&"tips_for_chapter", 5)
	var six: Array = failure.call(&"tips_for_chapter", 6)
	assert_true(four.has(15) and four.has(16) and not four.has(19), "第四章:螃蟹與水母")
	assert_true(five.has(17) and five.has(18) and not five.has(15), "第五章:雪人與火蜥蜴")
	assert_true(six.has(19) and six.has(20) and not six.has(17), "第六章:影子騎士與提燈鬼火")
	GameState.mode = &"story"
	GameState.chapter = 5
	for i in 40:
		var k: int = failure.call(&"_pick_tip")
		assert_true(five.has(k), "第五章不會抽到 %d" % k)


func test_endless_tips_use_the_opened_chapters() -> void:
	var failure: GDScript = load("res://ui/screens/failure.gd")
	GameState.mode = &"endless"
	GameState.chapters_cleared = 4
	var pool: Array = failure.call(&"tip_pool")
	assert_true(pool.has(15) and pool.has(14), "打完第四章:第一至四章的提示")
	assert_false(pool.has(19), "第六章的提示還不會出現")


func test_results_game_end_only_after_the_final_chapter() -> void:
	var r := (load("res://ui/screens/results.tscn") as PackedScene).instantiate() as Control
	add_child(r)
	_nodes.append(r)
	for n in range(3, GameState.CHAPTER_COUNT):
		r.call(&"setup", {"level_id": "%d-6" % n, "level_name": "LEVEL_%d_6" % n, "time_sec": 60.0, "kills": 5,
				"is_final": true, "chapter": n, "game_complete": false, "level_index": 5, "level_count": 6})
		assert_eq((r.get("title_label") as Label).text, tr("UI_CHAPTER_END") % tr("UI_CHAPTER_SHORT_%d" % n),
				"第 %d 章打完是「第 %d 章 完」" % [n, n])
		assert_eq((r.get("progress_label") as Label).text, tr("UI_CHAPTER_PROGRESS_N") % [tr("UI_CHAPTER_SHORT_%d" % n), 6, 6])
	r.call(&"setup", {"level_id": "6-6", "level_name": "LEVEL_6_6", "time_sec": 60.0, "kills": 5, "is_final": true,
			"chapter": 6, "game_complete": true})
	assert_eq((r.get("title_label") as Label).text, tr("UI_GAME_END"), "打完第六章是全劇終")
	r.call(&"setup", {"level_id": "6-6", "level_name": "LEVEL_6_6", "time_sec": 60.0, "kills": 5, "is_final": true})
	assert_eq((r.get("title_label") as Label).text, tr("UI_GAME_END"), "舊資料沒有 game_complete:最後一章最後一關")
	GameState.chapter = 5
	r.call(&"setup", {"level_name": "LEVEL_5_2", "time_sec": 60.0, "kills": 5, "level_index": 1, "level_count": 6})
	assert_eq((r.get("progress_label") as Label).text, tr("UI_CHAPTER_PROGRESS_N") % [tr("UI_CHAPTER_SHORT_5"), 2, 6],
			"沒有 level_id 時用 GameState.chapter(第五章)")


func test_hud_title_card_names_chapters_four_to_six() -> void:
	for n in range(4, GameState.CHAPTER_COUNT + 1):
		assert_ne(tr("CHAPTER_%d" % n), "CHAPTER_%d" % n, "第 %d 章有章名" % n)
		assert_ne(tr("UI_CHAPTER_SHORT_%d" % n), "UI_CHAPTER_SHORT_%d" % n)


# --------------------------------------------------------------------------
# CW9 音樂
# --------------------------------------------------------------------------

func test_chapter_four_to_six_music_loops() -> void:
	for id: StringName in NEW_MUSIC:
		assert_true(Music.has_track(id), "%s 有音樂檔" % id)
		var s := load("res://assets/music/%s.wav" % id) as AudioStreamWAV
		if s == null:
			continue
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s 無縫循環" % id)
		assert_eq(s.format, AudioStreamWAV.FORMAT_QOA, "%s 用 QOA" % id)
		assert_true(s.get_length() >= 20.0, "%s 夠長(%.1f 秒)" % [id, s.get_length()])
