extends "res://tests/line_b/flow_test_base.gd"
## B9、BP6 存檔:寫入與讀取、寫到一半中斷時舊存檔仍可讀、損毀的檔案、開機讀檔、繼續冒險、
## 新欄位(音樂、震動、教學、最佳星數、待進營地)與舊版存檔的向下相容。


func before_each() -> void:
	SaveStore.new(SAVE_PATH).delete()


func test_round_trip() -> void:
	var store := SaveStore.new(SAVE_PATH)
	assert_true(store.read().is_empty(), "一開始沒有存檔")
	assert_true(store.write(3, 7, false))
	var data := store.read()
	assert_eq(data["level_index"], 3)
	assert_eq(data["snacks"], 7)
	assert_eq(data["sound_on"], false)
	assert_false(FileAccess.file_exists(store.temp_path()), "改名後不留暫存檔")


func test_only_known_fields_are_saved() -> void:
	var store := SaveStore.new(SAVE_PATH)
	store.write_data({"level_index": 1, "snacks": 2, "player_name": "should not be saved"})
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var keys := raw.keys()
	keys.sort()
	assert_eq(keys, ["best_stars", "camp_pending", "chapter_cleared", "difficulty", "haptics_on", "level_index",
			"music_on", "snacks", "sound_on", "story_seen", "tutorial_done", "version"],
			"只存遊戲進度與設定,沒有任何個人資料")
	assert_eq(raw["version"], 3.0)


func test_overwrite_keeps_latest() -> void:
	var store := SaveStore.new(SAVE_PATH)
	store.write(1, 0, true)
	store.write(4, 2, true)
	assert_eq(store.read()["level_index"], 4)


func test_interrupted_write_keeps_the_old_save() -> void:
	var store := SaveStore.new(SAVE_PATH)
	assert_true(store.write(2, 5, true), "先有一份完整的舊存檔")
	store.simulate_crash_during_write = true
	assert_false(store.write(5, 9, false), "寫到一半就被中斷")
	assert_true(FileAccess.file_exists(store.temp_path()), "留下只寫了一半的暫存檔")
	var reader := SaveStore.new(SAVE_PATH)     # 模擬重新開啟 App
	var data := reader.read()
	assert_eq(data["level_index"], 2, "舊存檔仍可讀")
	assert_eq(data["snacks"], 5)
	assert_eq(data["sound_on"], true)
	assert_false(FileAccess.file_exists(store.temp_path()), "殘留的暫存檔被清掉")


func test_corrupt_or_wrong_files_mean_no_save() -> void:
	var store := SaveStore.new(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"level_index\": 3, \"snac")
	file.close()
	assert_true(store.read().is_empty(), "損毀的檔案當作沒有存檔,不會當機")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_true(store.read().is_empty())
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"level_index\": \"x\", \"snacks\": -4, \"sound_on\": 1}")
	file.close()
	var data := store.read()
	assert_eq(data["level_index"], 0, "型別不對 → 預設值")
	assert_eq(data["snacks"], 0, "負數 → 0")
	assert_eq(data["sound_on"], true)


func test_boot_loads_save_and_title_offers_continue() -> void:
	SaveStore.new(SAVE_PATH).write(3, 4, false)
	make_flow(true)
	await wait_frames(1)
	assert_eq(flow.state, FlowMain.State.TITLE)
	assert_true(flow.has_save())
	assert_eq(GameState.snacks, 4)
	assert_false(GameState.sound_on)
	var title := flow.get_screen()
	assert_true(title.get(&"_continue_button").visible, "標題收到 setup(true)")


func test_no_save_hides_continue() -> void:
	make_flow()
	await wait_frames(1)
	assert_false(flow.has_save())
	assert_false(flow.get_screen().get(&"_continue_button").visible)


func test_continue_starts_saved_level_with_a_fresh_run() -> void:
	SaveStore.new(SAVE_PATH).write(2, 0, true)
	GameState.hero_level = 5
	GameState.active_tricks.append(&"sit")
	make_flow(true)
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.LEVEL))
	assert_eq(started.last_args(), [&"1-3"])
	assert_eq(GameState.level_index, 2)
	assert_eq(GameState.hero_level, 1, "繼續 = 全新的一輪")
	assert_eq(GameState.active_tricks.size(), 0)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor)


func test_level_start_and_level_complete_write_the_save() -> void:
	make_flow()
	await wait_frames(1)
	assert_false(save_file_exists())
	assert_true(await start_new_game())
	assert_true(save_file_exists(), "關卡開始時寫入")
	assert_eq(read_save()["level_index"], 0)
	assert_true(await play_until_level_ends())
	assert_eq(flow.state, FlowMain.State.RESULTS)
	assert_eq(read_save()["level_index"], 1, "過關後存下一關")


func test_new_game_ignores_old_progress() -> void:
	SaveStore.new(SAVE_PATH).write(4, 0, true)
	make_flow(true)
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_eq(GameState.level_index, 0)
	assert_eq(read_save()["level_index"], 0)
