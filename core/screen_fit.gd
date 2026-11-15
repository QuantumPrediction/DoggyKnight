extends Node
## 畫面適配(Autoload 名稱:ScreenFit)。DEV_PLAN 2、4.8。
##
## Godot 內建的「整數倍放大 + expand」會先按長寬比延伸,再取整數倍,
## 在寬度不是 180 倍數的手機(例如大部分 iPhone)上會四邊都留黑邊。
## 這裡在視窗大小改變時,直接把畫面大小設為「視窗 ÷ 整數倍數」,
## 讓畫面永遠是整數倍放大,而黑邊只剩幾個實體像素。
##
## 結果:畫面寬至少 180、高至少 320 邏輯像素;多出的部分由場地背景填滿。

const BASE_SIZE: Vector2i = Vector2i(180, 320)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_refit)
	_refit()


## 視窗(實體像素)對應的整數放大倍數。
@warning_ignore("integer_division")
static func compute_scale(window_px: Vector2i) -> int:
	return maxi(1, mini(window_px.x / BASE_SIZE.x, window_px.y / BASE_SIZE.y))


## 視窗(實體像素)對應的畫面大小(邏輯像素)。
@warning_ignore("integer_division")
static func compute_viewport_size(window_px: Vector2i) -> Vector2i:
	var scale := compute_scale(window_px)
	return Vector2i(maxi(BASE_SIZE.x, window_px.x / scale), maxi(BASE_SIZE.y, window_px.y / scale))


func _refit() -> void:
	var root := get_tree().root
	var window_px := root.size
	if window_px.x <= 0 or window_px.y <= 0:
		return
	var target := compute_viewport_size(window_px)
	if root.content_scale_size != target:
		root.content_scale_size = target
