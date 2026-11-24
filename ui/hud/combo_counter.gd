class_name ComboCounter
extends Control
## 連擊數(C 線,CP4)。combo_changed(count):count 達到 min_show 才出現,每次增加就彈跳放大;
## 到達里程碑(5、10、20)變色並跳得更大;0 = 連擊中斷,淡出。不攔觸控。

var number_label: Label
var word_label: Label
var burst: TextureRect
var count: int = 0
var min_show: int = 2
var tiers: Array[int] = [5, 10, 20]

var _tween: Tween
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst = UiKit.texture_rect(preload("res://assets/ui/combo_burst.png"))
	burst.name = "Burst"
	burst.modulate.a = 0.0
	add_child(burst)
	number_label = UiKit.label("0", &"LabelTitle", HORIZONTAL_ALIGNMENT_RIGHT)
	number_label.add_theme_font_override(&"font", preload("res://assets/fonts/QuillFigures.ttf"))
	number_label.add_theme_font_size_override(&"font_size", 20)
	number_label.add_theme_color_override(&"font_outline_color", Color("392a25"))
	number_label.add_theme_constant_override(&"outline_size", 1)
	number_label.name = "Number"
	add_child(number_label)
	word_label = UiKit.label(tr("UI_COMBO"), &"LabelLight", HORIZONTAL_ALIGNMENT_RIGHT)
	word_label.name = "Word"
	add_child(word_label)
	size = Vector2(64, 40)
	pivot_offset = Vector2(56, 16)
	visible = false


func set_count(c: int) -> void:
	var prev := count
	count = maxi(c, 0)
	if count < min_show:
		if visible and _fade == null:
			_fade_out()
		return
	if _fade != null:
		_fade.kill()
		_fade = null
	visible = true
	modulate.a = 1.0
	number_label.text = str(count)
	var tier := _tier(count)
	number_label.add_theme_color_override(&"font_color", [PaletteColors.WHITE, PaletteColors.YELLOW,
			PaletteColors.ORANGE, PaletteColors.PINK][tier])
	_layout()
	var milestone := tier > _tier(prev) and count > prev
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	var peak := 1.28 if milestone else 1.12
	scale = Vector2(peak, peak)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22 if milestone else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if milestone:
		burst.modulate.a = 1.0
		burst.scale = Vector2(0.5, 0.5)
		_tween.parallel().tween_property(burst, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.5).set_delay(0.25)


func _tier(c: int) -> int:
	var t := 0
	for i in tiers.size():
		if c >= tiers[i]:
			t = i + 1
	return mini(t, 3)


func _fade_out() -> void:
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "modulate:a", 0.0, 0.35)
	_fade.tween_callback(func() -> void:
		visible = false
		_fade = null)


func _layout() -> void:
	number_label.size = number_label.get_minimum_size()
	word_label.size = word_label.get_minimum_size()
	number_label.position = Vector2(size.x - number_label.size.x, 0)
	word_label.position = Vector2(size.x - word_label.size.x, number_label.size.y - 6)
	burst.pivot_offset = burst.size * 0.5
	burst.position = Vector2(size.x - number_label.size.x * 0.5 - burst.size.x * 0.5, number_label.size.y * 0.5 - burst.size.y * 0.5)
