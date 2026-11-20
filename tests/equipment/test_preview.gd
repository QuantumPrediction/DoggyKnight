extends TestCase
func before_each() -> void:
	GameState.meta_upgrades = {}
	GameState.equipment = EquipmentInventory.defaults()
func after_each() -> void:
	GameState.meta_upgrades = {}
	GameState.equipment = EquipmentInventory.defaults()
	GameState.hero_class = &"knight"
	GameState.reset_run()

func test_preview_matches_departure_for_all_classes_and_training() -> void:
	GameState.meta_upgrades = {&"strength": 3, &"vitality": 2, &"agility": 1}
	var p := EquipmentInventory.defaults()
	for entry in EquipmentInventory.RULES.items:
		p.owned[entry.id] = EquipmentInventory.cap(entry)
	p.loadouts = {"knight": {"weapon": "training_sword", "armor": "oathplate", "treasure_a": "pack_bell"},
		"mage": {"weapon": "moonstaff", "armor": "starrobe", "treasure_a": "star_hourglass"},
		"archer": {"weapon": "stormbow", "armor": "mistcloak", "treasure_a": "star_hourglass"}}
	var progression := RunProgression.new()
	progression.setup(load("res://game/progression/difficulty.tres"), 7, MetaUpgradeTable.load_default())
	for hero in EquipmentInventory.HEROES:
		GameState.hero_class = StringName(hero)
		GameState.equipment = p.duplicate(true)
		GameState.reset_run()
		progression.rebuild_stats()
		var shown := EquipmentPreview.stats(p, hero)
		for key in EquipmentPreview.STAT_KEYS:
			assert_almost_eq(float(shown.get(key)), float(GameState.player_stats.get(key)), 0.0001, "%s %s" % [hero, key])
	progression.free()

func test_swap_previews_set_loss_and_never_mutates_profile_or_checkpoint() -> void:
	var p := EquipmentInventory.defaults()
	p.owned = {"training_sword": 2, "quilted_vest": 1, "ranger_jacket": 3}
	p.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}}
	GameState.run_equipment = EquipmentInventory.loadout(p, "knight")
	var before := p.duplicate(true)
	var checkpoint := GameState.run_equipment.duplicate(true)
	var comparison := EquipmentPreview.compare(p, "knight", "ranger_jacket", "armor")
	assert_eq(comparison.before_bonuses.sets.guardian, 2)
	assert_eq(comparison.after_bonuses.sets.guardian, 1)
	assert_true(comparison.after.move_speed > comparison.before.move_speed)
	assert_eq(p, before)
	assert_eq(GameState.run_equipment, checkpoint)

func test_treasure_preview_matches_actual_move_between_slots() -> void:
	var p := EquipmentInventory.defaults()
	p.owned = {"pack_bell": 1, "hearth_heart": 1}
	p.loadouts = {"knight": {"treasure_a": "pack_bell", "treasure_b": "hearth_heart"}}
	var result := EquipmentPreview.candidate(p, "knight", "pack_bell", "treasure_b")
	assert_eq(result.loadouts.knight, {"treasure_b": "pack_bell"})
	assert_eq(EquipmentInventory.bonuses(result, "knight").sets.guardian, 1)
	assert_eq(p.loadouts.knight.size(), 2)
	assert_true(EquipmentPreview.compare(p, "mage", "training_sword", "weapon").is_empty())

func test_forging_plateau_weapons_improves_real_cadence_at_every_rank() -> void:
	for id in ["training_sword", "stormbow"]:
		var entry := EquipmentInventory.item(id)
		var p := EquipmentInventory.defaults()
		p.owned[id] = 1
		p.loadouts[entry.hero] = {"weapon": id}
		for level in range(1, EquipmentInventory.cap(entry)):
			p.owned[id] = level
			var comparison := EquipmentPreview.compare(p, entry.hero, id, "weapon", true)
			assert_true(comparison.after.attack_interval < comparison.before.attack_interval)
			assert_true(comparison.after.attack_damage >= comparison.before.attack_damage)
		var base_interval := HeroClasses.get_data(StringName(entry.hero)).stats.attack_interval
		p.owned[id] = EquipmentInventory.cap(entry)
		assert_almost_eq(EquipmentPreview.stats(p, entry.hero).attack_interval, base_interval * (0.96 if id == "training_sword" else 0.88), .0001, "wind weapon adds -4% independent of forging")
