extends Control
## 標題畫面(C10,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(has_save: bool);訊號 new_game_pressed、continue_pressed、credits_pressed。
## 「繼續冒險」只在有存檔時出現。

signal new_game_pressed
signal continue_pressed
signal credits_pressed

var continue_button: Button
var new_game_button: Button
var credits_button: Button

var _has_save: bool = false
var _backdrop: TextureRect
var _logo: TextureRect
var _subtitle: Label
var _goldie: Control
var _buttons: VBoxContainer
var _version: Label


func _ready() -> void:
	UiKit.setup_root(self)
	_backdrop = UiKit.backdrop(preload("res://assets/ui/title_bg.png"))
	add_child(_backdrop)
	_logo = UiKit.texture_rect(preload("res://assets/ui/logo_2x.png"))
	_logo.name = "Logo"
	add_child(_logo)
	_subtitle = UiKit.label(tr("CHAPTER_1"), &"LabelLight")
	add_child(_subtitle)
	_goldie = UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", &"idle", 3)
	_goldie.name = "Goldie"
	add_child(_goldie)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", int(UiKit.GAP))
	add_child(_buttons)
	continue_button = UiKit.button(tr("UI_CONTINUE"))
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_buttons.add_child(continue_button)
	new_game_button = UiKit.button(tr("UI_NEW_GAME"))
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(func() -> void: new_game_pressed.emit())
	_buttons.add_child(new_game_button)
	credits_button = UiKit.button(tr("UI_CREDITS"), &"ButtonAlt")
	credits_button.name = "CreditsButton"
	credits_button.pressed.connect(func() -> void: credits_pressed.emit())
	_buttons.add_child(credits_button)

	_version = UiKit.label(tr("UI_VERSION") % ProjectSettings.get_setting("application/config/version", "0.1.0"),
			&"LabelLight", HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_version)

	_apply_save_state()
	get_viewport().size_changed.connect(_layout)
	_layout()


## 由 B 線呼叫:有存檔時顯示「繼續冒險」。可在加入場景前或後呼叫。
func setup(has_save: bool) -> void:
	_has_save = has_save
	if is_node_ready():
		_apply_save_state()
		_layout()


func _apply_save_state() -> void:
	continue_button.visible = _has_save
	# 有存檔時「繼續」是主要按鈕(金色),「開始冒險」改為次要(藍色)。
	new_game_button.theme_type_variation = &"ButtonAlt" if _has_save else &""


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	var screen := SafeArea.get_screen_size()
	UiKit.place_backdrop(_backdrop)
	var cx := safe.get_center().x
	_logo.position = Vector2(floorf(cx - _logo.size.x * 0.5), floorf(safe.position.y + 44.0))
	_subtitle.size = _subtitle.get_minimum_size()
	_subtitle.position = Vector2(floorf(cx - _subtitle.size.x * 0.5), _logo.position.y + _logo.size.y + 4.0)
	_buttons.size = _buttons.get_minimum_size()
	var bottom := minf(safe.end.y, screen.y) - 24.0
	_buttons.position = Vector2(floorf(cx - _buttons.size.x * 0.5), floorf(bottom - _buttons.size.y))
	# 金毛站在石中劍旁邊(背景圖中心 = 畫面中心;石頭在中心偏下)
	var center := (screen * 0.5).floor()
	_goldie.position = center + Vector2(-60, -22)
	_goldie.position.y = minf(_goldie.position.y, _buttons.position.y - _goldie.size.y - 2.0)
	_version.size = _version.get_minimum_size()
	_version.position = Vector2(floorf(safe.end.x - _version.size.x - 4.0), floorf(minf(safe.end.y, screen.y) - _version.size.y - 2.0))
