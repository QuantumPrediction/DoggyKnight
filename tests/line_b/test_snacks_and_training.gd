extends "res://tests/line_b/flow_test_base.gd"
## v2.4 BV2、BV4、BV5:零食(擊倒、寶箱、過關)、snacks_changed、復活、營地訓練資料與套用、存檔第 4 版。

const ECONOMY: String = "res://data/progression/economy.tres"


func _economy() -> EconomyData:
	return load(ECONOMY) as EconomyData


func _down_and_wait_failure() -> bool:
	flow.get_arena().call(&"debug_down_player")
	return await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE)


func test_meta_upgrade_table_matches_the_contract() -> void:
	var table := MetaUpgradeTable.load_default()
	assert_not_null(table, "data/progression/meta_upgrades.tres")
	var ids: Array[StringName] = []
	for entry in table.entries:
		ids.append(entry.id)
		var key := String(entry.id).to_upper()
		assert_eq(entry.name_key, "TRAINING_%s_NAME" % key, "名稱鍵(D 線寫文字)")
		assert_eq(entry.desc_key, "TRAINING_%s_DESC" % key)
		assert_eq(entry.max_level, 5)
		assert_eq(entry.costs.size(), 5, "%s 每級一個價格" % entry.id)
		for i in range(1, entry.costs.size()):
			assert_true(entry.costs[i] > entry.costs[i - 1], "%s 價格逐級上升" % entry.id)
		assert_true(entry.per_level > 0.0)
	assert_eq(ids, MetaUpgradeTable.IDS)


func test_purchase_spends_snacks_and_emits_snacks_changed() -> void:
	var table := MetaUpgradeTable.load_default()
	var changed := watch_signal(EventBus.snacks_changed)
	GameState.snacks = 5
	assert_false(table.purchase(&"strength"), "零食不夠")
	assert_eq(GameState.snacks, 5)
	GameState.snacks = 100
	var cost := table.next_cost(&"strength")
	assert_true(table.purchase(&"strength"))
	assert_eq(GameState.snacks, 100 - cost)
	assert_eq(table.level_of(&"strength"), 1)
	assert_eq(GameState.meta_upgrades[&"strength"], 1)
	assert_eq(changed.last_args(), [100 - cost])
	GameState.meta_upgrades[&"luck"] = 5
	assert_true(table.is_maxed(&"luck"))
	assert_eq(table.next_cost(&"luck"), -1)
	GameState.snacks = 9999
	assert_false(table.purchase(&"luck"), "滿級不能再買")
	assert_almost_eq(MetaUpgradeTable.current_bonus(&"luck"), 5 * table.get_entry(&"luck").per_level, 0.0001)


func test_meta_upgrades_apply_after_reset_run_on_new_game() -> void:
	GameState.meta_upgrades = {&"vitality": 2, &"strength": 5, &"agility": 1, &"loyalty": 3}
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var table := MetaUpgradeTable.load_default()
	var base := GameState.BASE_STATS
	assert_eq(GameState.player_stats.max_vigor,
			roundi(base.max_vigor * (1.0 + 2 * table.get_entry(&"vitality").per_level)), "活力上限")
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "新遊戲活力補滿(含訓練)")
	assert_eq(GameState.player_stats.attack_damage,
			roundi(base.attack_damage * (1.0 + 5 * table.get_entry(&"strength").per_level)), "攻擊")
	assert_almost_eq(GameState.player_stats.move_speed,
			base.move_speed * (1.0 + table.get_entry(&"agility").per_level), 0.01, "速度")
	assert_eq(GameState.meta_upgrades[&"loyalty"], 3, "reset_run 不重設訓練")


func test_save_v4_round_trip_and_old_saves_load() -> void:
	var store := SaveStore.new(SAVE_PATH)
	store.write_data({"level_index": 2, "snacks": 37, "meta_upgrades": {&"strength": 2, "luck": 9.0, "bad": "x"},
			"endless_best": 14})
	var data := store.read()
	assert_eq(data["version"], SaveStore.VERSION, "寫入的是目前的版本(v2.7 起第 6 版)")
	assert_eq(data["snacks"], 37)
	assert_eq(data["meta_upgrades"], {"strength": 2, "luck": 9})
	assert_eq(data["endless_best"], 14)
	# 第 3 版存檔:沒有新欄位 → 預設值
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 3, "level_index": 1, "snacks": 5}))
	file.close()
	data = store.read()
	assert_eq(data["meta_upgrades"], {})
	assert_eq(data["endless_best"], 0)
	assert_eq(data["snacks"], 5)
	# 讀進 GameState
	store.write_data({"level_index": 1, "snacks": 12, "meta_upgrades": {"agility": 3}, "endless_best": 7})
	make_flow(true)
	await wait_frames(1)
	assert_eq(GameState.snacks, 12)
	assert_eq(GameState.meta_upgrades, {&"agility": 3})
	assert_eq(GameState.endless_best, 7)
	assert_eq(MetaUpgradeTable.load_default().level_of(&"agility"), 3)


