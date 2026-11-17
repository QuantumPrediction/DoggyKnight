class_name TornadoTailAbility
extends TrickAbility
## 進化:旋風尾(tornado_tail = spin + wag,v2.4)。
## 一團旋風一直繞著金毛轉,每 0.45 秒打一次範圍內的所有敵人(不必等冷卻,也不必停下)。
## 畫面:金毛身邊持續旋轉的風(game/combat/tornado_fx.gd 讀 angle)。進化把戲最多一層。

var angle: float = 0.0
var tick_timer: float = 0.0
var hits: int = 0                ## 打中敵人的總次數(測試用)


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"tornado_tail"


func add_stack() -> void:
	stacks = 1


func reset() -> void:
	super()
	angle = 0.0
	tick_timer = 0.0
	hits = 0


func radius() -> float:
	return tuning.tornado_radius


func update(delta: float) -> void:
	if not is_active():
		return
	angle = wrapf(angle + tuning.tornado_spin_speed * delta, 0.0, TAU)
	tick_timer += delta
	if tick_timer < tuning.tornado_tick:
		return
	tick_timer -= tuning.tornado_tick
	var targets := _targets(radius())
	if targets.is_empty():
		return
	triggers += 1
	var damage: int = host.call(&"ability_base_damage", tuning.tornado_damage_mult)
	host.call(&"ability_visual", &"tornado", radius())
	for target: Node2D in targets:
		hits += 1
		host.call(&"ability_hit", target, damage, tuning.tornado_knockback_speed)


func speed_mult() -> float:
	return 1.0 + tuning.tornado_move_speed_bonus if is_active() else 1.0
