extends "res://tests/line_b/flow_test_base.gd"

func after_each() -> void:
	GameState.hero_class = &"knight"
	await super()

func test_continue_restores_saved_class_instead_of_title_candidate() -> void:
	SaveStore.new(SAVE_PATH).write_data({"hero_class": "mage", "level_index": 2})
	make_flow(true)
	await wait_frames(2)
	GameState.hero_class = &"archer"
	flow.continue_game()
	assert_true(await wait_until(flow.is_level_running))
	assert_eq(GameState.hero_class, &"mage")
	assert_eq(GameState.player_stats.max_vigor, 75)
	flow.save_now()
	assert_eq(read_save()["hero_class"], "mage")

func test_retry_preserves_archer_stats_and_class() -> void:
	make_flow()
	await wait_frames(1)
	GameState.hero_class = &"archer"
	assert_true(await start_new_game())
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(flow.is_level_running))
	assert_eq(GameState.hero_class, &"archer")
	assert_eq(GameState.player_stats.max_vigor, 85)
	assert_eq(read_save()["hero_class"], "archer")

func test_endless_class_does_not_overwrite_story_class() -> void:
	SaveStore.new(SAVE_PATH).write_data({"hero_class": "mage", "level_index": 2,
		"chapter_cleared": true, "chapters_cleared": 1})
	make_flow(true)
	await wait_frames(1)
	GameState.hero_class = &"archer"
	flow.start_endless()
	assert_true(await wait_until(flow.is_level_running))
	assert_eq(GameState.hero_class, &"archer")
	flow.save_now()
	assert_eq(read_save()["hero_class"], "mage")
	flow.show_title()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE and not flow.is_switching()))
	flow.continue_game()
	assert_true(await wait_until(flow.is_level_running))
	assert_eq(GameState.hero_class, &"mage")
