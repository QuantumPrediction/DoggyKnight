extends TestCase

func after_each() -> void:
	GameState.meta_upgrades = {}
	GameState.equipment = EquipmentInventory.defaults()
	GameState.hero_class = &"knight"
	GameState.reset_run()

func profile_for(hero: String, weapon_element: String, armor_element: String) -> Dictionary:
	var weapon: String = {"knight": "training_sword", "mage": "apprentice_staff", "archer": "ash_bow"}[hero]
	var p := EquipmentInventory.defaults()
	p.owned = {weapon: 1, "quilted_vest": 1}
	p.loadouts = {hero: {"weapon": weapon, "armor": "quilted_vest"}}
	p.elements = {weapon: weapon_element, "quilted_vest": armor_element}
	return p

func test_all_class_element_pairs_require_both_slots_and_ignore_treasures() -> void:
	for hero in EquipmentInventory.HEROES:
		for weapon in EquipmentInventory.ELEMENTS:
			for armor in EquipmentInventory.ELEMENTS:
				var p := profile_for(hero, weapon, armor)
				p.owned.pack_bell = 9
				p.loadouts[hero].treasure_a = "pack_bell"
				p.elements.pack_bell = "fire"
				assert_eq(EquipmentInventory.bonuses(p, hero).resonance, weapon if weapon == armor else "", "%s %s/%s" % [hero, weapon, armor])
				p.loadouts[hero].erase("armor")
				assert_eq(EquipmentInventory.resonance(p, hero), "", "unworn owned armor cannot activate a set")
				p.loadouts[hero] = {"armor": "quilted_vest"}
				assert_eq(EquipmentInventory.resonance(p, hero), "")

func test_default_and_invalid_affinities_preserve_legacy_collection() -> void:
	var raw := {"version": 8, "equipment": {"owned": {"training_sword": 4, "quilted_vest": 5, "pack_bell": 9},
		"coins": 83, "elements": {"training_sword": [], "quilted_vest": "void", "pack_bell": "fire", "sunblade": "water"},
		"loadouts": {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}}}}
	var clean: Dictionary = SaveStore.sanitize(raw).equipment
	assert_eq(clean.owned, raw.equipment.owned)
	assert_eq(clean.coins, 83)
	assert_eq(clean.elements, {"training_sword": "earth", "quilted_vest": "earth"})
	assert_eq(EquipmentInventory.sanitize(clean), clean)
	raw.equipment.elements = 17
	assert_eq(EquipmentInventory.sanitize(raw.equipment).elements, clean.elements)

func test_every_weapon_and_armor_can_be_reengraved_without_spending_or_level_loss() -> void:
	var count := 0
	for entry in EquipmentInventory.RULES.items:
		if entry.slot == "treasure":
			assert_eq(EquipmentInventory.element_of({}, entry.id), "")
			continue
		count += 1
		assert_true(EquipmentInventory.ELEMENTS.has(EquipmentInventory.element_of({}, entry.id)))
		var p := EquipmentInventory.defaults()
		p.owned[entry.id] = EquipmentInventory.cap(entry)
		var hero: String = "knight" if entry.hero == "all" else entry.hero
		for element in EquipmentInventory.ELEMENTS:
			assert_true(EquipmentInventory.transact(p, "attune", entry.id, hero, element).ok)
			assert_eq(EquipmentInventory.element_of(p, entry.id), element)
			assert_eq(p.coins, 250)
			assert_eq(p.gems, 0)
			assert_eq(p.shards, 0)
			assert_eq(p.owned[entry.id], EquipmentInventory.cap(entry))
	assert_eq(count, 12)

func test_invalid_engraving_actions_are_atomic() -> void:
	var p := profile_for("knight", "earth", "earth")
	p.owned.pack_bell = 1
	var before := p.duplicate(true)
	for args in [["sunblade", "knight", "fire"], ["training_sword", "mage", "fire"], ["training_sword", "knight", "void"], ["pack_bell", "knight", "water"]]:
		assert_false(EquipmentInventory.transact(p, "attune", args[0], args[1], args[2]).ok)
		assert_eq(p, before)

func test_resonance_adds_once_and_mixed_pieces_keep_individual_effects() -> void:
	var p := profile_for("knight", "fire", "fire")
	var b := EquipmentInventory.bonuses(p, "knight")
	assert_almost_eq(b.mods.attack_damage, .24, .0001, "sword .12 + fire weapon .08 + resonance .04")
	assert_almost_eq(b.effects.counter, .20)
	p.owned.pack_bell = 1
	p.loadouts.knight.treasure_a = "pack_bell"
	assert_almost_eq(EquipmentInventory.bonuses(p, "knight").mods.attack_damage, .24, .0001, "a third family item cannot multiply resonance")
	p.elements.quilted_vest = "wind"
	b = EquipmentInventory.bonuses(p, "knight")
	assert_almost_eq(b.mods.attack_damage, .20)
	assert_almost_eq(b.mods.move_speed, .06)
	assert_eq(b.resonance, "")
	assert_false(b.effects.has("counter"))

func test_element_preview_matches_real_transaction_without_mutating_snapshot() -> void:
	GameState.meta_upgrades = {&"strength": 3, &"agility": 2}
	for hero in EquipmentInventory.HEROES:
		var p := profile_for(hero, "earth", "earth")
		var id: String = p.loadouts[hero].weapon
		var original := p.duplicate(true)
		var snapshot := EquipmentInventory.loadout(p, hero)
		GameState.run_equipment = snapshot.duplicate(true)
		for element in EquipmentInventory.ELEMENTS:
			var preview := EquipmentPreview.compare_element(p, hero, id, element)
			var actual := p.duplicate(true)
			assert_true(EquipmentInventory.transact(actual, "attune", id, hero, element).ok)
			var expected := EquipmentPreview.stats(actual, hero)
			for key in EquipmentPreview.STAT_KEYS:
				assert_almost_eq(float(preview.after.get(key)), float(expected.get(key)))
			assert_eq(preview.after_bonuses, EquipmentInventory.bonuses(actual, hero))
			assert_eq(p, original)
			assert_eq(GameState.run_equipment, snapshot)
	assert_true(EquipmentPreview.compare_element(profile_for("knight", "earth", "earth"), "mage", "training_sword", "fire").is_empty())

func test_combined_proc_caps_match_runtime_maxima() -> void:
	var p := profile_for("knight", "water", "water")
	p.owned.hearth_heart = 9
	p.owned.avalon_grail = 9
	p.loadouts.knight.treasure_a = "hearth_heart"
	p.loadouts.knight.treasure_b = "avalon_grail"
	var b := EquipmentInventory.bonuses(p, "knight")
	assert_almost_eq(b.effects.wave_heal, .08)
	assert_almost_eq(b.effects.ult_heal, .15)
	p.owned.oathplate = 9
	p.loadouts.knight.armor = "oathplate"
	p.elements = {"training_sword": "earth", "oathplate": "earth"}
	assert_almost_eq(EquipmentInventory.bonuses(p, "knight").effects.guard, .6)
