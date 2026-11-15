extends Control
## 失敗結算的替身(金毛睡著了)。正式版:ui/screens/failure.tscn(C 線)。
##   setup(result: Dictionary);出現時播 Sfx fail;訊號 retry_pressed、title_pressed。

signal retry_pressed()
signal title_pressed()

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
	Sfx.play(&"fail")      # 與 C 線的正式畫面相同:畫面出現時自己播音效
	StubUI.add_label(_column, "Zzz...", StubUI.ACCENT, 16)
	StubUI.add_label(_column, "Goldie fell asleep")
	StubUI.add_label(_column, "Level %s  Time %.1f s  Kills %d" % [
			data.get("level_id", ""), float(data.get("time_sec", 0.0)), int(data.get("kills", 0))])
	StubUI.add_button(_column, "Retry", retry_pressed.emit)
	StubUI.add_button(_column, "Title", title_pressed.emit)
