extends "res://tests/integration/playthrough_bot.gd"
## Start at the real title, earn every unlock, and journal each attempt before continuing.
## Run in an empty, isolated XDG_DATA_HOME. An existing save is never deleted.

const CAMPAIGN_SAVE := "user://six_episode_campaign.json"
const TitleScreen = preload("res://ui/screens/title.gd")
const TICK_LIMIT := 648000
const ATTEMPT_LIMIT := 10
const CHAPTER_BOSSES := [
	["black_knight"], ["green_knight"], ["morgana"], ["kraken"], ["red_dragon", "white_dragon"], ["mordred"]
]

var volleys_by_loadout: Dictionary = {}
var journal: FileAccess
var clears: Array[String] = []
var bosses_seen: Array[String] = []
var bosses_defeated: Array[String] = []
var room_failures: Dictionary = {}
var credits_opened := ""
var title_departures := 0
var result_was_final := false
var chapter_boss_wins := 0
var return_to_title := false
var strict_handoffs := true
var last_departure := 0
var final_title: Dictionary = {}
var failure_reason := ""
var last_progress := 0
var clipped_controls := 0
var missing_rest := 0
var overlap_controls := 0
var verify_epilogue := false
var epilogue_lines: Array[String] = []
var last_epilogue_tap := -1000

func _seed_added_node(node: Node) -> void:
	super(node)
	if node is TechniqueVolley:
		var levels := (node as TechniqueVolley).ranks
		var key := "%d%d%d" % [levels.x, levels.y, levels.z]
		volleys_by_loadout[key] = int(volleys_by_loadout.get(key, 0)) + 1


func _entry(kind: String, data := {}) -> void:
	var row := {"type": kind, "tick": Engine.get_physics_frames()}
	row.merge(data)
	if kind == "end":
		row["volley_counts_arc_star_gale"] = volleys_by_loadout
	journal.store_line(JSON.stringify(row))
	journal.flush()
	if kind in ["attempt", "title_start", "credits", "end"]:
		print("[campaign] ", kind, " ", JSON.stringify(data))

func _disk() -> Dictionary:
	if not flow.save_store.exists():
		return {}
	var data := flow.save_store.read()
	return {"chapter": data.chapter, "chapters_cleared": data.chapters_cleared, "level_index": data.level_index,
			"hero": data.get("hero_class"), "departure": data.get("chapter_departure", 0), "snacks": data.snacks, "sha256": FileAccess.get_sha256(CAMPAIGN_SAVE)}

