extends "res://tests/integration/playthrough_bot.gd"
## Passive unless a named attack, delay and steering direction are supplied.
## Samples after actor physics. Signals capture geometry at the actual damage test.

const Legacy = preload("res://tests/integration/visible_pressure.gd")

var _file: FileAccess
var _level_epoch: int = -1
var _live: Dictionary = {}
var _last_resolver: String = ""
var _event_tick: int = -1
var _fork: String = ""
var _delay: int = 0
var _direction: String = ""
var _steering: Vector2 = Vector2.ZERO
var _overriding: bool = false
var _fork_ended: bool = false
var _frames_seen: int = 0
var _legacy_only_frames: int = 0
var _legacy_overcounts: int = 0
var _arrival_overlaps: int = 0
var _queued_overlaps: int = 0
var _other_overlaps: int = 0
var _real_multi_frames: int = 0
var _logged_damage: int = 0

func _ready() -> void:
	process_physics_priority = 1000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fork="):
			_fork = arg.trim_prefix("--fork=")
		elif arg.begins_with("--delay="):
			_delay = int(arg.trim_prefix("--delay="))
		elif arg.begins_with("--direction="):
			_direction = arg.trim_prefix("--direction=")
	if not _fork.is_empty() and (_delay < 0 or _direction not in ["radial", "left", "right", "stop"]):
		push_error("Invalid fork delay/direction")
		get_tree().quit(2)
		return
	get_tree().node_added.connect(_watch)
	EventBus.player_damaged.connect(_damage)
	EventBus.level_started.connect(_entered)
	super()
	_file = FileAccess.open(report_path + ".windows.jsonl", FileAccess.WRITE)
	if _file == null:
		push_error("Cannot write window trace: " + report_path)
		get_tree().quit(2)

func _entered(id: StringName) -> void:
	if id == &"1-4" and _level_epoch < 0:
		_level_epoch = Engine.get_physics_frames()

func _tick() -> int:
	return Engine.get_physics_frames() - _level_epoch

func _in_trial() -> bool:
	return _level_epoch >= 0 and flow != null and flow.get_session() != null and flow.get_session().level.id == &"1-4" and flow.state == FlowMain.State.LEVEL

func _watch(node: Node) -> void:
	if node is ScarecrowEnemy:
		var enemy := node as ScarecrowEnemy
		enemy.warning_committed.connect(_began.bind(enemy))
		enemy.swing_resolving.connect(_resolved.bind(enemy))

func _write(row: Dictionary) -> void:
	if _file != null:
		_file.store_line(JSON.stringify(row))

func _point(v: Vector2) -> Array:
	return [v.x, v.y]

func _key(enemy: ScarecrowEnemy) -> String:
	return "%d.%d" % [enemy.rng_seed_override, enemy.attacks_started]

func _player() -> GoldiePlayer:
	return get_tree().get_first_node_in_group(&"player") as GoldiePlayer

func _player_state(player: GoldiePlayer) -> Dictionary:
	var status := player.tactics_status()
	var bounds := CombatMath.arena_bounds(player._arena_margin)
	return {"xy": _point(player.global_position), "v": _point(player.velocity),
		"input": _point(player.get_move_input()), "holding_move": player._was_moving,
		"phase": status.phase, "roll": status.roll, "roll_left": status.roll_left,
		"rolling_left": status.roll_active_left, "immune": player.invuln_left > 0.0 or player.abilities.is_invulnerable(),
		"speed": GameState.player_stats.move_speed * player.abilities.speed_mult(),
		"accel_time": player.tuning.accel_time, "decel_time": player.tuning.decel_time,
		"radius": EnemyBase.radius_of(player), "cue_radius": player.tuning.body_radius,
		"bounds": [bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]}

func _began(mark: AttackTelegraph, enemy: ScarecrowEnemy) -> void:
	if not _in_trial() or enemy.data.id != &"scarecrow":
		return
	var player := _player()
	if player == null:
		return
	var key := _key(enemy)
	_live[key] = {"owner": weakref(enemy), "mark": weakref(mark), "start": _tick()}
	_event_tick = _tick()
	_write({"op": "begin", "t": _tick(), "id": key, "attempt": _attempts.size(),
		"player_target": enemy.target == player, "p": _player_state(player), "origin": _point(mark.global_position),
		"dir": _point(mark.direction), "radius": mark.radius, "angle": mark.half_angle,
		"covers": mark.intersects_sector_body(player.global_position, EnemyBase.radius_of(player)),
		"visible": mark.is_visible_damage_warning(), "tracking": mark.show_aim_lock and not mark.aim_locked,
		"tell_seconds": enemy._tell_total})

func _resolved(mark: AttackTelegraph, enemy: ScarecrowEnemy) -> void:
	_last_resolver = ""
	var key := _key(enemy)
	if not _live.has(key):
		return
	var player := _player()
	if player == null:
		return
	_last_resolver = key
	_event_tick = _tick()
	_write({"op": "impact", "t": _tick(), "id": key, "p": _player_state(player),
		"origin": _point(mark.global_position), "dir": _point(mark.direction),
		"covers": mark.intersects_sector_body(player.global_position, EnemyBase.radius_of(player)),
		"tracking": mark.show_aim_lock and not mark.aim_locked})
	_ended(key)

