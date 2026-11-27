extends "res://tests/integration/six_episode_campaign.gd"
## Use a fresh profile and --build=techniques. Capture the first qualifying card
## and the first two effects during normal combat. The campaign harness owns inputs.

var directory := ""
var pictures := {}


func _run() -> void:
	directory = OS.get_environment("ART_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		push_error("Technique gallery requires a rendering display and ART_CAPTURE_DIR")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await super()


func _play_level() -> void:
	if not pictures.has("skill-card") and flow.is_trick_choice_open():
		for card in flow.progression.get_current_offer():
			if not GameState.active_tricks.has(card.id) and not AttackTechniques.pair_hints(card.id, GameState.active_tricks).is_empty():
				await _frames(30)
				await _capture("skill-card")
				break
	if not flow.is_choice_open() and not get_tree().paused:
		for node in get_tree().get_nodes_in_group(&"friendly_technique"):
			var volley := node as TechniqueVolley
			if volley.is_queued_for_deletion():
				continue
			if not pictures.has("skill-lightning") and not volley.arcs.is_empty() and volley.age <= 0.14:
				await _capture("skill-lightning")
			if not pictures.has("skill-wind-star") and volley.ranks.y > 0 and volley.ranks.z > 0 and volley.blade_hits > 0 and volley.stars.size() > 1:
				await _capture("skill-wind-star")
	if pictures.size() == 3:
		var file := FileAccess.open(directory.path_join("skill-frames.json"), FileAccess.WRITE)
		file.store_line(JSON.stringify(pictures, "\t"))
		file.close()
		get_tree().quit(0)
		return
	await super()


func _capture(label: String) -> void:
	var row := {"chapter": GameState.chapter, "level": flow.get_level_index() + 1,
			"tick": Engine.get_physics_frames(), "tricks": GameState.active_tricks.duplicate()}
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if error != OK:
		push_error("Could not save " + label)
		get_tree().quit(2)
		return
	pictures[label] = row
	print("CAPTURE ", label, " ", JSON.stringify(row))
