extends Control
## 暫停選單(C10,DEV_PLAN 4.4、4.9)。B 線把它放在第 20 層 CanvasLayer。
##
## 聽 EventBus.game_paused(paused) 決定顯示或隱藏。
## 按鈕:繼續 → EventBus.resume_requested;回標題 → EventBus.quit_to_title_requested;
## 音效開關 → 直接切換 GameState.sound_on(B 線存檔時會一併保存)。

var resume_button: Button
var sound_button: Button
var title_button: Button
var _panel: PanelContainer


func _ready() -> void:
	UiKit.setup_root(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dim())
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", int(UiKit.GAP))
	_panel.add_child(box)
	var title := UiKit.label(tr("UI_PAUSED"), &"LabelTitle")
	title.custom_minimum_size = Vector2(0, 30)
	box.add_child(title)
	resume_button = UiKit.button(tr("UI_RESUME"))
	resume_button.name = "ResumeButton"
	resume_button.pressed.connect(func() -> void: EventBus.resume_requested.emit())
	box.add_child(resume_button)
	sound_button = UiKit.button("", &"ButtonAlt")
	sound_button.name = "SoundButton"
	sound_button.pressed.connect(toggle_sound)
	box.add_child(sound_button)
	title_button = UiKit.button(tr("UI_BACK_TO_TITLE"), &"ButtonAlt")
	title_button.name = "TitleButton"
	title_button.pressed.connect(func() -> void: EventBus.quit_to_title_requested.emit())
	box.add_child(title_button)
	_refresh_sound()
	visible = false
	EventBus.game_paused.connect(_on_game_paused)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _on_game_paused(paused: bool) -> void:
	visible = paused
	if paused:
		_refresh_sound()
		_layout()
		_panel.scale = Vector2(0.9, 0.9)
		_panel.pivot_offset = _panel.size * 0.5
		var t := create_tween()
		t.tween_property(_panel, "scale", Vector2.ONE, 0.1)


## 音效開關:切換 GameState.sound_on 並更新按鈕文字。
func toggle_sound() -> void:
	GameState.sound_on = not GameState.sound_on
	if not GameState.sound_on:
		Sfx.stop_all()
	_refresh_sound()


func _refresh_sound() -> void:
	sound_button.text = tr("UI_SOUND_ON") if GameState.sound_on else tr("UI_SOUND_OFF")
	sound_button.icon = preload("res://assets/ui/icon_sound_on.png") if GameState.sound_on else preload("res://assets/ui/icon_sound_off.png")


func _process(_delta: float) -> void:
	if visible:
		_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_panel.size = _panel.get_minimum_size()
	_panel.position = UiKit.center_in(safe, _panel.size)
