extends Control
## 失敗結算的替身(金毛睡著了)。正式版:ui/screens/failure.tscn(C 線)。
##   setup(result: Dictionary);出現時播 Sfx fail;訊號 retry_pressed、title_pressed。
##   v2.4:result["can_revive"] 為 true 時多一個「Revive (N)」按鈕,發 revive_pressed;
##   無盡試煉(result["mode"] == &"endless")顯示波數與最佳紀錄。

signal retry_pressed()
signal title_pressed()
signal revive_pressed()

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
	if data.get("mode", &"story") == &"endless":
		StubUI.add_label(_column, "Endless: wave %d  best %d%s  snacks +%d" % [int(data.get("endless_wave", 0)),
				int(data.get("endless_best", 0)), "  NEW!" if data.get("endless_new_best", false) else "",
				int(data.get("snacks_earned", 0))])
	if data.get("can_revive", false):
		StubUI.add_button(_column, "Revive (%d snacks)" % int(data.get("revive_cost", 0)), revive_pressed.emit)
	StubUI.add_button(_column, "Retry", retry_pressed.emit)
	StubUI.add_button(_column, "Title", title_pressed.emit)
