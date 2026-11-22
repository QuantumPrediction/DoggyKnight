extends Node
## Production UI/arena rendered in staged positions; not a human gameplay study.
var out := OS.get_environment("ART_CAPTURE_DIR")
var arena: CombatArena
var event_ui: Control
var trick_ui: Control
var evidence: Array[Dictionary] = []

func _ready() -> void:
	run.call_deferred()

func frames(count: int = 8) -> void:
	for i in count:
		await get_tree().process_frame

func shot(name: String, ui: Control) -> void:
	await get_tree().create_timer(0.85).timeout
	await RenderingServer.frame_post_draw
	var safe := SafeArea.get_safe_rect()
	var fits := true
	var text_fits := true
	var children_fit := true
	for card: Button in ui.get("cards"):
		fits = fits and safe.encloses(card.get_global_rect())
		var desc := card.get_node("Description") as Label
		text_fits = text_fits and desc.get_line_count() * desc.get_line_height() <= desc.size.y + 1
		if ui == event_ui:
			for child_name in ["Tone", "Name", "Description", "Icon", "Portrait"]:
				var child := card.get_node(child_name) as Control
				children_fit = children_fit and Rect2(Vector2.ZERO, card.size).encloses(Rect2(child.position, child.size))
				if child is Label:
					text_fits = text_fits and child.get_line_count() * child.get_line_height() <= child.size.y + 1
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	evidence.append({"capture": name, "cards_fit": fits, "text_fits": text_fits, "children_fit": children_fit})
	print("CAPTURE ", name, " ", fits, " ", text_fits, " ", children_fit)

func world(hero: StringName) -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		await frames(2)
	GameState.hero_class = hero
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.reset_run()
	arena = preload("res://game/combat/arena.tscn").instantiate()
	add_child(arena)
	arena.set_background(load("res://assets/backgrounds/farm_fence.tscn"))
	arena.get_player().set_physics_process(false)
	arena.get_player().global_position = Vector2(90, 270)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.set_physics_process(false)
	dog.global_position = Vector2(115, 270)

func run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(540, 960)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	event_ui = preload("res://ui/event_choice/event_choice.tscn").instantiate()
	trick_ui = preload("res://ui/trick_choice/trick_choice.tscn").instantiate()
	layer.add_child(event_ui)
	layer.add_child(trick_ui)
	for hero in HeroClasses.IDS:
		await world(hero)
		var event := BuildRoutes.event_for(hero)
		event_ui.call(&"show_event", event.id, event.offer_options())
		await shot("route_" + String(hero), event_ui)
	for level in [&"1-2", &"1-3", &"1-5"]:
		var event := BuildRoutes.encounter_for(level)
		event_ui.call(&"show_event", event.id, event.offer_options())
		await shot("encounter_" + String(level), event_ui)
	for story_event in LevelEventTable.load_default().events:
		event_ui.call(&"show_event", story_event.id, story_event.offer_options())
		await shot("story_" + String(story_event.id), event_ui)
	get_tree().root.size = Vector2i(360, 640)
	await world(&"knight")
	var event := BuildRoutes.event_for(&"knight")
	event_ui.call(&"show_event", event.id, event.offer_options())
	await shot("small_route", event_ui)
	var story_event := LevelEventTable.load_default().get_event(&"purple_feather")
	event_ui.call(&"show_event", story_event.id, story_event.offer_options())
	await shot("small_story", event_ui)
	get_tree().root.size = Vector2i(390, 844)
	SafeArea.simulate_notch = true
	await world(&"mage")
	event = BuildRoutes.event_for(&"mage")
	event_ui.call(&"show_event", event.id, event.offer_options())
	await shot("notched_route", event_ui)
	event_ui.call(&"show_event", story_event.id, story_event.offer_options())
	await shot("notched_story", event_ui)
	event_ui.hide()
	await world(&"knight")
	GameState.run_route = &"bulwark"
	GameState.active_tricks.append(&"bark")
	trick_ui.call(&"show_options", [TrickDeck.load_trick(&"bark"), TrickDeck.load_trick(&"roll"), TrickDeck.load_trick(&"shake")])
	await shot("guided_upgrade", trick_ui)
	SafeArea.simulate_notch = false
	var file := FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()
	get_tree().quit(0 if evidence.all(func(row: Dictionary) -> bool: return row.cards_fit and row.text_fits and row.children_fit) else 1)
