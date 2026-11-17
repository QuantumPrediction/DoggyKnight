extends "res://tests/line_b/flow_test_base.gd"
## BS4、BS6、BS7:困難模式(標題設定難度、只在打完第一章後才有效、隨存檔保存、最佳星數分開、
## 結算資料的 difficulty、困難模式多加的敵人)與存檔第 3 版(新欄位、舊存檔可讀)。

const FakeArena := preload("res://tests/line_b/fake_arena.gd")


## 模擬 C 線的標題畫面:先設定 GameState.difficulty,再發 new_game_pressed。
func _new_game(mode: StringName) -> bool:
	GameState.difficulty = mode
	flow.get_screen().emit_signal(&"new_game_pressed")
	return await wait_until(in_level)


func test_hard_is_ignored_until_the_chapter_is_cleared() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await _new_game(&"hard"))
	assert_eq(flow.get_run_difficulty(), &"normal", "還沒打完第一章:一律一般模式")
	assert_eq(GameState.difficulty, &"normal")
	assert_eq(read_save()["difficulty"], "normal")


func test_hard_run_saves_stars_separately_and_reports_difficulty() -> void:
	GameState.chapter_cleared = true
	GameState.best_stars = {"1-1": 1}
	make_flow()
	await wait_frames(1)
	assert_true(await _new_game(&"hard"))
	assert_eq(flow.get_run_difficulty(), &"hard")
	assert_eq(flow.get_session().difficulty_mode, &"hard", "關卡知道是困難模式")
	assert_eq(flow.get_session().spawner.difficulty_mode, &"hard")
	assert_eq(read_save()["difficulty"], "hard", "難度隨這一輪存檔")
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_eq(result["difficulty"], &"hard", "結算資料的 difficulty")
	assert_eq(result["stars"], 3)
	assert_eq(result["best_stars"], 3, "困難模式自己的最佳星數")
	assert_false(result["new_best"], "困難模式第一次過關")
	assert_eq(GameState.best_stars.get("1-1:hard", -1), 3, "存在「1-1:hard」")
	assert_eq(GameState.best_stars["1-1"], 1, "一般模式的紀錄不變")
	assert_eq(read_save()["best_stars"], {"1-1": 1, "1-1:hard": 3})


func test_normal_run_after_clearing_uses_normal_records() -> void:
	GameState.chapter_cleared = true
	GameState.best_stars = {"1-1:hard": 2}
	make_flow()
	await wait_frames(1)
	assert_true(await _new_game(&"normal"))
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_eq(result["difficulty"], &"normal")
	assert_eq(result["best_stars"], 3)
	assert_eq(GameState.best_stars["1-1"], 3)
	assert_eq(GameState.best_stars["1-1:hard"], 2, "困難模式的紀錄不變")


func test_continue_keeps_the_saved_runs_difficulty() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 2, "difficulty": "hard", "chapter_cleared": true})
	make_flow(true)
	await wait_frames(1)
	assert_true(GameState.chapter_cleared, "讀檔:已打完第一章")
	assert_eq(GameState.difficulty, &"hard", "讀檔:標題的難度預設 = 上一輪")
	GameState.difficulty = &"normal"           # 玩家在標題切換了難度,但按的是「繼續冒險」
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(flow.get_run_difficulty(), &"hard", "繼續冒險沿用存檔那一輪的難度")
	assert_eq(GameState.difficulty, &"hard")
	assert_eq(flow.get_session().difficulty_mode, &"hard")


func test_hard_mode_adds_a_few_regular_enemies() -> void:
	var shipped := load(DIFFICULTY) as DifficultyData
	assert_true(shipped.hard_extra_ratio >= 0.0 and shipped.hard_extra_ratio <= 0.5, "少量(每組最多多一半)")
	var d := shipped.duplicate() as DifficultyData
	d.hard_extra_ratio = 0.25
	var spawner := WaveSpawner.new()
	spawner.setup(LevelData.new(), null, d)
	var entry := SpawnEntry.new()
	entry.enemy_id = &"scarecrow"
	var normal_counts: Array[int] = []
	var hard_counts: Array[int] = []
	for count in [1, 2, 3, 4, 6, 7]:
		entry.count = count
		spawner.difficulty_mode = &"normal"
		normal_counts.append(spawner.spawn_count(entry))
		spawner.difficulty_mode = &"hard"
		hard_counts.append(spawner.spawn_count(entry))
	assert_eq(normal_counts, [1, 2, 3, 4, 6, 7] as Array[int], "一般模式不變")
	assert_eq(hard_counts, [1, 2, 3, 5, 7, 8] as Array[int], "困難模式:4 隻以上的組多 1 隻")
	for boss: StringName in [&"black_knight", &"scarecrow_captain"]:
		entry.enemy_id = boss
		entry.count = 3
		assert_eq(spawner.spawn_count(entry), 3, "%s 不會多加" % boss)
	spawner.free()