func test_snacks_from_drops_kills_and_clear_are_saved() -> void:
	make_flow()
	await wait_frames(1)
	var changed := watch_signal(EventBus.snacks_changed)
	assert_true(await start_new_game())
	assert_eq(changed.count, 1, "關卡開始時發一次(HUD 初始值)")
	EventBus.snack_collected.emit(3)
	assert_eq(GameState.snacks, 3)
	assert_eq(changed.last_args(), [3])
	var economy := _economy()
	for i in economy.kills_per_snack:
		EventBus.enemy_died.emit(&"scarecrow", Vector2.ZERO, 1)
	assert_eq(GameState.snacks, 4, "每 %d 隻 +1" % economy.kills_per_snack)
	var before := GameState.snacks
	assert_true(await play_until_level_ends())
	var result := flow.get_last_result()
	assert_true(result["victory"])
	var bonus := economy.clear_reward(result["stars"], false)
	assert_eq(result["snack_bonus"], bonus)
	assert_true(GameState.snacks >= before + bonus, "過關依星數給零食")
	assert_eq(result["snacks"], GameState.snacks)
	assert_eq(result["snacks_earned"], GameState.snacks, "這一關得到的(由 0 開始)")
	assert_eq(read_save()["snacks"], GameState.snacks, "過關存檔")


func test_clear_reward_uses_stars_and_hard_mode() -> void:
	var e := _economy()
	assert_eq(e.clear_reward(0, false), e.clear_snacks)
	assert_eq(e.clear_reward(3, false), e.clear_snacks + 3 * e.snacks_per_star)
	assert_eq(e.clear_reward(3, true), roundi((e.clear_snacks + 3 * e.snacks_per_star) * e.hard_snack_mult))
	assert_true(e.revive_cost(5) > e.revive_cost(0), "後面的關卡復活比較貴")


func test_normal_chest_heals_or_gives_snacks() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var e := _economy()
	GameState.snacks = 0
	EventBus.chest_collected.emit(0)
	assert_eq(GameState.snacks, e.chest_snack_amount(0), "活力滿:一定是零食")
	var healed := 0
	var snacked := 0
	for i in 30:
		GameState.vigor = 10
		var snacks := GameState.snacks
		EventBus.chest_collected.emit(0)
		if GameState.vigor > 10:
			healed += 1
			assert_eq(GameState.vigor, 10 + ceili(GameState.player_stats.max_vigor * e.chest_heal_ratio))
		elif GameState.snacks > snacks:
			snacked += 1
	assert_true(healed > 0 and snacked > 0, "回復與零食都會出現(%d / %d)" % [healed, snacked])
	assert_false(flow.is_trick_choice_open(), "普通寶箱不給把戲")


func test_elite_chest_offers_a_trick_choice() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var offered := watch_signal(EventBus.trick_offered)
	GameState.snacks = 0
	EventBus.chest_collected.emit(1)
	assert_true(flow.is_trick_choice_open(), "精英寶箱:把戲三選一")
	assert_true(get_tree().paused)
	await wait_frames(1)
	assert_eq(offered.count, 1)
	assert_eq(GameState.snacks, _economy().chest_snack_amount(1))
	var options: Array = offered.last_args()[0]
	EventBus.trick_chosen.emit((options[0] as TrickData).id)
	assert_false(flow.is_trick_choice_open())
	assert_false(get_tree().paused)
	assert_eq(flow.progression.tricks_this_level.size(), 1)


func test_chest_outside_a_level_is_ignored() -> void:
	make_flow()
	await wait_frames(1)
	EventBus.chest_collected.emit(2)
	EventBus.snack_collected.emit(5)
	assert_eq(GameState.snacks, 0, "標題畫面:不算")


