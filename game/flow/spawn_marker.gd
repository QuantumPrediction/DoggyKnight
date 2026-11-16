class_name SpawnMarker
extends Node2D
## 出場預警記號(BP7):隊形 surround 的敵人冒出來之前,地上先出現這個記號,
## 讓玩家看得出「這裡快要有敵人」,有時間走出包圍。
##
## 樣子:一個脈動的圓圈,中間的圓點由小變大,填滿時敵人就出現(與 A 線的攻擊預警同一個語言:
## 填滿 = 即將發生)。用程式畫,像素不平滑;放在場地的地面層,不會蓋住金毛或攻擊預警。
## 由 WaveSpawner 建立與移除;會被遊戲暫停(跟隨場地)。

const RADIUS: float = 7.0
const RING_COLOR: Color = Color(1.0, 0.42, 0.3, 0.85)
const FILL_COLOR: Color = Color(1.0, 0.42, 0.3, 0.45)

## 由出現到敵人冒出來的秒數。
var duration: float = 0.9
var _elapsed: float = 0.0


func setup(at: Vector2, seconds: float) -> void:
	position = at.round()
	duration = maxf(seconds, 0.01)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


## 0 到 1:填滿的程度。
func progress() -> float:
	return clampf(_elapsed / duration, 0.0, 1.0)


func _draw() -> void:
	var t := progress()
	var pulse := 0.5 + 0.5 * sin(_elapsed * TAU * 4.0)
	var ring := RING_COLOR
	ring.a *= 0.55 + 0.45 * pulse
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, ring, 1.0, false)
	var inner := maxf(1.0, RADIUS * t)
	draw_circle(Vector2.ZERO, inner, FILL_COLOR, true, -1.0, false)
