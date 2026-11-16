extends CanvasLayer
## 對白框的替身(沙盒與 B 線測試用)。正式版:ui/dialogue/dialogue_box.tscn(C 線)。合約相同(DEV_PLAN 4.11):
##   根節點 CanvasLayer 第 40 層、PROCESS_MODE_ALWAYS、群組 "dialogue_box";
##   await play(script);advance()、skip()、is_active();顯示期間擋住全部觸控;
##   開始時發 EventBus.dialogue_started,結束時記進 GameState.story_seen 再發 dialogue_finished。
## 替身的字型沒有中文字,所以顯示「說話者(表情):翻譯鍵」;插畫照樣顯示。
## 另有 played(測試用):每次 play() 的段落 id,依次序。

signal finished

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

## 測試用:play() 過的段落 id(依次序)。
var played: Array[StringName] = []

var _script: DialogueScript
var _index: int = 0
var _active: bool = false
var _root: Control
var _picture: TextureRect
var _text: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue_box")
	_root = Control.new()
	_root.name = "Root"
	StubUI.prepare_root(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	_root.visible = false
	add_child(_root)
	var dim := StubUI.add_background(_root, Color(0, 0, 0, 0.45))
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := SafeArea.get_safe_rect()
	_picture = TextureRect.new()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.position = Vector2(floorf(safe.get_center().x - 80.0), safe.position.y + 40.0)
	_picture.size = Vector2(160, 120)
	_root.add_child(_picture)
	var panel := ColorRect.new()
	panel.color = StubUI.PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(safe.position.x + 4.0, safe.end.y - 72.0)
	panel.size = Vector2(safe.size.x - 8.0, 64.0)
	_root.add_child(panel)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.position = Vector2(4, 4)
	_text.size = panel.size - Vector2(8, 8)
	panel.add_child(_text)
	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = StubUI.BUTTON_MIN * Vector2(0.75, 1.0)
	skip_button.position = Vector2(safe.end.x - 52.0, safe.position.y + 6.0)
	skip_button.pressed.connect(skip)
	_root.add_child(skip_button)


func play(script: DialogueScript) -> void:
	if script == null or script.lines.is_empty():
		return
	if _active:
		_finish()
	_script = script
	_index = 0
	_active = true
	played.append(script.id)
	_root.visible = true
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


## 目前顯示的是第幾句(0 起算;測試用)。
func get_line_index() -> int:
	return _index


func _finish() -> void:
	_active = false
	_root.visible = false
	var id := _script.id
	GameState.story_seen[id] = true
	EventBus.dialogue_finished.emit(id)
	finished.emit()


func _show_line() -> void:
	var line := _script.lines[_index]
	_text.text = "%s (%s): %s" % [line.speaker, line.expression, line.text_key]
	_picture.texture = line.illustration
	_picture.visible = line.illustration != null


func _on_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		_root.accept_event()
		advance()
