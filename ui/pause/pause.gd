extends Control
## 暫停選單(C10,DEV_PLAN 4.4、4.9)。B 線把它放在第 20 層 CanvasLayer。
##
## 聽 EventBus.game_paused(paused) 決定顯示或隱藏。
## 按鈕:繼續 → EventBus.resume_requested;回標題 → EventBus.quit_to_title_requested;
## 音效開關 → 直接切換 GameState.sound_on;音樂開關 → GameState.music_on 並呼叫 Music.refresh();
## 震動開關 → GameState.haptics_on(B 線存檔時一併保存)。每個按鈕都有按鍵音與輕震。

var resume_button: Button
var sound_button: Button
var music_button: Button
var haptics_button: Button
var title_button: Button
var lesson_button: Button
var _panel: PanelContainer


func _ready() -> void:
	UiKit.setup_root(self)
	# 根節點不攔觸控;打開時由半透明底色(dim)擋住後面的點擊,隱藏時完全不影響 A 線的搖桿。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.dim())
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_panel.add_child(box)
	var title := UiKit.label(tr("UI_PAUSED"), &"LabelTitle")
	title.add_theme_color_override(&"font_color", Color("302b24"))
	title.add_theme_font_size_override("font_size", 20)
	title.custom_minimum_size = Vector2(0, 28)
	box.add_child(title)
	if UiKit.uses_keyboard_hints():
		var controls := UiKit.label(tr("UI_DESKTOP_CONTROLS"), &"LabelSoft")
		controls.add_theme_font_size_override("font_size", 10)
		box.add_child(controls)
	var guard_help := UiKit.label(tr("UI_GUARD_PAUSE_HELP"), &"LabelSoft")
	guard_help.add_theme_font_size_override("font_size", 7)
	box.add_child(guard_help)
	lesson_button = UiKit.button(tr("UI_GUARD_LESSON_REPLAY"), &"ButtonAlt", Vector2(130, 20))
	lesson_button.name = "GuardLessonButton"
	lesson_button.visible = false
	lesson_button.pressed.connect(_replay_lesson)
	box.add_child(lesson_button)
	EventBus.companion_guard_state.connect(_on_guard_state)
	EventBus.companion_guard_status_requested.emit()
	resume_button = UiKit.button(tr("UI_RESUME"))
	resume_button.name = "ResumeButton"
	resume_button.pressed.connect(func() -> void: EventBus.resume_requested.emit())
	box.add_child(resume_button)
	sound_button = UiKit.button("", &"ButtonAlt")
	sound_button.name = "SoundButton"
	sound_button.pressed.connect(toggle_sound)
	box.add_child(sound_button)
	music_button = UiKit.button("", &"ButtonAlt")
	music_button.name = "MusicButton"
	music_button.pressed.connect(toggle_music)
	box.add_child(music_button)
	haptics_button = UiKit.button("", &"ButtonAlt")
	haptics_button.name = "HapticsButton"
	haptics_button.pressed.connect(toggle_haptics)
	box.add_child(haptics_button)
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
		# Desktop accept should resume, including after back-to-title was focused.
		if UiKit.uses_keyboard_hints():
			resume_button.grab_focus()
		_panel.scale = Vector2(0.85, 0.85)
		_panel.pivot_offset = _panel.size * 0.5
		var t := create_tween()
		t.tween_property(_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 音效開關:切換 GameState.sound_on 並更新按鈕文字。
func toggle_sound() -> void:
	GameState.sound_on = not GameState.sound_on
	if not GameState.sound_on:
		Sfx.stop_all()
	_refresh_sound()


## 音樂開關:切換 GameState.music_on,並請 Music 立刻跟著停止或重新播放。
func toggle_music() -> void:
	GameState.music_on = not GameState.music_on
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.call(&"refresh")
	_refresh_sound()


## 震動開關:切換 GameState.haptics_on(打開時輕震一下,讓玩家知道有效)。
func toggle_haptics() -> void:
	GameState.haptics_on = not GameState.haptics_on
	if GameState.haptics_on:
		Haptics.play(&"light")
	_refresh_sound()


func _refresh_sound() -> void:
	sound_button.text = tr("UI_SOUND_ON") if GameState.sound_on else tr("UI_SOUND_OFF")
	sound_button.icon = StoryArt.ui_icon("icon_sound_on")
	sound_button.expand_icon = true
	sound_button.add_theme_constant_override(&"icon_max_width", 10)
	sound_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	music_button.text = tr("UI_MUSIC_ON") if GameState.music_on else tr("UI_MUSIC_OFF")
	music_button.icon = StoryArt.ui_icon("icon_music_on")
	music_button.expand_icon = true
	music_button.add_theme_constant_override(&"icon_max_width", 10)
	music_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	haptics_button.text = tr("UI_HAPTICS_ON") if GameState.haptics_on else tr("UI_HAPTICS_OFF")
	haptics_button.icon = StoryArt.ui_icon("icon_vibrate_on")
	haptics_button.expand_icon = true
	haptics_button.add_theme_constant_override(&"icon_max_width", 10)
	haptics_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(_delta: float) -> void:
	if visible:
		_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_panel.size = _panel.get_minimum_size()
	_panel.position = UiKit.center_in(safe, _panel.size)


func _on_guard_state(value: StringName, _cooldown: float, _duration: float) -> void:
	lesson_button.visible = value != &"unavailable" and GameState.mode != &"endless"


func _replay_lesson() -> void:
	EventBus.resume_requested.emit()
	EventBus.guard_lesson_requested.emit()
