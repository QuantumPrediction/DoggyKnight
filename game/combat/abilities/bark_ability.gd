class_name BarkAbility
extends TrickAbility
## 吠叫(bark):每 8 秒一次,震懾附近敵人 1.5 秒(冒星星,不能動也不能攻擊)。
## 冷卻好了但附近沒有敵人時會「等著」。
## 疊加:冷卻每層 ×0.85(最短 4 秒),半徑每層 +8,暈眩每層 +0.5 秒。

var timer: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"bark"


func reset() -> void:
	super()
	timer = 0.0


func cooldown() -> float:
	return maxf(tuning.bark_cooldown_min, tuning.bark_cooldown * pow(tuning.bark_cooldown_stack_mult, stacks - 1))


func radius() -> float:
	return tuning.bark_radius + tuning.bark_radius_per_stack * float(stacks - 1)


func stun_time() -> float:
	return tuning.bark_stun_time + tuning.bark_stun_per_stack * float(stacks - 1)


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
	Sfx.play(&"bark")
	host.call(&"ability_visual", &"bark", radius())
	for target: Node2D in targets:
		host.call(&"ability_stun", target, stun_time())
