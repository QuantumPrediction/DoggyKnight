extends "res://tests/line_b/flow_test_base.gd"
## v2.6 BV3 至 BV7(DEV_PLAN 4.13、第 19 節):三章的流程。全部用替身(替身場地、替身敵人、替身對白框),
## 所以 A 線的新敵人還沒合併也能跑。
## - 三章各自可以從第 1 關玩到結局、預告、回標題;打完第 N 章 chapters_cleared = N。
## - 只能選已解鎖的章;存檔記住章;「繼續冒險」回到存檔的章與關;舊存檔轉換。
## - 每章的音樂(field_2 / boss_2 …),音樂檔不存在時退回 field / boss。
## - 無盡試煉依 chapters_cleared 加入第二、三章的敵人、頭目與背景。
## - 替身標題的選章。

const ENDLESS: String = "res://data/levels/endless.tres"
const CH1_BACKGROUNDS: Array[String] = ["sword_stone", "wheat_field", "meadow", "farm_fence", "crow_forest", "bridge"]

var _stories: PackedStringArray = []
var _story_hook: Callable


func before_each() -> void:
	_stories.clear()
	_story_hook = func(id: StringName) -> void: _stories.append(String(id))
	EventBus.dialogue_started.connect(_story_hook)


func after_each() -> void:
	if EventBus.dialogue_started.is_connected(_story_hook):
		EventBus.dialogue_started.disconnect(_story_hook)
	await super()


## 從標題按「新遊戲」一路玩到回標題:略過對白、打倒敵人、選第一張卡、離開營地、結算按繼續。
## 傳回每關的結算資料(依次序)。
func _play_whole_chapter(timeout_sec: float = 60.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var camps: Array[int] = []
	var left_title := [false]
	flow.get_screen().emit_signal(&"new_game_pressed")
	var finished := await wait_until(func() -> bool:
		if flow.is_switching():
			return false
		match flow.state:
			FlowMain.State.STORY:
				skip_dialogue()
			FlowMain.State.LEVEL:
				left_title[0] = true
				_auto_step()
			FlowMain.State.RESULTS:
				var result := flow.get_last_result()
				if results.is_empty() or results.back()["level_id"] != result["level_id"]:
					results.append(result)
					flow.get_screen().emit_signal(&"continue_pressed")
			FlowMain.State.CAMP:
				if not camps.has(flow.get_level_index()):
					camps.append(flow.get_level_index())
					assert_eq(GameState.chapter, flow.get_run_chapter(), "營地期間 GameState.chapter 是這一章")
					EventBus.camp_left.emit()
			FlowMain.State.TITLE:
				return left_title[0]
		return false, timeout_sec)
	assert_true(finished, "在時限內玩完一章")
	assert_eq(camps, [1, 3] as Array[int], "兩次營地")
	return results


func _expected_stories(n: int) -> PackedStringArray:
	var ids: PackedStringArray = ["prologue" if n == 1 else "c%d_prologue" % n]
	for m in range(1, 7):
		ids.append("l%d_before" % m if n == 1 else "c%dl%d_before" % [n, m])
		ids.append("l%d_after" % m if n == 1 else "c%dl%d_after" % [n, m])
	ids.append("teaser" if n == 1 else "c%d_teaser" % n)
	return ids


func test_each_chapter_plays_from_level_1_to_the_ending() -> void:
	for n in [1, 2, 3]:
		reset_settings()
		GameState.chapters_cleared = n - 1
		GameState.chapter_cleared = n > 1
		GameState.chapter = n                 # 標題在 new_game_pressed 之前設定
		make_flow(false, 1234, true)
		await wait_frames(1)
		_stories.clear()
		var started := watch_signal(EventBus.level_started)
		var results := await _play_whole_chapter()
		var ids: Array = results.map(func(r: Dictionary) -> StringName: return r["level_id"])
		var want: Array = []
		for m in range(1, 7):
			want.append(StringName("%d-%d" % [n, m]))
		assert_eq(ids, want, "第 %d 章的六關" % n)
		assert_eq(started.count, 6)
		assert_eq(_stories, _expected_stories(n), "第 %d 章的對白次序(開場繪本 → 每關前後 → 結局 → 預告)" % n)
		for i in results.size():
			assert_eq(results[i]["chapter"], n)
			assert_eq(results[i]["chapter_name"], "CHAPTER_%d" % n)
			assert_eq(results[i]["chapter_count"], 3)
			assert_eq(results[i]["is_final"], i == 5)
			assert_eq(results[i]["next_chapter_unlocked"], i == 5 and n < 3, "第 %d 章結算:解鎖下一章" % n)
			assert_eq(results[i]["level_count"], 6)
		assert_eq(results[5]["chapters_cleared"], n, "結算時已經記下")
		assert_eq(GameState.chapters_cleared, n, "打完第 %d 章" % n)
		assert_true(GameState.chapter_cleared, "chapter_cleared 保持 true")
		var saved := read_save()
		assert_eq(saved["chapters_cleared"], n, "存檔記下 chapters_cleared")
		assert_eq(GameState.chapter, mini(n + 1, 3), "標題預設選剛解鎖的章")
		assert_eq(saved["chapter"], mini(n + 1, 3))
		assert_false(flow.has_save(), "一章完成:沒有要繼續的關卡")
		assert_eq(flow.state, FlowMain.State.TITLE)
		flow.queue_free()
		flow = null
		await wait_frames(2)


func test_a_new_run_starts_at_level_1_with_a_fresh_hero() -> void:
	GameState.chapters_cleared = 1
	GameState.chapter_cleared = true
	GameState.chapter = 2
	GameState.hero_level = 7
	GameState.active_tricks.append(&"sit")
	make_flow()
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	assert_true(await start_new_game())
	assert_eq(started.last_args(), [&"2-1"])
	assert_eq(GameState.hero_level, 1, "每章是獨立的一輪:等級 1")
	assert_eq(GameState.active_tricks.size(), 0, "沒有把戲")
	assert_eq(GameState.level_index, 0)
	assert_eq(flow.get_run_chapter(), 2)
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 1, "2-1 只有貝德維爾")


