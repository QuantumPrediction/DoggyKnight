class_name HeroClassSelect
extends Control
signal confirmed(id: StringName)
signal reinforced_confirmed(id: StringName)
signal cancelled()

const ACTION_ART := {
	&"knight": preload("res://assets/illustrated/class_codex/knight.webp"),
	&"mage": preload("res://assets/illustrated/class_codex/mage.webp"),
	&"archer": preload("res://assets/illustrated/class_codex/archer.webp"),
}
# The selection tabs use close-ups of the same paintings as the field guide below.
const PORTRAIT_CROPS := {
	&"knight": Rect2(108, 4, 230, 126),
	&"mage": Rect2(108, 3, 260, 143),
	&"archer": Rect2(64, 0, 230, 126),
}

var selected: StringName = &"knight"
var confirm_button: Button
var cancel_button: Button
var offer_reinforcements: bool = false
var reinforced_button: Button
var choices: Array[Button] = []
var _panel: PanelContainer
var _portrait: TextureRect
var _description: Label
var _tactic: Label
var _facts: HBoxContainer
var _vigor: Label
var _range: Label
var _ultimate: Label
var _fact_paper := StyleBoxFlat.new()
var _compact_paper := StyleBoxEmpty.new()

func _ready() -> void:
	UiKit.setup_root(self)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var dim := UiKit.dim(Color(0.04, 0.08, 0.07, 0.94))
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "ClassPanel"
	add_child(_panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 3)
	_panel.add_child(page)
	page.add_child(UiKit.label(tr("UI_CLASS_SELECT"), &"LabelHeading"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	page.add_child(row)
	for id in HeroClasses.IDS:
		var button := _class_tab(id)
		choices.append(button)
		row.add_child(button)
	_portrait = TextureRect.new()
	_portrait.name = "AttackIllustration"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(0, 52)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_portrait)
	# Keep every departure reachable on short displays; only the written field notes scroll.
	var scroll := ScrollContainer.new()
	scroll.name = "FieldNotes"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("decca3")
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	var thumb := track.duplicate() as StyleBoxFlat
	thumb.bg_color = Color("927248")
	scroll.get_v_scroll_bar().add_theme_stylebox_override(&"scroll", track)
	for state in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		scroll.get_v_scroll_bar().add_theme_stylebox_override(state, thumb)
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override(&"separation", 1)
	scroll.add_child(notes)
	_description = UiKit.wrapped_label("", 0)
	_description.add_theme_font_size_override(&"font_size", 10)
	notes.add_child(_description)
	_tactic = UiKit.wrapped_label("", 0, &"LabelSoft")
	_tactic.add_theme_font_size_override(&"font_size", 9)
	notes.add_child(_tactic)
	_facts = HBoxContainer.new()
	notes.add_child(_facts)
	_fact_paper.bg_color = Color("f0e2c3")
	_fact_paper.border_color = Color("b59b6b")
	_fact_paper.border_width_top = 1
	_fact_paper.border_width_bottom = 1
	_fact_paper.content_margin_top = 4
	_fact_paper.content_margin_bottom = 4
	_fact_paper.content_margin_left = 2
	_fact_paper.content_margin_right = 2
	_vigor = _fact_value(tr("UI_CLASS_VIGOR"))
	_range = _fact_value(tr("UI_CLASS_RANGE"))
	_ultimate = _fact_value(tr("UI_CLASS_FINISHER"))
	confirm_button = UiKit.button(tr("UI_CLASS_DEPART"), &"", Vector2(0, 26))
	confirm_button.pressed.connect(func() -> void: confirmed.emit(selected))
	if offer_reinforcements:
		var hint := UiKit.wrapped_label(tr("UI_REINFORCED_HINT"), 132, &"LabelSoft", HORIZONTAL_ALIGNMENT_CENTER)
		hint.name = "ReinforcementRule"
		hint.add_theme_font_size_override(&"font_size", 9)
		page.add_child(hint)
		var departures := HBoxContainer.new()
		departures.add_theme_constant_override(&"separation", 4)
		page.add_child(departures)
		confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm_button.add_theme_font_size_override(&"font_size", 10)
		departures.add_child(confirm_button)
		reinforced_button = UiKit.button(tr("UI_REINFORCED_DEPART"), &"ButtonAlt", Vector2(0, 26))
		reinforced_button.name = "ReinforcedButton"
		reinforced_button.tooltip_text = hint.text
		reinforced_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reinforced_button.add_theme_font_size_override(&"font_size", 10)
		reinforced_button.pressed.connect(func() -> void: reinforced_confirmed.emit(selected))
		departures.add_child(reinforced_button)
	else:
		page.add_child(confirm_button)
	cancel_button = UiKit.button(tr("UI_BACK"), &"ButtonAlt", Vector2(0, 24))
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	page.add_child(cancel_button)
	select(HeroClasses.valid_id(GameState.hero_class))
	get_viewport().size_changed.connect(_layout)
	_layout()
	_layout.call_deferred()
	choices[HeroClasses.IDS.find(selected)].grab_focus()

func _class_tab(id: StringName) -> Button:
	var class_name_text := tr(HeroClasses.get_data(id).display_name)
	var button := UiKit.button("", &"ButtonAlt", Vector2(40, 42))
	button.name = String(id).capitalize()
	button.accessibility_name = class_name_text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var crop := AtlasTexture.new()
	crop.atlas = ACTION_ART[id]
	crop.region = PORTRAIT_CROPS[id]
	crop.filter_clip = true
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = crop
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	portrait.offset_left = 2
	portrait.offset_top = 2
	portrait.offset_right = -2
	portrait.offset_bottom = 24
	var caption := UiKit.label(class_name_text)
	caption.name = "Caption"
	caption.add_theme_font_size_override(&"font_size", 10)
	button.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -17
	caption.offset_bottom = -1
	button.pressed.connect(select.bind(id))
	return button

func _fact_value(title: String) -> Label:
	var cell := PanelContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facts.add_child(cell)
	var contents := BoxContainer.new()
	contents.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(contents)
	var label := UiKit.label(title, &"LabelSoft")
	label.add_theme_font_size_override(&"font_size", 9)
	contents.add_child(label)
	var value := UiKit.label("")
	contents.add_child(value)
	return value

func select(id: StringName) -> void:
	selected = HeroClasses.valid_id(id)
	var data := HeroClasses.get_data(selected)
	_portrait.texture = ACTION_ART[selected]
	_description.text = tr(data.description)
	_tactic.text = tr(data.tactic)
	_vigor.text = str(data.stats.max_vigor)
	_range.text = str(int(data.stats.attack_range))
	_ultimate.text = tr(data.ultimate_name)
	for i in choices.size():
		choices[i].set_pressed_no_signal(HeroClasses.IDS[i] == selected)
		choices[i].theme_type_variation = &"" if HeroClasses.IDS[i] == selected else &"ButtonAlt"
		var caption := choices[i].get_node("Caption") as Label
		caption.add_theme_color_override(&"font_color", choices[i].get_theme_color(&"font_color"))

func _layout() -> void:
	size = SafeArea.get_screen_size()
	var safe := UiKit.safe_rect()
	# On notched screens the same three facts fit on a single line below the tactic.
	var spacious := safe.size.y >= 310.0
	_facts.add_theme_constant_override(&"separation", 3 if spacious else 2)
	for value in [_vigor, _range, _ultimate]:
		var contents := value.get_parent() as BoxContainer
		contents.vertical = spacious
		contents.add_theme_constant_override(&"separation", 1 if spacious else 2)
		var cell := contents.get_parent() as PanelContainer
		cell.add_theme_stylebox_override(&"panel", _fact_paper if spacious else _compact_paper)
		value.add_theme_font_size_override(&"font_size", 12 if spacious else 9)
	var width := minf(174.0, safe.size.x - 8.0)
	_panel.position = Vector2(floorf(safe.get_center().x - width * 0.5), safe.position.y + 5.0)
	_panel.size = Vector2(width, safe.size.y - 10.0)
