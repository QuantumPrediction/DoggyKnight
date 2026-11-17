extends Control
## 營地訓練介面的替身(v2.4)。正式版:game/camp/training.tscn(D 線)。
## 讀 data/progression/meta_upgrades.tres,每項一個按鈕(買得起才可以按,用 MetaUpgradeTable.purchase);
## 「Close」或返回鍵發 closed(B 線收起介面並存檔;與 D 線的正式版相同)。

signal closed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var table: MetaUpgradeTable
var _column: VBoxContainer
var _buttons: Dictionary = {}
var _snack_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self)
	_column = StubUI.add_column(self)
	table = MetaUpgradeTable.load_default()
	StubUI.add_label(_column, "TRAINING (stand-in)", StubUI.ACCENT)
	_snack_label = StubUI.add_label(_column, "")
	if table != null:
		for entry in table.entries:
			var button := StubUI.add_button(_column, "", _buy.bind(entry.id))
			button.custom_minimum_size = Vector2(150, 24)
			_buttons[entry.id] = button
	StubUI.add_button(_column, "Close", closed.emit)
	EventBus.back_requested.connect(closed.emit)
	_refresh()


func _exit_tree() -> void:
	if EventBus.back_requested.is_connected(closed.emit):
		EventBus.back_requested.disconnect(closed.emit)


## 測試與沙盒用。
func buy(id: StringName) -> bool:
	return _buy(id)


func _buy(id: StringName) -> bool:
	var ok := table != null and table.purchase(id)
	_refresh()
	return ok


func _refresh() -> void:
	_snack_label.text = "Snacks %d" % GameState.snacks
	if table == null:
		return
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		var cost := table.next_cost(id)
		button.text = "%s Lv%d  %s" % [String(id).capitalize(), table.level_of(id), "MAX" if cost < 0 else "(%d)" % cost]
		button.disabled = not table.can_buy(id)
