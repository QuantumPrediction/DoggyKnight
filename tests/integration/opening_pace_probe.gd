extends "res://tests/integration/playthrough_bot.gd"
## Counts targetable foes once per playable physics tick in the first two rooms.
## The inherited bot owns every action, random seed and attempt limit.

var _histogram: Array[int] = []
var _diagnostic_finished: bool = false


func _ready() -> void:
	EventBus.level_started.connect(_reset_room)
	super()


func _reset_room(_id: StringName) -> void:
	_histogram.clear()


func _physics_process(_delta: float) -> void:
	if flow == null or flow.state != FlowMain.State.LEVEL:
		return
	var session := flow.get_session()
	if session == null or not session.can_process() or not session.is_playing() or not session.is_intro_done():
		return
	var count := 0
	for foe: Node in get_tree().get_nodes_in_group(&"enemy"):
		if foe is EnemyBase and not foe.is_queued_for_deletion() and (foe as EnemyBase).is_targetable():
			count += 1
	while _histogram.size() <= count:
		_histogram.append(0)
	_histogram[count] += 1


func _record_attempt(result: Dictionary) -> void:
	super(result)
	_attempts[-1]["active_enemy_histogram"] = _histogram.duplicate()


func _on_results() -> void:
	var result := flow.get_last_result()
	if String(result["level_id"]) != "1-2":
		await super()
		return
	if _diagnostic_finished:
		return
	_diagnostic_finished = true
	_record_attempt(result)
	_outcome = "opening_complete"
	var saved := _write_report(true)
	SaveStore.new(SAVE_PATH).delete()
	get_tree().quit(0 if saved else 2)
