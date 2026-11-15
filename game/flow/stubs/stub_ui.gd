extends RefCounted
## 替身畫面共用的小工具(只給 game/flow/stubs/ 用)。C 線的正式畫面合併後就不會再用到。
## 替身的文字用英文:預設字型沒有中文字,正式中文字型由 C 線提供。

const FONT_SIZE: int = 8
const BUTTON_MIN: Vector2 = Vector2(64, 24)     # 觸控目標至少 24×24 邏輯像素
const GAP: int = 4
const BG: Color = Color("2e2138")
const PANEL: Color = Color("3b2f4a")
const ACCENT: Color = Color("f2c14e")


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	return theme


## 把 root 設成全螢幕、套用小字型主題。
static func prepare_root(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = make_theme()


static func add_background(root: Control, color: Color = BG) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	return bg


## 在安全區內置中的一欄。
static func add_column(root: Control) -> VBoxContainer:
	var safe := SafeArea.get_safe_rect()
	var column := VBoxContainer.new()
	column.position = safe.position + Vector2(8, 8)
	column.size = safe.size - Vector2(16, 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", GAP)
	root.add_child(column)
	return column


static func add_label(parent: Control, text: String, color: Color = Color.WHITE, size: int = FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	parent.add_child(label)
	return label


static func add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_MIN
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		Sfx.play(&"ui_tap")
		on_press.call())
	parent.add_child(button)
	return button
