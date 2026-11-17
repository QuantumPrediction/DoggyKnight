class_name ZoomiesAbility
extends TrickAbility
## 暴衝(zoomies,v2.4):打倒敵人後 2 秒移動速度 +30%(再打倒會重新計時)。
## 速度乘在金毛目前的速度上,不改 GameState.player_stats。
## 疊加:每層速度 +10%、時間 +0.5 秒。

var boost_left: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"zoomies"


func reset() -> void:
	super()
	boost_left = 0.0


func duration() -> float:
	return tuning.zoomies_time + tuning.zoomies_time_per_stack * float(maxi(0, stacks - 1))


func bonus() -> float:
	return tuning.zoomies_speed_bonus + tuning.zoomies_speed_per_stack * float(maxi(0, stacks - 1))


func update(delta: float) -> void:
	boost_left = maxf(0.0, boost_left - delta)


func on_kill() -> void:
	if not is_active():
		return
	if boost_left <= 0.0:
		triggers += 1
	boost_left = duration()


func is_boosting() -> bool:
	return boost_left > 0.0


func speed_mult() -> float:
	return 1.0 + bonus() if boost_left > 0.0 else 1.0
