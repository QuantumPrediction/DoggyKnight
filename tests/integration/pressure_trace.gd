extends "res://tests/integration/playthrough_bot.gd"
## Read-only observer of the unchanged chapter bot. No RNG, inputs or stat changes.

var _damage_events: Array[Dictionary] = []
var _captain_samples: Array[Dictionary] = []
var _sample_left: float = 0.0
var _pressure_samples: Array[Dictionary] = []
const Visible = preload("res://tests/integration/visible_pressure.gd")

func _ready() -> void:
	EventBus.player_damaged.connect(_trace_damage)
	super()

func _snapshot() -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player") as GoldiePlayer
	var row := {"time": _sim_seconds, "attempt": _attempts.size(), "level": "",
		"vigor": GameState.vigor, "enemies": []}
	if flow != null and flow.get_session() != null:
		row.level = String(flow.get_session().level.id)
	if player == null:
		return row
	row.player = [player.global_position.x, player.global_position.y]
	row.input = [player.get_move_input().x, player.get_move_input().y]
	row.velocity = [player.velocity.x, player.velocity.y]
	row.invulnerable = player.invuln_left > 0.0 or player.abilities.is_invulnerable()
	row.attack_range = GameState.player_stats.attack_range
	row.warnings = []
	var marks := Visible.warnings(get_tree())
	for mark in marks:
		var warning: Dictionary = Visible.snapshot(mark)
		warning.covers_player_body = Visible.covers(mark, player.global_position, player.tuning.body_radius)
		row.warnings.append(warning)
	# This is a local geometric diagnostic, not proof that a path is reachable
	# before impact. It ignores acceleration, future warnings and moving bodies.
	row.clear_local_steps = 0
	for i in 16:
		var probe := player.global_position + Vector2.from_angle(TAU * i / 16.0) * 18.0
		if Layout.ARENA_RECT.grow(-14.0).has_point(probe) and Visible.warning_cost(marks, probe, player.tuning.body_radius) == 0.0:
			row.clear_local_steps += 1
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as EnemyBase
		if enemy == null:
			continue
		var info := {"id": String(enemy.data.id), "hp": enemy.hp,
			"distance": enemy.global_position.distance_to(player.global_position),
			"position": [enemy.global_position.x, enemy.global_position.y],
			"state": EnemyBase.State.keys()[enemy.state], "phase": enemy.get(&"phase"),
			"target_player": enemy.target == player}
		if enemy is CaptainBoss:
			info.phase = CaptainBoss.Phase.keys()[enemy.phase]
			info.summons = enemy.alive_summons()
			info.phase_left = enemy._phase_left
		row.enemies.append(info)
	return row

func _trace_damage(amount: int) -> void:
	var row := _snapshot()
	row.amount = amount
	row.stack = get_stack()
	_damage_events.append(row)

func _physics_process(delta: float) -> void:
	_sample_left -= delta
	if _sample_left > 0.0:
		return
	_sample_left = 0.5
	if flow != null and flow.state == FlowMain.State.LEVEL and not get_tree().paused:
		if flow.get_session() != null and flow.get_session().level.id == &"1-4":
			_pressure_samples.append(_snapshot())
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node is CaptainBoss:
			_captain_samples.append(_snapshot())
			break

func _write_report(finished: bool) -> bool:
	var ok := super(finished)
	if report_path.is_empty():
		return ok
	var file := FileAccess.open(report_path + ".trace.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"damage": _damage_events, "captain": _captain_samples,
		"pressure": _pressure_samples,
		"scope": "Read-only snapshots and synchronous damage call stacks; same bot policy and RNG. Local clear steps are geometric samples, not guaranteed reachable escape paths."}) + "\n")
	file.close()
	return ok
