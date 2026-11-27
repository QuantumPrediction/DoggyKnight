class_name EquipmentScreen
extends Control
## Illustrated armory. Preview never mutates a profile; every purchase is confirmed.
signal closed()
var commit: Callable
var hero: String = "knight"
var tab: String = "owned"
var selected: String = "training_sword"
var _root: VBoxContainer
var _classes: HBoxContainer
var _tabs: HBoxContainer
var _wallet: HBoxContainer
var _list: VBoxContainer
var _details: VBoxContainer
var _actions: VBoxContainer
var _body_scroll: ScrollContainer
var _showing_details: bool = false
var _choosing_element: bool = false
var _element_choice: String = ""
var _message: Label
var _confirm: Dictionary = {}
var _class_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _preview_slot: String = "weapon"
var _fitting_mode := "try"
var _atlas: Texture2D = preload("res://assets/illustrated/equipment/equipment_cutout.png")
const AtelierArt := preload("res://ui/equipment/atelier_art.gd")
const FittingFigure := preload("res://ui/illustrated/worn_gear_preview.gd")
const BANNER: Texture2D = preload("res://assets/illustrated/equipment/armory_forge.png")
const BODY_FONT: Font = preload("res://assets/fonts/StorySans.otf")
const TITLE_FONT: Font = preload("res://assets/fonts/StorySerif.otf")
const INK := Color("122a2d")
const GOLD := Color("edc778")
const CREAM := Color("f6edd8")
const MUTED := Color("b7c8bc")
const GREEN := Color("a9dfb1")
const RED := Color("f2ad98")
const HERO_NAMES := {"knight": "騎士", "mage": "法師", "archer": "弓手"}
const SLOT_NAMES := {"weapon": "武器", "armor": "護甲", "treasure_a": "寶物一", "treasure_b": "寶物二"}
const SET_NAMES := {"guardian": "守誓", "ranger": "林行", "scholar": "星學"}
const SET_EFFECTS := {"guardian": "活力 +8%", "ranger": "移速 +6%", "scholar": "經驗 +8%"}
const STAT_NAMES := {"attack_damage": "攻擊", "attack_range": "攻擊範圍", "attack_interval": "攻擊間隔", "max_vigor": "活力", "move_speed": "移速", "damage_taken_mult": "承傷倍率", "pickup_radius": "拾取", "exp_mult": "經驗倍率"}

func _ready() -> void:
	UiKit.setup_root(self)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	theme = theme.duplicate()
	theme.default_font = BODY_FONT
	hero = String(GameState.hero_class)
	if not GameState.equipment.owned.keys().any(func(id: String) -> bool:
		return EquipmentInventory.item(id).get("hero", "") in [hero, "all"] and int(GameState.equipment.owned[id]) > 0):
		tab = "common"
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 4)
	add_child(_root)
	var banner := Control.new()
	banner.custom_minimum_size.y = 34
	_root.add_child(banner)
	var painting := _picture(BANNER, Vector2.ZERO)
	painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(painting)
	var title := _label("軍械工坊", 17, GOLD)
	title.add_theme_font_override("font", TITLE_FONT)
	title.position = Vector2(5, 5)
	title.size = Vector2(94, 23)
	banner.add_child(title)
	_wallet = HBoxContainer.new()
	_wallet.add_theme_constant_override("separation", 4)
	_root.add_child(_wallet)
	var classes := HBoxContainer.new()
	_classes = classes
	classes.add_theme_constant_override("separation", 4)
	_root.add_child(classes)
	for id in EquipmentInventory.HEROES:
		var button := _button(HERO_NAMES[id], func() -> void: _choose_hero(id))
		_class_buttons[id] = button
		classes.add_child(button)
	var tabs := HBoxContainer.new()
	_tabs = tabs
	tabs.add_theme_constant_override("separation", 4)
	_root.add_child(tabs)
	for id in ["owned", "common", "epic"]:
		var button := _button({"owned": "配裝", "common": "普通商店", "epic": "史詩商場"}[id], func() -> void: _choose_tab(id))
		_tab_buttons[id] = button
		tabs.add_child(button)
	_body_scroll = ScrollContainer.new()
	_body_scroll.custom_minimum_size.y = 36
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	_root.add_child(_body_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(content)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	content.add_child(_list)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 5)
	content.add_child(_details)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	_root.add_child(_actions)
	_message = _label("裝備與鍛造會在下一關生效。", 7, MUTED)
	_root.add_child(_message)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	_root.add_child(footer)
	footer.add_child(_button("規則", _help))
	footer.add_child(_button("返回", func() -> void:
		if not back():
			closed.emit()))
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _layout() -> void:
	size = SafeArea.get_screen_size()
	var safe := SafeArea.get_safe_rect().grow(-6)
	_root.position = safe.position
	_root.size = safe.size

