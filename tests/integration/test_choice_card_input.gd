extends "res://tests/line_b/flow_test_base.gd"
## Deliver input through the viewport; direct choose()/pressed.emit() would bypass focus.

const EVENT := preload("res://ui/event_choice/event_choice.tscn")
const TRICK := preload("res://ui/trick_choice/trick_choice.tscn")
const THREE_TRICKS := [preload("res://data/tricks/wag.tres"), preload("res://data/tricks/sit.tres"), preload("res://data/tricks/shake.tres")]

var screen: Control
var behind: Button


func before_each() -> void:
	behind = Button.new()
	behind.text = "HUD"
	behind.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(behind)
	behind.grab_focus()


func after_each() -> void:
	if is_instance_valid(screen):
		screen.free()
	behind.free()
	await super.after_each()


func _key(code: Key, pressed: bool, shift: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	get_viewport().push_input(event)


func _tap(code: Key, shift: bool = false) -> void:
	_key(code, true, shift)
	_key(code, false, shift)


func _open(packed: PackedScene) -> void:
	screen = packed.instantiate() as Control
	add_child(screen)
	get_tree().paused = true


func _route() -> void:
	var event := BuildRoutes.event_for(&"archer")
	EventBus.event_offered.emit(event.id, event.offer_options())


func _settle() -> void:
	# The production guards use the monotonic clock. An engine timer may include
	# frame time from before this offer, especially on the first frame after loading.
	var deadline := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func test_route_arrows_and_tab_stay_on_the_current_offer() -> void:
	_open(EVENT)
	var chosen := watch_signal(EventBus.event_chosen)
	var stray := watch_signal(behind.pressed)
	_route()
	var cards: Array = screen.get("cards")
	assert_true(cards[0].has_focus(), "route opens on its first card")
	_tap(KEY_DOWN)
	assert_true(cards[1].has_focus(), "Down selects the second card during the entrance")
	_tap(KEY_RIGHT)
	assert_true(cards[1].has_focus(), "horizontal navigation stays in this column")
	_tap(KEY_TAB)
	assert_true(cards[0].has_focus(), "Tab wraps inside the offer")
	_tap(KEY_TAB, true)
	assert_true(cards[1].has_focus(), "Shift+Tab wraps back")
	_tap(KEY_ENTER)
	assert_eq(chosen.count, 0, "route cards keep their entrance guard")
	await _settle()
	_tap(KEY_ENTER)
	assert_eq(chosen.calls, [[&"route_archer", 1]])
	assert_false(screen.visible)
	assert_eq(stray.count, 0, "the underlying HUD must receive no activation")


func test_upgrades_ignore_early_hold_echo_and_require_a_fresh_press() -> void:
	_open(TRICK)
	var chosen := watch_signal(EventBus.trick_chosen)
	EventBus.trick_offered.emit(THREE_TRICKS)
	_key(KEY_ENTER, true)
	await _settle()
	_key(KEY_ENTER, true, false, true)
	_key(KEY_ENTER, false)
	assert_eq(chosen.count, 0, "a press begun during the guard cannot commit on late release")
	_tap(KEY_UP)
	var cards: Array = screen.get("cards")
	assert_true(cards[2].has_focus(), "Up wraps to the third upgrade")
	_tap(KEY_ENTER)
	assert_eq(chosen.calls, [[&"shake"]])
	EventBus.trick_offered.emit([THREE_TRICKS[1]])
	await _settle()
	_key(KEY_ENTER, true, false, true)
	_key(KEY_ENTER, false)
	assert_eq(chosen.count, 1, "an echo and orphan release cannot choose the next offer")
	_tap(KEY_TAB)
	_tap(KEY_DOWN)
	_tap(KEY_ENTER)
	assert_eq(chosen.calls, [[&"shake"], [&"sit"]], "a single-card offer stays reachable")
	assert_false(screen.visible)


func test_pressing_a_different_card_with_the_pointer_still_selects_it() -> void:
	_open(EVENT)
	var chosen := watch_signal(EventBus.event_chosen)
	_route()
	await _settle()
	var card: Button = screen.get("cards")[1]
	var point := card.get_global_transform_with_canvas() * (card.size / 2.0)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
	assert_eq(chosen.calls, [[&"route_archer", 1]], "clicking away from the starting focus chooses that card")


func _touch(card: Button) -> void:
	var point := card.get_screen_transform() * (card.size / 2.0)
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await wait_frames(1)


func test_touch_can_select_the_third_upgrade_after_the_guard() -> void:
	_open(TRICK)
	var chosen := watch_signal(EventBus.trick_chosen)
	EventBus.trick_offered.emit(THREE_TRICKS)
	await _settle()
	await _touch(screen.get("cards")[2])
	assert_eq(chosen.calls, [[&"shake"]], "touch follows the tapped card")


func test_dpad_and_south_button_use_the_same_native_card_focus() -> void:
	_open(EVENT)
	var chosen := watch_signal(EventBus.event_chosen)
	_route()
	await _settle()
	for button_index: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A]:
		for pressed: bool in [true, false]:
			var event := InputEventJoypadButton.new()
			event.button_index = button_index
			event.pressed = pressed
			get_viewport().push_input(event)
	assert_eq(chosen.calls, [[&"route_archer", 1]], "synthetic D-pad Down and south-button select the second card")


