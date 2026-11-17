extends "res://tests/line_b/flow_test_base.gd"
## v2.4 BV6 無盡試煉:波次產生(越來越強、全部敵人、每 5 波頭目)、每 10 波事件、倒下結束、最佳紀錄。

const ENDLESS: String = "res://data/levels/endless.tres"
const ALL_ENEMIES: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_archer", &"scarecrow_elite",
		&"armored_husk", &"scarecrow_captain", &"black_knight"]


func _data() -> EndlessData:
	return load(ENDLESS) as EndlessData


func _gen(rng_seed: int = 3) -> EndlessWaves:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return EndlessWaves.new(_data(), rng)


func _count(wave: WaveData) -> int:
	var n := 0
	for e in wave.spawns:
		n += e.count
	return n


func _budget(wave: WaveData, data: EndlessData) -> int:
	var total := 0
	for e in wave.spawns:
		var i := data.enemy_ids.find(e.enemy_id)
		total += e.count * (data.enemy_costs[i] if i >= 0 else 0)
	return total


func _start_endless() -> bool:
	GameState.chapter_cleared = true
	var fast := _data().duplicate() as EndlessData
	fast.group_gap = 0.0          # 測試:每組同時出場
	flow.endless_data = fast
	flow.get_screen().call(&"_endless")
	return await wait_until(in_level)


func test_generated_waves_escalate_and_use_every_enemy() -> void:
	var data := _data()
	var gen := _gen()
	var seen := {}
	var early := 0
	var late := 0
	for n in range(1, 31):
		var wave := gen.make_wave(n)
		assert_false(wave.spawns.is_empty(), "第 %d 波有敵人" % n)
		for e in wave.spawns:
			seen[e.enemy_id] = true
			assert_true(ALL_ENEMIES.has(e.enemy_id), "認識的敵人 %s" % e.enemy_id)
			assert_true(WaveSpawner.PATTERNS.has(e.pattern))
			assert_true(e.count > 0)
		var boss := data.boss_for_wave(n)
		if boss != &"":
			var ids := wave.spawns.map(func(e: SpawnEntry) -> StringName: return e.enemy_id)
			assert_true(ids.has(boss), "第 %d 波是頭目波 %s" % [n, boss])
		else:
			if n <= 4:
				early += _budget(wave, data)
			elif n >= 26:
				late += _budget(wave, data)
			assert_true(_count(wave) <= data.max_enemies_per_wave)
	for id in ALL_ENEMIES:
		assert_true(seen.has(id), "會出現 %s" % id)
	assert_true(late > early * 2, "越來越強(第 1 至 4 波 %d,第 26 至 29 波 %d)" % [early, late])
	assert_eq(data.boss_for_wave(5), &"scarecrow_captain", "每 5 波:中頭目")
	assert_eq(data.boss_for_wave(10), &"black_knight", "每 10 波:頭目")
	assert_eq(data.boss_for_wave(7), &"")
	assert_true(data.is_event_wave(10) and data.is_event_wave(20) and not data.is_event_wave(5))


func test_same_seed_same_waves_and_random_background() -> void:
	var a := _gen(9).make_level()
	var b := _gen(9).make_level()
	assert_eq(a.background, b.background)
	assert_eq(a.id, &"endless")
	assert_eq(a.display_name, "LEVEL_ENDLESS")
	assert_ne(tr(a.display_name), a.display_name)
	assert_eq(a.companions, [&"bulldog"] as Array[StringName])
	var backgrounds := {}
	for s in 40:
		backgrounds[_gen(s + 1).make_level().background] = true
	assert_true(backgrounds.size() >= 4, "背景隨機(%d 種)" % backgrounds.size())


