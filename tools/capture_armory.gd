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
	var record := {"name": label, "root_inside_safe": safe.encloses(box.get_global_rect()),
		"actions_inside_safe": not actions.visible or safe.encloses(actions.get_global_rect()),
		"scroll_height": screen.get("_body_scroll").size.y}
	if "--atelier-only" in OS.get_cmdline_user_args():
		record["window"] = [root.size.x, root.size.y]
		for area: String in ["_actions", "_wallet", "_body_scroll"]:
			var rect: Rect2 = (screen.get(area) as Control).get_global_rect()
			record[area.trim_prefix("_")] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		var body: Control = screen.get("_details") if screen.get("_showing_details") else screen.get("_list")
		var caption: Control = body.find_child("Caption", true, false)
		if caption != null:
			var cabinet: Control = caption.get_parent()
			var exhibit := cabinet.get_node("Hero" if cabinet.has_node("Hero") else "Specimen") as Control
			var text_rect := caption.get_global_rect()
			var stage := cabinet.get_global_rect()
			var subject := exhibit.get_global_rect()
			record["cabinet_rect"] = [stage.position.x, stage.position.y, stage.size.x, stage.size.y]
			record["subject_rect"] = [subject.position.x, subject.position.y, subject.size.x, subject.size.y]
			record["caption_rect"] = [text_rect.position.x, text_rect.position.y, text_rect.size.x, text_rect.size.y]
			record["caption_clears_figure"] = exhibit.get_global_rect().end.x <= text_rect.position.x
			record["caption_inside_cabinet"] = stage.encloses(text_rect)
			for label_node in caption.find_children("*", "Label", true, false):
				if not stage.grow(0.5).encloses((label_node as Control).get_global_rect()):
					record.caption_inside_cabinet = false
		var visible_cards := 0
		for item in body.find_children("Item_*", "Button", true, false):
			if (screen.get("_body_scroll") as Control).get_global_rect().encloses((item as Control).get_global_rect()):
				visible_cards += 1
		record["fully_visible_item_buttons"] = visible_cards
	checks.append(record)
	if "--layout-only" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURE ", label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	if "--atelier-only" in OS.get_cmdline_user_args():
		await capture_atelier()
		return
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

func capture_atelier() -> void:
	root.size = Vector2i(360, 640)
	await frames()
	var main: Node = load("res://game/flow/main.tscn").instantiate()
	main.save_path = "user://atelier-capture-%d.json" % OS.get_process_id()
	root.add_child(main)
	await frames(20)
	main.get_screen().get("_equipment_button").pressed.emit()
	await frames()
	screen = main.get("_equipment_screen")
	var state := root.get_node("GameState")
	var before: Dictionary = state.get("equipment").duplicate(true)
	await shot("shop_01_common")
	screen.get("_list").find_child("Item_training_sword", true, false).pressed.emit()
	await shot("shop_02_try_lv1")
	screen.get("_details").get_node("FittingOptions/current").pressed.emit()
	await shot("shop_03_current")
	screen.get("_details").get_node("FittingOptions/max").pressed.emit()
	await shot("shop_04_common_max")
	screen.back()
	screen.get("_tab_buttons")["epic"].pressed.emit()
	await shot("shop_05_epic")
	screen.get("_list").find_child("Item_sunblade", true, false).pressed.emit()
	screen.get("_details").get_node("FittingOptions/max").pressed.emit()
	await shot("shop_06_epic_max")
	var retained: bool = state.get("equipment") == before
	screen.back()
	state.equipment.owned = {"sunblade": 9, "oathplate": 9, "pack_bell": 3}
	state.equipment.loadouts = {"knight": {"weapon": "sunblade", "armor": "oathplate", "treasure_a": "pack_bell"}}
	screen.get("_tab_buttons")["owned"].pressed.emit()
	await shot("shop_07_staged_owned")
	var safe: Script = load("res://core/safe_area.gd")
	safe.simulate_notch = true
	root.size = Vector2i(390, 844)
	await frames(4)
	screen.get("_list").find_child("Item_oathplate", true, false).pressed.emit()
	await shot("shop_08_notched")
	safe.simulate_notch = false
	var good := retained
	for check in checks:
		good = good and check.root_inside_safe and check.actions_inside_safe and check.scroll_height > 0
		good = good and check.get("caption_clears_figure", false) and check.get("caption_inside_cabinet", false)
	var file := FileAccess.open(out.path_join("shop_layout.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checkpoints": checks, "try_on_preserved_profile": retained}, "\t") + "\n")
	file.close()
	main.save_store.delete()
	main.queue_free()
	await frames(3)
	quit(0 if good else 1)