func test_focus_ring_is_visible_against_all_four_paper_styles() -> void:
	for variation: StringName in [&"CardButton", &"CardMerlin", &"CardMorgana", &"CardEvolve"]:
		var card := Button.new()
		card.theme = UiKit.THEME
		card.theme_type_variation = variation
		add_child(card)
		var ring := card.get_theme_stylebox(&"focus") as StyleBoxFlat
		assert_not_null(ring, String(variation))
		if ring != null:
			assert_true(ring.border_width_top >= 2, "%s has a two-pixel focus edge" % variation)
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				var paper := card.get_theme_stylebox(state) as StyleBoxFlat
				var a := ring.border_color.srgb_to_linear().get_luminance()
				var b := paper.bg_color.srgb_to_linear().get_luminance()
				assert_true((maxf(a, b) + 0.05) / (minf(a, b) + 0.05) >= 3.0, "%s/%s focus contrast" % [variation, state])
		card.free()


func test_first_chapter_route_and_upgrade_resume_the_real_flow() -> void:
	flow = (load(MAIN_SCENE) as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.rng_seed = 19
	flow.chapter = fast_chapter()
	flow.chapters = [flow.chapter]
	flow.difficulty = fast_difficulty()
	add_child(flow)
	GameState.hero_class = &"archer"
	flow.start_new_game()
	assert_true(await wait_until(func() -> bool: return flow.progression.accepting_exp))
	# Stage only the opportunities. The real flow resolves data, pause, UI and rewards.
	flow.get_session().event_due.emit(0)
	assert_eq(flow.get_open_event_id(), &"route_archer")
	assert_true(get_tree().paused)
	await _settle()
	_tap(KEY_DOWN)
	_tap(KEY_ENTER)
	assert_eq(GameState.run_route, &"outrider", "the second route changes the actual run")
	assert_true(GameState.active_tricks.has(&"roll"))
	assert_false(get_tree().paused, "the fight resumes after a route choice")
	if flow.is_event_open():
		return
	assert_true(flow.progression.offer_bonus_choice(1))
	await wait_frames(2)
	assert_true(get_tree().paused)
	var offered := flow.progression.get_current_offer()
	assert_eq(offered.size(), 3)
	if offered.size() != 3:
		return
	var chosen_id := offered[2].id
	var prior_count := GameState.active_tricks.count(chosen_id)
	var ultimate := watch_signal(EventBus.ultimate_requested)
	await _settle()
	_tap(KEY_UP)
	_tap(KEY_SPACE)
	assert_eq(GameState.active_tricks.count(chosen_id), prior_count + 1, "the selected upgrade is applied once")
	assert_eq(ultimate.count, 0, "confirming the card with Space must not trigger a combat ultimate")
	assert_false(flow.is_trick_choice_open())
	assert_false(get_tree().paused)


func test_shield_echo_toggles_independently_and_resets_for_each_offer() -> void:
	_open(EVENT)
	screen.call(&"set_shield_echo_available", true)
	_route()
	await _settle()
	var toggle := screen.find_child("ShieldEcho", true, false) as Button
	var cards: Array = screen.get("cards")
	var chosen := watch_signal(EventBus.event_chosen)
	assert_true(toggle.is_visible_in_tree())
	assert_false(toggle.button_pressed)
	_tap(KEY_UP)
	assert_true(toggle.has_focus(), "the trial is reachable from the first route")
	_tap(KEY_ENTER)
	assert_true(toggle.button_pressed)
	assert_eq(chosen.count, 0)
	assert_true(screen.visible)
	var selected_text := toggle.text
	_tap(KEY_ENTER)
	assert_false(toggle.button_pressed, "the player can change their mind")
	assert_ne(toggle.text, selected_text)
	_tap(KEY_ENTER)
	_tap(KEY_DOWN)
	assert_true(cards[0].has_focus())
	_tap(KEY_ENTER)
	assert_eq(chosen.calls, [[&"route_archer", 0]])
	assert_true(screen.call(&"wants_shield_echo"), "the accepted offer has both independent choices")
	_route()
	assert_false(toggle.button_pressed)
	screen.call(&"set_shield_echo_available", false)
	_route()
	assert_false(toggle.visible)
	assert_false(screen.call(&"wants_shield_echo"))
	_tap(KEY_UP)
	assert_true(screen.get("cards")[1].has_focus(), "other menus retain their two-card focus order")


func test_shield_echo_card_and_both_routes_fit_the_notched_safe_area() -> void:
	SafeArea.simulate_notch = true
	_open(EVENT)
	screen.call(&"set_shield_echo_available", true)
	_route()
	await _settle()
	var toggle := screen.find_child("ShieldEcho", true, false) as Button
	var hint := screen.find_child("Hint", true, false) as Label
	var safe := SafeArea.get_safe_rect()
	var title := screen.find_child("Title", true, false) as PanelContainer
	assert_true(safe.encloses(title.get_global_rect()), "title %s in %s" % [title.get_global_rect(), safe])
	for card: Button in screen.get("cards"):
		assert_true(safe.encloses(card.get_global_rect()), "route %s in %s" % [card.get_global_rect(), safe])
		assert_false(card.get_global_rect().intersects(toggle.get_global_rect()))
	for pressed: bool in [false, true]:
		toggle.button_pressed = pressed
		assert_true(safe.encloses(toggle.get_global_rect()), "trial %s in %s" % [toggle.get_global_rect(), safe])
		assert_true(toggle.size.y >= UiKit.MIN_TOUCH)
		assert_true(toggle.size.x >= toggle.get_combined_minimum_size().x, "trial width %s vs minimum %s" % [toggle.size, toggle.get_combined_minimum_size()])
		assert_eq(toggle.text.split("\n").size(), 2, "the explanation survives CSV import")
	assert_true(safe.encloses(hint.get_global_rect()), "hint %s in %s" % [hint.get_global_rect(), safe])
	assert_false(hint.get_global_rect().intersects(toggle.get_global_rect()))
	SafeArea.simulate_notch = false
