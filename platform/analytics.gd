class_name PlatformAnalytics
extends Node
## 分析服務的介面(DEV_PLAN 4.8、11 D7)。
##
## 原型:空實作。事件只在除錯版印出,不儲存、不上傳、不讀取任何裝置識別碼。
## 調整難度用的資料改由本機的遊玩記錄(platform/play_log.gd)保存,不離開手機。
## 日後接真實的分析 SDK 之前必讀 platform/README.md。

const ENABLED: bool = false

var _consent: bool = false


func is_available() -> bool:
	return ENABLED


## 玩家是否同意分析(接真實服務時,未同意前不得送出任何事件)。
func set_consent(granted: bool) -> void:
	_consent = granted
	PlatformLog.note("analytics", "set_consent(%s) — no-op" % granted)


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	PlatformLog.note("analytics", "log_event(%s, %s) — no-op" % [event_name, params])
