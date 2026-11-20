extends "res://tests/integration/combat_readability_showcase.gd"
## Staged before/after information hierarchy, using actual actors and warnings.
## No fake HUD values; positions/focus are staged, not a human gameplay recording.

func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(540, 960)
	await world(&"archer")
	var player := arena.get_player() as GoldiePlayer
	player._focus_elapsed = 0.35
	archer._ai(archer._aim_total * 0.2)
	await shot("tracking_aim")
	player._focus_elapsed = player.loadout.focus_time
	archer._ai(archer._aim_total * 0.4)
	await shot("locked_focus_priority")
	get_tree().root.size = Vector2i(360, 640)
	var soldier := arena.spawn_enemy(&"scarecrow", player.global_position - Vector2(20, 0)) as ScarecrowEnemy
	soldier.set_physics_process(false)
	soldier.target = player
	soldier._start_telegraph(Vector2.RIGHT, false)
	soldier._telegraph.progress = 0.65
	await shot("overlap_small")
	# Place the actor outside both marks. No change to either enemy's commitment.
	player.global_position = Vector2(138, 202)
	player._focus_elapsed = 0.0
	await shot("outside_marked_area")
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await world(&"archer")
	player = arena.get_player() as GoldiePlayer
	player._focus_elapsed = player.loadout.focus_time
	archer._ai(archer._aim_total * 0.6)
	await shot("locked_notched")
	SafeArea.simulate_notch = false
	var expected: Array[int] = [1, 1, 2, 0, 1]
	for i in evidence.size():
		evidence[i]["expected_warnings"] = expected[i]
		evidence[i]["warnings_match"] = int(evidence[i].status.get("warning_count", -1)) == expected[i]
	var file := FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()
	get_tree().quit(0 if evidence.all(func(row: Dictionary) -> bool: return row.safe and row.text_fits and row.warnings_match) else 1)
