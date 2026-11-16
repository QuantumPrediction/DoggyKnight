extends CanvasLayer
## 對白框(DEV_PLAN 4.11、第 16 節 CS1,v2.3)。擁有者:C 線。
##
## 合約(與整合工作階段的初版相同,原地替換):
## - 根節點 CanvasLayer(第 40 層),PROCESS_MODE_ALWAYS(遊戲暫停時也能用)。B 線在流程中加一次;
##   D 線的營地可以自己加一個。在群組 "dialogue_box"(測試與試玩機器人靠它自動略過)。
## - `await dialogue_box.play(script)`:逐句顯示,播完(或略過)才返回。
## - 開始時發 EventBus.dialogue_started(script.id);結束時把 id 記進 GameState.story_seen,
##   再發 EventBus.dialogue_finished(script.id)。
## - 顯示期間擋住全部觸控(A 線的搖桿收不到)。
## - 程式用:advance()(直接到下一句)、skip()(等同按「略過」)、is_active()。
##
## 外觀:
## - 底部是羊皮紙對白框(精緻像素框),頭像框在框的上緣:金毛、貝德維爾在左,其他角色在右;
##   頭像旁有名牌 tr("SPEAKER_" + 代號大寫)。旁白(narrator)沒有頭像與名牌,文字置中。
## - 逐字顯示,每兩個字一聲說話音效(每個角色音高不同,見 dialogue_config.tres);
##   點一下先顯示整句,再點一下到下一句;整句顯示完時右下角有跳動的小箭頭。
## - 繪本頁:一句有插畫(line.illustration)時,畫面上方出現裱框的插畫(160×120)。
##   同一段對白裡,沒有插畫的句子沿用上一張插畫(docs/STORY.md「插畫空白 = 不換插畫」);
##   換插畫時有翻頁動畫與 page_turn 音效。
## - 右上角「略過 »」(至少 24×24)。暫停選單打開時(game_paused)對白框暫時隱藏。

signal finished

const LAYER: int = 40
const CONFIG: DialogueConfig = preload("res://ui/dialogue/dialogue_config.tres")
const LEFT_SPEAKERS: Array[StringName] = [&"goldie", &"bulldog"]
const PANEL_TEX: Texture2D = preload("res://assets/ui/dialogue_panel.png")
const FRAME_TEX: Texture2D = preload("res://assets/ui/portrait_frame.png")
const PLATE_TEX: Texture2D = preload("res://assets/ui/name_plate.png")
const PAGE_FRAME_TEX: Texture2D = preload("res://assets/ui/page_frame.png")
const ARROW_TEX: Texture2D = preload("res://assets/ui/next_arrow.png")
const PUNCTUATION: String = "，。！？…、；：,.!?—「」『』"
const PANEL_MAX_W: float = 176.0
const TEXT_LINES: int = 3
const LINE_H: float = 13.0
const PAGE_SIZE: Vector2 = Vector2(176, 136)

var _script: DialogueScript
var _index: int = 0
var _active: bool = false
var _line: DialogueLine
var _speaker: StringName = &""
var _illustration: Texture2D
var _shown_chars: float = 0.0
var _total_chars: int = 0
var _blip_count: int = 0
var _pause_left: float = 0.0
var _since_line: float = 0.0
var _last_tap_ms: int = -1000
var _time: float = 0.0
var _hidden_by_pause: bool = false

var _root: Control
var _dim: ColorRect
var _book: Control
var _page: NinePatchRect
var _picture: TextureRect
var _panel: NinePatchRect
var _text: Label
var _next: TextureRect
var _portrait_box: Control
var _portrait: TextureRect
var _plate: NinePatchRect
var _name: Label
var _skip: Button
var _out_tween: Tween
var _page_tween: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue_box")   # 合約:測試與試玩機器人用這個群組找到對白框
	_build()
	_root.visible = false
	get_viewport().size_changed.connect(_layout)
	EventBus.game_paused.connect(_on_game_paused)


# --------------------------------------------------------------------------
# 合約方法
# --------------------------------------------------------------------------

