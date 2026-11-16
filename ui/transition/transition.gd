extends CanvasLayer
## 畫面轉場(DEV_PLAN 4.10)。擁有者:C 線(整合工作階段放了這個淡入淡出初版,C 線原地替換成更好看的轉場)。
##
## 合約:根節點是 CanvasLayer(layer 100),PROCESS_MODE_ALWAYS。B 線在開機時加一次,
## 換畫面時:await transition.cover() → 換場景 → await transition.reveal()。
## cover() 結束時畫面完全被蓋住;reveal() 結束時完全露出。轉場進行中會擋住觸控。

signal covered
signal revealed

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.1, 0.07, 0.14, 1.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func cover(duration: float = 0.25) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animate(1.0, duration)
	covered.emit()


func reveal(duration: float = 0.25) -> void:
	await _animate(0.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	revealed.emit()


func is_covered() -> bool:
	return _rect.modulate.a >= 0.999


func _animate(alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", alpha, maxf(duration, 0.01))
	await _tween.finished
