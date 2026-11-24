extends SceneTree
## Matched 360×640 proofs. The arena and damage routine are the game's normal scenes;
## the camera, combatants and warning are posed to compare lettering across revisions.

const POSITIONS := [Vector2(52, 135), Vector2(128, 135), Vector2(52, 213), Vector2(128, 213)]
const AMOUNTS := [12, 24, 108, 7]
var output: String = OS.get_environment("TYPE_CAPTURE_DIR")
var metrics: Dictionary = {"hits": [], "controls": {}}
var failed: bool = false


func _initialize() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await process_frame


func capture(label: String, crop: Rect2i = Rect2i()) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var pic := root.get_texture().get_image()
	if pic != null and pic.get_size() == Vector2i(360, 640) and crop.has_area():
		pic = pic.get_region(crop)
	var expected := crop.size if crop.has_area() else Vector2i(360, 640)
	if pic == null or pic.get_size() != expected or pic.save_png(output.path_join(label + ".png")) != OK:
		push_error("Missing 360×640 proof: " + label)
		failed = true


func rect(control: Control) -> Array:
	var r := control.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func run() -> void:
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Set TYPE_CAPTURE_DIR to a writable comparison directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("trace"))
	root.size = Vector2i(360, 640)
	seed(19)
	await frames(3)
	var state := root.get_node("GameState")
	state.set("hero_class", &"knight")
	state.call("reset_run")
	var title: Node = load("res://ui/screens/title.tscn").instantiate()
	root.add_child(title)
	await frames(75)
	metrics.controls.new_game = rect(title.new_game_button)
	metrics.controls.logo = rect(title.get("_logo"))
	await capture("title")
	title.new_game_button.pressed.emit()
	await frames(12)
	var selection: Node = title.get_class_select()
	metrics.controls.class_confirm = rect(selection.confirm_button)
	metrics.controls.class_cancel = rect(selection.cancel_button)
	var reinforced := selection.find_child("ReinforcedButton", true, false) as Button
	if reinforced != null:
		metrics.controls.class_reinforced = rect(reinforced)
	await capture("selection")
	title.queue_free()
	await frames(3)

	var arena: Node = load("res://game/combat/arena.tscn").instantiate()
	arena.set("spawn_telegraph_time", 0.0)
	root.add_child(arena)
	arena.set_background(load("res://assets/backgrounds/wheat_field.tscn"))
	var player: Node2D = arena.get_player()
	player.global_position = Vector2(90, 174)
	var enemies: Array[Node2D] = []
	for at: Vector2 in POSITIONS:
		var foe: Node2D = arena.spawn_enemy(&"scarecrow", at)
		foe.set("hp", 512)
		foe.set("max_hp", 512)
		enemies.append(foe)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	root.add_child(overlay)
	var hud: Node = load("res://ui/hud/hud.tscn").instantiate()
	overlay.add_child(hud)
	root.get_node("EventBus").emit_signal("level_started", &"1-1")
	await frames(32)
	metrics.controls.guard = rect(hud.companion_guard.button)
	metrics.controls.pause = rect(hud.pause_button)
	metrics.controls.ultimate = rect(hud.ultimate_button)
	metrics.stage_name = hud.title_card.name_label.text
	metrics.stage_font_size = hud.title_card.name_label.get_theme_font_size(&"font_size")
	await capture("stage")
	hud.title_card.hide()
	# An ordinary scarecrow uses its shipped wind-up to point toward its own number.
	enemies[0].call("_start_telegraph", Vector2.UP, false)
	var mark: Node2D = enemies[0].get("_telegraph")
	mark.set("progress", 0.72)
	metrics.warning = [mark.global_position.x, mark.global_position.y, mark.get("radius"), mark.get("half_angle")]
	seed(19)
	var numbers: Array[Node2D] = []
	for i in enemies.size():
		var foe := enemies[i]
		var before: int = foe.get("hp")
		foe.call("hit", AMOUNTS[i], player.global_position, 0.0, i)
		var current := get_nodes_in_group(&"damage_number")
		if current.size() != i + 1:
			push_error("The production hit did not create one popup")
			quit(1)
			return
		var number: Node2D = current.back()
		numbers.append(number)
		number.set_process(false)
		var lost: int = before - int(foe.get("hp"))
		metrics.hits.append({"amount": AMOUNTS[i], "hp_lost": lost, "popup_value": number.get("value"),
				"style": number.get("style"), "text": number.get("_text"),
				"initial_ink_lift": -float(number.get("_offset").y), "lifetime": number.get("_lifetime"),
				"anchor": [number.global_position.x, number.global_position.y]})
		if lost != AMOUNTS[i] or number.get("value") != AMOUNTS[i] or number.get("style") != i:
			failed = true
	overlay.process_mode = Node.PROCESS_MODE_DISABLED
	for n in numbers:
		n.hide()
	await capture("without-numbers")
	mark.hide()
	await capture("without-warning-or-numbers")
	mark.show()
	for n in numbers:
		n.show()
	await capture("impact")
	# A crop of the real warning at every live normal-hit frame, including the descending arc.
	for frame in range(42):
		if frame == 8:
			await capture("impact-frame8")
		await capture("trace/%02d" % frame, Rect2i(50, 204, 108, 70))
		if frame < 41:
			for n in numbers:
				n.call("_process", 1.0 / 60.0)
	for n in numbers:
		n.hide()
	var received: Array[int] = []
	root.get_node("EventBus").connect("player_damaged", func(final: int) -> void: received.append(final), CONNECT_ONE_SHOT)
	var vigor: int = state.get("vigor")
	player.set("invuln_left", 0.0)
	player.call("take_damage", 17)
	var lost: int = vigor - int(state.get("vigor"))
	if received != [lost] or lost <= 0:
		failed = true
	var readout := hud.get_node_or_null("VigorBar/VigorLoss") as Label
	metrics.player_hit = {"attempt": 17, "hp_lost": lost, "event": received,
			"readout": readout.text if readout != null else "", "vigor_bar": rect(hud.vigor_bar)}
	if readout != null and readout.text != ("−%d" % lost):
		failed = true
	await capture("player-hit")
	metrics.renderer = DisplayServer.get_name()
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	if file == null:
		failed = true
	else:
		file.store_line(JSON.stringify(metrics, "  "))
		file.close()
	overlay.queue_free()
	arena.queue_free()
	await frames(3)
	print("TYPE_PROOF ", "FAIL" if failed else "OK", " ", metrics.renderer)
	quit(1 if failed else 0)
