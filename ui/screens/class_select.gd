class_name HeroClassSelect
extends Control
signal confirmed(id: StringName)
signal cancelled()

var selected: StringName = &"knight"
var confirm_button: Button
var cancel_button: Button
var choices: Array[Button] = []
var _panel: PanelContainer
var _portrait: TextureRect
var _description: Label
var _tactic: Label
var _stats: Label
var _ultimate: Label

func _ready() -> void:
	UiKit.setup_root(self)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var dim := UiKit.dim(Color(0.04, 0.08, 0.07, 0.94))
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "ClassPanel"
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	# Quiet, narrow fallback scrollbar for unusual safe-area sizes.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("decca3")
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	var thumb := track.duplicate() as StyleBoxFlat
	thumb.bg_color = Color("927248")
	scroll.get_v_scroll_bar().add_theme_stylebox_override(&"scroll", track)
	for state in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		scroll.get_v_scroll_bar().add_theme_stylebox_override(state, thumb)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 4)
	scroll.add_child(column)
	var heading := UiKit.label(tr("UI_CLASS_SELECT"), &"LabelHeading")
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	column.add_child(row)
	for id in HeroClasses.IDS:
		var button := UiKit.button(tr(HeroClasses.get_data(id).display_name), &"ButtonAlt", Vector2(40, 26))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select.bind(id))
		choices.append(button)
		row.add_child(button)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(0, 60)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	column.add_child(_portrait)
	_description = UiKit.wrapped_label("", 136)
	_description.add_theme_font_size_override(&"font_size", 10)
	column.add_child(_description)
	_stats = UiKit.label("", &"LabelSoft")
	_stats.add_theme_font_size_override(&"font_size", 9)
	column.add_child(_stats)
	_tactic = UiKit.wrapped_label("", 136, &"LabelSoft")
	_tactic.add_theme_font_size_override(&"font_size", 9)
	column.add_child(_tactic)
	_ultimate = UiKit.label("", &"LabelSoft")
	_ultimate.add_theme_font_size_override(&"font_size", 9)
	column.add_child(_ultimate)
	confirm_button = UiKit.button(tr("UI_CLASS_DEPART"), &"", Vector2(0, 28))
	confirm_button.pressed.connect(func() -> void: confirmed.emit(selected))
	column.add_child(confirm_button)
	cancel_button = UiKit.button(tr("UI_BACK"), &"ButtonAlt", Vector2(0, 24))
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	column.add_child(cancel_button)
	select(HeroClasses.valid_id(GameState.hero_class))
	get_viewport().size_changed.connect(_layout)
	_layout()
	choices[HeroClasses.IDS.find(selected)].grab_focus()

func select(id: StringName) -> void:
	selected = HeroClasses.valid_id(id)
	var data := HeroClasses.get_data(selected)
	_portrait.texture = StoryArt.motion_pose(selected, 0)
	_description.text = tr(data.description)
	_tactic.text = tr(data.tactic)
	_ultimate.text = tr("UI_CLASS_ULTIMATE") % tr(data.ultimate_name)
	_stats.text = tr("UI_CLASS_STATS") % [data.stats.max_vigor, int(data.stats.attack_range)]
	for i in choices.size():
		choices[i].set_pressed_no_signal(HeroClasses.IDS[i] == selected)
		choices[i].theme_type_variation = &"" if HeroClasses.IDS[i] == selected else &"ButtonAlt"

func _layout() -> void:
	size = SafeArea.get_screen_size()
	var safe := UiKit.safe_rect()
	var width := minf(164.0, safe.size.x - 12.0)
	_panel.position = Vector2(safe.get_center().x - width * 0.5, safe.position.y + 8.0)
	_panel.size = Vector2(width, safe.size.y - 16.0)
