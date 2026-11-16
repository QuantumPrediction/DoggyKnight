class_name Haptics
extends RefCounted
## 震動回饋(DEV_PLAN 4.10)。任何線呼叫:Haptics.play(&"light") / (&"medium") / (&"heavy")。
##
## 只在手機上真的震動;遵守 GameState.haptics_on;同一時間連續呼叫會被合併(避免手機一直嗡嗡響)。
## Android 需要匯出設定的 VIBRATE 權限(D 線)。iOS 不需要權限。
## 建議用法:light = 介面輕觸、拾取;medium = 金毛被擊中、升級;heavy = 必殺技、頭目重劈、打倒頭目。

const DURATION_MS: Dictionary = {&"light": 12, &"medium": 28, &"heavy": 55}
const AMPLITUDE: Dictionary = {&"light": 0.3, &"medium": 0.6, &"heavy": 1.0}
const MIN_INTERVAL_MS: int = 60

## 測試用:記錄最後一次有效的震動與次數(桌面上不會真的震動)。
static var last_kind: StringName = &""
static var play_count: int = 0
static var _last_ms: int = -100000


static func play(kind: StringName) -> void:
	if not GameState.haptics_on:
		return
	if not DURATION_MS.has(kind):
		push_warning("Haptics: unknown kind %s" % kind)
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_INTERVAL_MS:
		return
	_last_ms = now
	last_kind = kind
	play_count += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(DURATION_MS[kind]), float(AMPLITUDE[kind]))


## 測試用:清除合併計時,讓下一次呼叫一定有效。
static func reset_for_tests() -> void:
	_last_ms = -100000
	last_kind = &""
	play_count = 0
