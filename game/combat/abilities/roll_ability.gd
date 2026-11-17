class_name RollAbility
extends TrickAbility
## 打滾(roll,v2.4):開始移動時翻滾 0.3 秒,期間無敵、稍微加速(冷卻 3 秒)。
## 金毛在「由停下變成移動」的那一格呼叫 try_roll()。
## 疊加:冷卻每層 ×0.8(最短 1.5 秒),翻滾時間每層 +0.05 秒。

var cooldown_left: float = 0.0
var roll_left: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"roll"


func reset() -> void:
	super()
	cooldown_left = 0.0
	roll_left = 0.0


func cooldown() -> float:
	return maxf(tuning.roll_cooldown_min,
			tuning.roll_cooldown * pow(tuning.roll_cooldown_stack_mult, maxi(0, stacks - 1)))


func roll_time() -> float:
	return tuning.roll_time + tuning.roll_time_per_stack * float(maxi(0, stacks - 1))


func update(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	roll_left = maxf(0.0, roll_left - delta)


## 開始移動時呼叫。要翻滾時傳回 true。
func try_roll() -> bool:
	if not is_active() or cooldown_left > 0.0:
		return false
	roll_left = roll_time()
	cooldown_left = cooldown()
	triggers += 1
	return true


func is_rolling() -> bool:
	return roll_left > 0.0


func is_invulnerable() -> bool:
	return roll_left > 0.0


func speed_mult() -> float:
	return tuning.roll_speed_mult if roll_left > 0.0 else 1.0
