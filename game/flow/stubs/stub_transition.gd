extends CanvasLayer
## 轉場的替身。正式版:ui/transition/transition.tscn(C 線)。介面相同(DEV_PLAN 4.10):
##   根節點 CanvasLayer 第 100 層,PROCESS_MODE_ALWAYS;await cover(duration) 之後畫面完全被蓋住,
##   await reveal(duration) 之後完全露出;轉場進行中擋住觸控。

signal covered
signal revealed

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color("2e2138")
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
