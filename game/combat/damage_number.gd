class_name DamageNumber
extends Node2D
## 飄字用手繪楔形數字。暴擊的筆尖驚嘆號、必殺的四芒星在單色下也有區別。

enum Style { NORMAL, CRIT, ULTIMATE, ALLY }

const GROUP: StringName = &"damage_number"
const FONT: Font = preload("res://assets/fonts/QuillFigures.ttf")
const IMPACT_SETTLE: float = 0.13
const WARNING_LIFT: float = 16.0

var value: int = 0
var style: Style = Style.NORMAL
var feel: FeelTuning

var _text: String = ""
var _velocity: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _lifetime: float = 0.7
var _font_size: int = 10
var _origin: Vector2
var _color: Color = Color.WHITE


func _ready() -> void:
	add_to_group(GROUP)
	if feel == null:
		feel = CombatFx.feel()
	z_index = 2
	_text = str(maxi(0, value))
	var big := style == Style.CRIT or style == Style.ULTIMATE
	_font_size = 12 if big else 10
	_lifetime = feel.crit_lifetime if big else feel.number_lifetime
	match style:
		Style.CRIT:
			_text += "!"
			_color = feel.crit_color
		Style.ULTIMATE:
			_text += "✦"
			_color = feel.ultimate_number_color
		Style.ALLY:
			_color = feel.ally_number_color
		_:
			_color = feel.number_color
	var width := FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	# The quieter figures sit just above the enemy's bright hit silhouette.
	_origin = Vector2(-0.5 * width, _font_size * (0.33 if big else 0.14))
	var jump := feel.number_jump_speed * (1.2 if big else 1.0)
	_velocity = Vector2(randf_range(-feel.number_drift, feel.number_drift), -jump)


## Keep the source position for ownership. Choose the initial ink position once, without RNG.
func place_at(anchor: Vector2) -> void:
	global_position = anchor
	var ink_radius := maxf(-_origin.x, _font_size * 0.4) + 1.0
	var center := anchor + Vector2(0, _origin.y - _font_size * 0.4)
	var lift := clampf(center.y - Layout.ARENA_RECT.position.y - ink_radius, 0.0, WARNING_LIFT)
	if lift <= 0.0:
		return
	var nearby := AttackTelegraph.warning_counts(get_tree(), center, ink_radius).x
	if nearby > 0 and AttackTelegraph.warning_counts(get_tree(), center + Vector2.UP * lift, ink_radius).x < nearby:
		_offset.y = -lift


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	_velocity.y += feel.number_gravity * delta
	_offset += _velocity * delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()


func get_age() -> float:
	return _age


func _draw() -> void:
	var t := _age / maxf(_lifetime, 0.001)
	var alpha := clampf((1.0 - t) / 0.3, 0.0, 1.0)
	var scale_out := Vector2.ONE
	if style == Style.CRIT or style == Style.ULTIMATE:
		var remaining := 1.0 - smoothstep(0.0, IMPACT_SETTLE, _age)
		scale_out += Vector2(0.09, 0.17) * remaining
	draw_set_transform(_offset, 0.0, scale_out)
	draw_string_outline(FONT, _origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 1,
			Color(feel.number_outline, alpha))
	draw_string(FONT, _origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, Color(_color, alpha))
