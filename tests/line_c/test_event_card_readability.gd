extends TestCase
## Exercise the actual story data after theme inheritance and deferred art attachment.
const SCENE := preload("res://ui/event_choice/event_choice.tscn")
var ui: Control

func before_each() -> void:
	ui = SCENE.instantiate()
	add_child(ui)
	await wait_frames(2)

func after_each() -> void:
	ui.queue_free()
	await wait_frames(2)

func check_card(card: Button, context: String) -> void:
	var inside := Rect2(Vector2.ZERO, card.size)
	for child_name in ["Tone", "Name", "Description", "Icon", "Portrait"]:
		var child := card.get_node(child_name) as Control
		assert_true(inside.encloses(Rect2(child.position, child.size)), "%s %s stays inside card: %s" % [context, child_name, Rect2(child.position, child.size)])
		if child is Label:
			assert_true(child.get_line_count() * child.get_line_height() <= child.size.y + 1, "%s %s shows every line" % [context, child_name])
	var icon := card.get_node("Icon") as TextureRect
	assert_true(icon.size.x <= 16 and icon.size.y <= 16, "%s option icon stays small after portrait reskin" % context)
	var title := card.get_node("Name") as Label
	var desc := card.get_node("Description") as Label
	assert_true(title.position.y + title.size.y <= desc.position.y, "%s title does not overlap benefits or costs" % context)

func test_all_story_event_content_fits_after_illustrated_art_attaches() -> void:
	for event in LevelEventTable.load_default().events:
		ui.show_event(event.id, event.offer_options())
		await wait_frames(4)
		for card: Button in ui.cards:
			check_card(card, "%s/%s" % [event.id, card.name])

func test_route_and_encounter_content_still_fits() -> void:
	var events: Array[LevelEvent] = []
	for hero in HeroClasses.IDS:
		events.append(BuildRoutes.event_for(hero))
	for level in [&"1-2", &"1-3", &"1-5"]:
		events.append(BuildRoutes.encounter_for(level))
	for event in events:
		ui.show_event(event.id, event.offer_options())
		await wait_frames(4)
		for card: Button in ui.cards:
			check_card(card, "%s/%s" % [event.id, card.name])

func test_story_event_words_have_contrast_in_each_button_state() -> void:
	var event := LevelEventTable.load_default().get_event(&"purple_feather")
	ui.show_event(event.id, event.offer_options())
	await wait_frames(4)
	for card: Button in ui.cards:
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			var paper := (card.get_theme_stylebox(state) as StyleBoxFlat).bg_color
			for child_name in ["Tone", "Name", "Description"]:
				var label := card.get_node(child_name) as Label
				var ink := label.get_theme_color(&"font_color") * label.modulate
				var a := _luminance(ink)
				var b := _luminance(paper)
				assert_true((maxf(a, b) + 0.05) / (minf(a, b) + 0.05) >= 4.5, "%s/%s %s has readable ink" % [card.name, child_name, state])

func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
