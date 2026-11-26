extends "res://tests/integration/playthrough_bot.gd"
## Measures normal scene transitions and real combat signals from the title action.
## The agent has no authority to spawn combatants, force contact or grant a charge.

const TitleScreen := preload("res://ui/screens/title.gd")
const MAX_TICKS: int = 18000
const OBSERVE_THROUGH: StringName = &"1-3"
const RESPONSE_TICKS: int = 96

var response: String = "skip"
var borrow: bool = false
var route_tested: bool = false
var epoch: int = -1
var first: Dictionary = {}
var counts: Dictionary = {}
var contacts: Array[Dictionary] = []
var early_archers: Array[Dictionary] = []
var early_archer_index: Dictionary = {}
var snapshot_dir: String = ""
var pending_shots: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var room: StringName = &""
var dog: BulldogCompanion
var charge_source: String = ""
var last_block: int = -1
var last_reduction: int = 0
var turn_tick: int = -1
var hold_until: int = -1
var cue_tick: int = -1
var offered_direction := Vector2.ZERO
var follow_charged: bool = false
var final_outcome: String = "time_limit"


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--response="):
			response = arg.trim_prefix("--response=")
		elif arg == "--borrow=on":
			borrow = true
		elif arg.begins_with("--shield-shots="):
			snapshot_dir = arg.trim_prefix("--shield-shots=")
	if not snapshot_dir.is_empty() and (DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(snapshot_dir) != OK):
		push_error("A real display and writable directory are required for --shield-shots")
		get_tree().quit(2)
		return
	if not response in ["skip", "call", "follow"]:
		push_error("Expected --response=skip, call or follow")
		get_tree().quit(2)
		return
	seed(rng_seed)
	Loot.seed_rng(rng_seed + 200)
	get_tree().node_added.connect(_seed_added_node)
	SaveStore.new(SAVE_PATH).delete()
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.use_stand_ins = false
	flow.rng_seed = rng_seed
	add_child(flow)
	EventBus.level_started.connect(_room_entered)
	EventBus.player_downed.connect(func() -> void: _downs += 1)
	EventBus.player_damaged.connect(func(_amount: int) -> void: _observe_reduction())
	EventBus.companion_blocked.connect(_blocked)
	EventBus.companion_counter_granted.connect(_granted)
	EventBus.companion_counter_resolved.connect(_resolved)
	EventBus.guard_lesson_completed.connect(func() -> void: _note("lesson_saved_signal"))
	await _frames(65)
	var title := flow.get_screen() as TitleScreen
	if title == null or not title.new_game_button.is_visible_in_tree():
		push_error("Normal new-game control is unavailable")
		get_tree().quit(2)
		return
	epoch = Engine.get_physics_frames()
	_note("title_start")
	_click_control(title.new_game_button)
	await _frames(12)
	var chooser: HeroClassSelect = title.get_class_select()
	_click_control(chooser.choices[HeroClasses.IDS.find(hero_class)])
	await _frames(12)
	_note("class_confirm")
	_click_control(chooser.reinforced_button if OS.get_cmdline_user_args().has("--reinforced") else chooser.confirm_button)
	while _tick() < MAX_TICKS:
		await get_tree().process_frame
		if _skip_dialogues():
			continue
		match flow.state:
			FlowMain.State.LEVEL:
				await _play_level()
			FlowMain.State.RESULTS, FlowMain.State.FAILURE:
				var result := flow.get_last_result()
				rooms.append({"level": result.level_id, "won": result.victory, "kills": result.kills,
					"damage": result.damage_taken, "combat_s": result.time_sec, "tick": _tick()})
				if flow.state == FlowMain.State.FAILURE:
					if _downs >= 3:
						final_outcome = "down_limit"
						break
					flow.get_screen().emit_signal(&"retry_pressed")
					await _frames(5)
				elif StringName(result.level_id) == OBSERVE_THROUGH:
					final_outcome = "third_room_complete"
					break
				else:
					await super._on_results()
			FlowMain.State.CAMP:
				await _play_camp()
			FlowMain.State.TITLE:
				# Flow is still covering the title immediately after confirmation.
				if not room.is_empty():
					final_outcome = "returned_to_title"
					break
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save first-shield observation")
		get_tree().quit(2)
		return
	file.store_line(JSON.stringify({"hero": hero_class, "seed": rng_seed, "response": response,
		"borrow": borrow, "route": route_choice, "first": first, "counts": counts, "contacts": contacts,
		"rooms": rooms, "outcome": final_outcome,
		"end_tick": _tick(), "dialogues_skipped": _dialogues, "downs": _downs,
		"mode": GameState.difficulty, "actual_class": GameState.hero_class, "actual_route": GameState.run_route,
		"early_archers": early_archers, "engine": Engine.get_version_info().string}))
	file.close()
	print("FIRST_SHIELD %s %d %s %s" % [hero_class, rng_seed, response, final_outcome])
	get_tree().quit()