func _label(text: String, size_px: int = 9, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(fill: Color, border: Color, padding: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _skin(button: Button, active: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _style(Color("33483e") if active else Color("1b3739"), GOLD if active else Color("52645c")))
	button.add_theme_stylebox_override("hover", _style(Color("34514b"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("625431"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("fff0ac"), 0))
	button.add_theme_stylebox_override("disabled", _style(Color("233636"), Color("4b5b55")))
	button.add_theme_color_override("font_color", GOLD if active else CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_font_override("font", BODY_FONT)

func _button(text: String, action: Callable, width: float = 0) -> Button:
	var button := UiKit.button(text, &"ButtonAlt", Vector2(width, 24))
	button.add_theme_font_size_override("font_size", 8)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin(button)
	button.pressed.connect(action)
	return button

func _picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = minimum
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func icon(entry: Dictionary) -> Texture2D:
	var painted := StoryArt.object_icon(String(entry.get("id", "")))
	if painted != null:
		return painted
	var atlas := AtlasTexture.new()
	atlas.atlas = _atlas
	var cell := Vector2(_atlas.get_width() / 6.0, _atlas.get_height() / 3.0)
	var index := int(entry.icon)
	atlas.region = Rect2(Vector2(index % 6, floori(index / 6.0)) * cell, cell)
	atlas.filter_clip = true
	return atlas

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _choose_hero(id: String) -> void:
	_choosing_element = false
	hero = id
	selected = {"knight": "training_sword", "mage": "apprentice_staff", "archer": "ash_bow"}[id]
	_confirm.clear()
	_showing_details = false
	_body_scroll.scroll_vertical = 0
	refresh()

func _choose_tab(id: String) -> void:
	_choosing_element = false
	tab = id
	_confirm.clear()
	_showing_details = false
	_body_scroll.scroll_vertical = 0
	refresh()

func refresh() -> void:
	var profile := GameState.equipment
	_clear(_wallet)
	var wide_balance := maxi(int(profile.coins), maxi(int(profile.gems), int(profile.shards))) >= 10000
	for key in ["coins", "gems", "shards"]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", _style(Color("1a3335"), Color("42554d"), 2))
		_wallet.add_child(box)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		box.add_child(row)
		row.add_child(_picture(AtelierArt.emblem(key), Vector2(11, 11)))
		var currency: String = {"coins": "金幣", "gems": "寶石", "shards": "星鐵"}[key]
		var text := "%s\n%d" if wide_balance else "%s %d"
		var label := _label(text % [currency, profile[key]], 7, GOLD if key == "coins" else CREAM)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(label)
	for id in _class_buttons:
		_skin(_class_buttons[id], id == hero)
	for id in _tab_buttons:
		_skin(_tab_buttons[id], id == tab)
	_clear(_list)
	var entries: Array[Dictionary] = []
	var featured: Dictionary = {}
	for entry in EquipmentInventory.RULES.items:
		if entry.hero != "all" and entry.hero != hero:
			continue
		if tab == "owned":
			if int(profile.owned.get(entry.id, 0)) == 0:
				continue
		elif entry.quality != tab:
			continue
		entries.append(entry)
		if featured.is_empty() or selected == entry.id:
			featured = entry
	if tab == "owned":
		_loadout_display(profile)
		_loadout_strip(profile)
		_resonance_summary(_list, profile)
		if entries.is_empty():
			_list.add_child(_label("行囊還是空的。普通商店有武器和護甲，史詩商場另有寶物。", 8, MUTED))
	elif not featured.is_empty():
		_list.add_child(_featured_item(featured, profile))
		entries.erase(featured)
	if not entries.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_list.add_child(grid)
		for entry in entries:
			grid.add_child(_item_card(entry, profile))
	_list.visible = not _showing_details
	_details.visible = _showing_details
	_details_refresh()
	_layout.call_deferred()

func _piece_type(entry: Dictionary) -> String:
	return {"weapon": "武器", "armor": "護甲", "treasure": "寶物"}[entry.slot]

func _price(entry: Dictionary) -> String:
	if entry.quality == "epic":
		return "%d 金幣 或 %d 寶石" % [int(entry.coins), int(entry.gems)]
	return "%d 金幣" % int(entry.coins)

func _availability(entry: Dictionary, profile: Dictionary) -> String:
	var level := int(profile.owned.get(entry.id, 0))
	if level == 0:
		if int(entry.chapter) > mini(GameState.chapters_cleared + 1, GameState.CHAPTER_COUNT):
			return "第 %d 章開放" % int(entry.chapter)
		return "尚未收藏"
	if level >= EquipmentInventory.cap(entry):
		return "鍛造已達上限"
	var cost := EquipmentInventory.upgrade_cost(entry, level)
	var needs_coins := int(profile.coins) < int(cost.coins)
	var needs_shards := int(profile.shards) < int(cost.shards)
	if needs_coins and needs_shards:
		return "缺金幣及星鐵"
	if needs_coins or needs_shards:
		return "鍛造缺金幣" if needs_coins else "鍛造缺星鐵"
	return "可鍛造"

func _owned_rank(entry: Dictionary, profile: Dictionary) -> String:
	var equipped: bool = profile.loadouts.get(hero, {}).values().has(entry.id)
	return "%s Lv.%d/%d" % ["已裝備" if equipped else "已收藏", int(profile.owned[entry.id]), EquipmentInventory.cap(entry)]

func _case_text(copy: VBoxContainer, text: String, size_px: int, color: Color, title: bool = false) -> Label:
	var label := _label(text, size_px, color)
	if title:
		label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_color_override("font_outline_color", Color("1a211f"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("line_spacing", 0)
	copy.add_child(label)
	return label

func _featured_item(entry: Dictionary, profile: Dictionary) -> Button:
	var button := _button("", func() -> void: show_item(entry.id))
	button.name = "Item_" + entry.id
	button.tooltip_text = entry.name + " · 查看裝備"
	button.accessibility_name = _accessible_item_name(entry, profile)
	button.custom_minimum_size.y = 65
	_skin(button, true)
	var display := AtelierArt.case_art(entry.quality)
	button.add_child(display)
	display.offset_left = 1
	display.offset_right = -1
	display.offset_top = 1
	display.offset_bottom = -1
	_display_item(display, entry, profile)
	return button

func _accessible_item_name(entry: Dictionary, profile: Dictionary) -> String:
	var status := _owned_rank(entry, profile) if int(profile.owned.get(entry.id, 0)) > 0 else _price(entry)
	return "%s · %s · %s · %s" % [entry.name, _piece_type(entry), status, _availability(entry, profile)]

func _display_item(display: TextureRect, entry: Dictionary, profile: Dictionary) -> void:
	var specimen := _picture(icon(entry), Vector2.ZERO)
	specimen.name = "Specimen"
	AtelierArt.place_exhibit(display, specimen)
	var copy := AtelierArt.caption(display)
	_case_text(copy, "%s%s · 最高 Lv.%d" % ["普通" if entry.quality == "common" else "史詩", _piece_type(entry), EquipmentInventory.cap(entry)], 7, GOLD)
	_case_text(copy, entry.name, 11, CREAM, true)
	if int(profile.owned.get(entry.id, 0)) > 0:
		_case_text(copy, _owned_rank(entry, profile), 7, GREEN)
	else:
		_case_text(copy, _price(entry), 8, GOLD)
	_case_text(copy, _availability(entry, profile), 7, MUTED)

func _loadout_display(profile: Dictionary) -> void:
	var display := _dressing_case(_list)
	(display.get_node("Hero") as WornGearPreview).set_appearance(StringName(hero), profile)
	var copy := AtelierArt.caption(display)
	var stats := EquipmentPreview.stats(profile, hero)
	_case_text(copy, HERO_NAMES[hero] + " · 目前配裝", 10, CREAM, true)
	_case_text(copy, "攻擊 %d  ·  活力 %d" % [stats.attack_damage, stats.max_vigor], 8, GOLD)
	_case_text(copy, "攻擊間隔 %.3f 秒" % stats.attack_interval, 7, MUTED)

func _dressing_case(parent: VBoxContainer) -> TextureRect:
	var display := AtelierArt.case_art("owned")
	display.name = "FittingRoom"
	display.custom_minimum_size.y = 58
	parent.add_child(display)
	var figure := FittingFigure.new()
	figure.name = "Hero"
	AtelierArt.place_exhibit(display, figure)
	return display

func _loadout_strip(profile: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_list.add_child(row)
	for slot in EquipmentInventory.SLOTS:
		var id: String = profile.loadouts.get(hero, {}).get(slot, "")
		var button := _button("", func() -> void:
			if id != "":
				show_item(id)
			else:
				_choose_tab("epic" if slot.begins_with("treasure") else "common"))
		button.custom_minimum_size.y = 40
		row.add_child(button)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 2
		box.offset_right = -2
		box.offset_top = 2
		box.offset_bottom = -2
		box.add_theme_constant_override("separation", 1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		if id != "":
			button.accessibility_name = SLOT_NAMES[slot] + " · " + str(EquipmentInventory.item(id).name)
			box.add_child(_picture(icon(EquipmentInventory.item(id)), Vector2(24, 24)))
		else:
			button.tooltip_text = SLOT_NAMES[slot] + " · 尚未裝備"
			button.accessibility_name = button.tooltip_text
			box.add_child(_picture(AtelierArt.emblem(slot), Vector2(24, 24)))
		var label := _label(SLOT_NAMES[slot], 7, MUTED if id == "" else GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)

func _item_card(entry: Dictionary, profile: Dictionary) -> Button:
	var level := int(profile.owned.get(entry.id, 0))
	var equipped: bool = profile.loadouts.get(hero, {}).values().has(entry.id)
	var button := _button("", func() -> void: show_item(entry.id))
	button.name = "Item_" + entry.id
	button.custom_minimum_size = Vector2(65, 71)
	button.tooltip_text = entry.name + " · " + _availability(entry, profile)
	button.accessibility_name = _accessible_item_name(entry, profile)
	_skin(button, equipped)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3
	box.offset_right = -3
	box.offset_top = 2
	box.offset_bottom = -2
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var shelf := AtelierArt.shelf(entry.quality)
	shelf.custom_minimum_size.y = 28
	box.add_child(shelf)
	var exhibit := _picture(icon(entry), Vector2.ZERO)
	shelf.add_child(exhibit)
	exhibit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exhibit.offset_top = 1
	exhibit.offset_bottom = -1
	var element := EquipmentInventory.element_of(profile, entry.id)
	if element != "":
		var rune := _picture(ElementArt.icon(element), Vector2(11, 11))
		button.add_child(rune)
		rune.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		rune.offset_left = -15
		rune.offset_right = -3
		rune.offset_top = 3
		rune.offset_bottom = 15
	var name_label := _label(entry.name, 9)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var status := _label(_owned_rank(entry, profile) if level > 0 else _price(entry), 7, GREEN if level > 0 else GOLD)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var availability := _availability(entry, profile)
	var info := _piece_type(entry)
	if element != "":
		info += " · " + EquipmentInventory.element_name(element)
	if availability != "尚未收藏":
		info = availability
	var type_label := _label(info, 7, MUTED)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(type_label)
	return button

func _fitting_room(entry: Dictionary, profile: Dictionary) -> void:
	var owned := maxi(1, int(profile.owned.get(entry.id, 0)))
	var maximum := EquipmentInventory.cap(entry)
	if owned == maximum and _fitting_mode == "max":
		_fitting_mode = "try"
	var display := _dressing_case(_details)
	var copy := AtelierArt.caption(display)
	_case_text(copy, "%s%s · %s" % ["普通" if entry.quality == "common" else "史詩", _piece_type(entry), SET_NAMES[entry.group]], 7, GOLD)
	_case_text(copy, entry.name, 11, CREAM, true)
	_case_text(copy, "", 7, CREAM).name = "ViewLabel"
	var row := HBoxContainer.new()
	row.name = "FittingOptions"
	row.add_theme_constant_override("separation", 2)
	_details.add_child(row)
	var modes := {"current": "目前配裝", "try": "試穿 Lv.%d" % owned}
	if owned < maximum:
		modes["max"] = "滿級 Lv.%d" % maximum
	for mode: String in modes:
		var button := _button(modes[mode], _choose_fitting.bind(mode))
		button.name = StringName(mode)
		row.add_child(button)
	_choose_fitting(_fitting_mode)

func _choose_fitting(mode: String) -> void:
	_fitting_mode = mode
	var room := _details.get_node("FittingRoom")
	var profile := GameState.equipment
	var max_level := EquipmentInventory.cap(EquipmentInventory.item(selected))
	var level := max_level if mode == "max" else maxi(1, int(profile.owned.get(selected, 0)))
	var projected := profile if mode == "current" else EquipmentPreview.candidate(profile, hero, selected, _preview_slot, level)
	(room.get_node("Hero") as WornGearPreview).set_appearance(StringName(hero), projected)
	var view_label := room.find_child("ViewLabel", true, false) as Label
	var state := "目前配裝" if mode == "current" else "試穿 Lv.%d / %d" % [level, max_level]
	view_label.text = HERO_NAMES[hero] + " · " + state
	for button: Button in _details.get_node("FittingOptions").get_children():
		_skin(button, button.name == mode)

func _details_refresh() -> void:
	_clear(_details)
	_clear(_actions)
	_actions.visible = _showing_details
	_classes.visible = not _showing_details
	_tabs.visible = not _showing_details
	if not _showing_details:
		return
	var entry := EquipmentInventory.item(selected)
	if entry.is_empty():
		return
	var profile := GameState.equipment
	var level := int(profile.owned.get(selected, 0))
	if _choosing_element:
		_elements_refresh(entry, profile)
		return
	if entry.slot == "treasure":
		var case_art := AtelierArt.case_art(entry.quality)
		case_art.name = "TreasureDisplay"
		case_art.custom_minimum_size.y = 65
		_details.add_child(case_art)
		_display_item(case_art, entry, profile)
	else:
		_fitting_room(entry, profile)
	var element := EquipmentInventory.element_of(profile, selected)
	if element != "":
		_details.add_child(_element_badge(element))
		_details.add_child(_label(str(EquipmentInventory.RULES.elements[element][entry.slot + "_text"]), 8, ElementArt.color(element)))
	if entry.slot == "treasure":
		var slots := HBoxContainer.new()
		_details.add_child(slots)
		for slot: String in ["treasure_a", "treasure_b"]:
			var choose := _button("比較" + SLOT_NAMES[slot], func() -> void:
				_preview_slot = slot
				_confirm.clear()
				_details_refresh())
			_skin(choose, slot == _preview_slot)
			slots.add_child(choose)
	var can_forge := level > 0 and level < EquipmentInventory.cap(entry)
	var equipped: bool = profile.loadouts.get(hero, {}).get(_preview_slot, "") == selected
	var upgrading := can_forge and equipped
	_details.add_child(_label("鍛造 Lv.%d → %d" % [level, level + 1] if upgrading else "換入%s · 與目前配裝比較" % SLOT_NAMES[_preview_slot], 9, GOLD))
	var comparison := EquipmentPreview.compare(profile, hero, selected, _preview_slot, upgrading)
	_comparison_rows(comparison)
	if can_forge and not equipped:
		_details.add_child(_label("鍛造後（假設裝在此欄）", 9, GOLD))
		_comparison_rows(EquipmentPreview.compare(profile, hero, selected, _preview_slot, true))
	_details.add_child(_label(entry.desc, 8))
	var effects := EquipmentInventory.effect_text(entry, maxi(1, level))
	if not effects.is_empty():
		_details.add_child(_label(effects, 8, CREAM))
		if can_forge:
			_details.add_child(_label("下一級：" + EquipmentInventory.effect_text(entry, level + 1), 8, GREEN))
	_details.add_child(_label("出發屬性含永久訓練及套裝；不含當局把戲、暴擊及觸發加成。數值沿用實際取整規則。", 7, MUTED))
	if not _confirm.is_empty():
		_actions.add_child(_label(str(_confirm.message), 9, GOLD))
		var row := HBoxContainer.new()
		_actions.add_child(row)
		row.add_child(_button("確認", _confirm_transaction))
		row.add_child(_button("取消", func() -> void: _confirm.clear(); _details_refresh()))
		return
	if level == 0:
		var unlocked := int(entry.chapter) <= mini(GameState.chapters_cleared + 1, GameState.CHAPTER_COUNT)
		var buy := HBoxContainer.new()
		_actions.add_child(buy)
		for currency: String in (["coins", "gems"] if entry.quality == "epic" else ["coins"]):
			var price := int(entry[currency])
			var affordable := int(profile[currency]) >= price
			var button := _button("%d %s" % [price, "金幣" if currency == "coins" else "寶石"], _ask.bind("buy", "", currency))
			button.disabled = not unlocked or not affordable
			buy.add_child(button)
		var note := _purchase_note(entry, profile) if unlocked else "第 %d 章開放" % int(entry.chapter)
		_actions.add_child(_label(note, 7, MUTED))
	else:
		if can_forge:
			var cost := EquipmentInventory.upgrade_cost(entry, level)
			var button := _button("鍛造  %d 金幣%s" % [cost.coins, " + %d 星鐵" % cost.shards if int(cost.shards) > 0 else ""], _ask.bind("upgrade", "", "coins"))
			button.disabled = int(profile.coins) < int(cost.coins) or int(profile.shards) < int(cost.shards)
			_actions.add_child(button)
			if button.disabled:
				_actions.add_child(_label("還差 %d 金幣 / %d 星鐵" % [maxi(0, int(cost.coins) - int(profile.coins)), maxi(0, int(cost.shards) - int(profile.shards))], 7, MUTED))
		else:
			_actions.add_child(_label("鍛造已完成 · 最高 Lv.%d" % EquipmentInventory.cap(entry), 8, GOLD))
		_actions.add_child(_button(("卸下" if equipped else "裝備至") + SLOT_NAMES[_preview_slot], _execute.bind("unequip" if equipped else "equip", _preview_slot, "coins")))
		if element != "":
			_actions.add_child(_button("元素刻印 · 免費改配", _open_elements))

func _purchase_note(entry: Dictionary, profile: Dictionary) -> String:
	var coins := maxi(0, int(entry.coins) - int(profile.coins))
	if entry.quality == "common":
		return "金幣還差 %d" % coins if coins > 0 else "使用金幣購買"
	var gems := maxi(0, int(entry.gems) - int(profile.gems))
	if coins > 0 and gems > 0:
		return "還差 %d 金幣或 %d 寶石" % [coins, gems]
	if coins == 0 and gems == 0:
		return "可選金幣或寶石購買"
	return "可用金幣購買" if coins == 0 else "可用寶石購買"

func _element_badge(element: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_picture(ElementArt.icon(element), Vector2(14, 14)))
	row.add_child(_label(EquipmentInventory.element_name(element) + "刻印", 8, ElementArt.color(element)))
	return row

func _resonance_summary(parent: VBoxContainer, profile: Dictionary) -> void:
	var active := EquipmentInventory.resonance(profile, hero)
	var slots: Dictionary = profile.loadouts.get(hero, {})
	var weapon := EquipmentInventory.element_name(EquipmentInventory.element_of(profile, str(slots.get("weapon", ""))))
	var armor := EquipmentInventory.element_name(EquipmentInventory.element_of(profile, str(slots.get("armor", ""))))
	parent.add_child(_label("武器：%s  ＋  護甲：%s" % [weapon, armor], 8, MUTED))
	if active == "":
		parent.add_child(_label("共鳴未啟動 · 兩件同屬性即可啟動", 8, MUTED))
	else:
		var data: Dictionary = EquipmentInventory.RULES.elements[active]
		var row := _element_badge(active)
		(row.get_child(1) as Label).text = str(data.title) + " · 共鳴 2/2"
		parent.add_child(row)
		parent.add_child(_label(str(data.resonance_text), 7, ElementArt.color(active)))

func _open_elements() -> void:
	if int(GameState.equipment.owned.get(selected, 0)) <= 0:
		return
	_element_choice = EquipmentInventory.element_of(GameState.equipment, selected)
	if _element_choice == "":
		return
	_choosing_element = true
	_confirm.clear()
	_body_scroll.scroll_vertical = 0
	_details_refresh()

func _choose_element(element: String) -> void:
	if not EquipmentInventory.ELEMENTS.has(element):
		return
	_element_choice = element
	_confirm.clear()
	_details_refresh()

func _shared_element_notice(id: String) -> String:
	var users: Array[String] = []
	for class_id in EquipmentInventory.HEROES:
		if GameState.equipment.loadouts.get(class_id, {}).values().has(id):
			users.append(HERO_NAMES[class_id])
	return "刻印跟隨物品；目前使用：%s。" % "、".join(users) if not users.is_empty() else "刻印跟隨物品；共用此物品的職業會一起改變。"

func _elements_refresh(entry: Dictionary, profile: Dictionary) -> void:
	_details.add_child(_label(entry.name + " · 元素刻印", 12, GOLD))
	_details.add_child(_label("武器＋護甲同屬性，啟動一種共鳴。寶物不計入這兩件。", 8))
	_details.add_child(_label(_shared_element_notice(entry.id), 7, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_child(grid)
	for id in EquipmentInventory.ELEMENTS:
		var data: Dictionary = EquipmentInventory.RULES.elements[id]
		var button := _button("", _choose_element.bind(id))
		button.name = "Element_" + id
		button.custom_minimum_size = Vector2(74, 45)
		_skin(button, id == _element_choice)
		grid.add_child(button)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 3
		box.offset_right = -3
		box.offset_top = 2
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		button.add_child(box)
		var badge := _element_badge(id)
		(badge.get_child(0) as TextureRect).custom_minimum_size = Vector2(19, 19)
		box.add_child(badge)
		box.add_child(_label(str(data[entry.slot + "_text"]), 7, ElementArt.color(id)))
	var data: Dictionary = EquipmentInventory.RULES.elements[_element_choice]
	_details.add_child(_label(str(data.title) + " · 兩件共鳴", 10, ElementArt.color(_element_choice)))
	_details.add_child(_label(str(data.resonance_text), 8))
	var equipped: bool = profile.loadouts.get(hero, {}).get(entry.slot, "") == entry.id
	_details.add_child(_label("刻印後與目前比較" if equipped else "假設裝備此物品後，改刻印的差異", 9, GOLD))
	_comparison_rows(EquipmentPreview.compare_element(profile, hero, entry.id, _element_choice))
	_details.add_child(_label("免費、必定成功，保留等級。當關配裝保留到過關；新刻印在下一關生效。", 7, MUTED))
	if not _confirm.is_empty():
		_actions.add_child(_label(str(_confirm.message), 8, GOLD))
		var row := HBoxContainer.new()
		_actions.add_child(row)
		row.add_child(_button("確認刻印", _confirm_transaction))
		row.add_child(_button("取消", func() -> void: _confirm.clear(); _details_refresh()))
	else:
		var current := EquipmentInventory.element_of(profile, selected)
		var apply := _button("已是%s刻印" % EquipmentInventory.element_name(current) if current == _element_choice else "刻印為%s · 免費" % EquipmentInventory.element_name(_element_choice), _ask.bind("attune", _element_choice, "coins"))
		apply.disabled = current == _element_choice
		_actions.add_child(apply)

func _stat_text(key: String, value: float) -> String:
	match key:
		"attack_damage", "max_vigor": return "%d" % roundi(value)
		"attack_interval": return "%.3f 秒" % value
		"damage_taken_mult", "exp_mult": return "%.1f%%" % (value * 100)
		_: return "%.1f" % value

func _comparison_rows(comparison: Dictionary) -> void:
	if comparison.is_empty():
		return
	var before: StatBlock = comparison.before
	var after: StatBlock = comparison.after
	var changed := 0
	for key in EquipmentPreview.STAT_KEYS:
		var old := float(before.get(key))
		var value := float(after.get(key))
		if is_equal_approx(old, value):
			continue
		changed += 1
		var better := value < old if key in ["attack_interval", "damage_taken_mult"] else value > old
		_details.add_child(_label("%s  %s → %s" % [STAT_NAMES[key], _stat_text(key, old), _stat_text(key, value)], 8, GREEN if better else RED))
	if changed == 0:
		_details.add_child(_label("基礎屬性相同；請比較下方特效。", 8, MUTED))
	var old_effects: Dictionary = comparison.before_bonuses.effects
	var new_effects: Dictionary = comparison.after_bonuses.effects
	var effect_keys: Array = old_effects.keys()
	for key: String in new_effects:
		if not effect_keys.has(key):
			effect_keys.append(key)
	for key: String in effect_keys:
		var old := float(old_effects.get(key, 0.0))
		var value := float(new_effects.get(key, 0.0))
		if is_equal_approx(old, value):
			continue
		var before_text := EquipmentInventory.effect_text({"effects": {key: old}}, 1)
		var after_text := EquipmentInventory.effect_text({"effects": {key: value}}, 1)
		_details.add_child(_label(before_text + " → " + after_text, 8, GREEN if value > old else RED))
	var previous: Dictionary = comparison.before_bonuses.sets
	var next: Dictionary = comparison.after_bonuses.sets
	var old_element: String = comparison.before_bonuses.resonance
	var next_element: String = comparison.after_bonuses.resonance
	if old_element != next_element:
		if old_element != "":
			_details.add_child(_label("失去 " + str(EquipmentInventory.RULES.elements[old_element].title) + " 共鳴", 8, RED))
		if next_element != "":
			_details.add_child(_label("啟動 " + str(EquipmentInventory.RULES.elements[next_element].title) + " 共鳴", 8, GREEN))
	elif next_element != "":
		_details.add_child(_label(str(EquipmentInventory.RULES.elements[next_element].title) + " · 共鳴維持", 7, ElementArt.color(next_element)))
	for group: String in SET_NAMES:
		var old_active := int(previous.get(group, 0)) >= 2
		var active := int(next.get(group, 0)) >= 2
		if old_active != active:
			_details.add_child(_label("%s%s：%s" % ["啟動 " if active else "失去 ", SET_NAMES[group], SET_EFFECTS[group]], 8, GREEN if active else RED))
		elif int(next.get(group, 0)) > 0:
			_details.add_child(_label("%s %d/2 · %s" % [SET_NAMES[group], mini(2, int(next[group])), SET_EFFECTS[group] if active else "再一件啟動"], 7, GOLD if active else MUTED))

func _ask(action: String, slot: String, currency: String) -> void:
	var entry := EquipmentInventory.item(selected)
	var level := int(GameState.equipment.owned.get(selected, 0))
	var cost := EquipmentInventory.upgrade_cost(entry, level)
	var text := "%s\n支付 %d %s，取得 Lv.1。" % [entry.name, int(entry.get(currency, 0)), "寶石" if currency == "gems" else "金幣"]
	if action == "upgrade":
		text = "鍛造至 Lv.%d\n支付 %d 金幣%s，必定成功。" % [level + 1, cost.coins, " + %d 星鐵" % cost.shards if int(cost.shards) > 0 else ""]
	elif action == "attune":
		text = "%s → %s刻印\n免費，保留等級；共用此物品的職業一起改變。" % [entry.name, EquipmentInventory.element_name(slot)]
	_confirm = {"action": action, "id": selected, "hero": hero, "slot": slot, "currency": currency, "message": text}
	_details_refresh()

func _confirm_transaction() -> void:
	if _confirm.is_empty():
		return
	var pending := _confirm.duplicate()
	_confirm.clear()
	_execute(pending.action, pending.slot, pending.currency, pending.id, pending.hero)

func _execute(action: String, slot: String, currency: String, id: String = "", class_id: String = "") -> void:
	if not commit.is_valid():
		_message.text = "無法儲存，請稍後再試。"
		return
	var result: Dictionary = commit.call(action, selected if id == "" else id, hero if class_id == "" else class_id, slot, currency)
	_message.text = str(result.message) + (" · 下一關生效" if result.ok else "")
	_message.add_theme_color_override("font_color", GREEN if result.ok else RED)
	if result.ok:
		Sfx.play(&"level_up" if action == "upgrade" else &"pickup")
	refresh()

func _help() -> void:
	_choosing_element = false
	_showing_details = true
	_confirm.clear()
	_list.hide()
	_details.show()
	_actions.hide()
	_classes.hide()
	_tabs.hide()
	_body_scroll.scroll_vertical = 0
	_clear(_details)
	_details.add_child(_label("工坊手札", 14, GOLD))
	_details.add_child(_label("地・水・火・風\n武器與護甲各有刻印；兩件同屬性啟動共鳴，混搭保留單件效果。寶物維持原本套裝。刻印免費，所有職業共用同一物品的刻印；普通與史詩都能選四種元素。", 9))
	_details.add_child(_label("元素效果不隨鍛造等級倍增；與原有套裝相加。護盾減傷最多 60%、清波治療最多 8%、必殺治療最多 15%。反擊與蓄勢取當次最強加成，不連乘。", 8))
	_details.add_child(_label("普通上限 Lv.5 · 史詩上限 Lv.9\n鍛造必定成功。星鐵來自頭目；重複史詩換 8 星鐵。", 9))
	_details.add_child(_label("頭目每次 20% 掉史詩。連續 4 次未掉，第 5 次必得。物品從當章及較早章池等機率抽取。", 9))
	_details.add_child(_label("每章首次擊敗頭目得 20 寶石。商場明碼選購，沒有付費抽獎。本版尚未開放真實付款。", 9))
	_details.add_child(_label("配裝在下一關生效；續玩或重試保留當關檢查點的裝備。未過關的成長與零食會回復到檢查點。", 9))

func show_item(id: String) -> void:
	var entry := EquipmentInventory.item(id)
	if entry.is_empty():
		return
	selected = id
	_choosing_element = false
	_fitting_mode = "try"
	_preview_slot = entry.slot if entry.slot != "treasure" else "treasure_a"
	for slot: String in EquipmentInventory.SLOTS:
		if GameState.equipment.loadouts.get(hero, {}).get(slot, "") == id:
			_preview_slot = slot
	_confirm.clear()
	_showing_details = true
	_list.hide()
	_details.show()
	_body_scroll.scroll_vertical = 0
	_details_refresh()
	_layout.call_deferred()

func back() -> bool:
	if not _showing_details:
		return false
	if _choosing_element:
		_choosing_element = false
		_confirm.clear()
		_body_scroll.scroll_vertical = 0
		_details_refresh()
		return true
	_showing_details = false
	_confirm.clear()
	_body_scroll.scroll_vertical = 0
	refresh()
	return true
