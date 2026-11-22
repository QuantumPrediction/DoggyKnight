extends Control
## 抉擇事件介面(CV3,DEV_PLAN 4.12、第 17 節)。B 線把它放在第 20 層 CanvasLayer(和把戲選擇一樣)。
##
## 聽 EventBus.event_offered(event_id, options):options 是 Array[Dictionary],每項
## {"title": 翻譯鍵, "desc": 翻譯鍵, "icon": 圖示路徑, "tone": "merlin" | "morgana"}。
## 顯示兩張卡片:梅林(藍色、溫暖,星星閃閃)與摩根娜(紫色、神秘,微微搖晃的紫光)。
## 玩家點一張 → 發 EventBus.event_chosen(event_id, index) 並隱藏。
## 遊戲暫停時照常運作(PROCESS_MODE_ALWAYS)。不加入任何群組。
## 根節點不攔觸控;顯示時由半透明底色擋住後面的點擊,隱藏時完全不影響 A 線的搖桿。
## 卡片出現後短暫不接受點擊,避免玩家原本按著畫面的手指一放開就誤選。

const INPUT_DELAY: float = 0.45
const CARD_SIZE: Vector2 = Vector2(168, 92)
const CARD_GAP: float = 8.0
const CARD_INK := Color("302b24")
const MERLIN_INK := Color("35434b")
const MORGANA_INK := Color("48324e")
const PORTRAITS: Dictionary = {
	&"merlin": "res://assets/portraits/merlin/proud.png",
	&"morgana": "res://assets/portraits/morgana/smirk.png",
}
const PORTRAIT_FRAME: Texture2D = preload("res://assets/ui/portrait_frame.png")
const GLOW: Texture2D = preload("res://assets/fx/lights/glow_52.png")

var cards: Array[Button] = []
var event_id: StringName = &""

var _tones: Array[StringName] = []
var _title: PanelContainer
var _hint: Label
var _box: Control
var _accept_at: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	UiKit.setup_root(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.dim(Color(PaletteColors.NIGHT_D, 0.7)))
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_title = PanelContainer.new()
	_title.name = "Title"
	_title.theme_type_variation = &"RibbonBig"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(UiKit.label(tr("UI_EVENT_TITLE"), &"LabelLight"))
	_box.add_child(_title)
	_hint = UiKit.wrapped_label(tr("UI_EVENT_HINT"), 164, &"LabelLight")
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.name = "Hint"
	_box.add_child(_hint)
	visible = false
	EventBus.event_offered.connect(show_event)
	get_viewport().size_changed.connect(_layout)


