class_name HighFiveAbility
extends TrickAbility
## 進化:擊掌連打(high_five = shake + fetch,v2.4)。
## 每第 3 下打中的攻擊:那一下 ×1.5,並放出一個飛向最近敵人的掌印(攻擊力 ×1.5)。
## 畫面:金色的掌印(程式畫的肉球,game/combat/paw_print.gd)拖著光點飛過去。進化把戲最多一層。

var swings_landed: int = 0
var _since_trigger: int = 0


func _init(p_host: Object, p_tuning: AbilityTuning) -> void:
	super(p_host, p_tuning)
	id = &"high_five"


func add_stack() -> void:
	stacks = 1


func reset() -> void:
	super()
	swings_landed = 0
	_since_trigger = 0


func on_swing_landed() -> float:
	if not is_active():
		return 1.0
	swings_landed += 1
	_since_trigger += 1
	if _since_trigger < maxi(1, tuning.high_five_every):
		return 1.0
	_since_trigger = 0
	triggers += 1
	var damage: int = host.call(&"ability_base_damage", tuning.high_five_paw_damage_mult)
	host.call(&"ability_projectile", &"paw", damage)
	return tuning.high_five_swing_mult
