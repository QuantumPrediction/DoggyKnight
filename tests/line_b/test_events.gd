extends "res://tests/line_b/flow_test_base.gd"
## v2.4 BV3:抉擇事件的資料、出現時機(中段兩波之間)、暫停到選完、效果、沒有介面時自動選第一項。

const LEVELS: Array[String] = [
	"res://data/levels/level_1_1.tres", "res://data/levels/level_1_2.tres", "res://data/levels/level_1_3.tres",
	"res://data/levels/level_1_4.tres", "res://data/levels/level_1_5.tres", "res://data/levels/level_1_6.tres",
]


func _wait_event() -> bool:
	return await wait_until(func() -> bool:
		if flow.state == FlowMain.State.LEVEL and not flow.is_event_open() and not flow.is_trick_choice_open():
			var arena := flow.get_arena()
			if arena != null:
				arena.call(&"debug_kill_all")
		if flow.is_trick_choice_open():
			var offer := flow.progression.get_current_offer()
			if not offer.is_empty():
				EventBus.trick_chosen.emit(offer[0].id)
		return flow.is_event_open())


func test_every_level_has_a_different_event_with_merlin_and_morgana() -> void:
	var table := LevelEventTable.load_default()
	assert_not_null(table, "data/levels/events.tres")
	var seen := {}
	for path in LEVELS:
		var level := load(path) as LevelData
		var event := table.event_for_level(level.id)
		assert_not_null(event, "%s 有事件" % level.id)
		if event == null:
			continue
		assert_false(seen.has(event.id), "每關不同")
		seen[event.id] = true
		var wave := table.trigger_wave(level)
		assert_true(wave >= 0 and wave < maxi(1, level.waves.size()), "%s 在中段(第 %d 波後)" % [level.id, wave])
		if level.waves.size() >= 2:
			assert_true(wave >= 1, "有兩波以上:在兩波之間")
	for event in table.events:
		assert_ne(tr(event.title), event.title, "i18n 有 %s" % event.title)
		assert_eq(event.options.size(), 2, "%s 兩個選項" % event.id)
		assert_eq(event.options[0].tone, "merlin", "第一項是梅林的祝福")
		assert_eq(event.options[1].tone, "morgana", "第二項是摩根娜的誘惑")
		for option in event.options:
			assert_ne(tr(option.title), option.title, "i18n 有 %s" % option.title)
			assert_ne(tr(option.desc), option.desc, "i18n 有 %s" % option.desc)
			assert_true(ResourceLoader.exists(option.icon), "圖示 %s" % option.icon)
			assert_false(option.effects.is_empty(), "%s 有效果" % option.title)
			for key: Variant in option.effects:
				assert_true(EventOption.KEYS.has(String(key)), "認識的效果 %s" % key)
			var offer := option.to_offer()
			assert_eq(offer.keys(), ["title", "desc", "icon", "tone"], "event_offered 的格式(DEV_PLAN 4.12)")
	assert_eq(table.endless_pool.size(), table.events.size(), "無盡試煉可以抽到所有事件")


func test_event_appears_between_waves_and_pauses_until_chosen() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	var offered := watch_signal(EventBus.event_offered)
	var cleared := watch_signal(EventBus.wave_cleared)
	assert_true(await start_new_game())
	assert_true(await _wait_event(), "1-1 第 1 波清空後出現事件")
	assert_eq(cleared.count, 1, "在第 1 波與第 2 波之間")
	assert_eq(offered.count, 1)
	assert_eq(offered.last_args()[0], &"sword_glow")
	var options: Array = offered.last_args()[1]
	assert_eq(options.size(), 2)
	assert_eq((options[0] as Dictionary)["tone"], "merlin")
	assert_eq((options[1] as Dictionary)["title"], "EVENT_SWORD_GLOW_MORGANA")
	assert_true(get_tree().paused, "選完之前遊戲暫停")
	assert_eq(flow.state, FlowMain.State.LEVEL)
	EventBus.back_requested.emit()
	assert_false(flow.is_pause_open(), "事件中返回鍵無效")
	await wait_frames(5)
	assert_true(flow.is_event_open(), "有介面時不會自動選")
	GameState.vigor = 5
	# 只會「點第一張卡」的試玩機器人:is_choice_open() 與 get_trick_choice() 也涵蓋事件
	assert_true(flow.is_choice_open())
	assert_false(flow.is_trick_choice_open())
	assert_eq(flow.get_trick_choice(), flow.get_event_ui())
	flow.get_trick_choice().call(&"choose", 0)
	assert_false(flow.is_event_open())
	assert_false(get_tree().paused)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "梅林:活力回滿")
	assert_true(await play_until_level_ends())
	assert_eq(offered.count, 1, "每關一次")
	assert_eq(flow.get_last_result()["event_tone"], "merlin")


