extends Control
## 過關結算的替身。正式版:ui/screens/results.tscn(C 線)。
##   setup(result: Dictionary);訊號 continue_pressed。result 的鍵見 DEV_PLAN 4.9。

signal continue_pressed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var _column: VBoxContainer
var result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color(StubUI.BG, 0.85))
	_column = StubUI.add_column(self)


func setup(data: Dictionary) -> void:
	result = data
	var final: bool = data.get("is_final", false)
	StubUI.add_label(_column, "THE END" if final else "CLEAR!", StubUI.ACCENT, 16)
	StubUI.add_label(_column, "Level %s" % data.get("level_id", ""))
	StubUI.add_label(_column, "Time %.1f s" % float(data.get("time_sec", 0.0)))
	StubUI.add_label(_column, "Kills %d" % int(data.get("kills", 0)))
	StubUI.add_label(_column, "Hero Lv %d" % int(data.get("hero_level", 1)))
	var tricks: Array = data.get("tricks", [])
	StubUI.add_label(_column, "New tricks: %s" % (", ".join(tricks.map(func(t: Variant) -> String: return str(t))) if not tricks.is_empty() else "-"))
	if data.get("next_is_camp", false):
		StubUI.add_label(_column, "Next: camp", Color(1, 1, 1, 0.6))
	StubUI.add_button(_column, "Title" if final else "Next", continue_pressed.emit)
