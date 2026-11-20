extends SceneTree
## Real engine renders. UI-only staged profile; never touches a player's save.
var out := OS.get_environment("ART_CAPTURE_DIR")
var screen: Node
var checks: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func frames(n: int = 10) -> void:
	for i in n:
		await process_frame

func shot(label: String) -> void:
	await frames()
	var safe_script: Script = load("res://core/safe_area.gd")
	var safe: Rect2 = safe_script.call("get_safe_rect")
	var actions: Control = screen.get("_actions")
	var box: Control = screen.get("_root")
	checks.append({"name": label, "root_inside_safe": safe.encloses(box.get_global_rect()), "actions_inside_safe": not actions.visible or safe.encloses(actions.get_global_rect()), "scroll_height": screen.get("_body_scroll").size.y})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURE ", label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(540, 960)
	root.title = "Golden Knight — elemental capture"
	await frames()
	var inventory: Script = load("res://game/equipment/equipment_inventory.gd")
	var state := root.get_node("GameState")
	state.set("meta_upgrades", {})
	state.set("hero_class", &"knight")
	state.set("chapters_cleared", 0)
	var p: Dictionary = load("res://tests/integration/equipment_profiles.gd").make("knight", "common1")
	state.set("equipment", p)
	screen = load("res://ui/equipment/equipment_screen.gd").new()
	screen.commit = func(action: String, id: String, hero: String, slot: String, currency: String) -> Dictionary:
		return inventory.call("transact", p, action, id, hero, slot, currency, 6)
	root.add_child(screen)
	await shot("01_earth_starter")
	screen.show_item("training_sword")
	await shot("02_earth_weapon")
	screen._open_elements()
	await shot("03_four_elements")
	screen._choose_element("fire")
	await shot("04_fire_preview")
	screen.get("_body_scroll").scroll_vertical = 1000
	await shot("04b_fire_comparison")
	screen.get("_body_scroll").scroll_vertical = 0
	screen._ask("attune", "fire", "coins")
	await shot("05_fire_confirmation")
	screen._confirm_transaction()
	screen.back()
	screen.back()
	await shot("06_mixed_loadout")
	screen.show_item("quilted_vest")
	screen._open_elements()
	screen._choose_element("fire")
	await shot("07_matching_armor_preview")
	screen.get("_body_scroll").scroll_vertical = 1000
	await shot("07b_matching_comparison")
	screen.get("_body_scroll").scroll_vertical = 0
	screen._ask("attune", "fire", "coins")
	screen._confirm_transaction()
	screen.back()
	screen.back()
	await shot("08_fire_resonance")
	root.size = Vector2i(360, 640)
	screen.show_item("quilted_vest")
	screen._open_elements()
	screen._choose_element("water")
	await shot("09_small_water_preview")
	screen._ask("attune", "water", "coins")
	await shot("10_small_confirmation")
	root.size = Vector2i(390, 844)
	var safe_script: Script = load("res://core/safe_area.gd")
	safe_script.set("simulate_notch", true)
	screen._layout()
	screen._choose_element("wind")
	await shot("11_notch_wind_preview")
	screen._ask("attune", "wind", "coins")
	await shot("12_notch_confirmation")
	safe_script.set("simulate_notch", false)
	var file := FileAccess.open(out.path_join("layout_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(checks, "\t"))
	file.close()
	screen.queue_free()
	await frames(3)
	quit()
