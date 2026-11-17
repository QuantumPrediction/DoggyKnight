class_name PlayDeadAbility
extends TrickAbility
## 裝死(play_dead,v2.4):每關一次,活力歸零時改為剩 1,先「裝死」倒下一下,再跳起來無敵 2 秒。
## 金毛每關重新建立(場地重建),所以次數每關重算。疊加:每層每關多一次。

var uses_left: int = 0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"play_dead"


func add_stack() -> void:
	super()
	uses_left += 1


func reset() -> void:
	super()
	uses_left = 0


## 活力將要歸零時呼叫。還有次數就用掉一次並傳回 true(金毛改為剩 1 活力)。
func try_save() -> bool:
	if not is_active() or uses_left <= 0:
		return false
	uses_left -= 1
	triggers += 1
	return true
