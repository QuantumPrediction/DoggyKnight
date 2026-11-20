extends TestCase

func after_each() -> void:
	GameState.equipment = EquipmentInventory.defaults()
	GameState.reset_run()

func test_catalog_unique_ids_complete_prices_and_icons() -> void:
	var ids := []
	for entry in EquipmentInventory.RULES.items:
		assert_false(ids.has(entry.id))
		ids.append(entry.id)
		assert_eq(entry.icon, ids.size() - 1)
		assert_true(int(entry.coins) > 0)
		assert_true(entry.slot in ["weapon", "armor", "treasure"])
		assert_eq(EquipmentInventory.cap(entry), 5 if entry.quality == "common" else 9)
	assert_eq(ids.size(), 18)

func test_purchase_upgrade_caps_and_failed_actions_never_spend() -> void:
	for id in ["training_sword", "sunblade"]:
		var p := EquipmentInventory.defaults()
		p.coins = 100000
		p.shards = 1000
		assert_true(EquipmentInventory.transact(p, "buy", id, "knight").ok)
		var cap := EquipmentInventory.cap(EquipmentInventory.item(id))
		for level in range(1, cap):
			assert_true(EquipmentInventory.transact(p, "upgrade", id, "knight").ok)
		assert_eq(p.owned[id], cap)
		var old := p.duplicate(true)
		assert_false(EquipmentInventory.transact(p, "upgrade", id, "knight").ok)
		assert_eq(p, old)
		assert_false(EquipmentInventory.transact(p, "buy", id, "knight").ok)
		assert_eq(p, old)

func test_two_currencies_are_alternatives_and_do_not_cross_spend() -> void:
	var p := EquipmentInventory.defaults()
	p.coins = 0
	p.gems = 120
	assert_false(EquipmentInventory.transact(p, "buy", "sunblade", "knight").ok)
	assert_eq(p.gems, 120)
	assert_true(EquipmentInventory.transact(p, "buy", "sunblade", "knight", "", "gems").ok)
	assert_eq(p.gems, 0)
	assert_eq(p.coins, 0)
	assert_false(EquipmentInventory.transact(p, "buy", "mistcloak", "knight", "", "coins", 1).ok)
	assert_false(EquipmentInventory.transact(p, "buy", "training_sword", "knight", "", "gems").ok)

func test_class_slots_and_unique_treasures() -> void:
	var p := EquipmentInventory.defaults()
	p.owned = {"sunblade": 1, "pack_bell": 1, "hearth_heart": 1}
	assert_false(EquipmentInventory.transact(p, "equip", "sunblade", "mage", "weapon").ok)
	assert_false(EquipmentInventory.transact(p, "equip", "sunblade", "knight", "armor").ok)
	assert_true(EquipmentInventory.transact(p, "equip", "sunblade", "knight", "weapon").ok)
	assert_true(EquipmentInventory.transact(p, "equip", "pack_bell", "knight", "treasure_a").ok)
	assert_true(EquipmentInventory.transact(p, "equip", "pack_bell", "knight", "treasure_b").ok)
	assert_false(p.loadouts.knight.has("treasure_a"))
	assert_eq(p.loadouts.knight.treasure_b, "pack_bell")

func test_sanitizer_rejects_wrong_types_unknown_items_and_invalid_loadouts() -> void:
	var p := EquipmentInventory.sanitize({"coins": "999", "gems": -4, "shards": INF,
		"owned": {"sunblade": 999, "training_sword": 8, "made_up": 99, "mistcloak": "5"},
		"loadouts": {"mage": {"weapon": "sunblade"}, "knight": {"weapon": "sunblade", "armor": "sunblade"}}})
	assert_eq(p.coins, 0)
	assert_eq(p.gems, 0)
	assert_eq(p.shards, 0)
	assert_eq(p.owned, {"sunblade": 9, "training_sword": 5})
	assert_true(p.loadouts.mage.is_empty())
	assert_eq(p.loadouts.knight, {"weapon": "sunblade"})

func test_boss_pity_first_clear_and_duplicates() -> void:
	var p := EquipmentInventory.defaults()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var misses := 0
	for i in 1000:
		var before := int(p.gems)
		var reward := EquipmentInventory.reward_clear(p, 1, true, false, rng)
		assert_eq(int(p.gems) - before, 20 if i == 0 else 0)
		if reward.item == "":
			misses += 1
		else:
			misses = 0
		assert_true(misses < 5)
		assert_true(int(reward.shards) >= 2)
	assert_eq(p.owned.size(), 3, "chapter one epic pool: sword, plate, bell")
	assert_true(int(p.shards) > 2000, "duplicates convert to shards")

func test_equipment_bonuses_do_not_compound_and_sets_trigger_once() -> void:
	var p := EquipmentInventory.defaults()
	p.owned = {"training_sword": 5, "quilted_vest": 5, "pack_bell": 9}
	p.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest", "treasure_a": "pack_bell"}}
	var b := EquipmentInventory.bonuses(p, "knight")
	assert_almost_eq(b.mods.attack_damage, 0.24)
	assert_almost_eq(b.mods.max_vigor, 0.36, .0001, "armor .20 + family .08 + earth armor .08")
	assert_almost_eq(b.effects.pack, 0.45)
	GameState.equipment = p
	GameState.hero_class = &"knight"
	GameState.reset_run()
	var progression := RunProgression.new()
	progression.setup(load("res://game/progression/difficulty.tres"))
	progression.rebuild_stats()
	var attack := GameState.player_stats.attack_damage
	progression.rebuild_stats()
	assert_eq(GameState.player_stats.attack_damage, attack)
	progression.free()

func test_proc_cooldowns_single_consumption_and_pause_independence() -> void:
	var combat := EquipmentCombat.new()
	combat.effects = {"counter": .4, "ambush": .25, "pack": .3, "guard": .35, "control": 1.0}
	assert_eq(combat.incoming(100), 65)
	assert_eq(combat.incoming(100), 100)
	assert_almost_eq(combat.consume_attack(), 1.4)
	assert_almost_eq(combat.consume_attack(), 1.0)
	assert_true(combat.companion_block())
	assert_false(combat.companion_block())
	combat.tick(4.0, false)
	assert_almost_eq(combat.consume_attack(), 1.0, .0001, "buff expires without hit")
	combat.tick(2.0, true)
	combat.tick(.1, false)
	assert_almost_eq(combat.consume_attack(), 1.25)
	assert_true(combat.trigger_control())
	assert_false(combat.trigger_control())

func test_effect_only_treasures_improve_at_every_forge_level() -> void:
	for id in ["pack_bell", "hearth_heart", "thorn_badge", "avalon_grail"]:
		var entry := EquipmentInventory.item(id)
		var key: String = entry.effects.keys()[0]
		var previous := 0.0
		for level in range(1, 10):
			var profile := EquipmentInventory.defaults()
			profile.owned[id] = level
			profile.loadouts = {"knight": {"treasure_a": id}}
			var value := float(EquipmentInventory.bonuses(profile, "knight").effects[key])
			assert_true(value > previous, "%s Lv.%d must improve its actual effect" % [id, level])
			previous = value

func test_forge_keeps_original_milestone_strength_and_maximum() -> void:
	for level in [1, 3, 6, 9]:
		var profile := EquipmentInventory.defaults()
		profile.owned = {"pack_bell": level}
		profile.loadouts = {"knight": {"treasure_a": "pack_bell"}}
		var expected: float = {1: 0.3, 3: 0.345, 6: 0.39, 9: 0.45}[level]
		assert_almost_eq(EquipmentInventory.bonuses(profile, "knight").effects.pack, expected)
