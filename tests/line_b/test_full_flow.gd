extends "res://tests/line_b/flow_test_base.gd"
## 從新遊戲一路玩到打敗黑騎士(headless):用替身場地打倒敵人、經 EventBus 選把戲、
## 經 EventBus 離開營地,直到最後的結算(is_final)回到標題。六關、兩次營地。


func test_new_game_to_final_results() -> void:
	make_flow()
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	var completed := watch_signal(EventBus.level_completed)
	var failed := watch_signal(EventBus.level_failed)
	var camps := watch_signal(EventBus.camp_entered)
	var leveled := watch_signal(EventBus.leveled_up)
	var offered := watch_signal(EventBus.trick_offered)
	var results: Array[Dictionary] = []
	var in_camp_after: Array[int] = []

	flow.get_screen().emit_signal(&"new_game_pressed")
	var finished := await wait_until(func() -> bool:
		match flow.state:
			FlowMain.State.LEVEL:
				_auto_step()
			FlowMain.State.RESULTS:
				var result := flow.get_last_result()
				if results.is_empty() or results.back()["level_id"] != result["level_id"]:
					results.append(result)
					flow.get_screen().emit_signal(&"continue_pressed")
			FlowMain.State.CAMP:
				if not in_camp_after.has(flow.get_level_index()):
					in_camp_after.append(flow.get_level_index())
					EventBus.camp_left.emit()
			FlowMain.State.TITLE:
				return started.count > 0
		return false, 60.0)

	assert_true(finished, "在時限內玩完")
	assert_eq(started.count, 6, "六關")
	assert_eq(completed.count, 6)
	assert_eq(failed.count, 0)
	assert_eq(camps.count, 2, "兩次營地")
	assert_eq(in_camp_after, [1, 3] as Array[int], "1-2 與 1-4 之後")
	assert_eq(results.size(), 6)
	var ids: Array = results.map(func(r: Dictionary) -> StringName: return r["level_id"])
	assert_eq(ids, [&"1-1", &"1-2", &"1-3", &"1-4", &"1-5", &"1-6"])
	for i in results.size():
		assert_eq(results[i]["next_is_camp"], i == 1 or i == 3, "%s next_is_camp" % ids[i])
		assert_eq(results[i]["is_final"], i == 5, "%s is_final" % ids[i])
		assert_eq(results[i]["victory"], true)
	assert_eq(leveled.count, offered.count, "每升一級都有一次把戲選擇")
	assert_eq(GameState.active_tricks.size(), leveled.count, "每次選擇都記進 active_tricks")
	assert_true(leveled.count >= 6 and leveled.count <= 12, "整章升 %d 級(一關 1 至 2 級)" % leveled.count)
	assert_eq(flow.state, FlowMain.State.TITLE, "打敗黑騎士後回到標題")
	assert_false(flow.has_save(), "整章完成:沒有要繼續的關卡")
	assert_false(get_tree().paused)
