class_name QuitConfirm
extends Control
## 「要離開遊戲嗎?」(DEV_PLAN 4.8)。只在 Android 的標題畫面按返回鍵時出現。
## 「是」發 confirmed(FlowMain 存檔後關閉 App),「否」或再按返回鍵發 cancelled。
##
## 文字用 tr() 鍵(UI_QUIT_CONFIRM、UI_YES、UI_NO);中文字型由 C 線的介面主題提供。
## 按鈕至少 24×24 邏輯像素、間隔 4 像素(DEV_PLAN 第 10 節),放在安全區中央。

signal confirmed()
signal cancelled()

const BUTTON_SIZE: Vector2 = Vector2(48, 24)
const GAP: int = 4
const DIM: Color = Color(0, 0, 0, 0.6)
const PANEL: Color = Color("3b2f4a")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var safe := SafeArea.get_safe_rect()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", GAP * 2)
	panel.add_child(box)

	var label := Label.new()
	label.text = tr("UI_QUIT_CONFIRM")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", GAP * 2)
	box.add_child(row)
	row.add_child(_button(tr("UI_YES"), confirmed.emit))
	row.add_child(_button(tr("UI_NO"), cancelled.emit))

	panel.reset_size()
	panel.position = (safe.get_center() - panel.size * 0.5).floor()


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(func() -> void:
		Sfx.play(&"ui_tap")
		on_press.call())
	return button
