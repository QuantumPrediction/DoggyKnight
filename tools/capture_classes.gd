extends SceneTree
var out := OS.get_environment("ART_CAPTURE_DIR")
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURE ", label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	if "--selection-only" in OS.get_cmdline_user_args():
		await capture_class_picker()
		quit()
		return
	root.size = Vector2i(540, 960)
	await frames(3)
	var state := root.get_node("GameState")
	state.set("hero_class", &"knight")
	state.call("reset_run")
	var title: Node = load("res://ui/screens/title.tscn").instantiate()
	root.add_child(title)
	await frames(75)
	await shot("title")
	title.new_game_button.pressed.emit()
	for id in [&"knight", &"mage", &"archer"]:
		title.get_class_select().select(id)
		await frames(8)
		await shot("select_" + String(id))
	title.queue_free()
	await frames(3)
	for id in [&"knight", &"mage", &"archer"]:
		state.set("hero_class", id)
		state.call("reset_run")
		var arena: Node = load("res://game/combat/arena.tscn").instantiate()
		root.add_child(arena)
		arena.set_background(load("res://assets/backgrounds/wheat_field.tscn"))
		var player: Node2D = arena.get_player()
		player.invuln_left = 100.0
		player.global_position = Vector2(65, 180)
		for i in 5:
			arena.spawn_enemy(&"scarecrow", Vector2(105 + (i % 2) * 22, 130 + i * 19))
		var layer := CanvasLayer.new()
		layer.layer = 10
		root.add_child(layer)
		var hud: Node = load("res://ui/hud/hud.tscn").instantiate()
		layer.add_child(hud)
		root.get_node("EventBus").emit_signal("level_started", &"1-2")
		await frames(65)
		hud.title_card.hide()
		await shot("battle_" + String(id))
		hud.cut_in.play(1.2)
		await frames(22)
		await shot("ultimate_" + String(id))
		layer.queue_free()
		arena.queue_free()
		await frames(3)
	# Narrow portrait is the original 2x logical layout, a common small desktop window.
	root.size = Vector2i(360,640)
	await frames(3)
	var picker: Node = load("res://ui/screens/class_select.gd").new()
	root.add_child(picker)
	picker.select(&"mage")
	await frames(8)
	await shot("small_select")
	picker.queue_free()
	await frames(3)
	quit()

## Open the normal title menu so the first-chapter challenge and focus state are real.
func capture_class_picker() -> void:
	root.size = Vector2i(360, 640)
	await frames(4)
	var title: Node = load("res://ui/screens/title.tscn").instantiate()
	root.add_child(title)
	await frames(15)
	title.new_game_button.pressed.emit()
	var picker: Control = title.get_class_select()
	for button in picker.choices:
		button.grab_focus()
		button.pressed.emit()
		await frames(6)
		await shot("class_" + String(picker.selected))
	var safe = load("res://core/safe_area.gd")
	safe.simulate_notch = true
	picker._layout()
	await frames(6)
	await shot("class_archer_notched")
	safe.simulate_notch = false
	title.queue_free()
	await frames(3)