func _tick() -> int:
	return Engine.get_physics_frames() - epoch


func _note(event: String, detail: String = "", where: StringName = &"") -> void:
	if epoch < 0:
		return
	counts[event] = int(counts.get(event, 0)) + 1
	var here := room if where.is_empty() else where
	if event in ["companion_entered_tree", "command_accepted", "protected_damage", "projectile_block", "granted"] or event.begins_with("resolved_"):
		contacts.append({"event": event, "tick": _tick(), "room": String(here), "detail": detail})
	if not first.has(event):
		first[event] = {"tick": _tick(), "room": String(here), "detail": detail}
		if event in ["borrow_offered", "borrow_checked", "opportunity", "command_accepted", "projectile_block", "granted", "resolved_used"]:
			_queue_shot(event)


func _queue_shot(event: String) -> void:
	if not snapshot_dir.is_empty():
		pending_shots.append({"event": event, "tick": _tick()})


func _process(_delta: float) -> void:
	if pending_shots.is_empty():
		return
	# A real GL framebuffer, captured after the event tick's physics and UI.
	# This also works when the draw loop is disabled between evidence frames.
	RenderingServer.force_draw(true)
	var frame := get_viewport().get_texture().get_image()
	for shot in pending_shots:
		var name := "%s-%d.png" % [shot.event, shot.tick]
		if frame == null or frame.is_empty() or frame.save_png(snapshot_dir.path_join(name)) != OK:
			push_error("Cannot capture real viewport " + name)
	pending_shots.clear()


func _seed_added_node(node: Node) -> void:
	super(node)
	if room == &"1-1":
		_observe_archer_attack(node)
	if node is ScarecrowEnemy:
		(node as ScarecrowEnemy).swing_resolving.connect(_swing_resolving)
	elif node is BulldogCompanion and epoch >= 0 and flow.get_session() != null:
		_note("companion_entered_tree", String((node as BulldogCompanion).companion_id), flow.get_session().level.id)


func _observe_archer_attack(node: Node) -> void:
	if node is ArcherEnemy:
		var archer := node as ArcherEnemy
		var record := {"added": _tick(), "aims": [], "arrows": []}
		early_archers.append(record)
		early_archer_index[archer.get_instance_id()] = record
		archer.tree_exiting.connect(func() -> void:
			record["removed"] = _tick()
			record["dead"] = archer.is_dead()
			record["total_shots"] = archer.shots_fired
			record["total_aims"] = archer.aims_started)
	elif node is AttackTelegraph and node.get_parent() is ArcherEnemy and (node as AttackTelegraph).shape == AttackTelegraph.Shape.LINE:
		var archer := node.get_parent() as ArcherEnemy
		var record: Dictionary = early_archer_index.get(archer.get_instance_id(), {})
		if not record.is_empty():
			record.aims.append({"tick": _tick(), "at": "hero" if archer.target is GoldiePlayer else "other"})
	elif node is EnemyProjectile:
		var shot := node as EnemyProjectile
		if shot.shooter is ArcherEnemy and early_archer_index.has(shot.shooter.get_instance_id()):
			var record: Dictionary = early_archer_index[shot.shooter.get_instance_id()]
			var arrow := {"tick": _tick()}
			record.arrows.append(arrow)
			shot.tree_exiting.connect(func() -> void:
				arrow["blocked"] = shot.blocked
				arrow["hits"] = shot.hits)


