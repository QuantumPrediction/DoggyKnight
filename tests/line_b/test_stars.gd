extends "res://tests/line_b/flow_test_base.gd"
## BP3 星級:計算規則、目標文字、結算資料的新鍵、最佳星數(GameState 與存檔)、六關的門檻。

const LEVEL_FILES: Array[String] = [
	"res://data/levels/level_1_1.tres", "res://data/levels/level_1_2.tres", "res://data/levels/level_1_3.tres",
	"res://data/levels/level_1_4.tres", "res://data/levels/level_1_5.tres", "res://data/levels/level_1_6.tres",
]


func _level(par: float, budget: int) -> LevelData:
	var level := LevelData.new()
	level.id = &"test"
	level.par_time = par
	level.damage_budget = budget
	return level


func _met(goals: Array) -> Array:
	return goals.map(func(g: Dictionary) -> bool: return g["met"])


func test_each_goal_is_one_star() -> void:
	var level := _level(60.0, 20)
	assert_eq(StarRating.count(StarRating.goals(level, true, 45.0, 10)), 3, "快又沒怎麼受傷")
	assert_eq(StarRating.count(StarRating.goals(level, true, 60.0, 20)), 3, "剛好等於門檻也算")
	assert_eq(_met(StarRating.goals(level, true, 61.0, 0)), [true, false, true], "太慢:沒有時間星")
	assert_eq(_met(StarRating.goals(level, true, 30.0, 21)), [true, true, false], "受傷太多:沒有傷害星")
	assert_eq(StarRating.count(StarRating.goals(level, true, 99.0, 99)), 1, "過關至少一顆星")
	assert_eq(_met(StarRating.goals(level, false, 10.0, 0)), [false, false, false], "失敗:0 星")
	assert_eq(StarRating.count(StarRating.goals(level, false, 10.0, 0)), 0)


func test_goals_are_in_contract_order_with_translated_text() -> void:
	var goals := StarRating.goals(_level(65.0, 24), true, 10.0, 0)
	var keys: Array = goals.map(func(g: Dictionary) -> String: return g["key"])
	assert_eq(keys, ["STAR_CLEAR", "STAR_TIME", "STAR_DAMAGE"], "依序:過關、時間、傷害")
	for goal: Dictionary in goals:
		assert_true(goal.has("key") and goal.has("met") and goal.has("value") and goal.has("text"))
		assert_true((goal["key"] as String).begins_with("STAR_"))
		assert_ne(tr(goal["key"]), goal["key"], "i18n 有 %s" % goal["key"])
		assert_false((goal["text"] as String).contains("%"), "text 已填好數字:%s" % goal["text"])
	assert_eq(goals[1]["value"], 65)
	assert_true((goals[1]["text"] as String).contains("65"), "時間目標顯示秒數")
	assert_eq(goals[2]["value"], 24)
	assert_true((goals[2]["text"] as String).contains("24"), "傷害目標顯示點數")
	assert_true(tr("STAR_TIME").contains("%d"), "STAR_TIME 有一個 %d 給介面填入秒數")
	var untouched := StarRating.goals(_level(65.0, 0), true, 10.0, 0)
	assert_eq(untouched[2]["key"], "STAR_NO_DAMAGE", "門檻 0:不被打中")
	assert_false(tr("STAR_NO_DAMAGE").contains("%"))
	assert_true(untouched[2]["met"])


func test_all_levels_have_star_thresholds() -> void:
	for path in LEVEL_FILES:
		var level := load(path) as LevelData
		assert_true(level.par_time >= 30.0 and level.par_time <= 120.0, "%s par_time %.0f" % [level.id, level.par_time])
		assert_true(level.damage_budget >= 8 and level.damage_budget <= 80,
				"%s damage_budget %d" % [level.id, level.damage_budget])


func test_results_carry_stars_and_best_is_saved() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_eq(result["victory"], true)
	assert_eq(result["stars"], 3, "替身戰鬥:很快、沒受傷")
	assert_eq((result["star_goals"] as Array).size(), 3)
	assert_eq(result["best_stars"], 3)
	assert_false(result["new_best"], "第一次過關不算「新紀錄」")
	assert_eq(result["level_index"], 0)
	assert_eq(result["level_count"], 6)
	assert_eq(result["damage_taken"], 0)
	assert_eq(GameState.best_stars.get("1-1", -1), 3, "最佳星數寫回 GameState")
	assert_eq(read_save()["best_stars"], {"1-1": 3}, "最佳星數已存檔")


func test_damage_taken_costs_the_third_star() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var budget := flow.get_session().level.damage_budget
	EventBus.player_damaged.emit(budget + 1)
	assert_eq(flow.get_session().damage_taken, budget + 1)
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_eq(result["stars"], 2)
	assert_eq(_met(result["star_goals"]), [true, true, false])
	assert_eq(result["damage_taken"], budget + 1)


func test_new_best_only_when_improving_and_best_never_drops() -> void:
	GameState.best_stars = {"1-1": 2}
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_eq(result["stars"], 3)
	assert_true(result["new_best"], "2 星 → 3 星:新紀錄")
	assert_eq(result["best_stars"], 3)
	# 再玩一次,這次受傷太多:只有 2 星,最佳仍是 3
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	EventBus.quit_to_title_requested.emit()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	assert_true(await start_new_game())
	EventBus.player_damaged.emit(999)
	assert_true(await play_until_level_ends())
	result = flow.get_last_result()
	assert_eq(result["stars"], 2)
	assert_false(result["new_best"])
	assert_eq(result["best_stars"], 3, "最佳星數不會變少")
	assert_eq(GameState.best_stars["1-1"], 3)


func test_failure_result_has_zero_stars_and_keeps_best() -> void:
	GameState.best_stars = {"1-1": 2}
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	var result := flow.get_last_result()
	assert_eq(result["stars"], 0)
	assert_eq(_met(result["star_goals"]), [false, false, false])
	assert_eq(result["best_stars"], 2)
	assert_false(result["new_best"])
	assert_eq(GameState.best_stars["1-1"], 2)
