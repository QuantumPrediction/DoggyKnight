extends RefCounted
## Deliberately staged inventory for developer balance comparisons. No wallet grants.
const PRESETS: Array[String] = ["none", "common1", "common5", "epic1", "epic3", "epic9"]

static func make(hero: String, preset: String) -> Dictionary:
	var profile := EquipmentInventory.defaults()
	if preset == "none":
		return profile
	var items: Array
	var level: int
	if preset in ["common1", "common5"]:
		items = {"knight": ["training_sword", "quilted_vest"],
			"mage": ["apprentice_staff", "apprentice_robe"],
			"archer": ["ash_bow", "ranger_jacket"]}[hero]
		level = 1 if preset == "common1" else 5
	else:
		items = {"knight": ["sunblade", "oathplate", "pack_bell", "hearth_heart"],
			"mage": ["moonstaff", "starrobe", "star_hourglass", "avalon_grail"],
			"archer": ["stormbow", "mistcloak", "leaf_compass", "pack_bell"]}[hero]
		level = int(preset.trim_prefix("epic"))
	profile.loadouts[hero] = {}
	for i in items.size():
		if preset == "common1":
			EquipmentInventory.transact(profile, "buy", items[i], hero)
			EquipmentInventory.transact(profile, "equip", items[i], hero, EquipmentInventory.SLOTS[i])
			continue
		profile.owned[items[i]] = level
		profile.loadouts[hero][EquipmentInventory.SLOTS[i]] = items[i]
	return profile
