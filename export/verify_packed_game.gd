extends SceneTree
## Run outside the source project with --main-pack DoggyKnight.exe.
## Validates the delivered pack with the matching Godot engine on the build host.
## This is not a native Windows execution test or a GPU rendering test.

func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	if load("res://game/combat/arena.tscn") == null:
		push_error("Missing production arena")
		quit(1)
		return
	var checked: int = 0
	for chapter: int in range(1, 7):
		for level: int in range(1, 7):
			var resource: Resource = load("res://data/levels/level_%d_%d.tres" % [chapter, level])
			if resource == null or resource.get("background") == null:
				push_error("Missing level or background %d-%d" % [chapter, level])
				quit(1)
				return
			checked += 1
	for companion: String in ["bulldog", "lancelot", "tristan", "gawain"]:
		var resource: Resource = load("res://data/companions/%s.tres" % companion)
		if resource == null or resource.get("scene") == null:
			push_error("Missing companion " + companion)
			quit(1)
			return
	if ResourceLoader.exists("res://tests/framework/test_runner.tscn"):
		push_error("Test scene incorrectly included in playtest")
		quit(1)
		return
	var pause := (load("res://ui/pause/pause.tscn") as PackedScene).instantiate() as Control
	root.add_child(pause)
	pause.visible = true
	await process_frame
	await process_frame
	var panel := pause.get("_panel") as PanelContainer
	if panel.size.x > 180 or panel.size.y > 320:
		push_error("Desktop pause menu exceeds the base game viewport")
		quit(1)
		return
	print("PACK_OK: %d levels, 4 companions, production UI; tests excluded" % checked)
	pause.queue_free()
	await process_frame
	quit(0)
