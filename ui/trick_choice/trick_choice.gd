extends Control
## 升級選把戲(C9,DEV_PLAN 4.4、4.9)。B 線把它放在第 20 層 CanvasLayer。
##
## 聽 EventBus.trick_offered(options: Array[TrickData]),顯示三張卡片(圖示、名稱、一行說明)。
## 玩家點一張 → 發 EventBus.trick_chosen(id) 並隱藏。遊戲暫停中也能操作(PROCESS_MODE_ALWAYS)。
## 卡片出現後短暫不接受點擊,避免玩家原本按著畫面的手指一放開就誤選。
## CP5:卡片一張接一張翻進來、閃一下光;右上角標示「NEW」(還沒學過)或「Lv2」(選了會變第幾層,
## 由 GameState.active_tricks 數)。選中的卡片彈一下,其他卡片淡出。

const INPUT_DELAY: float = 0.35
const CARD_SIZE: Vector2 = Vector2(168, 54)
const CARD_GAP: float = 6.0
const ICON_SCALE: int = 2

var cards: Array[Button] = []
var _ids: Array[StringName] = []
var _title: PanelContainer
var _title_label: Label
var _box: Control
var _accept_at: float = 0.0


func _ready() -> void:
	UiKit.setup_root(self)
	# 根節點不攔觸控;打開時由半透明底色(dim)擋住後面的點擊,隱藏時完全不影響 A 線的搖桿。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.dim())
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_title = PanelContainer.new()
	_title.theme_type_variation = &"Ribbon"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label = UiKit.label(tr("UI_LEVEL_UP"), &"LabelLight")
	_title.add_child(_title_label)
	_box.add_child(_title)
	visible = false
	EventBus.trick_offered.connect(show_options)
	get_viewport().size_changed.connect(_layout)


## 顯示把戲選項(通常由 EventBus.trick_offered 呼叫)。
func show_options(options: Array) -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	_ids.clear()
	for i in options.size():
		var trick := options[i] as TrickData
		if trick == null:
			continue
		var card := _make_card(trick)
		_box.add_child(card)
		cards.append(card)
		_ids.append(trick.id)
	visible = true
	_accept_at = Time.get_ticks_msec() / 1000.0 + INPUT_DELAY
	_layout()
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(0.3, 0.3)
	var tt := _title.create_tween()
	tt.tween_property(_title, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in cards.size():
		var card := cards[i]
		card.pivot_offset = CARD_SIZE * 0.5
		card.scale = Vector2(0.0, 1.0)
		card.modulate = Color(2.0, 2.0, 2.0, 0.0)
		var t := card.create_tween()
		t.tween_interval(0.07 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.05)
		t.parallel().tween_property(card, "scale", Vector2(1.06, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2.ONE, 0.06)
		t.parallel().tween_property(card, "modulate", Color.WHITE, 0.25)
		if i == 0:
			t.tween_callback(UiKit.play_sfx.bind(&"whoosh"))


## 選擇第 index 張卡片(點卡片時呼叫;測試也用這個)。
func choose(index: int) -> void:
	if not visible or index < 0 or index >= _ids.size():
		return
	var id := _ids[index]
	visible = false
	EventBus.trick_chosen.emit(id)


## 這個把戲已經學了幾次(由 GameState.active_tricks 數)。
static func learned_count(id: StringName) -> int:
	return GameState.active_tricks.count(id)


## 卡片右上角的標記文字:沒學過是「NEW」,學過 n 次就是「Lv(n+1)」。
static func badge_text(id: StringName) -> String:
	var n := learned_count(id)
	return tr_static("UI_TRICK_NEW") if n == 0 else tr_static("UI_TRICK_LEVEL") % (n + 1)


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)


func _on_card_pressed(index: int) -> void:
	if Time.get_ticks_msec() / 1000.0 < _accept_at:
		return
	UiKit.tap_feedback()
	choose(index)


func _make_card(trick: TrickData) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"CardButton"
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.name = "Card_%s" % trick.id
	card.pressed.connect(_on_card_pressed.bind(cards.size()))
	var icon_tex := trick.icon
	if icon_tex == null:
		var path := "res://assets/icons/tricks/%s.png" % trick.id
		if ResourceLoader.exists(path):
			icon_tex = load(path) as Texture2D
	var icon := UiKit.texture_rect(icon_tex, ICON_SCALE)
	icon.position = Vector2(6, floorf((CARD_SIZE.y - 32) * 0.5))
	icon.size = Vector2(32, 32)
	card.add_child(icon)
	var text_x := 43.0
	var text_w := CARD_SIZE.x - text_x - 4.0
	var name_label := UiKit.label(tr(trick.display_name), &"", HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "Name"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.position = Vector2(text_x, 4)
	name_label.size = Vector2(text_w, 14)
	card.add_child(name_label)
	var desc := UiKit.wrapped_label(tr(trick.description), text_w, &"LabelSoft")
	desc.name = "Description"
	desc.position = Vector2(text_x, 21)
	desc.size = Vector2(text_w, 30)
	card.add_child(desc)
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.theme_type_variation = &"Ribbon" if learned_count(trick.id) == 0 else &"PanelDark"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_label := UiKit.label(badge_text(trick.id), &"LabelLight")
	badge_label.name = "Text"
	badge.add_child(badge_label)
	card.add_child(badge)
	badge.size = badge.get_minimum_size()
	badge.position = Vector2(CARD_SIZE.x - badge.size.x + 2, -5)
	return card


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_title.size = _title.get_minimum_size()
	var total_h := _title.size.y + 8.0 + cards.size() * CARD_SIZE.y + maxf(0, cards.size() - 1) * CARD_GAP
	var top := floorf(safe.position.y + (safe.size.y - total_h) * 0.45)
	_title.position = Vector2(floorf(safe.get_center().x - _title.size.x * 0.5), top)
	var y := top + _title.size.y + 8.0
	for card in cards:
		card.size = CARD_SIZE
		card.position = Vector2(floorf(safe.get_center().x - CARD_SIZE.x * 0.5), y)
		y += CARD_SIZE.y + CARD_GAP
