class_name SignalWatcher
extends RefCounted
## 記錄訊號被發出的次數與每次的參數。用 TestCase.watch_signal() 建立。
##
##   var w := watch_signal(EventBus.enemy_died)
##   ...觸發...
##   assert_eq(w.count, 1)
##   assert_eq(w.last_args()[0], &"scarecrow")

var count: int = 0
var calls: Array[Array] = []
var _signal: Signal
var _callable: Callable


func _init(sig: Signal) -> void:
	_signal = sig
	match _arg_count(sig):
		0: _callable = _on_0
		1: _callable = _on_1
		2: _callable = _on_2
		3: _callable = _on_3
		4: _callable = _on_4
		_: push_error("SignalWatcher supports up to 4 arguments: %s" % sig.get_name())
	if _callable.is_valid():
		sig.connect(_callable)


func last_args() -> Array:
	return calls.back() if not calls.is_empty() else []


func stop() -> void:
	if _callable.is_valid() and _signal.is_connected(_callable):
		_signal.disconnect(_callable)


func _record(args: Array) -> void:
	count += 1
	calls.append(args)


func _on_0() -> void:
	_record([])


func _on_1(a: Variant) -> void:
	_record([a])


func _on_2(a: Variant, b: Variant) -> void:
	_record([a, b])


func _on_3(a: Variant, b: Variant, c: Variant) -> void:
	_record([a, b, c])


func _on_4(a: Variant, b: Variant, c: Variant, d: Variant) -> void:
	_record([a, b, c, d])


static func _arg_count(sig: Signal) -> int:
	var owner := sig.get_object()
	for info: Dictionary in owner.get_signal_list():
		if info["name"] == sig.get_name():
			return (info["args"] as Array).size()
	return 0
