extends Node
## Offline developer audit using the actual inventory and stat implementation.
## It measures numeric progression, not player enjoyment or real session length.
const STAT_KEYS: Array[String] = ["attack_damage", "attack_interval", "attack_range", "max_vigor", "move_speed", "damage_taken_mult", "pickup_radius", "exp_mult"]

func _ready() -> void:
	var output := "user://equipment_audit.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.trim_prefix("--report=")
	var rows: Array[Dictionary] = []
	var unchanged: Array[Dictionary] = []
	var progression := RunProgression.new()
	progression.setup(load("res://game/progression/difficulty.tres"))
	for hero in EquipmentInventory.HEROES:
		GameState.hero_class = StringName(hero)
		GameState.meta_upgrades = {}
		GameState.active_tricks.clear()
		for entry in EquipmentInventory.RULES.items:
			var slot: String = "treasure_a" if entry.slot == "treasure" else entry.slot
			if not EquipmentInventory.fits(entry, hero, slot):
				continue
			var previous: Dictionary = {}
			for level in range(1, EquipmentInventory.cap(entry) + 1):
				var profile := EquipmentInventory.defaults()
				profile.owned[entry.id] = level
				profile.loadouts[hero] = {slot: entry.id}
				GameState.run_equipment = EquipmentInventory.loadout(profile, hero)
				progression.rebuild_stats()
				var stats := {}
				for key in STAT_KEYS:
					stats[key] = GameState.player_stats.get(key)
				var effects: Dictionary = EquipmentInventory.bonuses(profile, hero).effects.duplicate()
				# Penetration is an integer in the actual projectile path.
				if effects.has("pierce"):
					effects.pierce = roundi(float(effects.pierce))
				var signature := {"stats": stats, "effects": effects}
				var same := not previous.is_empty() and previous == signature
				var row := {"hero": hero, "item": entry.id, "level": level,
					"stats": stats, "effects": effects, "unchanged_from_previous": same}
				rows.append(row)
				if same:
					unchanged.append({"hero": hero, "item": entry.id, "from": level - 1, "to": level})
				previous = signature
	progression.free()
	var rules := EquipmentInventory.RULES
	var common_cost := 0
	var epic_cost := 0
	for cost in rules.common_costs:
		common_cost += cost
	for cost in rules.epic_costs:
		epic_cost += cost
	var cohort: Array[int] = []
	var first_epic_boss: Array[int] = []
	var drop_rng := RandomNumberGenerator.new()
	# Each trial is one six-boss campaign, no purchases, one independent fixed seed.
	for trial in 10000:
		drop_rng.seed = 110000 + trial
		var profile := EquipmentInventory.defaults()
		var first := 0
		for chapter in range(1, GameState.CHAPTER_COUNT + 1):
			var reward := EquipmentInventory.reward_clear(profile, chapter, true, false, drop_rng)
			if first == 0 and reward.item != "":
				first = chapter
		cohort.append(profile.owned.size())
		first_epic_boss.append(first)
	cohort.sort()
	first_epic_boss.sort()
	var report := {"schema": 1, "engine": Engine.get_version_info().string,
		"method": "Production inventory/stat calls. Isolated single-item rows at zero training, no tricks. Proc values do not prove per-hit gains after integer rounding. Economy trials simulate six chapter boss rewards; no player sessions.",
		"rows": rows, "unchanged_upgrades": unchanged,
		"economy": {"normal_chapter_coins": rules.level_coins * 5 + rules.boss_coins,
			"six_chapters_plus_start_coins": rules.starting_coins + 6 * (rules.level_coins * 5 + rules.boss_coins),
			"common_upgrade_cost": common_cost, "epic_upgrade_cost": epic_cost,
			"cohort_trials": cohort.size(), "cohort_seed_start": 110000,
			"unique_epics_p10_median_p90": [cohort[999], cohort[4999], cohort[8999]],
			"first_epic_boss_p10_median_p90": [first_epic_boss[999], first_epic_boss[4999], first_epic_boss[8999]]}}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write equipment audit: " + output)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("EQUIPMENT AUDIT: %d rows, %d unchanged upgrades; %s" % [rows.size(), unchanged.size(), output])
	get_tree().quit()