func test_locked_chapters_cannot_be_started() -> void:
	make_flow()
	await wait_frames(1)
	assert_eq(flow.max_selectable_chapter(), 1)
	GameState.chapter = 3
	var started := watch_signal(EventBus.level_started)
	assert_true(await start_new_game())
	assert_eq(started.last_args(), [&"1-1"], "還沒打完任何一章:只能玩第一章")
	assert_eq(GameState.chapter, 1)
	flow.queue_free()
	flow = null
	await wait_frames(2)
	GameState.chapters_cleared = 1
	GameState.chapter_cleared = true
	GameState.chapter = 3
	make_flow()
	await wait_frames(1)
	assert_eq(flow.max_selectable_chapter(), 2)
	started = watch_signal(EventBus.level_started)
	assert_true(await start_new_game())
	assert_eq(started.last_args(), [&"2-1"], "打完第一章:最多第二章")


func test_two_companions_from_2_3() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 2, "chapter": 2, "chapters_cleared": 1,
			"chapter_cleared": true})
	make_flow(true)
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"2-3"])
	await wait_frames(1)
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 2, "貝德維爾與蘭斯洛特")


func test_continue_returns_to_the_saved_chapter_and_level() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 4, "chapter": 3, "chapters_cleared": 2,
			"chapter_cleared": true, "difficulty": "hard"})
	make_flow(true)
	await wait_frames(1)
	assert_true(flow.has_save())
	assert_eq(GameState.chapters_cleared, 2)
	assert_eq(GameState.chapter, 3, "讀檔:標題預設選存檔的章")
	assert_eq(flow.get_run_chapter(), 3)
	GameState.chapter = 1                    # 玩家在標題上翻到第一章,但按的是「繼續冒險」
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"3-5"], "回到存檔的章與關")
	assert_eq(GameState.chapter, 3)
	assert_eq(GameState.level_index, 4)
	assert_eq(GameState.difficulty, &"hard", "沿用那一輪的難度")
	var saved := read_save()
	assert_eq(saved["chapter"], 3)
	assert_eq(saved["level_index"], 4)


