extends TestCase
## v2.7 DW1 至 DW3(DEV_PLAN 4.14、20;docs/STORY.md 第 18 節):第四至六章的營地。
## 誰在營地、點崔斯坦與高文說話、場景依章、小遊戲三個輪流、觸控範圍不重疊。

const CAMP_SCENE := preload("res://game/camp/camp.tscn")
const MAX_CJK: int = 26
const FISH_PATH: String = "res://game/minigames/fish/fish_minigame.tscn"
const WAKE_PATH: String = "res://game/minigames/wake/wake_minigame.tscn"
const SCROLL_PATH: String = "res://game/minigames/scroll/scroll_minigame.tscn"
const PHONES: Array[Vector2i] = [Vector2i(1080, 1920), Vector2i(1080, 2400), Vector2i(1179, 2556), Vector2i(750, 1334)]

var _camp: Camp


func before_each() -> void:
	GameState.reset_run()
	GameState.chapter = 1
	GameState.story_seen = {}
	Haptics.reset_for_tests()


func after_each() -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	await wait_frames(1)
	GameState.chapter = 1
	GameState.reset_run()
	GameState.story_seen = {}


func _enter(chapter: int, level_index: int, changes: Dictionary = {}) -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
		_camp = null
		await wait_frames(1)
	GameState.chapter = chapter
	GameState.level_index = level_index
	_camp = CAMP_SCENE.instantiate() as Camp
	if not changes.is_empty():
		var cfg := (_camp.config as CampConfig).duplicate() as CampConfig
		for key: String in changes:
			cfg.set(key, changes[key])
		_camp.config = cfg
	add_child(_camp)


func _skip_story() -> void:
	_camp.skip_story()
	for i in 60:
		if not _camp.is_story_playing():
			return
		await wait_frames(1)


# --- DW1 對白與人物 ---

func test_story_for_chapters_four_to_six() -> void:
	for chapter in range(4, GameState.CHAPTER_COUNT + 1):
		for camp in [[1, 1], [3, 2]]:
			var started := watch_signal(EventBus.dialogue_started)
			await _enter(chapter, camp[0])
			var id := "c%d_camp%d" % [chapter, camp[1]]
			assert_eq(_camp.story_path(), "res://data/story/%s.tres" % id)
			assert_true(ResourceLoader.exists(_camp.story_path()), "%s 存在" % id)
			assert_true(_camp.is_story_playing(), "%s:進營地就播" % id)
			assert_eq(started.last_args()[0], StringName(id))
			await _skip_story()
			assert_true(_camp.is_menu_visible(), "%s 播完出現選單" % id)


func test_cast_follows_story_section_18() -> void:
	# 章, level_index → 在場的人(其他人都不在)
	var expected := {
		[4, 1]: ["merlin", "bulldog", "tristan"], [4, 3]: ["merlin", "bulldog", "tristan"],
		[5, 1]: ["merlin", "lancelot", "gawain"], [5, 3]: ["merlin", "lancelot", "gawain"],
		[6, 1]: ["merlin", "bulldog", "lancelot", "tristan", "gawain"],
		[6, 3]: ["merlin", "bulldog", "lancelot", "tristan", "gawain", "lady_lake", "morgana"],
	}
	for key: Array in expected:
		await _enter(key[0], key[1])
		await _skip_story()
		var want: Array = expected[key]
		var label := "第 %d 章第 %d 次營地" % [key[0], _camp.camp_number()]
		var present := {
			"merlin": _camp.is_merlin_visible() and not _camp.is_lady_hosting(),
			"bulldog": _camp.is_bulldog_visible(),
			"lancelot": _camp.is_lancelot_visible(),
			"tristan": _camp.is_friend_visible(&"tristan"),
			"gawain": _camp.is_friend_visible(&"gawain"),
			"lady_lake": _camp.is_lady_present(),
			"morgana": _camp.is_friend_visible(&"morgana"),
		}
		for who: String in present:
			assert_eq(present[who], want.has(who), "%s:%s %s" % [label, who, "在" if want.has(who) else "不在"])
		assert_false(_camp.is_lady_hosting(), "%s:梅林回來了,坐在圓桌後面的是梅林" % label)
		assert_eq(_camp.get_merlin().name, &"Merlin")
		assert_eq(_camp.has_crystal_ball(), key == [5, 3], "%s:水晶球只在第五章第二次營地" % label)


