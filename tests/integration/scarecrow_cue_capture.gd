extends "res://tests/integration/scarecrow_window_probe.gd"
## Live replay: read the finished viewport without pausing or altering the attack.

var _capture_dir: String
var _capture_id: String
var _first_tick: int = -1
var _last_tick: int = -1
var _samples: Array[Dictionary] = []
var _images: Array[Image] = []
var _capture_error: String
var _lesson_completions: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--capture-id="):
			_capture_id = arg.trim_prefix("--capture-id=")
		elif arg.begins_with("--capture-first="):
			_first_tick = int(arg.trim_prefix("--capture-first="))
		elif arg.begins_with("--capture-last="):
			_last_tick = int(arg.trim_prefix("--capture-last="))
	if DisplayServer.get_name() == "headless" or _first_tick < 0 or _last_tick < _first_tick \
			or _last_tick - _first_tick > 40 or _capture_id.is_empty() \
			or not _capture_dir.is_absolute_path() or not DirAccess.dir_exists_absolute(_capture_dir):
		push_error("Capture needs a real display, registered tick range and fresh output directory.")
		get_tree().quit(2)
		return
	RenderingServer.frame_post_draw.connect(_capture_drawn_frame)
	EventBus.guard_lesson_completed.connect(_note_lesson_completion)
	super()


func _note_lesson_completion() -> void:
	_lesson_completions += 1


func _capture_drawn_frame() -> void:
	if _level_epoch < 0 or not _in_trial():
		return
	var tick := _tick()
	if tick < _first_tick or tick > _last_tick or not _capture_error.is_empty():
		return
	if _samples.size() >= 84:
		_capture_error = "Too many rendered frames in the bounded capture range."
		return
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image()
	var player := _player()
	if image == null or image.is_empty() or player == null:
		_capture_error = "Viewport image or player missing at the completed draw."
		return
	var to_pixels := viewport.get_stretch_transform()
	var own: Array = []
	var other: Array = []
	var eligible := false
	var progress := -1.0
	var selected: AttackTelegraph
	if _live.has(_capture_id):
		selected = _live[_capture_id].mark.get_ref() as AttackTelegraph
	if selected != null and selected.is_visible_damage_warning():
		eligible = true
		progress = selected.progress
		own = _sector_screen_points(selected, to_pixels)
	for mark_node: Node in get_tree().get_nodes_in_group(&"attack_warnings"):
		var mark := mark_node as AttackTelegraph
		if mark == null or mark == selected or not mark.is_visible_damage_warning():
			continue
		if mark.shape == AttackTelegraph.Shape.SECTOR and mark.global_position.distance_to(player.global_position) < 56.0:
			other.append(_sector_screen_points(mark, to_pixels))
	var hud := _hud_state(to_pixels)
	if hud.is_empty():
		_capture_error = "The completed draw did not have its production HUD."
		return
	_samples.append({"tick": tick, "process_frame": Engine.get_process_frames(),
		"file": "tick_%05d_draw_%03d.png" % [tick, _samples.size()], "image_size": [image.get_width(), image.get_height()],
		"warning_eligible": eligible, "progress": progress, "selected_sector_px": own, "nearby_sectors_px": other,
		"player_px": _point(to_pixels * player.get_global_transform_with_canvas().origin),
		"player_world": _point(player.global_position), "production_overlap": AttackTelegraph.warning_counts(
			get_tree(), player.global_position, player.tuning.body_radius).x, "coach_hud": hud})
	_images.append(image)


func _hud_state(to_pixels: Transform2D) -> Dictionary:
	var hud: Node = flow.get_hud()
	if hud == null:
		return {}
	var coach: GuardCoach = hud.get("guard_coach") as GuardCoach
	var guard: CompanionGuardControl = hud.get("companion_guard") as CompanionGuardControl
	var readout: CombatReadout = hud.get("combat_readout") as CombatReadout
	var ultimate: Control = hud.get("ultimate_button") as Control
	var pause: Control = hud.get("pause_button") as Control
	if coach == null or guard == null or readout == null or ultimate == null or pause == null:
		return {}
	return {"success_drawn": coach.completed and coach.heading.is_visible_in_tree(),
		"coach_slot": coach.is_visible_in_tree(), "success_nearby_warning": coach._nearby_warning,
		"lesson_completed": coach.completed, "persisted_completion_flag": GameState.guard_lesson_done,
		"lesson_completion_signals": _lesson_completions,
		"coach_px": _screen_rect(coach, to_pixels), "coach_close_active": coach.dismiss_button.is_visible_in_tree(),
		"guard_button_px": _screen_rect(guard.button, to_pixels), "guard_button_visible": guard.button.is_visible_in_tree(),
		"ultimate_button_px": _screen_rect(ultimate, to_pixels), "ultimate_button_visible": ultimate.is_visible_in_tree(),
		"pause_button_px": _screen_rect(pause, to_pixels), "readout_px": _screen_rect(readout, to_pixels),
		"readout_warning": readout.warning_active}


func _screen_rect(control: Control, to_pixels: Transform2D) -> Array:
	var tr := to_pixels * control.get_global_transform_with_canvas()
	return [_point(tr.origin), _point(tr * control.size)]


func _sector_screen_points(mark: AttackTelegraph, to_pixels: Transform2D) -> Array:
	var tr := to_pixels * mark.get_global_transform_with_canvas()
	var result: Array = []
	for point: Vector2 in mark._sector_points(mark.radius):
		result.append(_point(tr * point))
	return result


func _write_report(finished: bool) -> bool:
	var report_ok := super(finished)
	for i: int in _images.size():
		var err := _images[i].save_png(_capture_dir.path_join(String(_samples[i].file)))
		if err != OK:
			_capture_error = "A viewport image failed to save (%d)." % err
			break
	var file := FileAccess.open(_capture_dir.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "render_device": RenderingServer.get_current_rendering_driver_name(),
		"capture_id": _capture_id, "error": _capture_error, "frames": _samples}, "\t") + "\n")
	file.close()
	return report_ok and _capture_error.is_empty() and not _samples.is_empty()
