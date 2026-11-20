class_name CombatReadout
extends Control
## Combat clocks come exclusively from the current player's EventBus snapshots.
const WIDTH := 78.0
const HEIGHT := 42.0
var action: Label
var detail: Label
var dodge: Label
var status: Dictionary = {}
var meter: float = 0.0
var accent := Color("b8ddcd")
var _ended: bool = false
var _hero: StringName = &""
var _panel := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, HEIGHT)
	_panel.bg_color = Color("142a2bed")
	_panel.border_color = Color("8f8066")
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(4)
	action = _label(Vector2(5, 2))
	detail = _label(Vector2(5, 14))
	dodge = _label(Vector2(5, 30))
	dodge.add_theme_font_size_override("font_size", 6)
	EventBus.player_tactics_changed.connect(_on_status)
	EventBus.level_completed.connect(_on_ended)
	EventBus.level_failed.connect(_on_ended)
	EventBus.player_downed.connect(_on_downed)
	hide()
	EventBus.player_combat_status_requested.emit()

func _label(at: Vector2) -> Label:
	var label := UiKit.label("", &"LabelLight")
	label.position = at
	label.size = Vector2(WIDTH - 10, 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color("fff0cf"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _on_status(value: Dictionary) -> void:
	status = value.duplicate()
	visible = not _ended and status.phase != &"unavailable"
	if not visible:
		return
	var hero := String(status.hero)
	if _hero != status.hero:
		_hero = status.hero
		accent = HeroClasses.get_data(_hero).accent.lightened(0.3)
	var key := "UI_TACTIC_%s" % String(status.phase).to_upper()
	if status.phase in [&"windup", &"ready"]:
		key += "_" + hero.to_upper()
	action.text = tr(key)
	if status.hero == &"archer":
		meter = float(status.focus)
		detail.text = tr("UI_TACTIC_FOCUS_FULL") % float(status.focus_bonus) if meter >= 1.0 else tr("UI_TACTIC_FOCUS") % roundi(meter * 100.0)
	else:
		meter = 1.0 - clampf(float(status.attack_left) / float(status.attack_total), 0.0, 1.0)
		detail.text = tr("UI_TACTIC_ATTACK_WAIT") % (ceilf(float(status.attack_left) * 10.0) / 10.0) if status.phase == &"recovering" else tr("UI_TACTIC_STOP_" + hero.to_upper())
	match status.roll:
		&"absent": dodge.text = tr("UI_TACTIC_DODGE")
		&"rolling": dodge.text = tr("UI_TACTIC_ROLL_ACTIVE") % (ceilf(float(status.roll_active_left) * 10.0) / 10.0)
		&"cooldown": dodge.text = tr("UI_TACTIC_ROLL_WAIT") % (ceilf(float(status.roll_left) * 10.0) / 10.0)
		&"moving": dodge.text = tr("UI_TACTIC_ROLL_STOP")
		&"busy": dodge.text = tr("UI_TACTIC_ROLL_BUSY")
		_: dodge.text = tr("UI_TACTIC_ROLL_READY")
	queue_redraw()

func _on_ended(_id: StringName) -> void:
	_ended = true
	hide()

func _on_downed() -> void:
	hide()

func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(5, 27, size.x - 10, 1), Color("45615d"))
	draw_rect(Rect2(5, 27, (size.x - 10) * meter, 1), accent)