func test_chapter_five_bedivere_stays_home_and_gawain_sits_by_the_fire() -> void:
	await _enter(5, 1)
	await _skip_story()
	assert_false(_camp.is_bulldog_visible(), "貝德維爾留在卡美洛")
	var gawain := _camp.get_friend(&"gawain")
	assert_false(gawain.behind_table, "高文坐在營火旁(鬥牛犬的位置)")
	assert_true(gawain.get_parent().name == &"Actors", "畫在地面前面")
	assert_true(gawain.position.x < _camp.get_goldie().position.x, "在營火左邊")
	assert_false(gawain.face_left, "朝右看著營火")


func test_tapping_tristan_plays_the_harp_and_says_a_line() -> void:
	await _enter(4, 1, {"friend_tap_cooldown_sec": 0.0})
	await _skip_story()
	var spoke: Array = []
	_camp.friend_spoke.connect(func(id: StringName, key: String) -> void: spoke.append([id, key]))
	var key := _camp.tap_tristan()
	assert_true(key.begins_with("CAMP_TRISTAN_"), "說 CAMP_TRISTAN_XX(%s)" % key)
	var tristan := _camp.get_friend(&"tristan")
	assert_true(tristan.is_poking(), "彈一下豎琴")
	assert_eq(tristan.current_animation(), &"play")
	assert_eq(Haptics.last_kind, &"light")
	assert_eq(_camp.get_merlin_bubble().text, tr(key))
	assert_eq(spoke, [[&"tristan", key]])
	tristan.advance(0.4)
	assert_true(tristan.note_count() > 0, "飄出音符")
	tristan.advance(2.0)
	assert_false(tristan.is_poking())
	assert_eq(tristan.current_animation(), &"idle", "回到平常")
	var said: Array[String] = [key]
	for i in 7:
		said.append(_camp.tap_tristan())
	var first := said.slice(0, 4)
	first.sort()
	assert_eq(first, ["CAMP_TRISTAN_01", "CAMP_TRISTAN_02", "CAMP_TRISTAN_03", "CAMP_TRISTAN_04"] as Array[String], "四句都說過才重複")
	for i in range(1, said.size()):
		assert_ne(said[i], said[i - 1], "不會連續兩次說同一句")
	assert_true(_camp.tap_merlin().begins_with("CAMP_MERLIN_"), "梅林有自己的台詞")


func test_tristan_plays_now_and_then_by_himself() -> void:
	await _enter(4, 1)
	await _skip_story()
	var tristan := _camp.get_friend(&"tristan")
	for i in 120:
		tristan.advance(0.1)
	assert_true(tristan.ambient_count >= 1, "平常偶爾自己彈琴(%d 次)" % tristan.ambient_count)


func test_tapping_gawain_slams_and_says_a_line() -> void:
	await _enter(5, 3, {"friend_tap_cooldown_sec": 0.0})
	await _skip_story()
	var key := _camp.tap_gawain()
	assert_true(key.begins_with("CAMP_GAWAIN_"), "說 CAMP_GAWAIN_XX(%s)" % key)
	var gawain := _camp.get_friend(&"gawain")
	assert_true(gawain.is_poking())
	assert_eq(gawain.current_animation(), &"slam", "大鐵鎚敲一下地")
	var said: Array[String] = [key]
	for i in 3:
		said.append(_camp.tap_gawain())
	said.sort()
	assert_eq(said, ["CAMP_GAWAIN_01", "CAMP_GAWAIN_02", "CAMP_GAWAIN_03", "CAMP_GAWAIN_04"] as Array[String])
	assert_eq(_camp.tap_tristan(), "", "第五章崔斯坦不在")


