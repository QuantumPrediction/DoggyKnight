class_name OneShotFx
extends AnimatedSprite2D
## 播放一次就消失的特效(assets/fx/<名稱>/<名稱>_frames.tres 的 "default" 動畫)。
##
## 不依賴格數:不循環的動畫播完就移除;循環的動畫由 lifetime 決定;
## lifetime < 0 表示一直存在(例如頭上的暈眩星星,由擁有者移除)。

const GROUP: StringName = &"combat_fx"

var lifetime: float = 1.0
var drift: Vector2 = Vector2.ZERO        ## 每秒移動(例如向上飄的魔法煙)
var fade_out: bool = false               ## 最後 40% 的時間逐漸透明

var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if sprite_frames == null or not sprite_frames.has_animation(&"default"):
		queue_free()
		return
	play(&"default")
	if not sprite_frames.get_animation_loop(&"default"):
		animation_finished.connect(queue_free)


func _process(delta: float) -> void:
	_age += delta
	position += drift * delta
	if lifetime < 0.0:
		return
	if fade_out:
		var t := _age / maxf(lifetime, 0.001)
		modulate.a = clampf((1.0 - t) / 0.4, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
