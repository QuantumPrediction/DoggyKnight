class_name SafeArea
extends RefCounted
## 螢幕與安全區工具。DEV_PLAN 2、4.8。
##
## 座標系統(所有線共用):
## - 邏輯像素:遊戲畫面的像素,不是手機的實體像素。
## - 遊戲區固定 180×320(GAME_SIZE)。較長或較寬的手機會向外延伸,
##   畫面(root viewport)可能是 180×400、196×426 之類。
## - 遊戲世界:遊戲區佔世界座標 (0,0) 至 (180,320)。場景用 Camera2D 把
##   視角中心放在 GAME_CENTER,遊戲區就會置中,延伸出來的地方顯示場地背景。
## - 介面(CanvasLayer 內的 Control):用 get_safe_rect() 排列,避開瀏海、挖孔、
##   圓角與 iOS 底部橫條。

const GAME_SIZE: Vector2 = Vector2(180, 320)
const GAME_CENTER: Vector2 = GAME_SIZE * 0.5

## 桌面測試用:開啟後,get_safe_rect() 會假裝頂部有瀏海、底部有橫條。
static var simulate_notch: bool = false
const SIMULATED_TOP_INSET: float = 24.0
const SIMULATED_BOTTOM_INSET: float = 10.0


## 目前畫面的大小(邏輯像素),包含延伸出來的部分。
static func get_screen_size() -> Vector2:
	var root := _root()
	if root == null:
		return GAME_SIZE
	return root.get_visible_rect().size


## 安全區(以畫面的邏輯像素表示,原點在畫面左上角)。介面元件應放在這個範圍內。
## 桌面上傳回整個畫面;開啟 simulate_notch 時扣掉模擬的瀏海與底部橫條。
static func get_safe_rect() -> Rect2:
	var screen := Rect2(Vector2.ZERO, get_screen_size())
	var rect := screen
	if OS.has_feature("mobile"):
		var safe_px := Rect2(DisplayServer.get_display_safe_area())
		var window_px := Vector2(DisplayServer.window_get_size())
		rect = screen_to_logical(safe_px, window_px, screen.size)
	if simulate_notch:
		var inset := Rect2(
			Vector2(0, SIMULATED_TOP_INSET),
			screen.size - Vector2(0, SIMULATED_TOP_INSET + SIMULATED_BOTTOM_INSET))
		rect = rect.intersection(inset)
	return rect


## 遊戲區在畫面上的位置(邏輯像素)。延伸的畫面中,遊戲區永遠置中。
static func get_game_rect() -> Rect2:
	var screen_size := get_screen_size()
	return Rect2(((screen_size - GAME_SIZE) * 0.5).floor(), GAME_SIZE)


## 把實體像素的矩形換算成邏輯像素。
## window_px:視窗的實體像素大小;logical_size:畫面的邏輯像素大小。
## 依照專案設定的整數倍放大與置中計算。
static func screen_to_logical(rect_px: Rect2, window_px: Vector2, logical_size: Vector2) -> Rect2:
	var scale := maxf(1.0, floorf(minf(window_px.x / logical_size.x, window_px.y / logical_size.y)))
	var offset := (window_px - logical_size * scale) * 0.5
	var top_left := (rect_px.position - offset) / scale
	var bottom_right := (rect_px.end - offset) / scale
	var result := Rect2(top_left, bottom_right - top_left)
	return result.intersection(Rect2(Vector2.ZERO, logical_size))


static func _root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null
