extends Control
## 標題畫面的替身。正式版:ui/screens/title.tscn(C 線)。介面完全相同(DEV_PLAN 4.9):
##   setup(has_save: bool);訊號 new_game_pressed、continue_pressed、credits_pressed。

signal new_game_pressed()
signal continue_pressed()
signal credits_pressed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var _continue_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self)
	var column := StubUI.add_column(self)
	StubUI.add_label(column, "GOLDEN KNIGHT", StubUI.ACCENT, 16)
	StubUI.add_label(column, "(stand-in title)", Color(1, 1, 1, 0.6))
	StubUI.add_button(column, "New Game", new_game_pressed.emit)
	_continue_button = StubUI.add_button(column, "Continue", continue_pressed.emit)
	_continue_button.visible = false
	StubUI.add_button(column, "Credits", credits_pressed.emit)


func setup(has_save: bool) -> void:
	_continue_button.visible = has_save
