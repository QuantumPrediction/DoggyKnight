class_name SpinAbility
extends TrickAbility
## 轉圈(spin):每 6 秒一次迴旋斬,打中周圍所有敵人。
## 冷卻好了但附近沒有敵人時會「等著」,一有敵人靠近就立刻轉。
## 疊加:冷卻每層 ×0.8(最短 2.5 秒),半徑每層 +6。

var timer: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"spin"


func reset() -> void:
	super()
	timer = 0.0


func cooldown() -> float:
	return maxf(tuning.spin_cooldown_min, tuning.spin_cooldown * pow(tuning.spin_cooldown_stack_mult, stacks - 1))


func radius() -> float:
	return tuning.spin_radius + tuning.spin_radius_per_stack * float(stacks - 1)


func update(delta: float) -> void:
	if not is_active():
		return
	timer += delta
	var cd := cooldown()
	if timer < cd:
		return
	var targets := _targets(radius())
	if targets.is_empty():
		timer = cd
		return
	timer -= cd
	triggers += 1
	var damage: int = host.call(&"ability_base_damage", tuning.spin_damage_mult)
	host.call(&"ability_visual", &"spin", radius())
	for target: Node2D in targets:
		host.call(&"ability_hit", target, damage, tuning.spin_knockback_speed)