func _ended(key: String) -> void:
	_live.erase(key)
	if key == _fork:
		_fork_ended = true

func _damage(amount: int) -> void:
	if not _in_trial():
		return
	var source := ""
	var owner := ""
	for call_frame: Dictionary in get_stack():
		var path := str(call_frame.source)
		if path.ends_with("/scarecrow.gd") and call_frame.function == "_swing":
			owner = _last_resolver
			source = path.get_file()
			break
		if source.is_empty() and (path.contains("/enemies/") or path.ends_with("/enemy_projectile.gd")) and not path.ends_with("/enemy_base.gd"):
			source = path.get_file()
	_logged_damage += amount
	_event_tick = _tick()
	_write({"op": "damage", "t": _tick(), "id": owner, "source": source, "amount": amount, "attempt": _attempts.size()})

func _steer() -> void:
	super()
	if _overriding:
		var player := _player()
		if player != null:
			player.set_move_override(_steering)

func _physics_process(_delta: float) -> void:
	if _level_epoch < 0 or (not _in_trial() and _live.is_empty() and _event_tick != _tick()):
		return
	var player := _player()
	if player == null:
		_cancel_missing()
		return
	var counts := AttackTelegraph.warning_counts(get_tree(), player.global_position, player.tuning.body_radius)
	var old_count := 0
	var excluded := [0, 0, 0]
	for mark in Legacy.warnings(get_tree()):
		if Legacy.covers(mark, player.global_position, player.tuning.body_radius):
			old_count += 1
			if not mark.is_in_group(&"attack_warnings") or not mark.is_visible_damage_warning():
				if not mark.damage_warning:
					excluded[0] += 1
				elif mark.is_queued_for_deletion():
					excluded[1] += 1
				else:
					excluded[2] += 1
	_frames_seen += 1
	_legacy_only_frames += int(old_count > 0 and counts.x == 0)
	_legacy_overcounts += int(old_count > counts.x)
	_arrival_overlaps += int(excluded[0])
	_queued_overlaps += int(excluded[1])
	_other_overlaps += int(excluded[2])
	_real_multi_frames += int(counts.x >= 2)
	_cancel_missing()
	if not _live.is_empty() or _event_tick == _tick():
		var actors: Array = []
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var enemy := node as EnemyBase
			if enemy != null and enemy.data != null:
				actors.append([enemy.rng_seed_override, enemy.data.id, enemy.global_position.x, enemy.global_position.y, enemy.velocity.x, enemy.velocity.y, enemy.state])
		var warning_rows: Array = []
		for node in get_tree().get_nodes_in_group(&"attack_warnings"):
			var mark := node as AttackTelegraph
			if mark != null and mark.is_visible_damage_warning():
				warning_rows.append([mark.shape, mark.global_position.x, mark.global_position.y, mark.direction.x, mark.direction.y, mark.radius, mark.half_angle, mark.length, mark.width, mark.progress, mark.show_aim_lock and not mark.aim_locked, mark.overlaps_body(player.global_position, player.tuning.body_radius)])
		_write({"op": "frame", "t": _tick(), "ids": _live.keys(), "p": _player_state(player),
			"paused": get_tree().paused, "time_scale": CombatFx.time_scale, "actors": actors, "warnings": warning_rows,
			"legacy": old_count, "production": [counts.x, counts.y], "excluded": excluded})
	# Input written after sampling tick T is first consumed by player physics at T+1.
	if not _overriding and _live.has(_fork) and _tick() - int(_live[_fork].start) == _delay:
		var mark: AttackTelegraph = _live[_fork].mark.get_ref()
		_steering = (player.global_position - mark.global_position).normalized()
		if _steering == Vector2.ZERO:
			_steering = mark.direction
		if _direction == "left":
			_steering = mark.direction.orthogonal()
		elif _direction == "right":
			_steering = -mark.direction.orthogonal()
		elif _direction == "stop":
			_steering = Vector2.ZERO
		_write({"op": "input", "t": _tick(), "id": _fork, "dir": _point(_steering), "delay": _delay})
		_overriding = true
		player.set_move_override(_steering)
	if _fork_ended:
		_finish_fork()

func _cancel_missing() -> void:
	for key: String in _live.keys():
		var mark: AttackTelegraph = _live[key].mark.get_ref()
		var enemy: ScarecrowEnemy = _live[key].owner.get_ref()
		if enemy == null or mark == null or mark.is_queued_for_deletion() or not _in_trial():
			_write({"op": "cancel", "t": _tick(), "id": key})
			_event_tick = _tick()
			_ended(key)

func _finish_fork() -> void:
	_file.close()
	_file = null
	get_tree().quit(0 if _overriding else 2)

func _write_report(finished: bool) -> bool:
	var ok := super(finished)
	if _file == null:
		return false
	_cancel_missing()
	_write({"op": "end", "frames": _frames_seen, "legacy_only": _legacy_only_frames,
		"legacy_overcounts": _legacy_overcounts, "arrival_overlaps": _arrival_overlaps,
		"queued_overlaps": _queued_overlaps, "other_overlaps": _other_overlaps,
		"real_multi": _real_multi_frames, "damage": _logged_damage})
	_file.close()
	_file = null
	return ok and _fork.is_empty()
