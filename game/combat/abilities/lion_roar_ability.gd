class_name LionRoarAbility
extends TrickAbility
## 進化:獅王吼(lion_roar = bark + sit,v2.4)。
## 每 8 秒一次:範圍是吠叫的兩倍,震懾並造成傷害;震懾期間金毛受到的傷害減半。
## 畫面:金色的大聲波(三圈)、鬃毛般的光芒、震波、鏡頭震動。進化把戲最多一層。

var timer: float = 0.0
var guard_left: float = 0.0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"lion_roar"


func add_stack() -> void:
	stacks = 1


func reset() -> void:
	super()
	timer = 0.0
	guard_left = 0.0


func radius() -> float:
	return tuning.bark_radius * tuning.roar_radius_mult


func update(delta: float) -> void:
	if not is_active():
		return
	guard_left = maxf(0.0, guard_left - delta)
	timer += delta
	var cd := tuning.roar_cooldown
	if timer < cd:
		return
	var targets := _targets(radius())
	if targets.is_empty():
		timer = cd
		return
	timer -= cd
	triggers += 1
	guard_left = tuning.roar_stun_time
	CombatFx.sfx(&"lion_roar", &"bark")
	host.call(&"ability_visual", &"lion_roar", radius())
	var damage: int = host.call(&"ability_base_damage", tuning.roar_damage_mult)
	for target: Node2D in targets:
		host.call(&"ability_hit", target, damage, tuning.roar_knockback_speed)
		host.call(&"ability_stun", target, tuning.roar_stun_time)


func is_guarding() -> bool:
	return guard_left > 0.0


func damage_taken_mult() -> float:
	return tuning.roar_guard_mult if guard_left > 0.0 else 1.0