func test_final_camp_everyone_including_lady_and_morgana() -> void:
	await _enter(6, 3, {"friend_tap_cooldown_sec": 0.0, "merlin_tap_cooldown_sec": 0.0})
	await _skip_story()
	assert_true(_camp.tap_merlin().begins_with("CAMP_MERLIN_"), "梅林坐在老位置說梅林的話")
	var lady_key := _camp.tap_friend(&"lady_lake")
	assert_true(lady_key.begins_with("CAMP_LADY_"), "湖中仙女(%s)" % lady_key)
	var lady := _camp.get_friend(&"lady_lake")
	assert_eq(lady.current_animation(), &"cast")
	var spoke: Array = []
	_camp.friend_spoke.connect(func(id: StringName, key: String) -> void: spoke.append([id, key]))
	assert_eq(_camp.tap_friend(&"morgana"), "", "摩根娜只施法、不說話")
	assert_eq(spoke, [[&"morgana", ""]], "還是發出 friend_spoke(空的台詞)")
	var morgana := _camp.get_friend(&"morgana")
	assert_true(morgana.is_poking())
	assert_eq(morgana.current_animation(), &"cast")
	assert_eq(_camp.friend_taps, 2)
	assert_true(_camp.tap_tristan().begins_with("CAMP_TRISTAN_"))
	assert_true(_camp.tap_gawain().begins_with("CAMP_GAWAIN_"))
	assert_true(_camp.tap_lancelot().begins_with("CAMP_LANCELOT_"))


func test_friends_silent_when_busy_and_hidden_during_minigame() -> void:
	await _enter(6, 1)
	assert_eq(_camp.tap_tristan(), "", "對白中不說話")
	await _skip_story()
	var zone := _camp.find_child("TristanZone", true, false) as Control
	assert_true(zone.visible)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	zone.gui_input.emit(tap)
	assert_eq(_camp.friend_taps, 1, "點崔斯坦的範圍 = 點崔斯坦")
	assert_eq(_camp.tap_tristan(), "", "連點太快不算")
	_camp.open_minigame()
	for id: StringName in [&"tristan", &"gawain"]:
		assert_false(_camp.is_friend_visible(id), "小遊戲中看不到 %s" % id)
	assert_false(zone.visible)
	assert_eq(_camp.tap_gawain(), "")
	var game := _camp.get_minigame()
	game.set_process(false)
	game.close()
	await wait_frames(1)
	assert_true(_camp.is_friend_visible(&"tristan") and _camp.is_friend_visible(&"gawain"), "回到營地還在")
	_camp.leave_camp()
	assert_eq(_camp.tap_gawain(), "", "離開後不說話")


func test_zones_and_bubbles_fit_every_phone() -> void:
	var root := get_tree().root
	var original := root.size
	for key: Array in [[4, 1], [5, 1], [5, 3], [6, 1], [6, 3]]:
		await _enter(key[0], key[1], {"friend_tap_cooldown_sec": 0.0})
		await _skip_story()
		for phone in PHONES:
			root.size = phone
			ScreenFit.call(&"_refit")
			await wait_frames(2)
			_camp.finish_intro()
			var size := SafeArea.get_screen_size()
			var safe := SafeArea.get_safe_rect()
			var label := "%s 第 %d 章第 %d 次營地" % [size, key[0], _camp.camp_number()]
			var menu_node := _camp.find_child("Menu", true, false) as Control
			var menu := Rect2(menu_node.global_position, menu_node.size)
			var zones := {}
			for zone_name: String in ["PetZone", "BulldogZone", "MerlinZone", "LancelotZone", "TristanZone", "GawainZone",
					"MorganaZone", "LadyLakeZone"]:
				var node := _camp.find_child(zone_name, true, false) as Control
				if node != null and node.visible:
					zones[zone_name] = Rect2(node.global_position, node.size)
			for zone_name: String in zones:
				var rect: Rect2 = zones[zone_name]
				assert_true(rect.size.x >= 24.0 and rect.size.y >= 24.0, "%s:%s 夠大好點(%s)" % [label, zone_name, rect.size])
				assert_true(Rect2(Vector2.ZERO, size).encloses(rect.grow(-6.0)), "%s:%s 在畫面內" % [label, zone_name])
				assert_false(rect.intersects(menu), "%s:%s 不蓋住選單" % [label, zone_name])
				for other: String in zones:
					if other != zone_name:
						assert_false(rect.intersects(zones[other]), "%s:%s 和 %s 不重疊" % [label, zone_name, other])
			var bubble := _camp.get_merlin_bubble()
			for id: StringName in _camp.friend_ids():
				var friend := _camp.get_friend(id)
				for line_key: String in friend.data.lines:
					bubble.show_text(tr(line_key), friend.speech_anchor(), 1.0)
					assert_true(safe.encloses(bubble.get_box()), "%s:%s 的泡泡在安全區內" % [label, line_key])
					assert_true(bubble.get_lines().size() <= 2, "%s:%s 最多兩行" % [label, line_key])
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)


