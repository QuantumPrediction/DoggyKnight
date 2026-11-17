extends "res://tests/line_b/flow_test_base.gd"
## B1、B7、B8 流程:暫停與切到背景、返回鍵、結算資料、下一關加成、失敗重試、升級暫停。

const RESULT_KEYS: Array[String] = [
	"level_id", "level_name", "victory", "time_sec", "kills", "tricks", "hero_level", "next_is_camp", "is_final",
	# DEV_PLAN 4.10
	"stars", "star_goals", "best_stars", "new_best", "level_index", "level_count",
	# 額外:這一關受到的傷害
	"damage_taken",
	# DEV_PLAN 4.11(v2.3)
	"difficulty",
	# DEV_PLAN 4.12(v2.4)
	"mode", "snacks", "snacks_earned", "snack_bonus", "revive_cost", "can_revive", "event_tone",
	# DEV_PLAN 4.13(v2.6)
	"chapter", "chapter_name", "chapters_cleared", "chapter_count", "next_chapter_unlocked",
]


func _in_level() -> bool:
	return flow.is_level_running()


func test_boot_shows_title_on_layer_30() -> void:
	make_flow()
	await wait_frames(1)
	assert_eq(flow.state, FlowMain.State.TITLE)
	var title := flow.get_screen()
	assert_not_null(title)
	assert_true(title.has_signal(&"new_game_pressed"))
	assert_eq((title.get_parent() as CanvasLayer).layer, 30)


func test_level_uses_layers_10_and_20_and_emits_level_started() -> void:
	make_flow()
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	var exp_changed := watch_signal(EventBus.exp_changed)
	assert_true(await start_new_game())
	assert_eq(started.last_args(), [&"1-1"])
	assert_eq(exp_changed.last_args(), [0, 5], "HUD 拿到經驗初始值")
	assert_eq((flow.get_hud().get_parent() as CanvasLayer).layer, 10)
	assert_eq((flow.get_trick_choice().get_parent() as CanvasLayer).layer, 20)
	assert_eq((flow.get_pause_screen().get_parent() as CanvasLayer).layer, 20)
	assert_not_null(flow.get_arena())
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "新遊戲活力全滿")


func test_hud_exists_before_the_player_enters() -> void:
	make_flow()
	await wait_frames(1)
	var hud_ready_when_player_entered := [false]
	var on_vigor := func(_current: int, _maximum: int) -> void:
		var hud := flow.get_hud()
		hud_ready_when_player_entered[0] = hud != null and hud.is_inside_tree() and flow.get_session() != null
	EventBus.vigor_changed.connect(on_vigor)
	assert_true(await start_new_game())
	EventBus.vigor_changed.disconnect(on_vigor)
	assert_true(hud_ready_when_player_entered[0], "主角進場發 vigor_changed 時,HUD 已在場景樹內")
	assert_eq((flow.get_arena() as Node2D).global_position, Vector2.ZERO, "場地在世界原點")


func test_backgrounding_during_a_level_pauses_and_saves() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	SaveStore.new(SAVE_PATH).delete()
	var paused := watch_signal(EventBus.game_paused)
	AppLifecycle.simulate_background()
	assert_true(save_file_exists(), "切到背景時立即存檔(同步)")
	assert_eq(read_save()["level_index"], 0)
	assert_true(get_tree().paused, "戰鬥暫停")
	assert_true(flow.is_pause_open())
	assert_eq(paused.last_args(), [true])
	assert_true((flow.get_pause_screen() as CanvasItem).visible, "暫停選單出現")
	AppLifecycle.simulate_foreground()
	assert_true(get_tree().paused, "回到前景仍保持暫停,等玩家按繼續")
	EventBus.resume_requested.emit()
	assert_false(get_tree().paused)
	assert_eq(paused.last_args(), [false])


func test_clock_excludes_paused_time() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	AppLifecycle.simulate_back()
	var before := flow.get_session().time_sec
	var start := Time.get_ticks_msec()
	await wait_until(func() -> bool: return Time.get_ticks_msec() - start > 150)
	assert_almost_eq(flow.get_session().time_sec, before, 0.0001, "暫停時不計時")
	AppLifecycle.simulate_back()
	start = Time.get_ticks_msec()
	await wait_until(func() -> bool: return Time.get_ticks_msec() - start > 100)
	assert_true(flow.get_session().time_sec > before, "繼續後計時")


