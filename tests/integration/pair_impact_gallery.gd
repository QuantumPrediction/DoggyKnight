extends "res://tests/integration/six_episode_campaign.gd"
## Observe the normal campaign after drawing. Never change its inputs or wait a
## physics tick for a picture. A #36 control can replay the same capture ticks.
const SHOTS := ["ordinary", "arc_gale", "arc_star", "gale_star", "room-report"]

var directory := ""
var pictures := {}
var replay_ticks := {}
var report_since := -1


func _run() -> void:
	directory = OS.get_environment("ART_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		push_error("Provide ART_CAPTURE_DIR and a rendering display")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var reference := OS.get_environment("PAIR_CAPTURE_TICKS")
	if not reference.is_empty():
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference))
		for label: String in SHOTS:
			replay_ticks[label] = int(plan[label].tick)
	RenderingServer.frame_post_draw.connect(_observe)
	await super()


func _observe() -> void:
	if not is_instance_valid(flow) or pictures.size() == SHOTS.size():
		return
	var tick := Engine.get_physics_frames()
	if not replay_ticks.is_empty():
		for label: String in SHOTS:
			if tick == replay_ticks[label] and not pictures.has(label):
				_capture(label)
	elif flow.state == FlowMain.State.RESULTS:
		if report_since < 0:
			report_since = tick
		if tick >= report_since + 90 and not pictures.has("room-report") and flow.get_last_result().get("landed_pairs", {}).size() == 3:
			_capture("room-report")
	else:
		report_since = -1
		if not get_tree().paused and flow.state == FlowMain.State.LEVEL and not flow.is_choice_open():
			_observe_volleys()
	if pictures.size() == SHOTS.size():
		var file := FileAccess.open(directory.path_join("frames.json"), FileAccess.WRITE)
		file.store_line(JSON.stringify(pictures, "\t"))
		file.close()
		get_tree().quit(0)


func _result() -> void:
	# Stop on the first complete recap long enough for all three stars and
	# the stat counters to settle. Combat has already ended. Repeat on control.
	var tick := Engine.get_physics_frames()
	var wanted: bool = flow.get_last_result().get("landed_pairs", {}).size() == 3
	if not replay_ticks.is_empty():
		wanted = replay_ticks["room-report"] >= tick and replay_ticks["room-report"] < tick + 100
	if wanted and not pictures.has("room-report"):
		await _frames(97)
	await super()


func _observe_volleys() -> void:
	if pictures.size() >= 4 and not pictures.has("room-report"):
		return
	for node in get_tree().get_nodes_in_group(&"friendly_technique"):
		var volley := node as TechniqueVolley
		if volley.is_queued_for_deletion():
			continue
		for arc in volley.arcs:
			var pair := String(arc.get("pair", ""))
			_try_impact("ordinary" if pair.is_empty() else pair, volley, arc.to)
		for mark in volley.stars:
			if mark.get("pair", &"") == &"gale_star":
				_try_impact("gale_star", volley, mark.at)


func _try_impact(label: String, volley: TechniqueVolley, at: Vector2) -> void:
	if pictures.has(label):
		return
	var on_screen := volley.get_global_transform_with_canvas() * volley.to_local(at)
	# Frame the event within the playfield, away from top status and bottom touch controls.
	if Rect2(18, 70, 144, 167).has_point(on_screen):
		_capture(label, on_screen)


func _capture(label: String, on_screen := Vector2.INF) -> void:
	var arena := flow.get_arena()
	var player: Node2D = arena.get_player() if arena != null else null
	var row := {"tick": Engine.get_physics_frames(), "chapter": GameState.chapter,
			"room": flow.get_level_index() + 1, "tricks": GameState.active_tricks.duplicate(),
			"player_xy": [player.position.x, player.position.y] if player != null else []}
	if on_screen.is_finite():
		row["impact_xy_logical"] = [on_screen.x, on_screen.y]
	if label == "room-report":
		row["room_counts"] = flow.get_last_result().get("landed_pairs", {})
	var err := get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if err != OK:
		push_error("Could not save " + label)
		get_tree().quit(2)
		return
	pictures[label] = row
	print("PAIR_FRAME ", label, " ", JSON.stringify(row))
