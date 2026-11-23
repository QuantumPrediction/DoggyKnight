class_name CompanionGuardControl
extends Control
## Signal-driven, touch-safe command control; no combat-node reads.
const ICON: Texture2D = preload("res://assets/illustrated/combat/companion_guard.png")
var button: Button
var status_label: Label
var charge_label: Label
var _protected: bool = false
var state: StringName = &"unavailable"
var _cooldown: float = 0.0
var _duration: float = 0.0
var _ended: bool = false
var _downed: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(40, 45)
	button = UiKit.button("", &"ButtonAlt", Vector2(34, 34))
	button.name = "GuardButton"
	button.icon = ICON
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 28)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(3, 0)
	button.add_to_group(&"ui_touch_blocker")
	button.pressed.connect(_on_pressed)
	add_child(button)
	status_label = UiKit.label("", &"LabelLight")
	status_label.add_theme_font_size_override("font_size", 7)
	status_label.add_theme_color_override("font_outline_color", Color("112520"))
	status_label.add_theme_constant_override("outline_size", 2)
	status_label.position = Vector2(-8, 34)
	status_label.size = Vector2(56, 11)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	charge_label = UiKit.label("", &"LabelLight")
	charge_label.add_theme_font_size_override("font_size", 7)
	charge_label.add_theme_color_override("font_color", Color("ffe3a1"))
	charge_label.add_theme_color_override("font_outline_color", Color("112520"))
	charge_label.add_theme_constant_override("outline_size", 2)
	charge_label.position = Vector2(-15, -13)
	charge_label.size = Vector2(70, 11)
	charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_label.hide()
	add_child(charge_label)
	EventBus.companion_guard_coverage.connect(_on_coverage)
	EventBus.player_combat_readiness.connect(_on_readiness)
	EventBus.companion_guard_state.connect(_on_state)
	EventBus.level_completed.connect(_on_ended)
	EventBus.level_failed.connect(_on_ended)
	EventBus.player_downed.connect(_on_downed)
	EventBus.vigor_changed.connect(_on_vigor)
	_refresh()
	EventBus.companion_guard_status_requested.emit()
	EventBus.player_combat_status_requested.emit()

func _on_pressed() -> void:
	if not button.disabled and not _ended and not get_tree().paused:
		EventBus.companion_guard_requested.emit()

func _on_state(value: StringName, cooldown_left: float, duration_left: float) -> void:
	state = value
	_cooldown = cooldown_left
	_duration = duration_left
	_refresh()

func _refresh() -> void:
	visible = state != &"unavailable" and not _ended and not _downed
	button.disabled = state != &"ready" or _ended or _downed
	button.modulate = (Color("8eebdc") if _protected else Color("f0ba7c")) if state == &"guard" else Color.WHITE
	# A running ability is disabled for reactivation, but its emblem stays legible.
	button.add_theme_color_override("icon_disabled_color", Color.WHITE if state == &"guard" else Color(0.65, 0.7, 0.7, 0.8))
	match state:
		&"ready": status_label.text = tr("UI_GUARD_READY_PC" if UiKit.uses_keyboard_hints() else "UI_GUARD_READY")
		&"approach": status_label.text = tr("UI_GUARD_APPROACH")
		&"guard": status_label.text = tr("UI_GUARD_INSIDE" if _protected else "UI_GUARD_OUTSIDE") % (ceilf(_duration * 10.0) / 10.0)
		&"dazed": status_label.text = tr("UI_GUARD_DAZED")
		_: status_label.text = tr("UI_GUARD_COOLDOWN") % ceili(_cooldown)
	button.tooltip_text = tr("UI_GUARD_HELP")

func _on_ended(_id: StringName) -> void:
	_ended = true
	_refresh()

func _on_downed() -> void:
	_downed = true
	_refresh()

func _on_vigor(current: int, _maximum: int) -> void:
	if current > 0 and _downed:
		_downed = false
	_refresh()


func _on_coverage(value: bool) -> void:
	_protected = value
	_refresh()


func _on_readiness(value: StringName, remaining: float, bonus: float) -> void:
	charge_label.visible = remaining > 0.0 and value != &"unavailable"
	charge_label.text = tr("UI_GUARD_CHARGE") % [roundi(bonus * 100.0), ceilf(remaining * 10.0) / 10.0]