func _swing_resolving(mark: AttackTelegraph) -> void:
	var player := _live_player()
	if player != null and not player.is_downed() and mark.intersects_sector_body(player.global_position, EnemyBase.radius_of(player)):
		_note("sweep_body_at_release")


func _observe_flying_arrow(player: GoldiePlayer) -> void:
	for node: Node in get_tree().get_nodes_in_group(EnemyProjectile.GROUP):
		var shot := node as EnemyProjectile
		if shot == null or shot.is_queued_for_deletion() or shot.state != EnemyProjectile.State.FLYING or not shot.data.blockable:
			continue
		var end := shot.global_position + shot.direction * (shot.length - shot.traveled)
		if EnemyProjectile.segment_distance(shot.global_position, end, player.global_position) > EnemyBase.radius_of(player) + shot.data.hit_radius:
			continue
		if not first.has("body_on_live_arrow_lane"):
			_note("body_on_live_arrow_lane")
		if is_instance_valid(dog) and not first.has("live_arrow_lane_with_companion"):
			_note("live_arrow_lane_with_companion")
		return


func _room_entered(id: StringName) -> void:
	room = id
	dog = null
	last_reduction = 0
	hold_until = -1
	turn_tick = -1
	cue_tick = -1
	charge_source = ""
	follow_charged = false
	_escape_think_left = 0.0
	_escape_direction = Vector2.ZERO
	_note("entry_" + String(id))


func _observe_reduction() -> void:
	if is_instance_valid(dog) and dog.rally_protected_hits > last_reduction:
		_note("protected_damage", "prevented_total=" + str(dog.rally_prevented_damage))
		last_reduction = dog.rally_protected_hits


func _blocked(_at: Vector2) -> void:
	last_block = _tick()
	_note("projectile_block", "commanded" if is_instance_valid(dog) and dog.rally_left > 0.0 else "passive")


func _granted(_bonus: float) -> void:
	charge_source = "projectile" if last_block == _tick() else "protected_damage"
	_note("granted", charge_source)
	_note("granted_" + charge_source)
	hold_until = -1
	follow_charged = response == "follow"


func _resolved(result: StringName) -> void:
	_note("resolved_" + String(result), charge_source)
	charge_source = ""
	follow_charged = false


func _live_player() -> GoldiePlayer:
	var session := flow.get_session()
	if session == null or not session.can_process() or not session.is_playing() or not session.is_intro_done():
		return null
	var arena := flow.get_arena()
	return arena.call(&"get_player") as GoldiePlayer if arena != null else null


func _physics_process(_delta: float) -> void:
	if epoch < 0 or flow == null or flow.state != FlowMain.State.LEVEL:
		return
	var player := _live_player()
	if player == null or player.is_downed():
		return
	if not first.has("playable_" + String(room)):
		_note("playable_" + String(room))
	var dogs := get_tree().get_nodes_in_group(&"companion")
	for unit: Node in dogs:
		if unit is BulldogCompanion and not unit.is_queued_for_deletion():
			dog = unit as BulldogCompanion
			break
	_observe_flying_arrow(player)
	if not is_instance_valid(dog) or not dog.is_inside_tree() or dog.is_queued_for_deletion():
		return
	if not first.has("companion"):
		_note("companion")
	if dog.is_protecting(player.global_position) and not first.has("active_cover"):
		_note("active_cover")
	_observe_reduction()
	var hud := flow.get_hud()
	if hud == null:
		return
	var command := hud.get("companion_guard") as CompanionGuardControl
	if command == null or not command.is_visible_in_tree() or command.button.disabled:
		return
	if not first.has("command_ready"):
		_note("command_ready")
	if get_tree().get_nodes_in_group(&"enemy").is_empty() or dog.celebrating or dog.mode == BulldogCompanion.Mode.DAZED or player.celebrating:
		return
	if not first.has("command_usable"):
		_note("command_usable")
	for node: Node in get_tree().get_nodes_in_group(&"attack_warnings"):
		var mark := node as AttackTelegraph
		if mark == null or not mark.is_visible_damage_warning():
			continue
		var attacker := mark.get_parent() as EnemyBase
		if attacker == null or not attacker.is_targetable() or attacker._telegraph != mark:
			continue
		var kind := ""
		if attacker is ScarecrowEnemy and mark.shape == AttackTelegraph.Shape.SECTOR:
			kind = "sweep"
		elif attacker is ArcherEnemy and (attacker as ArcherEnemy).projectile.blockable and mark.shape == AttackTelegraph.Shape.LINE:
			kind = "arrow"
		if kind.is_empty():
			continue
		if mark.overlaps_body(player.global_position, player.tuning.body_radius):
			if not first.has("opportunity_" + kind):
				_note("opportunity_" + kind)
			if not first.has("opportunity"):
				_note("opportunity", kind)
		elif response != "follow" or kind != "arrow":
			continue
		if response != "skip" and turn_tick < 0 and (_tick() - cue_tick >= 90 or cue_tick < 0):
			_note("responded_to_" + kind)
			offered_direction = player.global_position.direction_to(attacker.global_position)
			cue_tick = _tick()
			turn_tick = _tick() + 1
		break