func test_new_camp_lines_are_short_full_width_and_in_the_font() -> void:
	var shared := load("res://ui/theme/main_theme.tres") as Theme
	var font: Font = shared.default_font if shared != null and shared.default_font != null else ThemeDB.fallback_font
	var keys: Array[String] = []
	for i in range(1, 5):
		keys.append("CAMP_TRISTAN_%02d" % i)
		keys.append("CAMP_GAWAIN_%02d" % i)
	for key in keys:
		var text := tr(key)
		assert_ne(text, key, "%s 有文字" % key)
		assert_true(text.length() <= MAX_CJK, "%s 不超過 %d 字(%d)" % [key, MAX_CJK, text.length()])
		assert_false(text.contains(","), "%s 用全形逗號" % key)
		assert_false(text.contains("!") or text.contains("?") or text.contains(":"), "%s 用全形標點" % key)
		for c in text:
			assert_true(font.has_char(c.unicode_at(0)), "%s:像素字型有「%s」" % [key, c])
	# 對話泡泡自動換成兩行時,剛好在標點後面換行(不會把「晚上」「星星」拆開)
	await _enter(6, 1)
	var bubble := _camp.get_merlin_bubble()
	for key in keys:
		bubble.show_text(tr(key), Vector2(90, 120), 1.0)
		var lines := bubble.get_lines()
		assert_eq(lines.size(), 2, "%s 兩行" % key)
		assert_true(MinigameSpeechBubble.NO_LINE_START.contains(lines[0].right(1)), "%s:第一行在標點結束(%s)" % [key, lines[0]])


func test_cast_layouts_and_friends_are_data() -> void:
	var cfg := load("res://game/camp/camp_config.tres") as CampConfig
	var known := ["merlin", "lady_lake", "lancelot", "bulldog", "crystal_ball"]
	var anims := {&"tristan": [&"idle", &"play"], &"gawain": [&"idle", &"slam"], &"morgana": [&"idle", &"cast"],
		&"lady_lake": [&"idle", &"cast"]}
	var friend_ids: Array[String] = []
	for data: CampFriendData in cfg.friends:
		friend_ids.append(String(data.id))
		assert_not_null(data.frames, "%s 用 C 線的圖" % data.id)
		for anim: StringName in anims.get(data.id, [&"idle"]):
			assert_true(data.frames.has_animation(anim), "%s 有 %s" % [data.id, anim])
		assert_true(data.frames.has_animation(data.tap_animation), "%s 被點時的動畫存在" % data.id)
	for chapter in range(4, GameState.CHAPTER_COUNT + 1):
		for camp in [1, 2]:
			var layout: Dictionary = cfg.cast_layouts.get("%d-%d" % [chapter, camp], cfg.cast_layouts.get(str(chapter), {}))
			assert_false(layout.is_empty(), "第 %d 章第 %d 次營地有人物表" % [chapter, camp])
			for who: String in layout:
				assert_true(known.has(who) or friend_ids.has(who), "%s 是認得的人" % who)
				assert_true(layout[who] is Vector2, "%s 的位置是 Vector2" % who)


# --- DW2 場景 ---

