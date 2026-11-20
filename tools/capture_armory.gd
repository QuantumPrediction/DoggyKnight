extends SceneTree
## Actual renderer captures with staged profiles. No player save is read or written.
var out := OS.get_environment("ART_CAPTURE_DIR")
var screen: Node
var inventory: Script
var checks: Array[Dictionary] = []
func _initialize() -> void:
	run.call_deferred()
func frames(n: int = 8) -> void:
	for i in n:
		await process_frame
func shot(label: String) -> void:
	await frames()
	var safe_script: Script = load("res://core/safe_area.gd")
	var safe: Rect2 = safe_script.call("get_safe_rect")
	var actions: Control = screen.get("_actions")
	var box: Control = screen.get("_root")
	checks.append({"name": label, "root_inside_safe": safe.encloses(box.get_global_rect()),
		"actions_inside_safe": not actions.visible or safe.encloses(actions.get_global_rect()),
		"scroll_height": screen.get("_body_scroll").size.y})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURE ", label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(540, 960)
	root.title = "Golden Knight — armory capture"
	await frames()
	inventory = load("res://game/equipment/equipment_inventory.gd")
	var state := root.get_node("GameState")
	state.set("meta_upgrades", {})
	state.set("hero_class", &"knight")
	state.set("chapters_cleared", 0)
	state.set("equipment", inventory.call("defaults"))
	screen = load("res://ui/equipment/equipment_screen.gd").new()
	root.add_child(screen)
	await shot("01_first_loadout")
	screen._choose_tab("common")
	await shot("02_common_shop")
	screen.show_item("training_sword")
	await shot("03_purchase_preview")
	var p: Dictionary = inventory.call("defaults")
	p.coins = 2600
	p.gems = 120
	p.shards = 18
	p.owned = {"training_sword": 2, "sunblade": 3, "oathplate": 3, "pack_bell": 3, "hearth_heart": 1, "stormbow": 5}
	p.loadouts = {"knight": {"weapon": "training_sword", "armor": "oathplate", "treasure_a": "pack_bell", "treasure_b": "hearth_heart"}, "archer": {"weapon": "stormbow"}}
	state.set("equipment", p)
	screen.commit = func(action: String, id: String, hero: String, slot: String, currency: String) -> Dictionary:
		return inventory.call("transact", p, action, id, hero, slot, currency, 6)
	screen.back()
	screen._choose_tab("owned")
	await shot("04_equipped")
	screen.show_item("training_sword")
	await shot("05_forge_preview")
	screen._ask("upgrade", "", "coins")
	await shot("06_forge_confirm")
	screen._confirm_transaction()
	await shot("07_forge_success")
	screen.back()
	screen._choose_tab("epic")
	await shot("08_epic_shop")
	screen.show_item("avalon_grail")
	await shot("09_chapter_lock")
	state.set("chapters_cleared", 5)
	screen.show_item("oathplate")
	root.size = Vector2i(360, 640)
	await shot("10_small_detail")
	screen._ask("upgrade", "", "coins")
	await shot("11_small_confirm")
	screen.back()
	screen._choose_hero("archer")
	screen.show_item("stormbow")
	root.size = Vector2i(390, 844)
	var safe_script: Script = load("res://core/safe_area.gd")
	safe_script.set("simulate_notch", true)
	screen._layout()
	await shot("12_tall_notch_bow")
	safe_script.set("simulate_notch", false)
	var file := FileAccess.open(out.path_join("layout_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(checks, "\t"))
	file.close()
	screen.queue_free()
	await frames(3)
	quit()
