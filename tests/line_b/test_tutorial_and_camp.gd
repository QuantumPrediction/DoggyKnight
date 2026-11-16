extends "res://tests/line_b/flow_test_base.gd"
## BP4 教學提示只出現一次、不暫停遊戲;BP6 存檔的新欄位與向下相容;
## D 線合約:營地顯示期間 GameState.level_index = 剛打完那一關;待進營地的存檔。


func _tutorial_visible() -> bool:
	var t := flow.get_tutorial()
	return t != null and is_instance_valid(t) and t.is_inside_tree()


func test_tutorial_shows_on_first_1_1_and_never_blocks() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await wait_until(_tutorial_visible, 2.0), "1-1 第一次玩:第一波開始時出現教學")
	var tutorial := flow.get_tutorial()
	assert_eq((tutorial.get_parent() as CanvasLayer).layer, 20, "第 20 層")
	assert_eq(tutorial.get_index(), 0, "在把戲選擇與暫停畫面之下")
	assert_false(get_tree().paused, "教學不暫停遊戲")
	assert_eq((tutorial as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "不吃掉觸控")
	assert_true(flow.get_session().is_playing())
	tutorial.emit_signal(&"finished")
	assert_true(GameState.tutorial_done)
	assert_true(read_save()["tutorial_done"], "看完教學立即存檔")
	await wait_frames(2)
	assert_null(flow.get_tutorial())
	assert_false(is_instance_valid(tutorial) and tutorial.is_inside_tree(), "教學已移除")


func test_tutorial_appears_only_once() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await wait_until(_tutorial_visible, 2.0))
	flow.get_tutorial().emit_signal(&"finished")
	# 倒下 → 再試一次:不再出現
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	await wait_frames(10)
	assert_null(flow.get_tutorial(), "看過了:重試時不出現")
	# 關掉遊戲再開(重新讀檔),新遊戲:也不出現
	flow.queue_free()
	await wait_frames(2)
	GameState.tutorial_done = false
	make_flow(true)
	await wait_frames(1)
	assert_true(GameState.tutorial_done, "讀檔還原 tutorial_done")
	assert_true(await start_new_game())
	await wait_frames(10)
	assert_null(flow.get_tutorial(), "新遊戲也不再出現")


func test_clearing_1_1_counts_as_tutorial_done() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await wait_until(_tutorial_visible, 2.0))
	assert_true(await play_until_level_ends())
	assert_true(GameState.tutorial_done, "打完 1-1 就算懂了,不會一直出現")
	assert_null(flow.get_tutorial(), "過關時移除教學")
	assert_true(read_save()["tutorial_done"])


func test_no_tutorial_outside_1_1() -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": 1})
	make_flow(true)
	await wait_frames(1)
	assert_false(GameState.tutorial_done)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	await wait_frames(10)
	assert_null(flow.get_tutorial(), "只在 1-1 出現")


# --- 存檔(BP6) ---

func test_settings_and_records_round_trip_through_the_save() -> void:
	GameState.music_on = false
	GameState.haptics_on = false
	GameState.tutorial_done = true
	GameState.best_stars = {"1-1": 3, "1-2": 1}
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var saved := read_save()
	assert_eq(saved["music_on"], false)
	assert_eq(saved["haptics_on"], false)
	assert_eq(saved["tutorial_done"], true)
	assert_eq(saved["best_stars"], {"1-1": 3, "1-2": 1})
	flow.queue_free()
	await wait_frames(2)
	reset_settings()
	make_flow(true)
	await wait_frames(1)
	assert_eq(GameState.music_on, false, "開機讀回音樂開關")
	assert_eq(GameState.haptics_on, false, "開機讀回震動開關")
	assert_eq(GameState.tutorial_done, true)
	assert_eq(GameState.best_stars, {"1-1": 3, "1-2": 1})


func test_pause_settings_are_saved_when_the_menu_closes() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	AppLifecycle.simulate_back()
	GameState.music_on = false             # C 線的暫停畫面直接改 GameState
	GameState.haptics_on = false
	AppLifecycle.simulate_back()            # 返回鍵關閉暫停選單
	assert_eq(read_save()["music_on"], false)
	assert_eq(read_save()["haptics_on"], false)


func test_version_1_save_still_loads() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"level_index\": 3, \"snacks\": 2, \"sound_on\": false}")
	file.close()
	var data := SaveStore.new(SAVE_PATH).read()
	assert_eq(data["level_index"], 3)
	assert_eq(data["snacks"], 2)
	assert_eq(data["sound_on"], false)
	assert_eq(data["music_on"], true, "缺的欄位用預設值")
	assert_eq(data["haptics_on"], true)
	assert_eq(data["best_stars"], {})
	assert_eq(data["camp_pending"], false)
	assert_eq(data["tutorial_done"], true, "舊存檔已到第 4 關:玩過第一關")
	make_flow(true)
	await wait_frames(1)
	assert_true(flow.has_save())
	assert_eq(flow.get_reached_level(), 3)
	assert_false(GameState.sound_on)
	assert_true(GameState.music_on)
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"level_index\": 0, \"snacks\": 0, \"sound_on\": true}")
	file.close()
	assert_eq(SaveStore.new(SAVE_PATH).read()["tutorial_done"], false, "還沒過第一關:要看教學")


func test_bad_star_records_are_cleaned() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 2, \"level_index\": 1, \"best_stars\": {\"1-1\": 9, \"1-2\": \"x\", \"1-3\": -2}, \"music_on\": \"yes\"}")
	file.close()
	var data := SaveStore.new(SAVE_PATH).read()
	assert_eq(data["best_stars"], {"1-1": 3, "1-3": 0}, "星數限制在 0 至 3,不是數字的略過")
	assert_eq(data["music_on"], true, "型別不對 → 預設值")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 2, \"level_index\": 1, \"best_stars\": [1, 2]}")
	file.close()
	assert_eq(SaveStore.new(SAVE_PATH).read()["best_stars"], {})


# --- 營地(D 線合約) ---

func _reach_camp_after(level_index: int) -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": level_index})
	make_flow(true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_true(await play_until_level_ends())
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.CAMP))


func test_level_index_during_camp_is_the_level_just_completed() -> void:
	await _reach_camp_after(1)
	assert_eq(GameState.level_index, 1, "1-2 之後的營地:level_index = 1")
	assert_true(read_save()["camp_pending"], "存檔記得要先進營地")
	EventBus.camp_left.emit()
	assert_true(await wait_until(in_level))
	assert_eq(GameState.level_index, 2)
	assert_false(read_save()["camp_pending"])
	flow.queue_free()
	await wait_frames(2)
	await _reach_camp_after(3)
	assert_eq(GameState.level_index, 3, "1-4 之後的營地:level_index = 3")


func test_app_closed_before_camp_continues_into_the_camp() -> void:
	await _reach_camp_after(1)
	# 在營地時 App 被系統關掉,再開:「繼續冒險」先回到營地
	flow.queue_free()
	await wait_frames(2)
	make_flow(true)
	await wait_frames(1)
	assert_true(flow.has_save())
	assert_true(flow.is_camp_pending())
	var entered := watch_signal(EventBus.camp_entered)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.CAMP))
	assert_eq(entered.count, 1)
	assert_eq(started.count, 0, "先進營地,不是直接開始下一關")
	assert_eq(GameState.level_index, 1, "營地合約:剛打完 1-2")
	assert_eq(flow.get_level_index(), 1)
	EventBus.camp_left.emit()
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"1-3"])
	assert_false(flow.is_camp_pending())