func test_continue_into_a_pending_camp_of_chapter_2() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 2, "camp_pending": true, "chapter": 2,
			"chapters_cleared": 1, "chapter_cleared": true})
	make_flow(true)
	await wait_frames(1)
	var camps := watch_signal(EventBus.camp_entered)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.CAMP))
	assert_eq(GameState.chapter, 2, "D 線的營地依 GameState.chapter 播 c2_camp1")
	assert_eq(GameState.level_index, 1, "剛打完 2-2")
	assert_true(camps.count <= 1)
	var started := watch_signal(EventBus.level_started)
	EventBus.camp_left.emit()
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"2-3"])


func test_old_saves_convert_to_chapters_cleared() -> void:
	var store := SaveStore.new(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "level_index": 3, "chapter_cleared": true, "snacks": 9}))
	file.close()
	var data := store.read()
	assert_eq(data["version"], 4)
	assert_eq(data["chapters_cleared"], 1, "舊存檔:打完第一章 → chapters_cleared = 1")
	assert_eq(data["chapter"], 1, "舊存檔的進度是第一章")
	assert_eq(data["level_index"], 3)
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 3, "level_index": 1, "chapter_cleared": false}))
	file.close()
	data = store.read()
	assert_eq(data["chapters_cleared"], 0)
	assert_eq(data["chapter_cleared"], false)
	# 不合理的值:章限制在 1 至 3,chapters_cleared 0 至 3;chapters_cleared ≥ 1 一定 chapter_cleared
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 5, "chapter": 7, "chapters_cleared": 9, "chapter_cleared": false}))
	file.close()
	data = store.read()
	assert_eq(data["chapter"], 3)
	assert_eq(data["chapters_cleared"], 3)
	assert_eq(data["chapter_cleared"], true)
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 5, "chapter": "x", "chapters_cleared": -2}))
	file.close()
	data = store.read()
	assert_eq(data["chapter"], 1)
	assert_eq(data["chapters_cleared"], 0)
	# 舊存檔開機:第一章第 4 關可以繼續,標題可以選到第二章;寫回時是第 5 版
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "level_index": 3, "chapter_cleared": true}))
	file.close()
	make_flow(true)
	await wait_frames(1)
	assert_eq(GameState.chapters_cleared, 1)
	assert_true(GameState.chapter_cleared)
	assert_eq(flow.max_selectable_chapter(), 2)
	assert_eq(flow.get_run_chapter(), 1)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"1-4"])
	var saved := read_save()
	assert_eq(saved["version"], SaveStore.VERSION)
	assert_eq(saved["chapters_cleared"], 1)
	assert_eq(saved["chapter"], 1)


func test_save_chapter_too_high_for_progress_falls_back() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 2, "chapter": 3, "chapters_cleared": 0})
	make_flow(true)
	await wait_frames(1)
	assert_eq(flow.get_run_chapter(), 1, "沒有解鎖第三章:回到第一章")
	assert_eq(GameState.chapter, 1)