func _run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path) or SaveStore.new(CAMPAIGN_SAVE).exists():
		push_error("A fresh profile and a new --report=... JSONL path are required.")
		get_tree().quit(2)
		return
	journal = FileAccess.open(report_path, FileAccess.WRITE)
	if journal == null:
		get_tree().quit(2)
		return
	strict_handoffs = not OS.get_cmdline_user_args().has("--reference-title-handoffs")
	verify_epilogue = OS.get_cmdline_user_args().has("--verify-epilogue")
	get_tree().root.size = Vector2i(360, 640)
	await get_tree().process_frame
	if SafeArea.get_screen_size() != Vector2(180, 320):
		_entry("end", {"complete": false, "reason": "portrait_viewport_unavailable", "actual": str(SafeArea.get_screen_size())})
		get_tree().quit(2)
		return
	seed(rng_seed)
	Loot.seed_rng(rng_seed + 200)
	Engine.time_scale = 1.0
	get_tree().node_added.connect(_seed_added_node)
	EventBus.level_started.connect(_started)
	EventBus.event_offered.connect(func(id: StringName, options: Array) -> void:
		_entry("event_offered", {"id": String(id), "options": options.size(), "chapter": GameState.chapter}))
	EventBus.event_chosen.connect(func(id: StringName, index: int) -> void:
		_entry("event_chosen", {"id": String(id), "option": index, "chapter": GameState.chapter}))
	EventBus.ultimate_used.connect(func() -> void: _ultimates += 1)
	EventBus.player_downed.connect(func() -> void: _downs += 1)
	EventBus.dialogue_started.connect(func(id: StringName) -> void: _entry("dialogue", {"id": String(id)}))
	EventBus.boss_appeared.connect(func(id: StringName) -> void: bosses_seen.append(String(id)))
	EventBus.enemy_died.connect(func(id: StringName, _at: Vector2, _xp: int) -> void:
		if GameState.chapter >= 1 and GameState.chapter <= CHAPTER_BOSSES.size() and String(id) in CHAPTER_BOSSES[GameState.chapter - 1]:
			bosses_defeated.append(String(id)))
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = CAMPAIGN_SAVE
	flow.use_stand_ins = false
	flow.rng_seed = rng_seed
	add_child(flow)
	_entry("start", {"fresh": not flow.save_store.exists(), "class": hero_class, "seed": rng_seed, "movement": movement_policy,
			"logical_viewport": [180, 320], "window": [360, 640], "guard": guard_policy, "build": build_policy, "route": route_choice, "require_direct_handoffs": strict_handoffs, "verify_epilogue": verify_epilogue, "engine": Engine.get_version_info().string})
	await _frames(65)
	while Engine.get_physics_frames() < TICK_LIMIT and failure_reason.is_empty():
		await get_tree().process_frame
		if Engine.get_physics_frames() - last_progress > 54000:
			failure_reason = "no_progress_for_900_simulated_seconds"
			break
		if _skip_dialogues() or flow.is_switching():
			continue
		var credits := flow.get_credits() as Control
		if credits != null and credits.is_visible_in_tree():
			if credits_opened.is_empty():
				credits_opened = "from_ending"
			_entry("credits", {"entry": credits_opened, "clears": clears.size()})
			await _frames(65)
			_click(credits.get("close_button"))
			await _frames(75)
			return_to_title = flow.state == FlowMain.State.TITLE and flow.get_credits() == null
			var title := flow.get_screen() as TitleScreen
			if title != null:
				final_title = {"selected": title.chosen_chapter(), "unlocked": TitleScreen.unlocked_chapters(),
						"continue_visible": title.continue_button.is_visible_in_tree()}
			break
		match flow.state:
			FlowMain.State.TITLE:
				await _at_title()
			FlowMain.State.LEVEL:
				_level_clock += get_process_delta_time()
				await _play_level()
			FlowMain.State.CAMP:
				_entry("camp", {"chapter": GameState.chapter, "after_level_index": flow.get_level_index()})
				await _play_camp()
			FlowMain.State.RESULTS, FlowMain.State.FAILURE:
				await _result()
	var disk := _disk()
	var complete := clears.size() == 36 and chapter_boss_wins == 6 and result_was_final and return_to_title
	complete = complete and disk.get("chapters_cleared", 0) == 6 and int(final_title.get("unlocked", 0)) == 6 and failure_reason.is_empty()
	if strict_handoffs:
		complete = complete and title_departures == 1 and credits_opened == "from_ending"
		complete = complete and clipped_controls == 0 and missing_rest == 0 and overlap_controls == 0
		complete = complete and int(disk.get("departure", -1)) == 0 and not bool(final_title.get("continue_visible", true))
	if verify_epilogue:
		complete = complete and epilogue_lines == ["STORY_C6_TEASER_01", "STORY_C6_TEASER_02"]
	_entry("end", {"complete": complete, "reason": failure_reason if not failure_reason.is_empty() else ("finished" if complete else "incomplete"),
			"rooms_won": clears.size(), "chapter_boss_wins": chapter_boss_wins, "downs": _downs,
			"ultimates": _ultimates, "credits": credits_opened, "return_to_title": return_to_title, "game_complete": result_was_final,
			"title_departures": title_departures, "clipped_result_controls": clipped_controls, "missing_rest": missing_rest,
			"overlap_controls": overlap_controls, "epilogue_lines": epilogue_lines, "returned_title": final_title, "save": disk})
	journal.close()
	get_tree().quit(0 if complete else 1)

func _started(id: StringName) -> void:
	_level_clock = 0.0
	_escape_direction = Vector2.ZERO
	_escape_think_left = 0.0
	bosses_seen.clear()
	bosses_defeated.clear()
	last_progress = Engine.get_physics_frames()
	var expected := "%d-%d" % [1 + floori(clears.size() / 6.0), 1 + clears.size() % 6]
	if String(id) != expected:
		failure_reason = "entered_%s_expected_%s" % [id, expected]
	_entry("level_start", {"id": String(id), "hero": GameState.hero_class, "difficulty": GameState.difficulty,
			"save": _disk()})

func _at_title() -> void:
	await _frames(65)
	var title := flow.get_screen() as TitleScreen
	if title == null:
		failure_reason = "missing_title"
		return
	if clears.size() == 36:
		if strict_handoffs:
			failure_reason = "ending_returned_to_title_before_credits"
			return
		credits_opened = "from_title_button"
		var legacy := title.find_child("CreditsButton", true, false) as Button
		if legacy == null:
			failure_reason = "missing_legacy_credits_entry"
			return
		_click(legacy)
		await _frames(30)
		return
	var expected := 1 + floori(clears.size() / 6.0)
	if clears.size() % 6 != 0 or title.chosen_chapter() != expected or title.is_chapter_locked(expected):
		failure_reason = "unexpected_title_selection"
		return
	if last_departure == expected or (strict_handoffs and expected > 1):
		failure_reason = "unexpected_title_before_chapter_%d" % expected
		return
	last_departure = expected
	title_departures += 1
	_entry("title_start", {"chosen": title.chosen_chapter(), "save": _disk()})
	_click(title.new_game_button)
	await _frames(12)
	var chooser: HeroClassSelect = title.get_class_select()
	if chooser == null or not chooser.is_visible_in_tree():
		failure_reason = "class_chooser_did_not_open"
		return
	_click(chooser.choices[HeroClasses.IDS.find(hero_class)])
	await _frames(12)
	_click(chooser.confirm_button)
	await _frames(18)
	if is_instance_valid(title) and title.is_difficulty_open():
		_click(title.normal_button)
	await _frames(65)

