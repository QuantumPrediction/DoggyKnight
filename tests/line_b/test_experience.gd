extends "res://tests/line_b/flow_test_base.gd"
## B4 經驗與升級:門檻(第 2 級 5,之後每級 +3)、exp_mult 的小數、一次升好幾級時排隊選把戲。

var progression: RunProgression


func before_each() -> void:
	GameState.reset_run()
	if progression != null:
		remove_child(progression)
		progression.queue_free()
	progression = RunProgression.new()
	progression.setup(load(DIFFICULTY) as DifficultyData, 99)
	add_child(progression)
	progression.reset_run()
	progression.begin_level()


func test_thresholds_follow_the_curve() -> void:
	var curve := load(DIFFICULTY) as DifficultyData
	assert_eq(curve.exp_to_next(1), 5, "第 1 → 2 級")
	assert_eq(curve.exp_to_next(2), 8, "第 2 → 3 級")
	assert_eq(curve.exp_to_next(3), 11, "第 3 → 4 級")
	assert_eq(curve.exp_to_next(10), 32)


func test_level_up_exactly_at_threshold() -> void:
	var xp := HeroExperience.new(load(DIFFICULTY) as DifficultyData)
	assert_eq(xp.add(4), 0)
	assert_eq(xp.current(), 4)
	assert_eq(xp.needed(), 5)
	assert_eq(xp.add(1), 1, "第 5 點升到第 2 級")
	assert_eq(xp.level, 2)
	assert_eq(xp.current(), 0)
	assert_eq(xp.needed(), 8)


func test_overflow_carries_into_next_level_and_can_skip_levels() -> void:
	var xp := HeroExperience.new(load(DIFFICULTY) as DifficultyData)
	assert_eq(xp.add(15), 2, "15 = 5 + 8 + 2 → 升兩級")
	assert_eq(xp.level, 3)
	assert_eq(xp.current(), 2)


func test_fractional_exp_mult_is_kept() -> void:
	var xp := HeroExperience.new(load(DIFFICULTY) as DifficultyData)
	for i in 4:
		xp.add(1, 1.2)
	assert_eq(xp.level, 1, "4 × 1.2 = 4.8,還不夠")
	assert_eq(xp.current(), 4, "顯示整數部分")
	assert_eq(xp.add(1, 1.2), 1, "5 × 1.2 = 6.0 ≥ 5")
	assert_eq(xp.get_centi(), 100, "多出的 1.0 保留")


func test_exp_collected_applies_exp_mult_and_emits_exp_changed() -> void:
	GameState.player_stats.exp_mult = 1.5
	var changed := watch_signal(EventBus.exp_changed)
	EventBus.exp_collected.emit(2)
	assert_eq(changed.last_args(), [3, 5], "2 × 1.5 = 3")


func test_level_up_emits_signal_and_offers_tricks() -> void:
	var leveled := watch_signal(EventBus.leveled_up)
	var offered := watch_signal(EventBus.trick_offered)
	var opened := [0]
	progression.choice_opened.connect(func() -> void: opened[0] += 1)
	EventBus.exp_collected.emit(5)
	assert_eq(leveled.count, 1)
	assert_eq(leveled.last_args(), [2])
	assert_eq(GameState.hero_level, 2)
	assert_eq(opened[0], 1, "要求暫停")
	assert_true(progression.is_choice_open())
	await wait_frames(1)
	assert_eq(offered.count, 1)
	var options: Array = offered.last_args()[0]
	assert_eq(options.size(), 3)
	for option: Variant in options:
		assert_true(option is TrickData)


func test_multiple_level_ups_queue_one_choice_each() -> void:
	var leveled := watch_signal(EventBus.leveled_up)
	var offered := watch_signal(EventBus.trick_offered)
	var closed := [0]
	progression.choice_closed.connect(func() -> void: closed[0] += 1)
	EventBus.exp_collected.emit(13)     # 5 + 8 → 第 3 級
	assert_eq(leveled.count, 2)
	assert_eq(leveled.calls[0], [2])
	assert_eq(leveled.calls[1], [3])
	await wait_frames(1)
	assert_eq(offered.count, 1, "一次只出一組")
	EventBus.trick_chosen.emit((offered.last_args()[0][0] as TrickData).id)
	assert_eq(closed[0], 0, "還有一次升級沒選")
	assert_true(progression.is_choice_open())
	await wait_frames(1)
	assert_eq(offered.count, 2, "第二組")
	EventBus.trick_chosen.emit((offered.last_args()[0][1] as TrickData).id)
	assert_eq(closed[0], 1)
	assert_false(progression.is_choice_open())
	assert_eq(GameState.active_tricks.size(), 2)
	assert_eq(progression.tricks_this_level.size(), 2)


func test_trick_chosen_outside_an_offer_is_ignored() -> void:
	EventBus.trick_chosen.emit(&"sit")
	assert_eq(GameState.active_tricks.size(), 0)
	EventBus.exp_collected.emit(5)
	await wait_frames(1)
	EventBus.trick_chosen.emit(&"not_offered_trick")
	assert_eq(GameState.active_tricks.size(), 0, "不在選項內")
	assert_true(progression.is_choice_open())


func test_exp_outside_a_level_is_ignored() -> void:
	progression.end_level()
	var changed := watch_signal(EventBus.exp_changed)
	EventBus.exp_collected.emit(50)
	assert_eq(changed.count, 0)
	assert_eq(GameState.hero_level, 1)


func test_snapshot_restores_level_exp_stats_and_tricks() -> void:
	EventBus.exp_collected.emit(3)
	var snapshot := progression.take_snapshot()
	EventBus.exp_collected.emit(2)
	await wait_frames(1)
	var offer := progression.get_current_offer()
	EventBus.trick_chosen.emit(offer[0].id)
	GameState.player_stats.move_speed = 999.0
	progression.restore_snapshot(snapshot)
	assert_eq(GameState.hero_level, 1)
	assert_eq(progression.get_exp(), 3)
	assert_eq(GameState.active_tricks.size(), 0)
	assert_almost_eq(GameState.player_stats.move_speed, 70.0)
