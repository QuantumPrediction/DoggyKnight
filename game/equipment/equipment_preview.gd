class_name EquipmentPreview
extends RefCounted
## Read-only departure comparisons. Uses the production modifier and training rules.
## Temporary tricks, camp buffs, crits and triggered effects are deliberately excluded.
const STAT_KEYS: Array[String] = ["attack_damage", "attack_interval", "attack_range", "max_vigor", "move_speed", "damage_taken_mult", "pickup_radius", "exp_mult"]
const CURVE: DifficultyData = preload("res://game/progression/difficulty.tres")

static func stats(profile: Dictionary, hero: String) -> StatBlock:
	var base := HeroClasses.get_data(StringName(hero)).stats
	var result := base.duplicate() as StatBlock
	var training := MetaUpgradeTable.load_default()
	if training != null:
		training.apply_to(result, base)
	TrickDeck.apply_modifiers(result, base, EquipmentInventory.bonuses(profile, hero).mods, CURVE.min_damage_taken_mult)
	return result

static func candidate(profile: Dictionary, hero: String, id: String, slot: String, level: int = 0) -> Dictionary:
	var out := EquipmentInventory.sanitize(profile)
	var entry := EquipmentInventory.item(id)
	if not EquipmentInventory.fits(entry, hero, slot):
		return out
	out.owned[id] = clampi(level if level > 0 else int(out.owned.get(id, 1)), 1, EquipmentInventory.cap(entry))
	EquipmentInventory.transact(out, "equip", id, hero, slot)
	return out

static func compare(profile: Dictionary, hero: String, id: String, slot: String, upgrade: bool = false) -> Dictionary:
	var entry := EquipmentInventory.item(id)
	if not EquipmentInventory.fits(entry, hero, slot):
		return {}
	var level := maxi(1, int(profile.owned.get(id, 0)))
	var before := candidate(profile, hero, id, slot, level) if upgrade else EquipmentInventory.sanitize(profile)
	var after := candidate(profile, hero, id, slot, mini(level + 1, EquipmentInventory.cap(entry)) if upgrade else level)
	return {"before": stats(before, hero), "after": stats(after, hero),
		"before_bonuses": EquipmentInventory.bonuses(before, hero),
		"after_bonuses": EquipmentInventory.bonuses(after, hero)}

static func compare_element(profile: Dictionary, hero: String, id: String, element: String) -> Dictionary:
	var entry := EquipmentInventory.item(id)
	if entry.get("slot", "") not in ["weapon", "armor"] or not EquipmentInventory.ELEMENTS.has(element) or not EquipmentInventory.fits(entry, hero, entry.slot):
		return {}
	var before := candidate(profile, hero, id, entry.slot)
	var after := before.duplicate(true)
	if not EquipmentInventory.transact(after, "attune", id, hero, element).ok:
		return {}
	return {"before": stats(before, hero), "after": stats(after, hero),
		"before_bonuses": EquipmentInventory.bonuses(before, hero),
		"after_bonuses": EquipmentInventory.bonuses(after, hero)}
