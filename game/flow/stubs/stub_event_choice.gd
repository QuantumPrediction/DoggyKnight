extends Control
## 抉擇事件介面的替身(v2.4)。正式版:ui/event_choice/event_choice.tscn(C 線)。
## 聽 EventBus.event_offered(事件 id, 選項),顯示兩個按鈕(梅林 / 摩根娜);點一個 → 藏起自己,
## 發 event_chosen(事件 id, 索引)。遊戲在選擇時是暫停的,所以根節點用 PROCESS_MODE_ALWAYS。

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var _column: VBoxContainer
var _event_id: StringName = &""
var _options: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color(0.1, 0.05, 0.2, 0.7))
	_column = StubUI.add_column(self)
	visible = false
	EventBus.event_offered.connect(_on_event_offered)
	EventBus.event_chosen.connect(_on_event_chosen)


func _exit_tree() -> void:
	if EventBus.event_offered.is_connected(_on_event_offered):
		EventBus.event_offered.disconnect(_on_event_offered)
	if EventBus.event_chosen.is_connected(_on_event_chosen):
		EventBus.event_chosen.disconnect(_on_event_chosen)


func get_options() -> Array:
	return _options.duplicate()


## 測試與沙盒用:選第 index 項。
func choose(index: int) -> void:
	if visible and index >= 0 and index < _options.size():
		_choose(index)


func _on_event_offered(event_id: StringName, options: Array) -> void:
	_event_id = event_id
	_options = options.duplicate()
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	StubUI.add_label(_column, "EVENT: %s" % event_id, StubUI.ACCENT)
	for i in options.size():
		var option := options[i] as Dictionary
		var text := "%s: %s" % [String(option.get("tone", "")).capitalize(), option.get("title", "")]
		var button := StubUI.add_button(_column, text, _choose.bind(i))
		button.custom_minimum_size = Vector2(150, 28)
	visible = true


func _on_event_chosen(_id: StringName, _index: int) -> void:
	visible = false
	_options.clear()


func _choose(index: int) -> void:
	if not visible:
		return
	visible = false
	_options.clear()
	EventBus.event_chosen.emit(_event_id, index)