func test_back_button_in_level_toggles_pause() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var paused := watch_signal(EventBus.game_paused)
	AppLifecycle.simulate_back()
	assert_true(flow.is_pause_open())
	assert_true(get_tree().paused)
	AppLifecycle.simulate_back()
	assert_false(flow.is_pause_open(), "暫停中再按返回鍵 = 繼續")
	assert_false(get_tree().paused)
	assert_eq(paused.count, 2)


func test_back_is_ignored_while_choosing_a_trick() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var paused := watch_signal(EventBus.game_paused)
	var offered := watch_signal(EventBus.trick_offered)
	EventBus.exp_collected.emit(5)
	assert_true(flow.is_choice_open())
	assert_true(get_tree().paused, "升級時戰鬥暫停")
	await wait_frames(1)
	assert_eq(offered.count, 1)
	AppLifecycle.simulate_back()
	assert_false(flow.is_pause_open(), "選把戲時返回鍵無效")
	assert_eq(paused.count, 0, "選把戲不發 game_paused")
	AppLifecycle.simulate_background()
	assert_false(flow.is_pause_open(), "選把戲時切到背景:只存檔,不疊暫停選單")
	assert_true(get_tree().paused)
	AppLifecycle.simulate_foreground()
	var options: Array = offered.last_args()[0]
	EventBus.trick_chosen.emit((options[0] as TrickData).id)
	assert_false(get_tree().paused, "選完繼續")
	assert_eq(GameState.active_tricks, [(options[0] as TrickData).id] as Array[StringName])


func test_back_on_title_is_ignored_off_android() -> void:
	make_flow()
	await wait_frames(1)
	AppLifecycle.simulate_back()
	await wait_frames(1)
	assert_null(flow.get_quit_dialog())
	assert_eq(flow.state, FlowMain.State.TITLE)
	assert_eq(quit_calls, 0)


func test_back_on_title_asks_to_quit_on_android() -> void:
	make_flow()
	flow.platform_name = "Android"
	await wait_frames(1)
	AppLifecycle.simulate_back()
	assert_not_null(flow.get_quit_dialog(), "Android:詢問是否離開")
	AppLifecycle.simulate_back()
	assert_null(flow.get_quit_dialog(), "再按返回鍵 = 否")
	assert_eq(quit_calls, 0)
	AppLifecycle.simulate_back()
	var dialog := flow.get_quit_dialog()
	dialog.emit_signal(&"cancelled")
	await wait_frames(1)
	assert_null(flow.get_quit_dialog())
	AppLifecycle.simulate_back()
	flow.get_quit_dialog().emit_signal(&"confirmed")
	assert_eq(quit_calls, 1, "按「是」才離開")


func test_back_closes_credits() -> void:
	make_flow()
	await wait_frames(1)
	var title := flow.get_screen()
	title.emit_signal(&"credits_pressed")
	assert_true(await wait_until(func() -> bool: return flow.get_credits() != null and not flow.is_switching()))
	AppLifecycle.simulate_back()
	assert_true(await wait_until(func() -> bool: return flow.get_credits() == null and not flow.is_switching()))
	assert_eq(flow.state, FlowMain.State.TITLE)
	assert_eq(flow.get_screen(), title, "標題畫面一直都在")
	title.emit_signal(&"credits_pressed")
	assert_true(await wait_until(func() -> bool: return flow.get_credits() != null and not flow.is_switching()))
	flow.get_credits().emit_signal(&"closed")
	assert_true(await wait_until(func() -> bool: return flow.get_credits() == null and not flow.is_switching()))
	assert_eq(flow.state, FlowMain.State.TITLE)


func test_results_have_exactly_the_contract_keys() -> void:
	make_flow()
	await wait_frames(1)
	var completed := watch_signal(EventBus.level_completed)
	assert_true(await start_new_game())
	assert_true(await play_until_level_ends())
	assert_eq(completed.last_args(), [&"1-1"])
	var result := flow.get_last_result()
	var keys: Array = result.keys()
	keys.sort()
	var expected: Array = RESULT_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected)
	assert_eq(result["level_id"], &"1-1")
	assert_true(result["level_id"] is StringName)
	assert_eq(result["level_name"], "LEVEL_1_1", "翻譯鍵")
	assert_eq(result["victory"], true)
	assert_true(result["time_sec"] is float and result["time_sec"] > 0.0)
	var expected_kills := 0
	for wave: WaveData in (load("res://data/levels/level_1_1.tres") as LevelData).waves:
		for entry: SpawnEntry in wave.spawns:
			expected_kills += entry.count
	assert_eq(result["kills"], expected_kills, "1-1 的稻草人兵全部被擊倒")
	assert_true(result["tricks"] is Array)
	assert_eq((result["tricks"] as Array).size(), 2, "21 點經驗 → 升兩級 → 兩個把戲")
	assert_eq(result["hero_level"], 3)
	assert_eq(result["next_is_camp"], false)
	assert_eq(result["is_final"], false)
	assert_eq(result["difficulty"], &"normal", "v2.3:一般模式")
	var screen := flow.get_screen()
	assert_eq(screen.get(&"result"), result, "結算畫面收到 setup(result)")


