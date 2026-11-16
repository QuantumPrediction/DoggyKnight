extends CanvasLayer
## 畫面轉場:狗掌印擦拭(DEV_PLAN 4.10、CP8)。擁有者:C 線。
##
## 合約:根節點是 CanvasLayer(layer 100),PROCESS_MODE_ALWAYS。B 線在開機時加一次,
## 換畫面時:await transition.cover() → 換場景 → await transition.reveal()。
## cover() 結束時畫面完全被蓋住;reveal() 結束時完全露出。轉場進行中會擋住觸控。
## 兩個方法的 duration 參數一定照做(B 線用 cover(0.12)、reveal(0.3)),動畫長度不會超過它。
##
## 樣子:一排排深紫色的大狗掌印從左上往右下「蓋章」,掌印長大到連成一片蓋住畫面;
## 露出時掌印從同一個方向縮小消失。掌印裡有金色的小肉球,看起來可愛不陰沉。

signal covered
signal revealed

const CELL: float = 34.0
const SPREAD: float = 0.55          # 掌印依位置錯開的比例(0 = 全部同時)
const COLOR_FILL: Color = Color(0.294, 0.184, 0.341, 1.0)     # PaletteColors.PLUM
const COLOR_PAD: Color = Color(0.478, 0.353, 0.6, 1.0)        # PaletteColors.VIOLET

var _wipe: Control
var _progress: float = 0.0       # 0 = 完全露出,1 = 完全蓋住
var _revealing: bool = false
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wipe = Control.new()
	_wipe.name = "Wipe"
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.draw.connect(_draw_wipe)
	add_child(_wipe)


func cover(duration: float = 0.25) -> void:
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_revealing = false
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and duration >= 0.08:
		sfx.call(&"play", &"whoosh", -4.0)
	await _animate(1.0, duration)
	covered.emit()


func reveal(duration: float = 0.25) -> void:
	_revealing = true
	await _animate(0.0, duration)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	revealed.emit()


func is_covered() -> bool:
	return _progress >= 0.999


## 目前的進度(0 至 1,測試用)。
func progress() -> float:
	return _progress


func _animate(target: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		_set_progress(target)
		return
	_tween = create_tween()
	_tween.tween_method(_set_progress, _progress, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	_set_progress(target)


func _set_progress(v: float) -> void:
	_progress = clampf(v, 0.0, 1.0)
	_wipe.queue_redraw()


func _draw_wipe() -> void:
	if _progress <= 0.0:
		return
	var size := _wipe.get_viewport_rect().size
	if _progress >= 0.999:
		_wipe.draw_rect(Rect2(Vector2.ZERO, size), COLOR_FILL)
		return
	var cols := int(ceil(size.x / CELL)) + 2
	var rows := int(ceil(size.y / CELL)) + 2
	var diag := float(cols + rows)
	for r in rows:
		for c in cols:
			var offset := CELL * 0.5 if r % 2 else 0.0
			var center := Vector2(c * CELL - CELL * 0.5 + offset, r * CELL - CELL * 0.5)
			var order := float(c + r) / diag
			# local growth of this paw: 0 = not there, 1 = big enough to touch its neighbours.
			# Covering stamps from the top-left; revealing also starts shrinking at the top-left.
			var lag := (1.0 - order) if _revealing else order
			var local := clampf(_progress * (1.0 + SPREAD) - lag * SPREAD, 0.0, 1.0)
			if local <= 0.0:
				continue
			_draw_paw(center, local)


func _draw_paw(center: Vector2, t: float) -> void:
	# a big pad and four toes; grows past the cell so the paws merge into a solid cover
	var s := CELL * 0.62 * t
	var pad := center + Vector2(0, s * 0.18)
	_wipe.draw_circle(pad.floor(), maxf(1.0, s * 0.62), COLOR_FILL)
	for k in 4:
		var a := deg_to_rad(-150.0 + k * 40.0)
		var toe := pad + Vector2(cos(a), sin(a)) * s * 0.92
		_wipe.draw_circle(toe.floor(), maxf(1.0, s * 0.3), COLOR_FILL)
	if t > 0.25 and t < 0.95:
		_wipe.draw_circle(pad.floor(), maxf(1.0, s * 0.3), COLOR_PAD)
	if t >= 0.9:
		_wipe.draw_rect(Rect2((center - Vector2(CELL, CELL) * 0.75).floor(), Vector2(CELL, CELL) * 1.5), COLOR_FILL)