func test_endless_run_goes_on_and_records_best() -> void:
	make_flow()
	await wait_frames(1)
	GameState.endless_best = 1
	GameState.snacks = 0
	var waves := watch_signal(EventBus.wave_started)
	var started := watch_signal(EventBus.level_started)
	assert_true(await _start_endless())
	assert_true(flow.is_endless())
	assert_eq(GameState.mode, &"endless")
	assert_eq(started.last_args(), [&"endless"])
	assert_eq(read_save()["level_index"], 0, "故事進度不受影響")
	assert_true(await wait_until(func() -> bool:
		if flow.is_choice_open():
			EventBus.trick_chosen.emit(flow.progression.get_current_offer()[0].id)
		elif flow.state == FlowMain.State.LEVEL:
			flow.get_arena().call(&"debug_kill_all")
		return flow.get_session().waves_cleared >= 6, 20.0), "一波接一波")
	assert_eq(waves.last_args()[1], 0, "無盡試煉的 total = 0")
	assert_true(flow.get_session().level.waves.size() > 6, "永遠有下一波")
	assert_eq(GameState.endless_best, 1, "倒下之前不改 GameState.endless_best(HUD 比較新紀錄)")
	assert_true(int(read_save()["endless_best"]) >= 6, "但每清一波都存檔")
	assert_true(GameState.snacks >= 6 + EconomyData.new().endless_boss_wave_snacks, "每波零食,頭目波另加")
	# 倒下就結束
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	var result := flow.get_last_result()
	assert_eq(result["mode"], &"endless")
	assert_eq(result["level_id"], &"endless")
	assert_true(result["endless_wave"] >= 6)
	assert_eq(GameState.endless_best, result["endless_wave"], "倒下時更新紀錄")
	assert_eq(result["endless_best"], GameState.endless_best)
	assert_true(result["endless_new_best"])
	assert_eq(result["snacks_earned"], flow.rewards.snacks_this_level)
	# 回標題:回到故事模式
	flow.get_screen().emit_signal(&"title_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE and not flow.is_switching()))
	assert_eq(GameState.mode, &"story")
	assert_eq(GameState.difficulty, &"normal")


func test_endless_event_every_ten_waves() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	var offered := watch_signal(EventBus.event_offered)
	assert_true(await _start_endless())
	assert_true(await wait_until(func() -> bool:
		if flow.is_choice_open():
			EventBus.trick_chosen.emit(flow.progression.get_current_offer()[0].id)
		elif flow.state == FlowMain.State.LEVEL and not flow.is_event_open():
			flow.get_arena().call(&"debug_kill_all")
		return flow.is_event_open() or flow.get_session().waves_cleared > 10, 30.0))
	assert_true(flow.is_event_open(), "第 10 波後有事件")
	assert_eq(flow.get_session().waves_cleared, 10)
	assert_eq(offered.count, 1, "前 9 波沒有事件")
	assert_true(LevelEventTable.load_default().endless_pool.has(offered.last_args()[0]))
	EventBus.event_chosen.emit(offered.last_args()[0], 0)
	assert_false(get_tree().paused)


func test_endless_retry_starts_a_new_run_and_title_button_needs_chapter_cleared() -> void:
	make_flow()
	await wait_frames(1)
	GameState.chapter_cleared = false
	GameState.mode = &"endless"
	flow.get_screen().emit_signal(&"endless_pressed")
	await wait_frames(5)
	assert_eq(flow.state, FlowMain.State.TITLE, "還沒打完第一章:不能玩無盡試煉")
	assert_eq(GameState.mode, &"story")
	assert_true(await _start_endless())
	flow.get_arena().call(&"debug_kill_all")
	EventBus.trick_chosen.emit(&"none")
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	var old_session := flow.get_session()
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_ne(flow.get_session(), old_session)
	assert_true(flow.is_endless(), "再試一次 = 新的一輪無盡試煉")
	assert_eq(flow.get_session().waves_cleared, 0)


func test_endless_switches_to_hard_scaling_late() -> void:
	var data := _data()
	assert_true(data.hard_from_wave > 10, "後段才用困難模式的倍數")
	make_flow()
	await wait_frames(1)
	assert_true(await _start_endless())
	flow.get_session().waves_cleared = data.hard_from_wave - 1
	flow.call(&"_on_endless_wave_done", data.hard_from_wave - 1)
	assert_eq(GameState.difficulty, &"hard")
	flow.get_screen()
	EventBus.quit_to_title_requested.emit()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE and not flow.is_switching()))
	assert_eq(GameState.difficulty, &"normal", "回標題時還原")
	assert_eq(GameState.endless_best, data.hard_from_wave - 1, "從暫停選單回標題也記錄")

