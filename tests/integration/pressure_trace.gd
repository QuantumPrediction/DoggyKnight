extends "res://tests/integration/playthrough_bot.gd"
## Read-only observer of the unchanged chapter bot. No RNG, inputs or stat changes.

var _damage_events: Array[Dictionary] = []
var _captain_samples: Array[Dictionary] = []
var _sample_left: float = 0.0

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
	row.attack_range = GameState.player_stats.attack_range
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as EnemyBase
		if enemy == null:
			continue
		var info := {"id": String(enemy.data.id), "hp": enemy.hp,
			"distance": enemy.global_position.distance_to(player.global_position),
			"position": [enemy.global_position.x, enemy.global_position.y]}
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
		"scope": "Read-only snapshots and synchronous damage call stacks; same bot policy and RNG."}, "\t") + "\n")
	return ok
