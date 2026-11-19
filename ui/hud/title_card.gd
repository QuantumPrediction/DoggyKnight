class_name TitleCard
extends Control
## 關卡標題卡(C 線,CP4):level_started 時,一條深色緞帶在畫面中段展開,
## 章節名與關卡名從左邊滑入、停一下、再從右邊滑出。全程不攔觸控,金毛可以照常走動。

const BAND_HEIGHT: float = 50.0
const MARGIN_X: float = 12.0      # 文字與畫面左右邊的最小距離(避開兩邊的菱形裝飾)

var chapter_label: Label
var name_label: Label

var _open: float = 0.0          # 0 = 收起,1 = 完全展開(_draw 用)
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	chapter_label = UiKit.label("", &"LabelLight")
	chapter_label.name = "Chapter"
	chapter_label.add_theme_color_override(&"font_color", PaletteColors.GOLD_L)
	add_child(chapter_label)
	name_label = UiKit.label("", &"LabelTitle")
	name_label.name = "LevelName"
	add_child(name_label)
	visible = false


## 顯示標題卡;total 是總長(秒)。
func play(chapter_text: String, level_text: String, total: float) -> void:
	# 「1-4 稻草人包圍網」用大字一行會比 180 像素寬:把關卡編號移到章節那一行(小字)。
	var parts := level_text.split(" ", false, 1)
	if parts.size() == 2 and parts[0].contains("-"):
		chapter_text = "%s  %s" % [chapter_text, parts[0]]
		level_text = parts[1]
	chapter_label.text = chapter_text
	name_label.text = level_text
	name_label.theme_type_variation = &"LabelTitle"
	visible = true
	_layout()
	var rest_c := chapter_label.position
	var rest_n := name_label.position
	chapter_label.position = rest_c - Vector2(48, 0)
	name_label.position = rest_n - Vector2(64, 0)
	chapter_label.modulate.a = 0.0
	name_label.modulate.a = 0.0
	_open = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var t_in := 0.28
	var t_out := 0.26
	var hold := maxf(0.2, total - t_in - t_out - 0.05)
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_set_open, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(name_label, "position", rest_n, t_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(name_label, "modulate:a", 1.0, 0.16)
	_tween.parallel().tween_property(chapter_label, "position", rest_c, t_in).set_delay(0.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(chapter_label, "modulate:a", 1.0, 0.16).set_delay(0.05)
	_tween.tween_interval(hold)
	_tween.tween_property(name_label, "position", rest_n + Vector2(72, 0), t_out).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(name_label, "modulate:a", 0.0, t_out)
	_tween.parallel().tween_property(chapter_label, "position", rest_c + Vector2(56, 0), t_out).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(chapter_label, "modulate:a", 0.0, t_out)
	_tween.parallel().tween_method(_set_open, 1.0, 0.0, t_out).set_delay(0.08)
	_tween.tween_callback(func() -> void: visible = false)
	UiKit.play_sfx(&"whoosh")


func is_playing() -> bool:
	return visible and _tween != null and _tween.is_running()


func _set_open(v: float) -> void:
	_open = v
	queue_redraw()


func _band_rect() -> Rect2:
	var safe := SafeArea.get_safe_rect()
	var screen := SafeArea.get_screen_size()
	var cy := floorf(safe.position.y + safe.size.y * 0.34)
	var h := floorf(BAND_HEIGHT * _open)
	return Rect2(0, cy - floorf(h * 0.5), screen.x, h)


func _layout() -> void:
	var safe := SafeArea.get_safe_rect()
	var cy := floorf(safe.position.y + safe.size.y * 0.34)
	chapter_label.size = chapter_label.get_minimum_size()
	name_label.size = name_label.get_minimum_size()
	if name_label.size.x > safe.size.x - MARGIN_X * 2.0:
		# 保險:名字仍然太長時改用小字,絕不超出畫面。
		name_label.theme_type_variation = &"LabelLight"
		name_label.size = name_label.get_minimum_size()
	var cx := safe.get_center().x
	chapter_label.position = Vector2(floorf(cx - chapter_label.size.x * 0.5), cy - 22)
	name_label.position = Vector2(floorf(cx - name_label.size.x * 0.5), cy - 9)


func _draw() -> void:
	if _open <= 0.0:
		return
	var r := _band_rect()
	if r.size.y < 2:
		return
	draw_rect(r, Color(0.06, 0.14, 0.13, 0.88))
	# gold trim: a bright line and a darker one, top and bottom
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), PaletteColors.GOLD_D)
	draw_rect(Rect2(r.position.x, r.position.y + 2, r.size.x, 1), PaletteColors.YELLOW)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), PaletteColors.GOLD_D)
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 1), PaletteColors.YELLOW)
	# small diamonds beside the title
	var cy := r.get_center().y + 4
	var safe := SafeArea.get_safe_rect()
	if name_label.size.x > safe.size.x - 40.0:
		return    # 名字很長時不畫菱形,免得貼著文字
	for x: float in [safe.position.x + 8, safe.end.x - 13]:
		var d := PackedVector2Array([Vector2(x + 2.5, cy - 3), Vector2(x + 5, cy), Vector2(x + 2.5, cy + 3), Vector2(x, cy)])
		draw_colored_polygon(d, PaletteColors.GOLD_L)
