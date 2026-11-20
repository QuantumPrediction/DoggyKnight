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
	root.size = Vector2i(540, 960)
	await frames(3)
	var state := root.get_node("GameState")
	var inventory: Script = load("res://game/equipment/equipment_inventory.gd")
	var p: Dictionary = inventory.call("defaults")
	p.coins = 2600
	p.gems = 120
	p.shards = 18
	p.owned = {"training_sword": 5, "sunblade": 3, "oathplate": 3, "pack_bell": 3, "hearth_heart": 1}
	p.loadouts = {"knight": {"weapon":"sunblade", "armor":"oathplate", "treasure_a":"pack_bell", "treasure_b":"hearth_heart"}}
	state.set("equipment", p)
	state.set("hero_class", &"knight")
	state.set("chapters_cleared", 5)
	var screen: Node = load("res://ui/equipment/equipment_screen.gd").new()
	screen.commit = func(action: String, id: String, hero: String, slot: String, currency: String) -> Dictionary:
		return inventory.call("transact", p, action, id, hero, slot, currency, 6)
	root.add_child(screen)
	screen.selected = "sunblade"
	screen.refresh()
	await frames(8)
	await shot("equipment_loadout")
	screen.show_item("sunblade")
	await frames(8)
	await shot("equipment_detail")
	screen.back()
	screen.tab = "epic"
	screen.selected = "avalon_grail"
	screen.refresh()
	await frames(8)
	await shot("equipment_arcade")
	screen.show_item("avalon_grail")
	screen._ask("buy", "", "gems")
	await frames(8)
	await shot("equipment_confirm")
	root.size = Vector2i(360, 640)
	await frames(6)
	await shot("equipment_small")
	screen.queue_free()
	await frames(3)
	quit()
