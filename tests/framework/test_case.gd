class_name TestCase
extends Node
## 所有自動化測試的基底(擁有者:Phase 0 / 整合)。
##
## 寫法:
## - 檔名用 test_*.gd,放在 tests/ 之下(例如 tests/line_a/test_damage.gd)。
## - extends TestCase;每個以 test_ 開頭的方法就是一個測試,可以使用 await。
## - 需要每個測試前後重設狀態時,覆寫 before_each() / after_each()。
## - 範例見 tests/core/test_example.gd。
## 執行:tools/run_tests.sh(全部)或 tools/run_tests.sh line_a(只跑路徑含 line_a 的檔案)。

var _failures: PackedStringArray = []
var _watchers: Array[SignalWatcher] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _equal(actual, expected):
		_fail("expected %s, got %s" % [var_to_str(expected), var_to_str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _equal(actual, unexpected):
		_fail("did not expect %s" % var_to_str(unexpected), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s" % [expected, tolerance, actual], message)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_fail("expected a value, got null", message)


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		_fail("expected null, got %s" % var_to_str(value), message)


## 開始記錄某個訊號被發出的次數與參數。測試結束時自動停止記錄。
func watch_signal(sig: Signal) -> SignalWatcher:
	var watcher := SignalWatcher.new(sig)
	_watchers.append(watcher)
	return watcher


## 等待若干個畫面格。
func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


# --- 以下由 tests/framework/test_runner.gd 使用 ---

func _begin_test() -> void:
	_failures.clear()


func _end_test() -> PackedStringArray:
	for watcher in _watchers:
		watcher.stop()
	_watchers.clear()
	return _failures.duplicate()


func _fail(reason: String, message: String) -> void:
	_failures.append(reason if message.is_empty() else "%s: %s" % [message, reason])


static func _equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta != tb:
		var numeric := [TYPE_INT, TYPE_FLOAT]
		var text := [TYPE_STRING, TYPE_STRING_NAME]
		if not ((ta in numeric and tb in numeric) or (ta in text and tb in text)):
			return false
	return a == b
