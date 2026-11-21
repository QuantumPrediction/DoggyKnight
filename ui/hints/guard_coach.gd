class_name GuardCoach
extends Control
## Optional, non-modal lesson. All observations come from production combat signals.
const ATLAS: Texture2D = preload("res://assets/illustrated/combat/guard_lesson_atlas.png")
const CONFIG: HudConfig = preload("res://ui/hud/hud_config.tres")
const HEIGHT: float = 40.0
var icon: TextureRect
var heading: Label
var instruction: Label
var dismiss_button: Button
var completed: bool = false
var _guard_state: StringName = &"unavailable"
var _protected: bool = false
var _readiness: StringName = &"idle"
var _charge_left: float = 0.0
var _saw_counter: bool = false
var _danger: bool = false
var _success_left: float = 0.0
var _success_limit_left: float = 0.0
var _clear_left: float = 0.0
var _sampling_success_context: bool = false
var _success_context_known: bool = false
var _nearby_warning: bool = false
var _drag_active: bool = false
var _surface: Control
var _icons: Array[AtlasTexture] = []


func _ready() -> void:
	for cell in 3:
		var texture := AtlasTexture.new()
		texture.atlas = ATLAS
		var cell_width := float(ATLAS.get_width()) / 3.0
		texture.region = Rect2(cell_width * cell, 0, cell_width, ATLAS.get_height())
		_icons.append(texture)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 100 # Read the final actor positions before the viewport draws.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the coach's existing layout reservation independent of its optional
	# visuals. A hidden surface also removes its own X from touch hit testing.
	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102b2ef0")
	style.border_color = Color("af915d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	plate.add_theme_stylebox_override("panel", style)
	_surface.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(3, 3)
	icon.size = Vector2(28, 28)
	_surface.add_child(icon)
	heading = UiKit.label("", &"LabelLight")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_font_size_override("font_size", 8)
	heading.add_theme_color_override("font_color", Color("f6d99a"))
	heading.position = Vector2(33, 2)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(heading)
	instruction = UiKit.label("", &"LabelLight")
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	instruction.add_theme_font_size_override("font_size", 7)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.position = Vector2(33, 13)
	instruction.add_theme_constant_override("line_spacing", 0)
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(instruction)
	dismiss_button = UiKit.button("×", &"ButtonAlt", Vector2(24, 36))
	dismiss_button.add_theme_font_size_override("font_size", 10)
	dismiss_button.tooltip_text = tr("UI_GUARD_LESSON_SKIP")
	dismiss_button.focus_mode = Control.FOCUS_NONE
	dismiss_button.add_to_group(&"ui_touch_blocker")
	dismiss_button.pressed.connect(dismiss)
	_surface.add_child(dismiss_button)
	EventBus.companion_guard_state.connect(_on_guard_state)
	EventBus.companion_guard_coverage.connect(_on_coverage)
	EventBus.player_combat_readiness.connect(_on_readiness)
	EventBus.companion_counter_granted.connect(_on_counter)
	EventBus.companion_counter_resolved.connect(_on_resolved)
	EventBus.guard_success_context_observed.connect(_on_success_context)
	EventBus.boss_intent_changed.connect(_on_intent)
	EventBus.level_completed.connect(_on_ended)
	EventBus.level_failed.connect(_on_ended)
	EventBus.player_downed.connect(_close_now)
	hide()


func begin() -> void:
	completed = false
	_saw_counter = false
	_success_left = 0.0
	_success_limit_left = 0.0
	_clear_left = 0.0
	_nearby_warning = false
	_drag_active = false
	_surface.show()
	show()
	EventBus.companion_guard_status_requested.emit()
	EventBus.player_combat_status_requested.emit()
	_refresh()


func dismiss() -> void:
	if completed:
		# Do not shift the game controls before the next presentation snapshot.
		_success_left = 0.0
		_success_limit_left = 0.0
		_surface.hide()
		return
	_close_now()
	EventBus.guard_lesson_dismissed.emit()


func layout(safe: Rect2) -> void:
	position = Vector2(safe.position.x + 4, safe.end.y - HEIGHT - 4).floor()
	size = Vector2(safe.size.x - 8, HEIGHT)
	dismiss_button.position = Vector2(size.x - 27, 2)
	heading.size = Vector2(size.x - 64, 11)
	instruction.size = Vector2(size.x - 64, 24)


func _process(delta: float) -> void:
	if not completed or not visible:
		return
	_success_context_known = false
	_nearby_warning = false
	_drag_active = false
	_sampling_success_context = true
	EventBus.guard_success_context_requested.emit(CONFIG.guard_success_warning_padding)
	_sampling_success_context = false
	var threat := not _success_context_known or _nearby_warning
	_clear_left = CONFIG.guard_success_clear_time if threat else maxf(0.0, _clear_left - delta)
	if _success_limit_left > 0.0:
		_success_limit_left = maxf(0.0, _success_limit_left - delta)
	if _success_limit_left <= 0.0:
		_success_left = 0.0
	var clear := not threat and _clear_left <= 0.0
	if clear and _success_left > 0.0:
		_success_left = maxf(0.0, _success_left - delta)
	_surface.visible = clear and _success_left > 0.0
	if _success_left <= 0.0 and clear and not _drag_active:
		_close_now()


func _on_success_context(nearby_warning: bool, drag_active: bool) -> void:
	if _sampling_success_context:
		_success_context_known = true
		_nearby_warning = _nearby_warning or nearby_warning
		_drag_active = _drag_active or drag_active


func _close_now() -> void:
	_saw_counter = false
	_success_left = 0.0
	_success_limit_left = 0.0
	_clear_left = 0.0
	_nearby_warning = false
	_drag_active = false
	_surface.hide()
	hide()


func _on_guard_state(value: StringName, _cooldown: float, _duration: float) -> void:
	_guard_state = value
	_refresh()


func _on_coverage(value: bool) -> void:
	_protected = value
	_refresh()


func _on_readiness(value: StringName, remaining: float, _bonus: float) -> void:
	_readiness = value
	_charge_left = remaining
	_refresh()


func _on_counter(_bonus: float) -> void:
	if visible and not completed:
		_saw_counter = true
	_refresh()


func _on_resolved(result: StringName) -> void:
	if visible and not completed and _saw_counter and result == &"used":
		completed = true
		_success_left = CONFIG.guard_success_time
		_success_limit_left = CONFIG.guard_success_limit
		EventBus.guard_lesson_completed.emit()
	_saw_counter = false
	_refresh()


func _on_intent(enemy_id: StringName, intent: StringName, _remaining: float) -> void:
	if enemy_id == &"scarecrow_captain":
		_danger = intent in [&"sweep", &"throw", &"returning", &"charge"]
		_refresh()


func _on_ended(_id: StringName) -> void:
	_close_now()


func _refresh() -> void:
	if not is_node_ready() or not visible:
		return
	var step := 0
	var title_key := "UI_COACH_EVADE"
	var body_key := "UI_COACH_START_PC" if OS.has_feature("pc") else "UI_COACH_START_TOUCH"
	if completed:
		step = 2
		title_key = "UI_COACH_DONE"
		body_key = "UI_COACH_DONE_BODY"
	elif _danger:
		title_key = "UI_COACH_DANGER"
		body_key = "UI_COACH_DANGER_BODY"
	elif _saw_counter and _charge_left > 0.0:
		step = 2
		title_key = "UI_COACH_COUNTER"
		match _readiness:
			&"moving": body_key = "UI_COACH_STOP"
			&"out_of_range": body_key = "UI_COACH_RANGE"
			&"recovering", &"busy": body_key = "UI_COACH_RECOVER"
			_: body_key = "UI_COACH_STRIKE"
	elif _guard_state == &"guard":
		step = 1
		title_key = "UI_COACH_INSIDE" if _protected else "UI_COACH_OUTSIDE"
		body_key = "UI_COACH_BLOCK" if _protected else "UI_COACH_RETURN"
	elif _guard_state == &"approach":
		step = 1
		title_key = "UI_COACH_APPROACH"
		body_key = "UI_COACH_APPROACH_BODY"
	elif _guard_state in [&"cooldown", &"dazed"]:
		title_key = "UI_COACH_WAIT"
		body_key = "UI_COACH_WAIT_BODY"
	heading.text = tr(title_key)
	instruction.text = tr(body_key)
	icon.texture = _icons[step]
