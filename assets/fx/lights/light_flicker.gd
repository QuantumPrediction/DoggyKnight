extends Sprite2D
## 光暈精靈(C 線,v2.3 CS5):加亮混合(Add)的柔光圖,便宜又不用 Light2D。
## 火把、營火會閃爍;魔法、眼睛、劍會慢慢呼吸。所有數值都可以在場景裡調。
##
## 其他線使用:把 assets/fx/lights/<名稱>.tscn 加成角色或場景的子節點即可
## (torch、campfire、magic、eye_violet、visor_blue、sword、ultimate)。

@export var base_alpha: float = 0.5
@export var flicker: float = 0.25          ## 閃爍幅度(0 = 不閃)
@export var flicker_speed: float = 9.0
@export var breathe: float = 0.0           ## 慢慢放大縮小的幅度(比例)
@export var breathe_speed: float = 2.0
@export var seed_offset: float = 0.0

var _t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_scale = scale
	_t = seed_offset
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_apply()


func _apply() -> void:
	var n := sin(_t * flicker_speed) * 0.5 + sin(_t * flicker_speed * 2.37 + 1.3) * 0.3 + sin(_t * flicker_speed * 0.61 + 4.0) * 0.2
	modulate.a = clampf(base_alpha * (1.0 + flicker * n), 0.0, 1.0)
	if breathe > 0.0:
		scale = _base_scale * (1.0 + breathe * sin(_t * breathe_speed))
