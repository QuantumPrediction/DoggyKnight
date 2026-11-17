class_name PounceAbility
extends TrickAbility
## 撲擊(pounce,v2.4):停下要攻擊時,若最近的敵人在 60 像素內(但不在身邊),先撲過去再揮劍。
## 能力只決定「撲不撲」與數值;撲過去的動作由金毛做(player.gd 的 _begin_pounce)。
## 疊加:範圍每層 +8,冷卻每層 ×0.85(最短 0.8 秒)。

var cooldown_left: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"pounce"


func reset() -> void:
	super()
	cooldown_left = 0.0


## 撲擊範圍(到敵人身體邊緣的距離)。
func reach() -> float:
	return tuning.pounce_range + tuning.pounce_range_per_stack * float(maxi(0, stacks - 1))


func cooldown() -> float:
	return maxf(tuning.pounce_cooldown_min,
			tuning.pounce_cooldown * pow(tuning.pounce_cooldown_stack_mult, maxi(0, stacks - 1)))


func dash_time() -> float:
	return tuning.pounce_time


func hop_height() -> float:
	return tuning.pounce_hop_height


func is_ready() -> bool:
	return is_active() and cooldown_left <= 0.0


func update(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)


## distance:到敵人身體邊緣的距離。要撲時傳回 true,並開始冷卻。
func try_pounce(distance: float) -> bool:
	if not is_ready() or distance < tuning.pounce_min_distance or distance > reach():
		return false
	cooldown_left = cooldown()
	triggers += 1
	return true


## 撲完落地(金毛已在落點)。流星撲擊在這裡造成衝擊。
func on_land() -> void:
	pass