func test_replaying_an_earlier_chapter_keeps_the_highest_record() -> void:
	GameState.chapters_cleared = 2
	GameState.chapter_cleared = true
	SaveStore.new(SAVE_PATH).write_data({"level_index": 5, "chapter": 1, "chapters_cleared": 2,
			"chapter_cleared": true})
	make_flow(true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_true(await play_until_level_ends())
	assert_eq(flow.get_last_result()["is_final"], true)
	assert_eq(flow.get_last_result()["next_chapter_unlocked"], true, "第一章之後還有第二章")
	assert_eq(GameState.chapters_cleared, 2, "重玩第一章:不會變少")
	assert_eq(read_save()["chapters_cleared"], 2)


func test_chapter_music_and_fallback() -> void:
	GameState.chapters_cleared = 1
	GameState.chapter_cleared = true
	SaveStore.new(SAVE_PATH).write_data({"level_index": 3, "chapter": 2, "chapters_cleared": 1,
			"chapter_cleared": true})
	make_flow(true)
	await wait_frames(1)
	music_log.clear()
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(music_log.tracks()[-1], "field_2", "第二章的一般曲")
	# 2-4 的最後一波是石像鬼統領:改播第二章的頭目曲
	assert_true(await wait_until(func() -> bool:
		_auto_step()
		return music_log.tracks()[-1] == "boss_2" or flow.state != FlowMain.State.LEVEL))
	assert_eq(music_log.tracks()[-1], "boss_2", "中頭目那一波播 boss_2")
	assert_eq(flow.get_session().spawner.current_wave(), 3)
	# 音樂檔不存在:退回 field / boss
	music_log.missing = PackedStringArray(["field_2", "boss_2", "field_3", "boss_3"])
	var level := flow.get_chapter_data(2).get_level(0)
	assert_eq(flow.call(&"_level_track", level), &"field", "field_2 不存在 → field")
	assert_eq(flow.call(&"_level_track", flow.get_chapter_data(2).get_level(5)), &"boss", "boss_2 不存在 → boss")
	assert_eq(flow.call(&"_chapter_boss_track"), &"boss")
	music_log.missing = PackedStringArray()
	assert_eq(flow.call(&"_level_track", flow.get_chapter_data(2).get_level(5)), &"boss_2")
	# LevelData.music 空白:用這一章的 field_music / boss_music
	var blank := LevelData.new()
	assert_eq(flow.call(&"_level_track", blank), &"field_2")
	blank.is_boss = true
	assert_eq(flow.call(&"_level_track", blank), &"boss_2")


func test_real_music_files_decide_the_fallback() -> void:
	make_flow()
	await wait_frames(1)
	flow.music = null                  # 沒有 has_track():看 assets/music/ 有沒有檔案
	assert_true(flow.has_music_track(&"field"), "field.wav 存在")
	assert_false(flow.has_music_track(&"no_such_track_v26"), "不存在的曲子")
	var level := LevelData.new()
	level.music = &"no_such_track_v26"
	assert_eq(flow.call(&"_level_track", level), &"field")
	level.is_boss = true
	assert_eq(flow.call(&"_level_track", level), &"boss")


func test_first_chapter_music_is_unchanged() -> void:
	make_flow()
	await wait_frames(1)
	music_log.clear()
	assert_true(await start_new_game())
	assert_eq(music_log.tracks()[-1], "field", "第一章仍然是 field")


# --- 無盡試煉(BV5) ---

func _gen(tier: int, rng_seed: int = 3) -> EndlessWaves:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return EndlessWaves.new(load(ENDLESS) as EndlessData, rng, tier)


func _enemies_seen(tier: int, waves: int = 40) -> Dictionary:
	var gen := _gen(tier)
	var seen := {}
	for n in range(1, waves + 1):
		for e in gen.make_wave(n).spawns:
			seen[e.enemy_id] = true
	return seen


func test_endless_adds_later_chapter_enemies_and_bosses() -> void:
	var t1 := _enemies_seen(1)
	var t2 := _enemies_seen(2)
	var t3 := _enemies_seen(3)
	for kind: StringName in [&"gargoyle", &"spellbook", &"foxfire", &"shadow_wolf", &"gargoyle_elite",
			&"phantom_knight", &"green_knight", &"morgana"]:
		assert_false(t1.has(kind), "只打完第一章:沒有 %s" % kind)
	for kind: StringName in [&"gargoyle", &"spellbook", &"gargoyle_elite", &"green_knight"]:
		assert_true(t2.has(kind), "打完第二章:有 %s" % kind)
	for kind: StringName in [&"foxfire", &"shadow_wolf", &"phantom_knight", &"morgana"]:
		assert_false(t2.has(kind), "打完第二章:還沒有 %s" % kind)
		assert_true(t3.has(kind), "打完第三章:有 %s" % kind)
	var data := load(ENDLESS) as EndlessData
	assert_eq([data.boss_for_wave(5, 3), data.boss_for_wave(15, 3), data.boss_for_wave(25, 3), data.boss_for_wave(35, 3)],
			[&"scarecrow_captain", &"gargoyle_elite", &"phantom_knight", &"scarecrow_captain"], "中頭目輪流")
	assert_eq([data.boss_for_wave(10, 3), data.boss_for_wave(20, 3), data.boss_for_wave(30, 3)],
			[&"black_knight", &"green_knight", &"morgana"], "頭目輪流")
	assert_eq([data.boss_for_wave(10, 2), data.boss_for_wave(20, 2), data.boss_for_wave(30, 2)],
			[&"black_knight", &"green_knight", &"black_knight"])
	assert_eq(data.boss_for_wave(20), &"black_knight", "預設(第一章)不變")
	assert_eq(data.boss_for_wave(15), &"scarecrow_captain")


func test_endless_backgrounds_follow_chapters_cleared() -> void:
	var tier1 := {}
	var tier3 := {}
	for s in range(1, 61):
		tier1[_gen(1, s).make_level().background.resource_path.get_file().get_basename()] = true
		tier3[_gen(3, s).make_level().background.resource_path.get_file().get_basename()] = true
	for bg: String in tier1:
		assert_true(CH1_BACKGROUNDS.has(bg), "只打完第一章:第一章的背景(%s)" % bg)
	var later := 0
	for bg: String in tier3:
		if not CH1_BACKGROUNDS.has(bg):
			later += 1
	assert_true(later >= 3, "打完第三章:也有第二、三章的背景(%d 張)" % later)
	var data := load(ENDLESS) as EndlessData
	assert_eq(data.backgrounds_for(1).size(), 6)
	assert_eq(data.backgrounds_for(2).size(), 12)
	assert_eq(data.backgrounds_for(3).size(), 18)


func test_endless_run_uses_chapters_cleared() -> void:
	GameState.chapter_cleared = true
	GameState.chapters_cleared = 3
	make_flow()
	await wait_frames(1)
	flow.get_screen().call(&"_endless")
	assert_true(await wait_until(in_level))
	var waves := flow.get(&"_endless_waves") as EndlessWaves
	assert_eq(waves.tier, 3)
	assert_eq(music_log.tracks()[-1], "field", "無盡試煉播 field")


# --- 替身標題(BV6) ---

func test_stand_in_title_picks_only_unlocked_chapters() -> void:
	make_flow()
	await wait_frames(1)
	var title := flow.get_screen()
	var row := title.get(&"_chapter_row") as Control
	assert_false(row.visible, "還沒打完任何一章:不顯示選章")
	GameState.chapters_cleared = 1
	GameState.chapter_cleared = true
	await wait_frames(1)
	assert_true(row.visible, "打完第一章:顯示選章")
	title.call(&"pick_chapter", 1)
	assert_eq(title.get(&"selected_chapter"), 2)
	title.call(&"pick_chapter", 1)
	assert_eq(title.get(&"selected_chapter"), 2, "第三章還鎖著")
	title.call(&"pick_chapter", -1)
	title.call(&"pick_chapter", -1)
	assert_eq(title.get(&"selected_chapter"), 1)
	title.call(&"pick_chapter", 1)
	var started := watch_signal(EventBus.level_started)
	title.call(&"_new_game", &"normal")
	assert_eq(GameState.chapter, 2, "按「新遊戲」之前設定 GameState.chapter")
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"2-1"])