func test_hard_mode_spawns_the_extra_enemies_in_a_wave() -> void:
	var arena := FakeArena.new()
	add_child(arena)
	var level := LevelData.new()
	level.id = &"hard_test"
	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.enemy_id = &"scarecrow"
	entry.count = 4
	entry.pattern = &"surround"
	wave.spawns.append(entry)
	level.waves.append(wave)
	var d := fast_difficulty()
	d.hard_extra_ratio = 0.25
	var spawner := WaveSpawner.new()
	spawner.setup(level, arena, d)
	spawner.difficulty_mode = &"hard"
	add_child(spawner)
	spawner.set_physics_process(false)
	spawner.start(0.0)
	spawner.step(0.01)
	spawner.step(0.01)
	assert_eq(arena.spawned.size(), 5, "困難模式:4 隻的包圍變成 5 隻")
	spawner.queue_free()
	arena.queue_free()


# --- 存檔第 3 版(BS6) ---

func test_version_3_fields_round_trip() -> void:
	var store := SaveStore.new(SAVE_PATH)
	store.write_data({"level_index": 4, "difficulty": "hard", "chapter_cleared": true,
			"story_seen": {&"prologue": true, "l1_before": true}, "best_stars": {"1-1:hard": 2}})
	var data := store.read()
	assert_eq(data["version"], SaveStore.VERSION)
	assert_eq(data["difficulty"], "hard")
	assert_eq(data["chapter_cleared"], true)
	assert_eq(data["story_seen"], {"prologue": true, "l1_before": true})
	assert_eq(data["best_stars"], {"1-1:hard": 2})


func test_version_2_save_still_loads_with_v3_defaults() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 2, \"level_index\": 3, \"snacks\": 1, \"sound_on\": true, \"music_on\": false," +
			" \"haptics_on\": true, \"tutorial_done\": true, \"best_stars\": {\"1-1\": 3}, \"camp_pending\": false}")
	file.close()
	var data := SaveStore.new(SAVE_PATH).read()
	assert_eq(data["version"], 2)
	assert_eq(data["level_index"], 3)
	assert_eq(data["music_on"], false)
	assert_eq(data["difficulty"], "normal", "缺的欄位用預設值")
	assert_eq(data["chapter_cleared"], false)
	assert_eq(data["story_seen"], {})
	make_flow(true)
	await wait_frames(1)
	assert_true(flow.has_save())
	assert_eq(flow.get_run_difficulty(), &"normal")
	assert_false(GameState.chapter_cleared)
	assert_eq(GameState.best_stars, {"1-1": 3})
	flow.save_now()
	assert_eq(read_save()["version"], SaveStore.VERSION, "下次存檔就是最新版")


func test_bad_v3_values_are_cleaned() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 3, \"level_index\": 1, \"difficulty\": \"nightmare\", \"chapter_cleared\": 1," +
			" \"story_seen\": {\"prologue\": true, \"l1_before\": \"yes\", \"l2_before\": false}}")
	file.close()
	var data := SaveStore.new(SAVE_PATH).read()
	assert_eq(data["difficulty"], "normal", "不認識的難度 → normal")
	assert_eq(data["chapter_cleared"], false, "型別不對 → 預設值")
	assert_eq(data["story_seen"], {"prologue": true}, "只留值是 true 的段落")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 3, \"level_index\": 1, \"story_seen\": [\"prologue\"]}")
	file.close()
	assert_eq(SaveStore.new(SAVE_PATH).read()["story_seen"], {})


func test_story_seen_and_chapter_cleared_load_into_game_state() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 1, "chapter_cleared": true,
			"story_seen": {"prologue": true, "l1_before": true}})
	make_flow(true)
	await wait_frames(1)
	assert_true(GameState.chapter_cleared)
	assert_true(GameState.story_seen.has(&"prologue"), "讀檔:看過的段落(StringName 鍵,與對白框一致)")
	assert_true(GameState.story_seen.has(&"l1_before"))
	assert_eq(GameState.story_seen.size(), 2)
