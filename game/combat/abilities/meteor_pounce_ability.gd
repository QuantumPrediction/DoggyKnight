class_name MeteorPounceAbility
extends PounceAbility
## 進化:流星撲擊(meteor_pounce = pounce + zoomies,v2.4)。
## 撲得更遠、跳得更高,落地時造成小範圍衝擊(橘色衝擊圈、震波、鏡頭震動);
## 保留暴衝:打倒敵人後一段時間加速。進化把戲最多一層。

var boost_left: float = 0.0
var impacts: int = 0             ## 落地衝擊打中過敵人的次數(測試用)


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"meteor_pounce"


func add_stack() -> void:
	stacks = 1


func reset() -> void:
	super()
	boost_left = 0.0
	impacts = 0


func reach() -> float:
	return tuning.meteor_range


func cooldown() -> float:
	return tuning.meteor_cooldown


func dash_time() -> float:
	return tuning.meteor_time


func hop_height() -> float:
	return tuning.meteor_hop_height


func update(delta: float) -> void:
	super(delta)
	boost_left = maxf(0.0, boost_left - delta)


func on_land() -> void:
	if not is_active():
		return
	var r := tuning.meteor_impact_radius
	host.call(&"ability_visual", &"meteor", r)
	var targets := _targets(r)
	if targets.is_empty():
		return
	impacts += 1
	var damage: int = host.call(&"ability_base_damage", tuning.meteor_damage_mult)
	for target: Node2D in targets:
		host.call(&"ability_hit", target, damage, tuning.meteor_knockback_speed)


func on_kill() -> void:
	if is_active():
		boost_left = tuning.meteor_zoomies_time


func is_boosting() -> bool:
	return boost_left > 0.0


func speed_mult() -> float:
	return 1.0 + tuning.meteor_zoomies_speed_bonus if boost_left > 0.0 else 1.0