func test_scenery_for_chapters_four_to_six() -> void:
	var tops: Array[Color] = []
	for key: Array in [[4, 1], [5, 1], [5, 3], [6, 1], [6, 3]]:
		await _enter(key[0], key[1])
		await _skip_story()
		var sky := _camp.find_child("Sky", true, false) as CampScenery
		var parts: Array[CampScenery] = []
		for child in sky.get_parent().get_children():
			if child is CampScenery:
				parts.append(child as CampScenery)
		assert_eq(parts.size(), 3, "夜空、地面、光暈")
		for part in parts:
			assert_eq(part.chapter, key[0], "%s 用第 %d 章的場景(不會被限制在 3)" % [part.name, key[0]])
			assert_eq(part.crystal_ball, key == [5, 3], "水晶球")
			part.advance(0.7)
		_camp.get_node("Layer/Root/Front").queue_redraw()
		await wait_frames(2)
		if key[1] == 1:
			tops.append(_camp.config.sky_top_color)
		match key[0]:
			4:
				assert_true(CampChapterScenes.sea_top(sky) < sky.horizon_y - 15.0, "看得到海")
				assert_true(CampChapterScenes.sea_top(sky) > sky.top_y - 20.0, "海不蓋到標題")
			5:
				assert_true(CampChapterScenes.spring_center(sky).x > SafeArea.get_screen_size().x * 0.7, "溫泉在右邊")
				assert_true(CampChapterScenes.hut_window(sky).x < SafeArea.get_screen_size().x * 0.3, "小木屋在左邊")
			6:
				assert_eq(CampChapterScenes.lantern_spots(sky).size(), 2, "兩邊樹上的燈籠")
	assert_ne(tops[0], tops[1], "第四、五章顏色不同")
	assert_ne(tops[1], tops[2], "第五、六章顏色不同")
	var cfg := load("res://game/camp/camp_config.tres") as CampConfig
	for chapter in range(4, GameState.CHAPTER_COUNT + 1):
		var palette: Dictionary = cfg.chapter_palettes.get(chapter, {})
		assert_false(palette.is_empty(), "第 %d 章的顏色在 camp_config.tres" % chapter)
		for color_key: String in palette:
			assert_true(palette[color_key] is Color, "%s 是顏色" % color_key)


func test_beach_waves_roll_in() -> void:
	await _enter(4, 1)
	var sky := _camp.find_child("Sky", true, false) as CampScenery
	var phases: Array[float] = []
	for i in 6:
		sky.advance(0.6)
		phases.append(CampChapterScenes.wave_phase(sky))
	assert_true(phases.max() - phases.min() > 0.5, "浪一波一波打上來")


# --- DW3 小遊戲輪流 ---

func test_minigames_rotate_in_chapters_four_to_six() -> void:
	var expected := {
		[1, 1]: SCROLL_PATH, [2, 1]: WAKE_PATH, [2, 3]: SCROLL_PATH, [3, 1]: SCROLL_PATH, [3, 3]: WAKE_PATH,
		[4, 1]: FISH_PATH, [4, 3]: SCROLL_PATH, [5, 1]: SCROLL_PATH, [5, 3]: WAKE_PATH, [6, 1]: WAKE_PATH, [6, 3]: FISH_PATH,
	}
	var keys := {SCROLL_PATH: "UI_CAMP_MINIGAME", WAKE_PATH: "UI_CAMP_MINIGAME_WAKE", FISH_PATH: "UI_CAMP_MINIGAME_FISH"}
	var late := {}
	for key: Array in expected:
		await _enter(key[0], key[1])
		var path: String = expected[key]
		assert_eq(_camp.current_minigame_scene().resource_path, path, "第 %d 章第 %d 次營地" % [key[0], _camp.camp_number()])
		var button := _camp.find_child("MinigameButton", true, false) as Button
		assert_eq(button.text, tr(keys[path]), "按鈕文字跟著小遊戲")
		if key[0] >= 4:
			late[path] = true
	assert_eq(late.size(), 3, "第四至六章三個小遊戲都會出現")
	assert_eq(_camp.rotation_count(3), 2, "第三章以前兩個輪流")
	assert_eq(_camp.rotation_count(GameState.CHAPTER_COUNT), 3)


func test_fish_round_trip_in_a_chapter_four_camp() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	await _enter(4, 1)
	await _skip_story()
	GameState.vigor = 20
	_camp.open_minigame()
	var game := _camp.get_minigame() as FishMinigame
	assert_not_null(game, "第四章第一次營地:接住跳跳魚")
	assert_false(_camp.is_friend_visible(&"tristan"), "小遊戲蓋住營地")
	game.set_process(false)
	game.step(game.config.countdown_sec + 0.001)
	while game.state == MinigameBase.State.PLAYING:
		game.bot_step(1.0 / 60.0)
		game.step(1.0 / 60.0)
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args()[0], &"fish")
	assert_eq(GameState.next_level_bonus, 0.15, "下一關攻擊 +15%")
	assert_true(GameState.vigor > 20)
	game.step(game.config.results_delay_sec + game.config.results_min_sec + 0.1)
	game.close()
	await wait_frames(1)
	assert_null(_camp.get_minigame(), "回到營地")
	assert_eq(_camp.last_grade, 3)
	assert_true(_camp.is_friend_visible(&"tristan"))
	_camp.open_minigame()
	assert_null(_camp.get_minigame(), "今晚玩過了")
