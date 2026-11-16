class_name CutIn
extends Control
## 必殺技切入畫面(C 線,CP4):ultimate_used 時,一條斜斜的金色光帶劃過畫面,
## 金毛的半身像從右邊衝進來、停一下、再從左邊衝出去(約 0.6 秒)。不攔觸控。

var portrait: TextureRect
var shout: Label

var _open: float = 0.0
var _lines: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait = UiKit.texture_rect(preload("res://assets/ui/cutin_goldie.png"))
	portrait.name = "Portrait"
	add_child(portrait)
	var words := tr("UI_ULTIMATE")
	# 兩行疊起來(「王者/之劍!」),窄螢幕也放得下
	var cut := ceili(words.length() / 2.0)
	shout = UiKit.label(words.substr(0, cut) + "\n" + words.substr(cut) + "!", &"LabelTitle", HORIZONTAL_ALIGNMENT_LEFT)
	shout.name = "Shout"
	add_child(shout)
	visible = false


func play(total: float = 0.6) -> void:
	visible = true
	var band := _band_rect()
	var safe := SafeArea.get_safe_rect()
	var rest := Vector2(floorf(safe.get_center().x - portrait.size.x - 8), band.end.y - portrait.size.y)
	portrait.position = rest + Vector2(140, 0)
	shout.size = shout.get_minimum_size()
	var shout_rest := Vector2(floorf(safe.get_center().x - 2), floorf(band.get_center().y - shout.size.y * 0.5 - 2))
	shout.position = shout_rest + Vector2(-120, 0)
	shout.modulate.a = 0.0
	_open = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var t_in := total * 0.22
	var t_out := total * 0.28
	var hold := maxf(0.05, total - t_in - t_out)
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_set_open, 0.0, 1.0, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(portrait, "position", rest, t_in).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(shout, "position", shout_rest, t_in).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(shout, "modulate:a", 1.0, t_in * 0.6)
	var lines := create_tween().set_ignore_time_scale(true)
	lines.tween_method(_set_lines, 0.0, 1.0, total)
	_tween.tween_interval(hold)
	_tween.tween_property(portrait, "position", rest - Vector2(170, 0), t_out).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(shout, "position", shout_rest - Vector2(170, 0), t_out).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_method(_set_open, 1.0, 0.0, t_out).set_delay(t_out * 0.3)
	_tween.tween_callback(func() -> void: visible = false)
	UiKit.play_sfx(&"whoosh")


func is_playing() -> bool:
	return visible and _tween != null and _tween.is_running()


func _set_open(v: float) -> void:
	_open = v
	queue_redraw()


func _set_lines(v: float) -> void:
	_lines = v
	queue_redraw()


func _band_rect() -> Rect2:
	var safe := SafeArea.get_safe_rect()
	var screen := SafeArea.get_screen_size()
	var cy := floorf(safe.position.y + safe.size.y * 0.42)
	return Rect2(0, cy - 32, screen.x, 64)


func _draw() -> void:
	if _open <= 0.0:
		return
	var r := _band_rect()
	var h := r.size.y * _open
	var cy := r.get_center().y
	var slant := 14.0
	var top := cy - h * 0.5
	var bot := cy + h * 0.5
	var w := r.size.x
	# dark rim, gold body, light core
	draw_colored_polygon(PackedVector2Array([Vector2(-4, top - 2 + slant), Vector2(w + 4, top - 2 - slant),
			Vector2(w + 4, bot + 2 - slant), Vector2(-4, bot + 2 + slant)]), PaletteColors.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, top + slant), Vector2(w + 4, top - slant),
			Vector2(w + 4, bot - slant), Vector2(-4, bot + slant)]), PaletteColors.ORANGE)
	var inset := h * 0.22
	draw_colored_polygon(PackedVector2Array([Vector2(-4, top + inset + slant), Vector2(w + 4, top + inset - slant),
			Vector2(w + 4, bot - inset - slant), Vector2(-4, bot - inset + slant)]), PaletteColors.YELLOW)
	# speed lines racing left
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 14:
		var y := lerpf(top + 3, bot - 3, rng.randf())
		var lx := fposmod(rng.randf() * w - _lines * w * 2.2, w + 60) - 30
		var ln := rng.randf_range(14, 40)
		var yy := y + slant * (1.0 - 2.0 * clampf(lx / w, 0.0, 1.0))
		draw_rect(Rect2(floorf(lx), floorf(yy), ln, 1), PaletteColors.WHITE if i % 3 else PaletteColors.CREAM)
