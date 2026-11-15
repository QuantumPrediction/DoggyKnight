extends Control
## 製作名單與授權的替身。正式版:ui/screens/credits.tscn(C 線)。訊號 closed。

signal closed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self)
	var safe := SafeArea.get_safe_rect()
	var column := VBoxContainer.new()
	column.position = safe.position + Vector2(6, 6)
	column.size = safe.size - Vector2(12, 12)
	column.add_theme_constant_override(&"separation", StubUI.GAP)
	add_child(column)
	StubUI.add_label(column, "CREDITS (stand-in)", StubUI.ACCENT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var text := Label.new()
	text.text = "Godot Engine\n\n%s" % Engine.get_license_text()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(column.size.x - 8, 0)
	scroll.add_child(text)
	StubUI.add_button(column, "Close", closed.emit)
