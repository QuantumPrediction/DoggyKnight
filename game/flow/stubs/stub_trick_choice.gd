extends Control
## 把戲選擇介面的替身。正式版:ui/trick_choice/trick_choice.tscn(C 線)。
## 聽 EventBus.trick_offered(Array[TrickData]),顯示三張卡;點一張 → 先藏起自己,再發 trick_chosen(id)。
## 遊戲在選擇時是暫停的,所以根節點用 PROCESS_MODE_ALWAYS。

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var _column: VBoxContainer
var _options: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color(0, 0, 0, 0.55))
	_column = StubUI.add_column(self)
	visible = false
	EventBus.trick_offered.connect(_on_trick_offered)
	EventBus.trick_chosen.connect(_on_trick_chosen)


func _exit_tree() -> void:
	if EventBus.trick_offered.is_connected(_on_trick_offered):
		EventBus.trick_offered.disconnect(_on_trick_offered)
	if EventBus.trick_chosen.is_connected(_on_trick_chosen):
		EventBus.trick_chosen.disconnect(_on_trick_chosen)


## 別處(例如測試)直接發了 trick_chosen 時也收起來。
func _on_trick_chosen(_trick_id: StringName) -> void:
	visible = false
	_options.clear()


func get_options() -> Array:
	return _options.duplicate()


## 測試與沙盒用:選第 index 個選項(等同點那張卡)。
func choose(index: int) -> void:
	if index >= 0 and index < _options.size():
		_choose((_options[index] as TrickData).id)


func _on_trick_offered(options: Array) -> void:
	_options = options.duplicate()
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	StubUI.add_label(_column, "LEVEL UP! Pick a trick", StubUI.ACCENT)
	for option: Variant in options:
		var trick := option as TrickData
		if trick == null:
			continue
		var button := StubUI.add_button(_column, String(trick.id).capitalize(), _choose.bind(trick.id))
		button.icon = trick.icon
		button.custom_minimum_size = Vector2(96, 28)
		button.expand_icon = false
	visible = true


func _choose(trick_id: StringName) -> void:
	if not visible:
		return
	visible = false
	_options.clear()
	EventBus.trick_chosen.emit(trick_id)