func _result() -> void:
	var r := flow.get_last_result()
	var id := String(r.level_id)
	var won := bool(r.victory)
	var screen := flow.get_screen()
	var action := "continue"
	if not won:
		room_failures[id] = int(room_failures.get(id, 0)) + 1
		var revive := screen.get("revive_button") as Button
		action = "revive" if revive != null and revive.is_visible_in_tree() and not revive.disabled else "retry"
	var row := {"id": id, "won": won, "kills": r.kills, "damage": r.damage_taken, "combat_s": r.time_sec,
			"hero_level": r.hero_level, "vigor": GameState.vigor, "tricks": r.tricks, "route": GameState.run_route,
			"chapter_final": r.is_final, "game_complete": r.game_complete, "bosses_seen": bosses_seen.duplicate(),
			"bosses_defeated": bosses_defeated.duplicate(), "action": action, "snacks": GameState.snacks}
	_entry("attempt", row)
	last_progress = Engine.get_physics_frames()
	if won:
		clears.append(id)
		if bool(r.is_final):
			var expected_bosses: Array = CHAPTER_BOSSES[int(r.chapter) - 1]
			if not expected_bosses.all(func(boss: String) -> bool: return boss in bosses_defeated):
				failure_reason = "missing_boss_death_in_%s" % id
				return
			chapter_boss_wins += 1
		result_was_final = bool(r.game_complete)
	elif int(room_failures[id]) >= ATTEMPT_LIMIT:
		failure_reason = "room_down_limit_%s" % id
		return
	await _frames(25)
	var button := screen.get(action + "_button") as BaseButton
	if button == null:
		failure_reason = "missing_%s_button_in_%s" % [action, id]
		return
	var rect := _button_bounds(button)
	var safe := SafeArea.get_safe_rect()
	var inside := safe.encloses(rect)
	if not inside:
		clipped_controls += 1
	var control_row := {"id": id, "action": action, "rect": _bounds_array(rect), "whole": inside, "center": safe.has_point(rect.get_center())}
	if bool(r.is_final):
		var rest := screen.find_child("RestButton", true, false) as Button
		if rest != null and rest.is_visible_in_tree():
			var rest_rect := _button_bounds(rest)
			control_row["rest"] = _bounds_array(rest_rect)
			control_row["rest_whole"] = safe.encloses(rest_rect)
			control_row["overlap"] = rect.intersects(rest_rect)
			if not safe.encloses(rest_rect):
				clipped_controls += 1
			if rect.intersects(rest_rect):
				overlap_controls += 1
		else:
			missing_rest += 1
	_entry("result_controls", control_row)
	_click(button)
	await _frames(65)
	if is_instance_valid(screen) and screen == flow.get_screen() and flow.state in [FlowMain.State.RESULTS, FlowMain.State.FAILURE]:
		var viewport := button.get_viewport()
		var hit := viewport.gui_get_hovered_control()
		_entry("blocked_button", {"room": id, "action": action, "button": String(button.get_path()),
				"button_rect": str(button.get_global_rect()), "hit": String(hit.get_path()) if hit != null else "",
				"viewport": str(viewport.get_visible_rect()), "safe": str(SafeArea.get_safe_rect())})
		failure_reason = "results_button_did_not_advance_%s" % id

func _button_bounds(button: BaseButton) -> Rect2:
	return button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)

func _bounds_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _click(button: BaseButton) -> void:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		failure_reason = "missing_visible_enabled_control"
		return
	_tap(button.get_viewport(), button.get_global_transform_with_canvas() * (button.size / 2.0))

func _tap(viewport: Viewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		event.position = at
		event.global_position = at
		viewport.push_input(event, true)


func _skip_dialogues() -> bool:
	if not verify_epilogue:
		return super._skip_dialogues()
	for box in get_tree().get_nodes_in_group(&"dialogue_box"):
		if box.call(&"is_active") and box.get("_script").id == &"c6_teaser":
			if not box.call(&"is_typing"):
				_read_epilogue(box)
			return true
	return super._skip_dialogues()

func _read_epilogue(box: Node) -> void:
	var line := box.get("_line") as DialogueLine
	var label := box.get("_text") as Label
	var picture := box.get("_picture") as TextureRect
	if not epilogue_lines.has(line.text_key):
		epilogue_lines.append(line.text_key)
		var path := picture.texture.resource_path if picture.texture != null else ""
		var readable := label.is_visible_in_tree() and label.text == tr(line.text_key) and label.text != line.text_key
		readable = readable and label.get_line_count() <= label.get_visible_line_count() and SafeArea.get_safe_rect().encloses(label.get_global_rect())
		_entry("epilogue_page", {"key": line.text_key, "text": label.text, "readable_bounds": readable,
				"character_count": label.get_total_character_count(), "line_count": label.get_line_count(),
				"picture": path, "picture_visible": picture.is_visible_in_tree()})
		if not readable or not picture.is_visible_in_tree() or path != "res://assets/story/round_table_homecoming.webp":
			failure_reason = "epilogue_text_or_art_missing"
			return
	var now := Time.get_ticks_msec()
	if now - last_epilogue_tap >= 125:
		last_epilogue_tap = now
		_tap(box.get_viewport(), Vector2(9.0, 155.0))
