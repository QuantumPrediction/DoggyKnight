extends "res://tests/line_b/flow_test_base.gd"

func test_production_first_event_chooses_route_and_retry_restores_boundary() -> void:
	make_flow(false, 1234, false, true)
	GameState.hero_class = &"knight"
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await wait_until(func() -> bool:
		if flow.is_trick_choice_open():
			EventBus.trick_chosen.emit(flow.progression.get_current_offer()[0].id)
		elif in_level() and not flow.is_event_open():
			flow.get_arena().call(&"debug_kill_all")
		return flow.is_event_open()))
	assert_eq(flow.level_events.get_open_id(), &"route_knight")
	assert_true(get_tree().paused)
	flow.get_event_ui().call(&"choose", 1)
	assert_eq(GameState.run_route, &"vanguard")
	assert_false(get_tree().paused)
	assert_true(GameState.active_tricks.has(&"pounce"))
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_route, &"")
	assert_false(GameState.active_tricks.has(&"pounce"))

func test_banked_route_survives_actual_save_and_continue() -> void:
	make_flow(false, 1234)
	GameState.hero_class = &"archer"
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(flow.progression.choose_route(&"marksman"))
	assert_true(await play_until_level_ends())
	var saved := read_save()
	assert_eq(saved.version, 11)
	assert_eq(saved.checkpoint.route, "marksman")
	flow.queue_free()
	flow = null
	await wait_frames(2)
	make_flow(true)
	await wait_frames(1)
	flow.continue_game()
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_route, &"marksman")
	assert_true(GameState.player_stats.attack_range > GameState.base_stats().attack_range)

func test_route_cards_show_costs_fit_safe_area_and_reject_double_taps() -> void:
	SafeArea.simulate_notch = true
	var ui := preload("res://ui/event_choice/event_choice.tscn").instantiate() as Control
	add_child(ui)
	for hero in HeroClasses.IDS:
		var event := BuildRoutes.event_for(hero)
		ui.call(&"show_event", event.id, event.offer_options())
		await get_tree().create_timer(0.8).timeout
		assert_eq(ui.get("cards").size(), 2)
		for card: Button in ui.get("cards"):
			assert_true(SafeArea.get_safe_rect().encloses(card.get_global_rect()))
			var desc := card.get_node("Description") as Label
			assert_ne(desc.text, event.options[0].desc)
			assert_true(desc.get_line_count() * desc.get_line_height() <= desc.size.y + 1, "full route cost must remain readable")
	var chosen := watch_signal(EventBus.event_chosen)
	ui.call(&"choose", 0)
	ui.call(&"choose", 1)
	assert_eq(chosen.count, 1)
	ui.queue_free()
	SafeArea.simulate_notch = false
