extends CanvasLayer
## 對白框(DEV_PLAN 4.11,v2.3)。擁有者:C 線(整合工作階段放了這個可用的初版,C 線原地替換成正式版)。
##
## 合約:
## - 根節點 CanvasLayer(第 40 層),PROCESS_MODE_ALWAYS(遊戲暫停時也能用)。B 線在流程中加一次;D 線的營地可以自己加一個。
## - `await dialogue_box.play(script)`:逐句顯示;點畫面 = 下一句;「略過」= 直接結束。結束時才返回。
## - 開始時發 EventBus.dialogue_started(script.id);結束時把 id 記進 GameState.story_seen,
##   再發 EventBus.dialogue_finished(script.id)。
## - 顯示期間擋住全部觸控,A 線的搖桿收不到。
## - 測試與機器人用:advance()(等同點一下)、skip()(等同按略過)、is_active()。對白框在群組 "dialogue_box"。
## - 頭像:assets/portraits/<speaker>/<expression>.png;名牌:tr("SPEAKER_" + speaker 大寫);旁白(narrator)沒有頭像與名牌。
## - 繪本頁:line.illustration 不是空的時候,在上方顯示插畫(160×120)。

signal finished

const LAYER: int = 40

var _script: DialogueScript
var _index: int = 0
var _active: bool = false

var _root: Control
var _panel: ColorRect
var _portrait: TextureRect
var _name: Label
var _text: Label
var _illustration: TextureRect
var _skip: Button


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue_box")   # 合約:測試與試玩機器人用這個群組找到對白框
	_build()
	_root.visible = false


func play(script: DialogueScript) -> void:
	if script == null or script.lines.is_empty():
		return
	if _active:
		_finish()
	_script = script
	_index = 0
	_active = true
	_root.visible = true
	_layout()
	EventBus.dialogue_started.emit(script.id)
	_show_line()
	await finished


func advance() -> void:
	if not _active:
		return
	_index += 1
	if _index >= _script.lines.size():
		_finish()
	else:
		_show_line()


func skip() -> void:
	if _active and _script.skippable:
		_finish()


func is_active() -> bool:
	return _active


func _finish() -> void:
	_active = false
	_root.visible = false
	var id := _script.id
	GameState.story_seen[id] = true
	EventBus.dialogue_finished.emit(id)
	finished.emit()


func _show_line() -> void:
	var line := _script.lines[_index]
	var is_narrator := line.speaker == &"narrator"
	_name.visible = not is_narrator
	_name.text = tr("SPEAKER_" + String(line.speaker).to_upper()) if not is_narrator else ""
	_text.text = tr(line.text_key)
	var path := "res://assets/portraits/%s/%s.png" % [line.speaker, line.expression]
	_portrait.visible = not is_narrator and ResourceLoader.exists(path)
	_portrait.texture = load(path) if _portrait.visible else null
	_illustration.visible = line.illustration != null
	_illustration.texture = line.illustration


func _build() -> void:
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_illustration = TextureRect.new()
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_illustration)
	_panel = ColorRect.new()
	_panel.color = Color(0.98, 0.93, 0.8, 1.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.add_child(_portrait)
	_name = Label.new()
	_name.add_theme_color_override(&"font_color", Color(0.55, 0.25, 0.1))
	_panel.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.add_theme_color_override(&"font_color", Color(0.17, 0.11, 0.18))
	_panel.add_child(_text)
	_skip = Button.new()
	_skip.text = tr("UI_SKIP") if tr("UI_SKIP") != "UI_SKIP" else "略過"
	_skip.pressed.connect(skip)
	_root.add_child(_skip)


func _layout() -> void:
	var safe := SafeArea.get_safe_rect()
	_panel.position = Vector2(safe.position.x + 4, safe.end.y - 84)
	_panel.size = Vector2(safe.size.x - 8, 76)
	_portrait.position = Vector2(4, 14)
	_portrait.size = Vector2(48, 48)
	_name.position = Vector2(58, 2)
	_text.position = Vector2(58, 16)
	_text.size = Vector2(_panel.size.x - 62, 56)
	_illustration.position = Vector2(floorf(safe.get_center().x - 80), safe.position.y + 40)
	_illustration.size = Vector2(160, 120)
	_skip.position = Vector2(safe.end.x - 52, safe.position.y + 6)
	_skip.size = Vector2(46, 24)


func _on_root_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		_root.accept_event()
		advance()