func test_failure_flow_and_retry_restores_snapshot() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	GameState.next_level_bonus = 0.1
	# 這一關內升級並學會「搖尾巴」,之後倒下
	EventBus.exp_collected.emit(5)
	await wait_frames(1)
	var wag: TrickData = null
	for option in flow.progression.get_current_offer():
		wag = option
	EventBus.trick_chosen.emit(wag.id)
	assert_eq(GameState.hero_level, 2)
	var failed := watch_signal(EventBus.level_failed)
	flow.get_arena().call(&"debug_down_player")
	assert_eq(GameState.vigor, 0)
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	assert_eq(failed.last_args(), [&"1-1"])
	var result := flow.get_last_result()
	assert_eq(result["victory"], false)
	assert_eq(result["is_final"], false)
	assert_eq(result["next_is_camp"], false)
	var started := watch_signal(EventBus.level_started)
	var t0 := Time.get_ticks_msec()
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(_in_level, 2.0), "2 秒內回到戰鬥")
	assert_true(Time.get_ticks_msec() - t0 < 2000)
	assert_eq(started.last_args(), [&"1-1"])
	assert_eq(GameState.hero_level, 1, "還原這一關開始時的等級")
	assert_eq(GameState.active_tricks.size(), 0, "還原把戲")
	assert_almost_eq(GameState.player_stats.move_speed, 70.0, 0.001, "還原數值")
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "活力補滿")
	assert_almost_eq(GameState.next_level_bonus, 0.1, 0.0001, "失敗重試時保留下一關加成")
	assert_eq(flow.progression.get_exp(), 0)


func test_next_level_bonus_resets_after_completion() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	GameState.next_level_bonus = 0.15
	assert_true(await play_until_level_ends())
	assert_eq(flow.state, FlowMain.State.RESULTS)
	assert_almost_eq(GameState.next_level_bonus, 0.0, 0.0001, "過關後歸零")


func test_failure_title_button_returns_to_title() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"title_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	assert_true(flow.has_save() == false, "1-1 失敗:沒有可以繼續的進度")
	assert_false(get_tree().paused)


func test_quit_to_title_from_pause() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	AppLifecycle.simulate_back()
	assert_true(get_tree().paused)
	EventBus.quit_to_title_requested.emit()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	assert_false(get_tree().paused)
	assert_null(flow.get_arena())
	assert_eq(get_tree().get_node_count_in_group(&"enemy"), 0)


func test_camp_follows_level_1_2_and_bonus_carries_to_next_level() -> void:
	SaveStore.new(SAVE_PATH).write(1, 0, true)
	make_flow(true)
	await wait_frames(1)
	var entered := watch_signal(EventBus.camp_entered)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(_in_level))
	assert_eq(flow.get_level_index(), 1)
	assert_true(await play_until_level_ends())
	assert_eq(flow.get_last_result()["next_is_camp"], true)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.CAMP))
	assert_eq(entered.count, 1, "營地發 camp_entered")
	assert_null(flow.get_arena(), "營地時場地已移除")
	GameState.next_level_bonus = 0.1          # 小遊戲的獎勵(D 線設定)
	EventBus.camp_left.emit()
	assert_true(await wait_until(_in_level))
	assert_eq(flow.get_level_index(), 2)
	assert_almost_eq(GameState.next_level_bonus, 0.1, 0.0001, "加成帶到下一關")
	assert_eq(GameState.level_index, 2)
	assert_eq(read_save()["level_index"], 2)


func test_companion_joins_from_level_1_3() -> void:
	SaveStore.new(SAVE_PATH).write(2, 0, true)
	make_flow(true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(_in_level))
	await wait_frames(1)
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 1, "鬥牛犬加入")
	assert_eq(flow.get_session().arriving, [&"bulldog"] as Array[StringName], "1-3 才加入:畫面露出後出場")


func test_companion_is_already_there_after_1_3() -> void:
	SaveStore.new(SAVE_PATH).write(3, 0, true)
	make_flow(true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(_in_level))
	assert_eq(flow.get_session().arriving.size(), 0, "1-4 的鬥牛犬一開始就在場上")
	await wait_frames(1)
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 1)
