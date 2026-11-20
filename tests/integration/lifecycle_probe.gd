extends Node
## Real flow/scene churn, separate from gameplay balance and the full test suite.
## A fresh isolated user directory is required when launching this developer scene.

var cycles: int = 30
var output: String = ""
var rows: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="):
			cycles = maxi(1, int(arg.trim_prefix("--cycles=")))
		elif arg.begins_with("--report="):
			output = arg.trim_prefix("--report=")
	_run.call_deferred()


func _run() -> void:
	for index in cycles:
		var flow := preload("res://game/flow/main.tscn").instantiate() as FlowMain
		flow.save_path = "user://lifecycle_probe.json"
		SaveStore.new(flow.save_path).delete()
		flow.rng_seed = 7
		add_child(flow)
		await _frames(5)
		GameState.hero_class = [&"knight", &"mage", &"archer"][index % 3]
		GameState.chapter = 1
		GameState.difficulty = &"normal"
		flow.start_new_game()
		for frame in 240:
			for box in get_tree().get_nodes_in_group(&"dialogue_box"):
				if box.has_method(&"is_active") and box.call(&"is_active"):
					box.call(&"skip")
			await _frames(1)
		var reached_level := flow.state == FlowMain.State.LEVEL and flow.get_arena() != null
		# Exercise the production pause/title cleanup, not just a detached mock.
		EventBus.back_requested.emit()
		await _frames(3)
		EventBus.quit_to_title_requested.emit()
		await _frames(30)
		flow.queue_free()
		await _frames(15)
		rows.append({"cycle": index + 1, "reached_level": reached_level, "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
			"enemies_remaining": get_tree().get_nodes_in_group(&"enemy").size(),
			"players_remaining": get_tree().get_nodes_in_group(&"player").size()})
		print(JSON.stringify(rows[-1]))
	var file := FileAccess.open(output, FileAccess.WRITE) if not output.is_empty() else null
	if file != null:
		file.store_string(JSON.stringify({"cycles": rows, "scope": "Production flow scene churn with dialogue skip, pause and title return; accelerated headless test, not long-session/device or native-crash certification."}, "\t") + "\n")
		file.close()
	get_tree().quit(0 if file != null else 2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
