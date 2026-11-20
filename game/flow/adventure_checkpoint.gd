class_name AdventureCheckpoint
extends RefCounted
## Strict JSON boundary: no Resource serialization, objects, or arbitrary property names.
static func sanitize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var data: Dictionary = value
	if not data.get("tricks", null) is Array or not data.get("run_modifiers", null) is Array:
		return {}
	var out := {"hero_level": maxi(1, EquipmentInventory.number(data.get("hero_level", 1), 1, 1000)),
		"exp_centi": EquipmentInventory.number(data.get("exp_centi", 0), 0, 1000000),
		"vigor": maxi(1, EquipmentInventory.number(data.get("vigor", 100), 100, 100000)),
		"satisfaction": EquipmentInventory.number(data.get("satisfaction", 0), 0, 100),
		"bonus_trick_levels": EquipmentInventory.number(data.get("bonus_trick_levels", 0), 0, 10),
		"snacks": EquipmentInventory.number(data.get("snacks", 0)),
		"next_level_bonus": 0.0, "tricks": [], "run_modifiers": [], "rng": "0", "spawn_rng": "0", "event_rng": "0", "equipment_rng": "0",
		"equipment": EquipmentInventory.sanitize(data.get("equipment", {}))}
	var bonus: Variant = data.get("next_level_bonus", 0.0)
	if (bonus is float or bonus is int) and is_finite(float(bonus)):
		out.next_level_bonus = clampf(float(bonus), 0.0, 2.0)
	for key in ["rng", "spawn_rng", "event_rng", "equipment_rng"]:
		var raw: Variant = data.get(key, "0")
		if raw is String and raw.is_valid_int():
			out[key] = str(int(raw))
	for raw: Variant in (data.tricks as Array).slice(0, 256):
		if not raw is String and not raw is StringName:
			continue
		var trick := TrickDeck.load_trick(StringName(raw)) if String(raw).is_valid_identifier() else null
		if trick != null and (trick.max_level <= 0 or out.tricks.count(String(raw)) < trick.max_level):
			out.tricks.append(String(raw))
	var allowed := ["max_vigor", "move_speed", "attack_damage", "attack_interval", "attack_range", "damage_taken_mult", "pickup_radius", "exp_mult"]
	for raw: Variant in (data.run_modifiers as Array).slice(0, 64):
		if not raw is Dictionary:
			continue
		var mods := {}
		for key in allowed:
			var number: Variant = raw.get(key)
			if (number is float or number is int) and is_finite(float(number)):
				mods[key] = clampf(float(number), -0.8, 5.0)
		if not mods.is_empty():
			out.run_modifiers.append(mods)
	return out
