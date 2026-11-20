extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var music := root.get_node("Music")
	var rows: Array[Dictionary] = []
	for lap in 4:
		for track: StringName in [&"field", &"boss_2", &"field_4", &"boss_6", &"title"]:
			var start := Time.get_ticks_usec()
			music.call(&"play", track, 0.05)
			rows.append({"lap": lap + 1, "track": track, "us": Time.get_ticks_usec() - start,
				"playing": music.call(&"playing_track") == track})
			await create_timer(0.2).timeout
	print("MUSIC_SWITCHES " + JSON.stringify(rows))
	quit()
