class_name StoryTheme
extends RefCounted

static func install() -> void:
	var theme := load("res://ui/theme/main_theme.tres") as Theme
	theme.default_font = load("res://assets/fonts/StorySans.otf") as Font
	theme.default_font_size = 11
	# Preserve all content margins: responsive cards and touch targets retain their contracts.
	for type: StringName in theme.get_type_list():
		for name: StringName in theme.get_stylebox_list(type):
			var old := theme.get_stylebox(name, type)
			# Empty layout/focus boxes and scrollbar tracks must keep zero minimums.
			# Adding a border to ScrollContainer's empty panel enlarges its minimum width.
			if old is StyleBoxEmpty or String(type).contains("Scroll"):
				continue
			var box := StyleBoxFlat.new()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				box.set_content_margin(side, old.get_content_margin(side))
			var is_button := String(type).contains("Button")
			var is_card := String(type).contains("Card")
			var secondary := String(type).contains("Alt") or String(type).contains("Violet")
			box.bg_color = Color("e9d7b0")
			box.border_color = Color("927248")
			if is_button and not is_card:
				box.bg_color = Color("233d3c") if secondary else Color("d3aa61")
			if name == &"pressed":
				box.bg_color = box.bg_color.darkened(0.18)
			if name == &"hover":
				box.bg_color = box.bg_color.lightened(0.12)
			if name == &"disabled":
				box.bg_color = Color("7b7d70")
			if String(type).contains("Dark"):
				box.bg_color = Color("19302f")
			if String(type).begins_with("Ribbon"):
				box.bg_color = Color("294340")
			box.set_border_width_all(1)
			box.set_corner_radius_all(2)
			box.shadow_color = Color(0.04, 0.08, 0.07, 0.28)
			box.shadow_size = 1
			box.shadow_offset = Vector2(0, 1)
			theme.set_stylebox(name, type, box)
		for color_name: StringName in theme.get_color_list(type):
			if color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
				var light := String(type).contains("Light") or String(type).contains("Alt") or String(type).contains("Violet") or String(type).contains("Pop")
				theme.set_color(color_name, type, Color("f5e8cb") if light else Color("302b24"))
		theme.set_color(&"font_shadow_color", type, Color(0, 0, 0, 0))

		for constant in [&"outline_size", &"shadow_offset_x", &"shadow_offset_y"]:
			theme.set_constant(constant, type, 0)
	# Stronger brush terminals keep display headings distinct from the reading face.
	var serif := preload("res://assets/fonts/StoryDisplay.tres")
	for type in [&"LabelTitle", &"LabelBig", &"LabelHeading"]:
		theme.set_type_variation(type, &"Label")
		theme.set_font(&"font", type, serif)
		theme.set_color(&"font_color", type, Color("f5e8cb") if type != &"LabelHeading" else Color("302b24"))
	theme.set_font_size(&"font_size", &"LabelHeading", 16)
	theme.set_color(&"font_color", &"LabelSoft", Color("655d50"))
	theme.set_color(&"font_color", &"LabelPop", Color("f5e8cb"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("fff2c5")
	focus.set_border_width_all(1)
	focus.set_expand_margin_all(1)
	for type in [&"Button", &"ButtonAlt", &"ButtonViolet"]:
		theme.set_stylebox(&"focus", type, focus)
	# Draw inside the parchment so focus stays legible over any battlefield.
	var card_focus := StyleBoxFlat.new()
	card_focus.draw_center = false
	card_focus.border_color = Color("205249")
	card_focus.set_border_width_all(2)
	card_focus.set_corner_radius_all(2)
	for type in [&"CardButton", &"CardEvolve", &"CardMerlin", &"CardMorgana"]:
		theme.set_stylebox(&"focus", type, card_focus)
