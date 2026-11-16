extends CPUParticles2D
## 一次性粒子特效(DEV_PLAN 4.10)。擁有者:C 線(整合工作階段放了佔位版)。
##
## 合約:assets/fx/particles/<名稱>.tscn 的根節點是 CPUParticles2D,掛這個腳本:
## 加進場景樹就自動噴發一次,結束後自己刪除。使用者只要:
##   var fx := preload("res://assets/fx/particles/hit_burst.tscn").instantiate()
##   fx.global_position = 位置;fx_layer.add_child(fx)
## 用 CPUParticles2D(不是 GPU 版)是為了 Compatibility 算繪器與舊手機。


func _ready() -> void:
	one_shot = true
	emitting = true
	finished.connect(queue_free)