func _click_control(button: BaseButton) -> void:
	var at := button.get_global_transform_with_canvas() * (button.size / 2.0)
	for is_down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_down else 0
		event.pressed = is_down
		event.position = at
		event.global_position = at
		button.get_viewport().push_input(event, true)


func _play_level() -> void:
	if not route_tested and flow.is_event_open() and BuildRoutes.is_route_event(flow.level_events.get_open_id()):
		route_tested = true
		var menu := flow.get_trick_choice()
		_note("route_prompt")
		# Normal route cards reject clicks for 0.45 wall seconds. At fixed FPS the
		# engine can run faster than wall time. Give *both* clocks time to settle.
		await _frames(36)
		OS.delay_msec(470)
		var toggle := menu.find_child("ShieldEcho", true, false) as BaseButton
		if toggle != null and toggle.is_visible_in_tree():
			_note("borrow_offered", "on" if toggle.button_pressed else "off")
			await _frames(1)
			if borrow and not toggle.button_pressed:
				_click_control(toggle)
				if toggle.button_pressed:
					_note("borrow_checked")
		else:
			await _frames(1)
		var card := menu.find_child("Card" + str(route_choice), true, false) as BaseButton
		if toggle != null and toggle.is_visible_in_tree() and borrow and not toggle.button_pressed:
			push_error("Shield option did not accept the viewport click")
			get_tree().quit(2)
			return
		await _frames(1) # Render the selected toggle before the normal route card closes.
		if card != null and card.is_visible_in_tree():
			_click_control(card)
		if not flow.is_event_open():
			_note("route_confirmed")
		else:
			push_error("Route button did not accept the viewport click")
			get_tree().quit(2)
		return
	await super()


func _steer() -> void:
	super()
	if turn_tick < 0 and hold_until < _tick() and response != "follow":
		return
	var player := _live_player()
	if player == null:
		return
	if turn_tick >= 0:
		if _tick() <= turn_tick:
			player.set_move_override(offered_direction)
			return
		var control := flow.get_hud().get("companion_guard") as CompanionGuardControl
		if control != null and control.is_visible_in_tree() and not control.button.disabled:
			var before := dog.rally_commands
			_click_control(control.button)
			if dog.rally_commands > before:
				_note("command_accepted")
				hold_until = _tick() + RESPONSE_TICKS
		turn_tick = -1
	if hold_until >= _tick():
		player.set_move_override(Vector2.ZERO)
	elif response == "follow" and is_instance_valid(dog) and not dog.is_queued_for_deletion():
		if follow_charged:
			var nearest := player._nearest_enemy(INF)
			if nearest != null:
				_approach_and_stop(player, nearest, minf(38.0, GameState.player_stats.attack_range - 4.0))
		elif dog.rally_cooldown_left <= 0.0:
			for node: Node in get_tree().get_nodes_in_group(&"enemy"):
				if node is ArcherEnemy and (node as ArcherEnemy).is_targetable():
					_approach_and_stop(player, node as ArcherEnemy, 24.0)
					break


func _approach_and_stop(player: GoldiePlayer, target: Node2D, distance: float) -> void:
	var offset := target.global_position - player.global_position
	player.set_move_override(offset.normalized() if offset.length() > distance + EnemyBase.radius_of(target) else Vector2.ZERO)
