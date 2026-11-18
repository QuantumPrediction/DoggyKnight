extends "res://game/flow/stubs/stub_dialogue_box.gd"
## BW4 的測試替身(檔名不是 test_*,測試執行器不會把它當成測試):和替身對白框一樣,
## 但播完之後像 C 線的正式對白框(ui/dialogue/dialogue_box.gd)那樣,先淡出 fade_sec 秒才隱藏。
## 正式對白框在發 finished 之前就開始淡出,所以 finished 之後的那幾格對白框仍然看得見(第 40 層,
## 在結算畫面的第 30 層之上)。

## 淡出秒數(正式對白框是 0.18 秒;這裡長一點,測試才看得出次序)。
var fade_sec: float = 0.3

var _fade: Tween


func play(script: DialogueScript) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_root.modulate.a = 1.0
	await super.play(script)


## 播完了、但還在淡出(看得見)嗎。
func is_fading() -> bool:
	return not _active and _root.visible and _root.modulate.a > 0.0


func _finish() -> void:
	_active = false
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_root, "modulate:a", 0.0, fade_sec)
	_fade.tween_callback(_hide_when_idle)
	var id := _script.id
	GameState.story_seen[id] = true
	EventBus.dialogue_finished.emit(id)
	finished.emit()


func _hide_when_idle() -> void:
	if not _active:
		_root.visible = false
