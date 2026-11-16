class_name BossBar
extends Control
## 頭目血條(C 線,CP4)。聽 boss_hp_changed 出現;第二階段(boss_phase_changed(2))變紅並閃一下。
## 名字用 tr("ENEMY_BLACK_KNIGHT")。不攔觸控。

const BAR_HEIGHT: float = 7.0

var name_label: Label
var bar: PixelBar
var icon: TextureRect
var phase: int = 1

var _shown: bool = false
var _tween: Tween
var _flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = UiKit.texture_rect(preload("res://assets/ui/icon_boss.png"))
	icon.name = "Icon"
	add_child(icon)
	name_label = UiKit.label(tr("ENEMY_BLACK_KNIGHT"), &"LabelLight", HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "Name"
	add_child(name_label)
	bar = PixelBar.new()
	bar.name = "Bar"
	bar.fill_color = PaletteColors.VIOLET
	bar.fill_light = PaletteColors.LILAC
	bar.empty_color = PaletteColors.INK
	bar.trail_color = PaletteColors.WHITE
	bar.segments = 10
	add_child(bar)
	modulate.a = 0.0
	visible = false


func set_hp(current: int, maximum: int) -> void:
	var first := not _shown
	bar.set_values(current, maximum)
	if first:
		bar.snap_to_value()
		_appear()
	elif current <= 0:
		_disappear(0.6)
	else:
		_flash = 0.12


func set_phase(p: int) -> void:
	if p == phase:
		return
	phase = p
	if p >= 2:
		bar.fill_color = PaletteColors.RED
		bar.fill_light = PaletteColors.PINK
		name_label.add_theme_color_override(&"font_color", PaletteColors.PINK)
		_flash = 0.5
		var t := create_tween().set_ignore_time_scale(true)
		for dx: float in [-2.0, 2.0, -1.0, 1.0, 0.0]:
			t.tween_property(self, "position:x", position.x + dx, 0.04)


func is_shown() -> bool:
	return _shown


func reset() -> void:
	_shown = false
	phase = 1
	bar.fill_color = PaletteColors.VIOLET
	bar.fill_light = PaletteColors.LILAC
	name_label.remove_theme_color_override(&"font_color")
	visible = false
	modulate.a = 0.0


func layout(width: float) -> void:
	size = Vector2(width, 18)
	icon.position = Vector2(0, 0)
	name_label.size = name_label.get_minimum_size()
	name_label.position = Vector2(11, -3)
	bar.position = Vector2(0, 10)
	bar.size = Vector2(width, BAR_HEIGHT)


func _appear() -> void:
	_shown = true
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _disappear(delay: float) -> void:
	_shown = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_interval(delay)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		bar.self_modulate = Color(1.6, 1.6, 1.6) if fmod(_flash, 0.08) > 0.04 else Color.WHITE
		if _flash <= 0.0:
			bar.self_modulate = Color.WHITE
