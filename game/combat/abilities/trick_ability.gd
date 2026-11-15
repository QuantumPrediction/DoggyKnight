class_name TrickAbility
extends RefCounted
## 能力類把戲的共同基底(A10)。
##
## 能力不直接碰場景,只透過「宿主」(金毛,或測試用的替身)的這幾個方法:
##   ability_targets(radius: float) -> Array[Node2D]   範圍內可以打的敵人
##   ability_base_damage(multiplier: float) -> int      已套用 next_level_bonus 的傷害
##   ability_hit(target: Node2D, damage: int, knockback: float) -> void
##   ability_stun(target: Node2D, duration: float) -> void
##   ability_visual(kind: StringName, radius: float) -> void
## 時間由宿主每個物理格呼叫 update(delta) 推進,所以測試可以用模擬時間。

var id: StringName
var stacks: int = 0              ## 選了幾次(0 = 未啟用)
var triggers: int = 0            ## 觸發了幾次(給測試與除錯用)
var host: Object
var tuning: AbilityTuning


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	host = p_host
	tuning = p_tuning


func is_active() -> bool:
	return stacks > 0


func add_stack() -> void:
	stacks += 1


func reset() -> void:
	stacks = 0
	triggers = 0


## 每個物理格呼叫。
func update(_delta: float) -> void:
	pass


## 金毛的一次揮劍打中了至少一隻敵人。傳回這一下的傷害倍數。
func on_swing_landed() -> float:
	return 1.0


func _targets(radius: float) -> Array:
	return host.call(&"ability_targets", radius)
