class_name ShakeAbility
extends TrickAbility
## 握手(shake):每第 4 下「打中敵人的」攻擊造成雙倍傷害。揮空不算。
## 疊加:每多一層,間隔減 1(最少 2 下);到最少之後每多一層倍數 +0.5。

var swings_landed: int = 0       ## 啟用後打中的揮劍次數
var _since_trigger: int = 0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"shake"


func reset() -> void:
	super()
	swings_landed = 0
	_since_trigger = 0


## 距離下一次雙倍還差幾下(1 = 下一下就是雙倍)。給介面或除錯用。
func swings_until_trigger() -> int:
	return maxi(1, interval() - _since_trigger)


func interval() -> int:
	return maxi(tuning.shake_every_min, tuning.shake_every - (stacks - 1))


func multiplier() -> float:
	var reductions_used := tuning.shake_every - tuning.shake_every_min
	var extra := maxi(0, stacks - 1 - reductions_used)
	return tuning.shake_multiplier + tuning.shake_multiplier_per_extra_stack * float(extra)


func on_swing_landed() -> float:
	if not is_active():
		return 1.0
	swings_landed += 1
	_since_trigger += 1
	if _since_trigger >= interval():
		_since_trigger = 0
		triggers += 1
		return multiplier()
	return 1.0