## 顯示一個抉擇事件(通常由 EventBus.event_offered 呼叫)。
func show_event(id: StringName, options: Array) -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	_tones.clear()
	event_id = id
	(_title.get_child(0) as Label).text = tr(BuildRoutes.event_title(id))
	_hint.text = tr("UI_ROUTE_HINT" if BuildRoutes.is_route_event(id) else "UI_EVENT_HINT")
	for i in options.size():
		var opt: Dictionary = options[i] if options[i] is Dictionary else {}
		var card := _make_card(opt, i)
		_box.add_child(card)
		cards.append(card)
		_tones.append(StringName(String(opt.get("tone", ""))))
	visible = true
	_accept_at = Time.get_ticks_msec() / 1000.0 + INPUT_DELAY
	_layout()
	UiKit.play_sfx(&"event")
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(0.3, 0.3)
	var tt := _title.create_tween()
	tt.tween_property(_title, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hint.modulate.a = 0.0
	_hint.create_tween().tween_property(_hint, "modulate:a", 1.0, 0.3).set_delay(0.4)
	for i in cards.size():
		var card := cards[i]
		var rest := card.position
		var from_x := -CARD_SIZE.x - 8.0 if i % 2 == 0 else SafeArea.get_screen_size().x + 8.0
		card.position = Vector2(from_x, rest.y)
		card.modulate.a = 0.0
		var t := card.create_tween()
		t.tween_interval(0.12 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.08)
		t.parallel().tween_property(card, "position", rest, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 選第 index 張卡片(點卡片時呼叫;測試與試玩機器人也可以直接呼叫)。
func choose(index: int) -> void:
	if not visible or index < 0 or index >= cards.size():
		return
	visible = false
	EventBus.event_chosen.emit(event_id, index)


func is_open() -> bool:
	return visible


func _on_card_pressed(index: int) -> void:
	if Time.get_ticks_msec() / 1000.0 < _accept_at:
		return
	UiKit.tap_feedback()
	choose(index)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# 摩根娜的卡片微微發出紫光(呼吸),梅林的卡片穩定溫暖
	for i in cards.size():
		var card := cards[i]
		var glow := card.get_node_or_null(^"Glow") as CanvasItem
		if glow != null:
			var phase := _time * (2.2 if _tones[i] == &"morgana" else 1.4) + i
			glow.modulate.a = 0.35 + 0.35 * sin(phase)


func _make_card(opt: Dictionary, index: int) -> Button:
	var tone := StringName(String(opt.get("tone", "")))
	var morgana := tone == &"morgana"
	var route := tone == &"route"
	var card := Button.new()
	card.name = "Card%d" % index
	card.theme_type_variation = &"CardMorgana" if morgana else (&"CardMerlin" if tone == &"merlin" else &"CardButton")
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pressed.connect(_on_card_pressed.bind(index))
	UiKit.add_squash(card)

	# 頭像後面呼吸的光暈(加亮混合):梅林是溫暖的藍光,摩根娜是神秘的紫光
	var glow := UiKit.texture_rect(GLOW)
	glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.self_modulate = Color(PaletteColors.VIOLET) if morgana else Color(PaletteColors.SKY)
	glow.position = Vector2(5, floorf((CARD_SIZE.y - 52) * 0.5))
	card.add_child(glow)
	# 頭像:梅林(微笑)或摩根娜(紫色剪影)
	var holder := Control.new()
	holder.name = "Portrait"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(5, floorf((CARD_SIZE.y - 52) * 0.5))
	holder.size = Vector2(52, 52)
	var path: String = String(opt.get("icon", "")) if route else String(PORTRAITS.get(tone, ""))
	if path != "" and ResourceLoader.exists(path):
		var face := _card_image(load(path) as Texture2D, Vector2(44, 44))
		face.position = Vector2(2, 2)
		holder.add_child(face)
	holder.add_child(UiKit.texture_rect(PORTRAIT_FRAME))
	card.add_child(holder)

	var text_x := 61.0
	var text_w := CARD_SIZE.x - text_x - 5.0
	var tone_key := "UI_ROUTE_TONE" if route else ("UI_EVENT_MORGANA" if morgana else ("UI_EVENT_MERLIN" if tone == &"merlin" else ""))
	# v2.6:第三章梅林被抓走了,祝福改由湖中仙女給(docs/STORY.md 第 13 節)
	if tone_key == "UI_EVENT_MERLIN" and GameState.mode == &"story" and GameState.chapter == 3:
		tone_key = "UI_EVENT_LADY"
	var tone_label := _card_label(tr(tone_key) if tone_key != "" else "", 8, MORGANA_INK if morgana else MERLIN_INK)
	tone_label.name = "Tone"
	tone_label.position = Vector2(text_x, 3)
	tone_label.size = Vector2(text_w - 18, 13)
	card.add_child(tone_label)
	var title := _card_label(tr(String(opt.get("title", ""))), 10, CARD_INK)
	title.name = "Name"
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.position = Vector2(text_x, 17)
	title.size = Vector2(text_w, 16)
	card.add_child(title)
	var desc := _card_label(tr(String(opt.get("desc", ""))), 9, CARD_INK, true)
	desc.add_theme_constant_override(&"line_spacing", 0)
	desc.name = "Description"
	desc.position = Vector2(text_x, 34)
	desc.size = Vector2(text_w, 54)
	card.add_child(desc)

	# 右上角的小圖示(選項資料提供的路徑;沒有就不顯示)
	var icon_path := String(opt.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := load(icon_path) as Texture2D
		if tex != null:
			var icon := _card_image(tex, Vector2(12, 12))
			icon.name = "Icon"
			icon.position = Vector2(CARD_SIZE.x - 16, 3)
			card.add_child(icon)

	return card


func _card_image(texture: Texture2D, dimensions: Vector2) -> TextureRect:
	# Set only the intended display minimum. Shrinking UiKit's texture-sized
	# minimum in the same frame leaves a cached 48px portrait in a 12px slot.
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture
	image.custom_minimum_size = dimensions
	image.size = dimensions
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _card_label(text: String, font_size: int, ink: Color, wrap: bool = false) -> Label:
	# Measure with the final CJK font before sizing; inherited fallback font
	# metrics previously made the title overlap the cost description.
	var label := Label.new()
	label.add_theme_font_override(&"font", get_theme_font(&"font", &"Label"))
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", ink)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	return label


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_title.size = _title.get_minimum_size()
	_hint.size = _hint.get_minimum_size()
	var total_h := _title.size.y + 8.0 + cards.size() * CARD_SIZE.y + maxf(0, cards.size() - 1) * CARD_GAP \
			+ 6.0 + _hint.size.y
	var top := floorf(safe.position.y + (safe.size.y - total_h) * 0.45)
	var cx := safe.get_center().x
	_title.position = Vector2(floorf(cx - _title.size.x * 0.5), top)
	var y := top + _title.size.y + 8.0
	for card in cards:
		card.size = CARD_SIZE
		card.pivot_offset = (CARD_SIZE * 0.5).floor()
		card.position = Vector2(floorf(cx - CARD_SIZE.x * 0.5), y)
		y += CARD_SIZE.y + CARD_GAP
	_hint.position = Vector2(floorf(cx - _hint.size.x * 0.5), y - CARD_GAP + 6.0)