func test_morgana_option_changes_stats_for_the_run_and_retry_restores() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await _wait_event())
	EventBus.event_chosen.emit(&"sword_glow", 1)
	assert_eq(GameState.player_stats.attack_damage, 13, "攻擊 +30%")
	assert_eq(GameState.player_stats.max_vigor, 80, "活力上限 −20%")
	assert_true(GameState.vigor <= 80)
	# 倒下 → 再試一次:事件的效果還原,事件再出現一次
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(GameState.player_stats.attack_damage, 10, "重試還原")
	assert_eq(GameState.player_stats.max_vigor, 100)
	assert_true(await _wait_event(), "重試時事件再出現")
	EventBus.event_chosen.emit(&"sword_glow", 1)
	assert_true(await play_until_level_ends())
	assert_true(await _next_level())
	assert_eq(GameState.player_stats.attack_damage, 13, "這一輪冒險都有效(下一關重算仍在)")


func _next_level() -> bool:
	flow.get_screen().emit_signal(&"continue_pressed")
	return await wait_until(in_level)


func test_event_waits_for_trick_choice_and_can_give_tricks() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	assert_true(await start_new_game())
	var session := flow.get_session()
	# 正在選把戲時事件排隊
	flow.progression.offer_bonus_choice(1)
	await wait_frames(1)
	assert_true(flow.is_trick_choice_open())
	var event := LevelEventTable.load_default().get_event(&"sausage")
	flow.level_events.offer(event)
	assert_false(flow.is_event_open(), "把戲選完才出現")
	EventBus.trick_chosen.emit(flow.progression.get_current_offer()[0].id)
	assert_true(await wait_until(flow.is_event_open), "接著出現事件")
	assert_true(get_tree().paused)
	EventBus.event_chosen.emit(&"sausage", 0)
	assert_false(flow.is_event_open())
	assert_true(flow.is_trick_choice_open(), "梅林:馬上學一個把戲(遊戲維持暫停)")
	assert_true(get_tree().paused)
	await wait_frames(1)
	EventBus.trick_chosen.emit(flow.progression.get_current_offer()[0].id)
	assert_false(get_tree().paused)
	assert_eq(flow.progression.tricks_this_level.size(), 2)
	assert_eq(flow.get_session(), session)


func test_effects_snacks_vigor_and_bonus_levels() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	assert_true(await start_new_game())
	var table := LevelEventTable.load_default()
	GameState.vigor = 80
	GameState.snacks = 0
	flow.level_events.offer(table.get_event(&"wheat_cart"))
	EventBus.event_chosen.emit(&"wheat_cart", 1)
	assert_eq(GameState.snacks, 25, "摩根娜:25 個零食")
	assert_eq(GameState.vigor, 40, "活力只剩一半")
	flow.level_events.offer(table.get_event(&"wheat_cart"))
	EventBus.event_chosen.emit(&"wheat_cart", 0)
	assert_eq(flow.progression.bonus_trick_levels, 1, "梅林:下一個把戲升兩級")
	EventBus.event_chosen.emit(&"wheat_cart", 0)
	assert_eq(flow.progression.bonus_trick_levels, 1, "沒有開著的事件:不理會")


func test_without_event_ui_the_first_option_is_picked_automatically() -> void:
	make_flow(false, 1234, false, true)
	await wait_frames(1)
	assert_true(await start_new_game())
	flow.get_event_ui().queue_free()
	flow.level_events.has_ui = false
	var chosen := watch_signal(EventBus.event_offered)
	flow.level_events.offer(LevelEventTable.load_default().get_event(&"moon_pool"))
	assert_true(flow.is_event_open())
	assert_true(await wait_until(func() -> bool: return not flow.is_event_open(), 3.0), "約 0.5 秒後自動選")
	assert_eq(chosen.count, 1)
	assert_eq(flow.level_events.last_choice.get("tone"), "merlin", "自動選第一項(梅林)")
	assert_false(get_tree().paused)


func test_boss_level_event_comes_after_the_intro() -> void:
	var table := LevelEventTable.load_default()
	var boss := load(LEVELS[5]) as LevelData
	assert_eq(table.trigger_wave(boss), 0, "1-6 只有一波:開場之後")
	var session := LevelSession.new()
	var due := watch_signal(session.event_due)
	session.event_after_wave = 0
	session.state = LevelSession.State.PLAYING
	session.call(&"_on_wave_began", 1)
	assert_eq(due.count, 1)
	assert_eq(due.last_args(), [0])
	session.free()
