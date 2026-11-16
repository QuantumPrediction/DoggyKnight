extends Control
## 暫停畫面的替身。正式版:ui/pause/pause.tscn(C 線)。
## 聽 EventBus.game_paused;按鈕發 resume_requested、quit_to_title_requested;
## 音效、音樂、震動開關直接改 GameState.sound_on / music_on / haptics_on(音樂改了之後呼叫
## Music.refresh(),DEV_PLAN 4.10);B 線在「繼續」時存檔。根節點 PROCESS_MODE_ALWAYS。

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")

var _sound_button: Button
var _music_button: Button
var _haptics_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color(0, 0, 0, 0.6))
	var column := StubUI.add_column(self)
	StubUI.add_label(column, "PAUSED", StubUI.ACCENT, 16)
	StubUI.add_button(column, "Resume", EventBus.resume_requested.emit)
	_sound_button = StubUI.add_button(column, "", _toggle_sound)
	_music_button = StubUI.add_button(column, "", _toggle_music)
	_haptics_button = StubUI.add_button(column, "", _toggle_haptics)
	StubUI.add_button(column, "Title", EventBus.quit_to_title_requested.emit)
	_update_sound_text()
	visible = false
	EventBus.game_paused.connect(_on_game_paused)


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)


func _on_game_paused(paused: bool) -> void:
	visible = paused
	_update_sound_text()


func _toggle_sound() -> void:
	GameState.sound_on = not GameState.sound_on
	_update_sound_text()


func _toggle_music() -> void:
	GameState.music_on = not GameState.music_on
	var music := get_node_or_null(^"/root/Music")
	if music != null and music.has_method(&"refresh"):
		music.call(&"refresh")
	_update_sound_text()


func _toggle_haptics() -> void:
	GameState.haptics_on = not GameState.haptics_on
	_update_sound_text()


func _update_sound_text() -> void:
	_sound_button.text = "Sound: ON" if GameState.sound_on else "Sound: OFF"
	_music_button.text = "Music: ON" if GameState.music_on else "Music: OFF"
	_haptics_button.text = "Vibrate: ON" if GameState.haptics_on else "Vibrate: OFF"
