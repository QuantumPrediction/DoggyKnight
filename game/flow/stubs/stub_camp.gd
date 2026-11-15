extends Control
## 營地的替身(B8)。正式版:game/camp/camp.tscn(D 線)。
## 進入時發 camp_entered;「Continue」發 camp_left(FlowMain 據此進入下一關)。

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")


func _ready() -> void:
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color("3a2a1e"))
	var column := StubUI.add_column(self)
	StubUI.add_label(column, "CAMP", StubUI.ACCENT, 16)
	StubUI.add_label(column, "(stand-in camp)", Color(1, 1, 1, 0.6))
	StubUI.add_label(column, "Vigor %d / %d" % [GameState.vigor, GameState.player_stats.max_vigor])
	StubUI.add_button(column, "Continue", EventBus.camp_left.emit)
	EventBus.camp_entered.emit()