func test_revive_spends_snacks_and_returns_to_the_same_fight() -> void:
	make_flow()
	await wait_frames(1)
	var cost := _economy().revive_cost(0)
	GameState.snacks = cost + 40
	assert_true(await start_new_game())
	await wait_frames(3)
	var session := flow.get_session()
	var level_started := watch_signal(EventBus.level_started)
	assert_true(await _down_and_wait_failure())
	var result := flow.get_last_result()
	assert_eq(result["revive_cost"], cost)
	assert_true(result["can_revive"], "零食夠:可以復活")
	var kills := session.kills
	var time_sec := session.time_sec
	flow.get_screen().emit_signal(&"revive_pressed")
	assert_eq(flow.state, FlowMain.State.LEVEL, "回到戰鬥")
	assert_eq(flow.get_session(), session, "同一關,不重新開始")
	assert_eq(GameState.snacks, 40, "扣零食")
	assert_eq(read_save()["snacks"], 40, "立即存檔")
	assert_false(flow.get_arena().call(&"get_player").get(&"downed"), "金毛醒來")
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor)
	assert_eq(level_started.count, 0, "不重發 level_started")
	assert_eq(session.kills, kills)
	assert_true(session.time_sec >= time_sec)
	await wait_frames(2)
	assert_true(session.is_playing())
	assert_false(get_tree().paused)
	# 同一關第二次倒下:不能再復活
	assert_true(await _down_and_wait_failure())
	assert_false(flow.get_last_result()["can_revive"], "每關一次")
	flow.get_screen().emit_signal(&"revive_pressed")
	assert_eq(flow.state, FlowMain.State.FAILURE, "按了也沒用")
	assert_eq(GameState.snacks, 40)
	# 再試一次之後又可以復活
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_true(await _down_and_wait_failure())
	assert_true(flow.get_last_result()["can_revive"], "重試 = 新的一次")


func test_cannot_revive_without_enough_snacks() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	GameState.snacks = _economy().revive_cost(0) - 1
	assert_true(await _down_and_wait_failure())
	assert_false(flow.get_last_result()["can_revive"])
	flow.get_screen().emit_signal(&"revive_pressed")
	assert_eq(flow.state, FlowMain.State.FAILURE)


func test_revive_keeps_the_waves_going_until_the_level_is_cleared() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	GameState.snacks = 100
	assert_true(await _down_and_wait_failure())
	flow.get_screen().emit_signal(&"revive_pressed")
	assert_true(await play_until_level_ends())
	assert_eq(flow.state, FlowMain.State.RESULTS, "復活後照樣可以過關")


func test_training_opens_from_title_and_saves_on_close() -> void:
	make_flow()
	await wait_frames(1)
	GameState.snacks = 200
	flow.get_screen().emit_signal(&"training_pressed")
	assert_true(await wait_until(func() -> bool: return flow.get_training() != null and not flow.is_switching()))
	var training := flow.get_training()
	assert_eq((training.get_parent() as CanvasLayer).layer, 30)
	assert_true(training.call(&"buy", &"vitality"))
	flow.get_screen().emit_signal(&"new_game_pressed")
	await wait_frames(3)
	assert_eq(flow.state, FlowMain.State.TITLE, "訓練開著時標題的按鈕無效")
	EventBus.back_requested.emit()
	assert_true(await wait_until(func() -> bool: return flow.get_training() == null and not flow.is_switching()))
	assert_eq(read_save()["meta_upgrades"], {"vitality": 1}, "關閉時存檔")
	assert_eq(read_save()["snacks"], 200 - MetaUpgradeTable.load_default().get_entry(&"vitality").costs[0])
	assert_true(await start_new_game())
	assert_true(GameState.player_stats.max_vigor > GameState.BASE_STATS.max_vigor, "下一輪就生效")


func test_boss_chest_after_the_fight_becomes_snacks() -> void:
	var progression := RunProgression.new()
	progression.setup(load(DIFFICULTY) as DifficultyData, 5)
	add_child(progression)
	var rewards := RunRewards.new()
	rewards.setup(_economy(), progression, 5)
	add_child(rewards)
	rewards.begin_level()         # 寶箱還算(結算畫面之前)
	progression.end_level()       # 但已經不能選把戲
	GameState.snacks = 0
	EventBus.chest_collected.emit(2)
	assert_false(progression.is_choice_open())
	assert_eq(GameState.snacks, _economy().chest_snack_amount(2) * 2, "把戲換成零食")
	EventBus.snack_collected.emit(1)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "B 線不做挖寶的回復(A 線做)")
	rewards.queue_free()
	progression.queue_free()
