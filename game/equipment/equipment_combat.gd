class_name EquipmentCombat
extends RefCounted
## Per-player proc state. No loops: procs do not emit damage or item grants themselves.
var effects: Dictionary = {}
var guard_left: float = 0.0
var control_left: float = 0.0
var pack_left: float = 0.0
var charged_left: float = 0.0
var charge_bonus: float = 0.0
var moving_time: float = 0.0
var rules: EquipmentRules = EquipmentInventory.RULES

func setup(profile: Dictionary, hero: String) -> void:
	effects = EquipmentInventory.bonuses(profile, hero).effects

func tick(delta: float, moving: bool) -> void:
	guard_left = maxf(0.0, guard_left - delta)
	control_left = maxf(0.0, control_left - delta)
	pack_left = maxf(0.0, pack_left - delta)
	charged_left = maxf(0.0, charged_left - delta)
	if charged_left <= 0.0:
		charge_bonus = 0.0
	if moving:
		moving_time += delta
	elif moving_time > 0.0:
		if moving_time >= rules.movement_charge_time:
			charge(float(effects.get("ambush", 0.0)))
		moving_time = 0.0

func charge(amount: float) -> void:
	if amount > 0.0:
		charge_bonus = maxf(charge_bonus, amount) # strongest only, no multiplication chain
		charged_left = rules.synergy_window

func consume_attack() -> float:
	var mult := 1.0 + charge_bonus if charged_left > 0.0 else 1.0
	charged_left = 0.0
	charge_bonus = 0.0
	return mult

func incoming(amount: int) -> int:
	charge(float(effects.get("counter", 0.0)))
	if guard_left <= 0.0 and float(effects.get("guard", 0.0)) > 0.0:
		guard_left = rules.guard_cooldown
		return maxi(1, roundi(amount * (1.0 - minf(0.6, float(effects.guard)))))
	return amount

func companion_block() -> bool:
	if pack_left > 0.0 or float(effects.get("pack", 0.0)) <= 0.0:
		return false
	pack_left = rules.synergy_cooldown
	charge(float(effects.pack))
	return true

func trigger_control() -> bool:
	if control_left > 0.0 or float(effects.get("control", 0.0)) <= 0.0:
		return false
	control_left = rules.control_cooldown
	return true
