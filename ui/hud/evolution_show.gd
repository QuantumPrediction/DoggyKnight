class_name EvolutionShow
extends Control
## 把戲進化演出(CV2,DEV_PLAN 4.12、第 17 節)。HUD 的一部分,聽 EventBus.trick_evolved。
##
## 約 1.9 秒:兩個原把戲的圖示從左右兩邊轉著靠近 → 碰在一起時白光一閃(evolve 音效、中等震動)
## → 進化後的金框圖示彈出、金色光暈與星星 → 「把戲進化!」緞帶與名稱 → 淡出。
## 不攔觸控(全部 MOUSE_FILTER_IGNORE);遊戲暫停中也會播完(HUD 是 PROCESS_MODE_ALWAYS)。
## 同時收到好幾個進化時排隊依序播放。

const ICON_SCALE: float = 3.0
const SPREAD: float = 46.0
const MERGE_TIME: float = 0.55
const HOLD_TIME: float = 1.0
const STAR_BURST: PackedScene = preload("res://assets/fx/particles/star_burst.tscn")
const GLOW: Texture2D = preload("res://assets/fx/lights/glow_96.png")

var left_icon: TextureRect
var right_icon: TextureRect
var result_icon: TextureRect
var ribbon: PanelContainer
var name_label: Label
var evolution_id: StringName = &""

var _glow: TextureRect
var _flash: ColorRect
var _queue: Array[StringName] = []
var _tween: Tween
var _playing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(PaletteColors.WHITE, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_glow = UiKit.texture_rect(GLOW)
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.self_modulate = Color(PaletteColors.GOLD_L)
	add_child(_glow)
	left_icon = _icon("Left")
	right_icon = _icon("Right")
	result_icon = _icon("Result")
	ribbon = PanelContainer.new()
	ribbon.name = "Ribbon"
	ribbon.theme_type_variation = &"RibbonGold"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(UiKit.label(tr("UI_EVOLVED"), &"LabelLight"))
	add_child(ribbon)
	name_label = UiKit.label("", &"LabelPop")
	name_label.name = "Name"
	add_child(name_label)
	_hide_all()
	EventBus.trick_evolved.connect(play)


func _icon(node_name: String) -> TextureRect:
	var t := UiKit.texture_rect(null)
	t.name = node_name
	t.size = Vector2(16, 16) * ICON_SCALE
	add_child(t)
	return t


func is_playing() -> bool:
	return _playing


## 播放一次進化演出(通常由 EventBus.trick_evolved 呼叫)。
func play(id: StringName) -> void:
	if _playing:
		_queue.append(id)
		return
	_playing = true
	evolution_id = id
	visible = true
	var parents := EvolutionInfo.parents_of(id)
	left_icon.texture = EvolutionInfo.icon_of(parents[0]) if parents.size() > 0 else null
	right_icon.texture = EvolutionInfo.icon_of(parents[1]) if parents.size() > 1 else null
	result_icon.texture = EvolutionInfo.icon_of(id)
	var key := EvolutionInfo.name_key(id)
	name_label.text = tr(key) if tr(key) != key else ""
	name_label.size = name_label.get_minimum_size()
	ribbon.size = ribbon.get_minimum_size()

	var safe := SafeArea.get_safe_rect()
	var center := Vector2(safe.get_center().x, safe.position.y + safe.size.y * 0.36).floor()
	var icon_size := Vector2(16, 16) * ICON_SCALE
	for t: TextureRect in [left_icon, right_icon, result_icon]:
		t.size = icon_size
		t.pivot_offset = icon_size * 0.5
		t.rotation = 0.0
		t.scale = Vector2.ONE
		t.modulate = Color.WHITE
	var rest := center - icon_size * 0.5
	left_icon.position = rest - Vector2(SPREAD, 0)
	right_icon.position = rest + Vector2(SPREAD, 0)
	left_icon.visible = left_icon.texture != null
	right_icon.visible = right_icon.texture != null
	left_icon.modulate.a = 0.0
	right_icon.modulate.a = 0.0
	result_icon.position = rest
	result_icon.visible = false
	_glow.position = (center - _glow.size * 0.5).floor()
	_glow.pivot_offset = _glow.size * 0.5
	_glow.modulate.a = 0.0
	ribbon.position = Vector2(floorf(center.x - ribbon.size.x * 0.5), rest.y - ribbon.size.y - 6.0)
	ribbon.visible = false
	name_label.position = Vector2(floorf(center.x - name_label.size.x * 0.5), rest.y + icon_size.y + 4.0)
	name_label.visible = false

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	# 1. 兩個圖示出現並轉著靠近
	_tween.tween_property(left_icon, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(right_icon, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(_glow, "modulate:a", 0.6, 0.3)
	_tween.tween_property(left_icon, "position", rest, MERGE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(right_icon, "position", rest, MERGE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(left_icon, "rotation", TAU, MERGE_TIME)
	_tween.parallel().tween_property(right_icon, "rotation", -TAU, MERGE_TIME)
	# 2. 合體:白光一閃
	_tween.tween_callback(_merge.bind(center))
	_tween.tween_property(_flash, "color:a", 0.0, 0.25)
	# 3. 進化圖示彈出
	_tween.parallel().tween_property(result_icon, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(result_icon, "scale", Vector2.ONE, 0.12)
	_tween.parallel().tween_property(_glow, "scale", Vector2(1.25, 1.25), 0.3)
	_tween.tween_interval(HOLD_TIME)
	# 4. 淡出
	for c: CanvasItem in [result_icon, ribbon, name_label, _glow]:
		_tween.parallel().tween_property(c, "modulate:a", 0.0, 0.3).set_delay(HOLD_TIME)
	_tween.tween_callback(_finish)


func _merge(center: Vector2) -> void:
	left_icon.visible = false
	right_icon.visible = false
	result_icon.visible = true
	result_icon.scale = Vector2(0.4, 0.4)
	result_icon.modulate.a = 1.0
	ribbon.visible = true
	ribbon.modulate.a = 1.0
	name_label.visible = true
	name_label.modulate.a = 1.0
	_glow.modulate.a = 1.0
	_glow.scale = Vector2(0.8, 0.8)
	_flash.color = Color(PaletteColors.WHITE, 0.55)
	UiKit.play_sfx(&"evolve")
	Haptics.play(&"medium")
	var fx := STAR_BURST.instantiate() as Node2D
	if fx != null:
		fx.position = center
		add_child(fx)


func _finish() -> void:
	_playing = false
	_hide_all()
	if not _queue.is_empty():
		play(_queue.pop_front())


func _hide_all() -> void:
	for c: CanvasItem in [left_icon, right_icon, result_icon, ribbon, name_label]:
		c.visible = false
	_glow.modulate.a = 0.0
	_flash.color.a = 0.0
