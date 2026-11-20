class_name DamageNumber
extends Node2D
## 使用與介面一致的清晰數字。暴擊與必殺保留較大字級、色彩和跳動回饋。

enum Style { NORMAL, CRIT, ULTIMATE, ALLY }

const GROUP: StringName = &"damage_number"
const FONT: Font = preload("res://assets/fonts/StorySans.otf")

var value: int = 0
var style: Style = Style.NORMAL
var feel: FeelTuning

var _text: String = ""
var _velocity: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _lifetime: float = 0.7
var _font_size: int = 8
var _color: Color = Color.WHITE


func _ready() -> void:
	add_to_group(GROUP)
	if feel == null:
		feel = CombatFx.feel()
	z_index = 2
	_text = str(maxi(0, value))
	var big := style == Style.CRIT or style == Style.ULTIMATE
	if style == Style.CRIT:
		_text += "!"
	_font_size = 11 if big else 8
	_lifetime = feel.crit_lifetime if big else feel.number_lifetime
	match style:
		Style.CRIT:
			_color = feel.crit_color
		Style.ULTIMATE:
			_color = feel.ultimate_number_color
		Style.ALLY:
			_color = feel.ally_number_color
		_:
			_color = feel.number_color
	var jump := feel.number_jump_speed * (1.2 if big else 1.0)
	_velocity = Vector2(randf_range(-feel.number_drift, feel.number_drift), -jump)


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
	var fs := _font_size + (2 if _font_size > 8 and _age < 0.07 else 0)
	var width := FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := _offset + Vector2(-width * 0.5, fs * 0.3)
	draw_string_outline(FONT, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0.08, 0.14, 0.12, alpha * 0.85))
	draw_string(FONT, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_color, alpha))