func play(script: DialogueScript) -> void:
	if script == null or script.lines.is_empty():
		return
	if _active:
		_finish()
	_script = script
	_index = 0
	_active = true
	_speaker = &""
	_illustration = null
	if _out_tween != null and _out_tween.is_valid():
		_out_tween.kill()
	_root.visible = not _hidden_by_pause
	_root.modulate.a = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.dialogue_started.emit(script.id)
	_show_line(true)
	await finished


## 直接到下一句(程式與測試用;玩家點畫面時先把這句顯示完整)。
func advance() -> void:
	if not _active:
		return
	_index += 1
	if _index >= _script.lines.size():
		_finish()
	else:
		_show_line(false)


func skip() -> void:
	if _active and _script.skippable:
		_finish()


func is_active() -> bool:
	return _active


## 這一句還在逐字顯示中嗎(測試用)。
func is_typing() -> bool:
	return _active and _text.visible_characters >= 0 and _text.visible_characters < _total_chars


## 目前是繪本頁模式嗎(測試用)。
func is_storybook() -> bool:
	return _active and _illustration != null


# --------------------------------------------------------------------------
# 顯示
# --------------------------------------------------------------------------

func _finish() -> void:
	_active = false
	_text.visible_characters = -1     # 淡出時顯示整句
	_next.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _out_tween != null and _out_tween.is_valid():
		_out_tween.kill()
	_out_tween = create_tween()
	_out_tween.tween_property(_root, "modulate:a", 0.0, 0.18)
	_out_tween.tween_callback(func() -> void:
		if not _active:
			_root.visible = false)
	var id := _script.id
	GameState.story_seen[id] = true
	EventBus.dialogue_finished.emit(id)
	finished.emit()


func _show_line(first: bool) -> void:
	_line = _script.lines[_index]
	var previous_picture := _illustration
	if _line.illustration != null:
		_illustration = _line.illustration
	var is_narrator := _line.speaker == &"narrator"
	var speaker_changed := _line.speaker != _speaker
	_speaker = _line.speaker
	_name.text = "" if is_narrator else tr("SPEAKER_" + String(_line.speaker).to_upper())
	_text.text = tr(_line.text_key)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_narrator else HORIZONTAL_ALIGNMENT_LEFT
	_total_chars = _text.get_total_character_count()
	_text.visible_characters = 0
	_shown_chars = 0.0
	_blip_count = 0
	_pause_left = 0.0
	_since_line = 0.0
	_next.visible = false
	var path := "res://assets/portraits/%s/%s.png" % [_line.speaker, _line.expression]
	if not is_narrator and not ResourceLoader.exists(path):
		path = "res://assets/portraits/%s/normal.png" % _line.speaker
	var has_portrait := not is_narrator and ResourceLoader.exists(path)
	_portrait.texture = load(path) as Texture2D if has_portrait else null
	_portrait_box.visible = has_portrait
	_plate.visible = not is_narrator
	_book.visible = _illustration != null
	_dim.color = Color(PaletteColors.NIGHT_D if _illustration != null else PaletteColors.INK,
			CONFIG.book_dim_alpha if _illustration != null else CONFIG.dim_alpha)
	_layout()
	if _illustration != null and previous_picture != null and previous_picture != _illustration and not first:
		_turn_page(_illustration)
	else:
		_picture.texture = _illustration
		if _illustration != null and (first or previous_picture == null):
			_settle(_book, 4.0)
	if first:
		_settle(_panel, 3.0)
	if has_portrait:
		_react(_line.expression, speaker_changed or first)


## 進場:從稍低、半透明的位置很快就位(第一格就看得見,截圖不會是空的)。
func _settle(node: Control, dy: float) -> void:
	var rest := node.position
	node.position.y = rest.y + dy
	node.modulate.a = 0.7
	var t := create_tween().set_parallel(true)
	t.tween_property(node, "position:y", rest.y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.12)


