extends Node
## 手機生命週期(Autoload 名稱:AppLifecycle)。DEV_PLAN 4.8。
##
## 把作業系統的通知轉成 EventBus 的三個訊號:
## - app_backgrounded:切到背景、來電、鎖螢幕、拉下通知欄
## - app_foregrounded:回到遊戲
## - back_requested:Android 返回鍵或返回手勢;桌面測試時按 Esc(輸入動作 "back")
##
## 重要:收到 app_backgrounded 的程式要「立即」完成存檔,不要用 await。
## iOS 與 Android 在 App 進入背景後,只給很短的時間就可能把它停掉。
##
## 測試或沙盒場景要模擬這些事件時,呼叫 simulate_background()、
## simulate_foreground()、simulate_back()。

var _in_background: bool = false


func _ready() -> void:
	# 遊戲暫停時仍要收到系統通知與返回鍵。
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_set_background(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_background(false)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			EventBus.back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		get_viewport().set_input_as_handled()
		EventBus.back_requested.emit()


func is_in_background() -> bool:
	return _in_background


func simulate_background() -> void:
	_set_background(true)


func simulate_foreground() -> void:
	_set_background(false)


func simulate_back() -> void:
	EventBus.back_requested.emit()


# 手機切到背景時,系統常會連續送出「失去焦點」與「暫停」兩個通知;
# 這裡只在狀態真的改變時發一次訊號。
func _set_background(value: bool) -> void:
	if value == _in_background:
		return
	_in_background = value
	if value:
		EventBus.app_backgrounded.emit()
	else:
		EventBus.app_foregrounded.emit()
