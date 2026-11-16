extends Sprite2D
## 雨幕(C 線,v2.3 CS5):一張可重複的斜雨紋理,不停往左下捲動,做出大雨一陣一陣的層次。
## 只用在暴風雨夜的石橋;在戰鬥區上方的那層很淡,前景那層只放在戰鬥區外面。

@export var speed: Vector2 = Vector2(-60, 220)
@export var gust_alpha: float = 0.15       ## 一陣一陣:透明度隨時間起伏的幅度
@export var gust_speed: float = 0.7

var _offset: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _base_alpha: float = 1.0


func _ready() -> void:
	_base_alpha = modulate.a


func _process(delta: float) -> void:
	_t += delta
	_offset -= speed * delta
	var size := texture.get_size() if texture != null else Vector2(64, 64)
	_offset = Vector2(fposmod(_offset.x, size.x), fposmod(_offset.y, size.y))
	region_rect.position = _offset.floor()
	modulate.a = clampf(_base_alpha * (1.0 + gust_alpha * sin(_t * gust_speed * TAU)), 0.0, 1.0)
