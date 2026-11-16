class_name FlowTransition
extends Node
## 畫面轉場的包裝(BP2)。FlowMain 開機時建立一次,換畫面時:
##   await cover() → 換場景 → await reveal()
##
## 轉場畫面本身是 C 線的 ui/transition/transition.tscn(根節點 CanvasLayer 第 100 層,
## 方法 cover(duration) / reveal(duration),可以 await)。檔案不存在時不播轉場(直接切換)。
##
## 保證不會卡住流程:轉場超過「預定秒數 + timeout」仍沒有完成(例如轉場畫面出錯、
## 或被下一次轉場打斷),就當作已完成,流程照常進行。逾時以真實時間計算(不受 time_scale 影響)。

## 轉場畫面(CanvasLayer);null = 沒有轉場。
var screen: Node
var cover_time: float = 0.12
var reveal_time: float = 0.3
var timeout: float = 1.5

## 正在等的轉場步驟數目(0 = 沒有在播)。
var _running: int = 0


## 把轉場畫面加進場景樹(scene 為 null 時不播轉場)。
func setup(scene: PackedScene, curve: DifficultyData) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if curve != null:
		cover_time = curve.transition_cover_time
		reveal_time = curve.transition_reveal_time
		timeout = curve.transition_timeout
	if scene != null:
		screen = scene.instantiate()
		if screen != null:
			screen.name = "Transition"
			add_child(screen)


## 換掉轉場畫面(測試用;傳入 null = 不播轉場)。舊的畫面會被移除。
func use_screen(node: Node) -> void:
	if screen != null and is_instance_valid(screen) and screen != node:
		remove_child(screen)
		screen.queue_free()
	screen = node
	if node != null and node.get_parent() == null:
		add_child(node)


## 有轉場畫面,而且設定了秒數。
func is_active() -> bool:
	return screen != null and is_instance_valid(screen) and (cover_time > 0.0 or reveal_time > 0.0)


func is_running() -> bool:
	return _running > 0


## 蓋住畫面。沒有轉場時立即傳回。
func cover() -> void:
	await _run(&"cover", cover_time)


## 露出畫面。沒有轉場時立即傳回。
func reveal() -> void:
	await _run(&"reveal", reveal_time)


func _run(method: StringName, duration: float) -> void:
	if not is_active() or duration <= 0.0 or not screen.has_method(method):
		return
	var gate := Gate.new()
	_running += 1
	_invoke(method, duration, gate)
	if not gate.done:
		var timer := get_tree().create_timer(duration + maxf(timeout, 0.05), true, false, true)
		timer.timeout.connect(gate.finish)
		await gate.finished
	_running -= 1


func _invoke(method: StringName, duration: float, gate: Gate) -> void:
	if screen.get_method_argument_count(method) >= 1:
		await screen.call(method, duration)
	else:
		await screen.call(method)
	gate.finish()


## 一次轉場步驟:轉場完成或逾時,先到的那個觸發 finished(只觸發一次)。
class Gate:
	extends RefCounted
	signal finished
	var done: bool = false

	func finish() -> void:
		if done:
			return
		done = true
		finished.emit()