## 頭像依表情動一下:換人時彈出、驚訝時跳起、生氣時抖動、開心時輕彈。
func _react(expression: StringName, popped: bool) -> void:
	var base := _portrait_box.position
	var t := create_tween()
	if popped:
		_portrait_box.scale = Vector2(0.9, 1.1)
		t.tween_property(_portrait_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match expression:
		&"surprised":
			t.tween_property(_portrait_box, "position:y", base.y - 4, 0.07)
			t.tween_property(_portrait_box, "position:y", base.y, 0.1)
		&"angry":
			for dx: float in [-2.0, 2.0, -2.0, 1.0, 0.0]:
				t.tween_property(_portrait_box, "position:x", base.x + dx, 0.035)
		&"happy", &"proud":
			t.tween_property(_portrait_box, "position:y", base.y - 2, 0.08)
			t.tween_property(_portrait_box, "position:y", base.y, 0.1)


func _turn_page(to: Texture2D) -> void:
	UiKit.play_sfx(&"page_turn")
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_book.pivot_offset = Vector2(0, PAGE_SIZE.y * 0.5)
	var half := CONFIG.page_turn_time * 0.5
	_page_tween = create_tween()
	_page_tween.tween_property(_book, "scale:x", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_page_tween.parallel().tween_property(_book, "modulate", Color(0.7, 0.7, 0.8), half)
	_page_tween.tween_callback(func() -> void: _picture.texture = to)
	_page_tween.tween_property(_book, "scale:x", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_page_tween.parallel().tween_property(_book, "modulate", Color.WHITE, half)


func _process(delta: float) -> void:
	_time += delta
	if not _active:
		return
	_since_line += delta
	if _text.visible_characters >= 0 and _text.visible_characters < _total_chars:
		if _pause_left > 0.0:
			_pause_left -= delta
			return
		_shown_chars += delta * CONFIG.chars_per_second
		var target := mini(int(_shown_chars), _total_chars)
		while _text.visible_characters < target:
			_text.visible_characters += 1
			var ch := _text.text.substr(_text.visible_characters - 1, 1)
			if PUNCTUATION.contains(ch):
				_pause_left = CONFIG.punctuation_pause
				_shown_chars = float(_text.visible_characters)
				break
			if ch.strip_edges() != "":
				_blip()
		if _text.visible_characters >= _total_chars:
			_text.visible_characters = -1
	else:
		_next.visible = true
		_next.position.y = _next_rest_y() + roundf(sin(_time * 7.0) * 1.0)


func _blip() -> void:
	_blip_count += 1
	if _speaker == &"narrator" or _blip_count % maxi(1, CONFIG.blip_every) != 1 % maxi(1, CONFIG.blip_every):
		return
	var pitch: float = float(CONFIG.speaker_pitch.get(String(_speaker), 1.0))
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.call(&"play", &"talk", CONFIG.blip_volume_db, pitch * randf_range(0.96, 1.04))


func _on_tap() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 90:    # 觸控與模擬滑鼠會各送一次,只算一下
		return
	_last_tap_ms = now
	if not _active or _since_line < CONFIG.tap_guard:
		return
	if is_typing():
		_text.visible_characters = -1
	else:
		UiKit.play_sfx(&"ui_tap")
		advance()


func _on_root_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		_root.accept_event()
		_on_tap()


func _on_game_paused(paused: bool) -> void:
	_hidden_by_pause = paused
	if _active:
		_root.visible = not paused


# --------------------------------------------------------------------------
# 建立與排版
# --------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "DialogueRoot"
	UiKit.setup_root(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_book = Control.new()
	_book.name = "Storybook"
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.size = PAGE_SIZE
	_root.add_child(_book)
	_page = _nine(PANEL_TEX, 8)
	_page.size = PAGE_SIZE
	_book.add_child(_page)
	_picture = UiKit.texture_rect(null)
	_picture.name = "Illustration"
	_picture.position = Vector2(8, 8)
	_picture.size = Vector2(160, 120)
	_book.add_child(_picture)
	var frame := UiKit.texture_rect(PAGE_FRAME_TEX)
	frame.position = Vector2(4, 4)
	_book.add_child(frame)

	_panel = _nine(PANEL_TEX, 8)
	_panel.name = "Panel"
	_root.add_child(_panel)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_color_override(&"font_color", PaletteColors.INK)
	_text.add_theme_constant_override(&"line_spacing", 1)
	_panel.add_child(_text)
	_next = UiKit.texture_rect(ARROW_TEX)
	_next.name = "NextArrow"
	_panel.add_child(_next)

	_portrait_box = Control.new()
	_portrait_box.name = "Portrait"
	_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_box.size = Vector2(52, 52)
	_portrait_box.pivot_offset = Vector2(26, 52)
	_root.add_child(_portrait_box)
	_portrait = UiKit.texture_rect(null)
	_portrait.position = Vector2(2, 2)
	_portrait.size = Vector2(48, 48)
	_portrait_box.add_child(_portrait)
	_portrait_box.add_child(UiKit.texture_rect(FRAME_TEX))

	_plate = _nine(PLATE_TEX, 5)
	_plate.name = "NamePlate"
	_root.add_child(_plate)
	_name = UiKit.label("", &"LabelLight")
	_name.name = "Name"
	_plate.add_child(_name)

	var skip_text := tr("UI_SKIP") if tr("UI_SKIP") != "UI_SKIP" else "略過"
	_skip = UiKit.button(skip_text + " »", &"ButtonAlt", Vector2(48, 24))
	_skip.name = "SkipButton"
	_skip.pressed.connect(skip)
	_root.add_child(_skip)


func _nine(tex: Texture2D, margin: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.patch_margin_left = margin
	n.patch_margin_top = margin
	n.patch_margin_right = margin
	n.patch_margin_bottom = margin
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _next_rest_y() -> float:
	return _panel.size.y - 10.0


func _layout() -> void:
	if _root == null or not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	var screen := SafeArea.get_screen_size()
	var bottom := minf(safe.end.y, screen.y)
	var w := floorf(minf(PANEL_MAX_W, safe.size.x - 4.0))
	var x := floorf(safe.get_center().x - w * 0.5)
	var panel_h := 12.0 + LINE_H * TEXT_LINES + 8.0
	_panel.size = Vector2(w, panel_h)
	_panel.position = Vector2(x, floorf(bottom - panel_h - 6.0))
	var narrator := _line != null and _line.speaker == &"narrator"
	_text.position = Vector2(9, 9 if narrator else 11)
	_text.size = Vector2(w - 18, LINE_H * TEXT_LINES + 2)
	_next.position = Vector2(w - 15, _next_rest_y())
	# 頭像框:站在對白框上緣,左右分邊
	var left := _line == null or LEFT_SPEAKERS.has(_line.speaker)
	_portrait_box.position = Vector2(x + 4.0 if left else x + w - 56.0, _panel.position.y - 46.0)
	_name.size = _name.get_minimum_size()
	_plate.size = Vector2(maxf(30.0, _name.size.x + 12.0), 16.0)
	_name.position = Vector2(floorf((_plate.size.x - _name.size.x) * 0.5), 1.0)
	var plate_y := _panel.position.y - 9.0
	_plate.position = Vector2(_portrait_box.position.x + 54.0, plate_y) if left \
			else Vector2(_portrait_box.position.x - _plate.size.x - 2.0, plate_y)
	# 繪本頁:放在對白框(和頭像)上方的空間置中
	var top := safe.position.y + 32.0
	var limit := (_portrait_box.position.y if _portrait_box.visible else _panel.position.y) - 4.0
	_book.position = Vector2(floorf(safe.get_center().x - PAGE_SIZE.x * 0.5),
			floorf(maxf(safe.position.y + 2.0, top + (limit - top - PAGE_SIZE.y) * 0.5)))
	_skip.size = _skip.get_combined_minimum_size()
	_skip.position = Vector2(floorf(safe.end.x - _skip.size.x - 4.0), floorf(safe.position.y + 4.0))
