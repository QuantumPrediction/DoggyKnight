extends TestCase

var progression: RunProgression
var nodes: Array[Node] = []

func make_run(hero: StringName = &"knight") -> void:
	GameState.hero_class = hero
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.chapter = 1
	GameState.mode = &"story"
	GameState.reset_run()
	progression = RunProgression.new()
	add_child(progression)
	nodes.append(progression)
	progression.setup(load("res://game/progression/difficulty.tres"), 73)
	progression.reset_run()
	progression.begin_level()

func test_all_six_routes_grant_the_actual_player_ability_and_tradeoff() -> void:
	for id in BuildRoutes.IDS:
		var route := BuildRoutes.get_route(id)
		make_run(route.hero)
		var arena := preload("res://game/combat/arena.tscn").instantiate() as CombatArena
		add_child(arena)
		var player := arena.get_player()
		player.set_physics_process(false)
		assert_true(progression.choose_route(id))
		assert_eq(GameState.active_tricks.count(route.starter), 1)
		if AbilitySet.is_ability(route.starter):
			assert_eq(player.abilities.get_ability(route.starter).stacks, 1, "live ability receives exactly one grant")
		else:
			assert_true(player.crit_chance() > 0, "marksman sniff modifies actual critical chance")
		var base := GameState.base_stats()
		for key: String in route.modifiers:
			var expected := float(base.get(key)) * (1.0 + float(route.modifiers[key]))
			if base.get(key) is int:
				expected = roundf(expected)
			assert_almost_eq(float(GameState.player_stats.get(key)), expected, 0.001)
		var before := GameState.player_stats.duplicate()
		progression.rebuild_stats()
		for key: String in route.modifiers:
			assert_eq(GameState.player_stats.get(key), before.get(key), "rebuild does not compound bonuses")
		remove_child(arena)
		arena.queue_free()
		remove_child(progression)
		progression.queue_free()
		await wait_frames(1)

func test_route_choice_rejects_wrong_class_duplicate_and_open_upgrade() -> void:
	make_run()
	assert_false(progression.choose_route(&"marksman"))
	assert_false(progression.choose_route(&"unknown"))
	progression.offer_bonus_choice()
	assert_false(progression.choose_route(&"bulwark"))
	progression.cancel_choices()
	assert_true(progression.choose_route(&"bulwark"))
	assert_false(progression.choose_route(&"vanguard"))
	assert_eq(GameState.active_tricks.count(&"bark"), 1)

func test_starter_respects_caps_evolution_and_pending_bonus() -> void:
	make_run()
	GameState.active_tricks.assign([&"bark", &"bark", &"bark"])
	progression.bonus_trick_levels = 1
	assert_true(progression.choose_route(&"bulwark"))
	assert_eq(GameState.active_tricks.count(&"bark"), 3)
	assert_eq(progression.bonus_trick_levels, 1)
	progression.reset_run()
	GameState.active_tricks.assign([&"lion_roar"])
	assert_true(progression.choose_route(&"bulwark"))
	assert_false(GameState.active_tricks.has(&"bark"), "an evolved source is not reintroduced")

func test_snapshot_retry_and_new_run_reset_route_without_stacking() -> void:
	make_run()
	var before := progression.take_snapshot()
	assert_true(progression.choose_route(&"vanguard"))
	var chosen := progression.take_snapshot()
	progression.restore_snapshot(before)
	assert_eq(GameState.run_route, &"")
	assert_false(GameState.active_tricks.has(&"pounce"))
	assert_true(progression.choose_route(&"vanguard"))
	assert_eq(GameState.player_stats.move_speed, (chosen.stats as StatBlock).move_speed)
	progression.restore_snapshot(chosen)
	assert_eq(GameState.run_route, &"vanguard")
	GameState.reset_run()
	progression.reset_run()
	assert_eq(GameState.run_route, &"")

func test_checkpoint_roundtrip_old_save_and_invalid_route() -> void:
	make_run(&"mage")
	assert_true(progression.choose_route(&"mistwalker"))
	var before := GameState.player_stats.duplicate()
	var raw: Dictionary = JSON.parse_string(JSON.stringify(progression.export_checkpoint()))
	var clean := AdventureCheckpoint.sanitize(raw)
	GameState.reset_run()
	progression.reset_run()
	progression.import_checkpoint(clean)
	assert_eq(GameState.run_route, &"mistwalker")
	assert_eq(GameState.player_stats.attack_range, before.attack_range)
	assert_eq(GameState.player_stats.attack_damage, before.attack_damage)
	assert_eq(GameState.active_tricks.count(&"roll"), 1)
	raw.erase("route")
	var old := SaveStore.sanitize({"version": 10, "checkpoint": raw})
	assert_eq(old.checkpoint.route, "", "v10 checkpoints migrate without inventing a route")
	for bad: Variant in ["../../evil", 42, {}, "missing"]:
		raw.route = bad
		assert_eq(AdventureCheckpoint.sanitize(raw).route, "")
	raw.route = "bulwark"
	progression.import_checkpoint(AdventureCheckpoint.sanitize(raw))
	assert_eq(GameState.run_route, &"", "cross-class route cannot apply its stats")

func test_guided_offers_are_legal_unique_and_leave_unrouted_rng_unchanged() -> void:
	for id in BuildRoutes.IDS:
		var route := BuildRoutes.get_route(id)
		make_run(route.hero)
		var deck := progression.get_deck()
		for seed_value in range(1, 30):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var raw := deck.draw(3, rng, [])
			var state := rng.state
			assert_eq(BuildRoutes.guide_offer(raw, deck, [], &""), raw)
			assert_eq(rng.state, state)
			var guided := BuildRoutes.guide_offer(raw, deck, [], id)
			var seen := {}
			var related := false
			for trick in guided:
				assert_true(deck.available([]).has(trick.id))
				assert_false(seen.has(trick.id))
				seen[trick.id] = true
				related = related or route.preferred.has(trick.id)
			assert_true(related)
		remove_child(progression)
		progression.queue_free()
		await wait_frames(1)

func test_evolutions_and_exhausted_preferred_skills_are_preserved() -> void:
	make_run()
	var deck := progression.get_deck()
	var owned: Array = [&"bark", &"bark", &"bark", &"sit"]
	var raw := deck.draw(3, progression.rng, owned)
	var offer := BuildRoutes.guide_offer(raw, deck, owned, &"bulwark")
	assert_eq(offer[0].id, &"lion_roar")
	owned = [&"lion_roar"]
	for i in 20:
		offer = BuildRoutes.guide_offer(deck.draw(3, progression.rng, owned), deck, owned, &"bulwark")
		for trick in offer:
			assert_false(trick.id in [&"bark", &"sit"])

func test_three_encounters_have_real_costs_rewards_and_single_resolution() -> void:
	make_run()
	var rewards := RunRewards.new()
	add_child(rewards)
	nodes.append(rewards)
	var events := LevelEvents.new()
	add_child(events)
	nodes.append(events)
	events.setup(progression, rewards)
	events.has_ui = true
	GameState.vigor = 80
	GameState.snacks = 0
	events.offer(BuildRoutes.encounter_for(&"1-2"))
	assert_true(events.choose(1))
	assert_eq(GameState.vigor, 56)
	assert_eq(GameState.snacks, 25)
	assert_false(events.choose(1))
	assert_eq(GameState.snacks, 25)
	events.offer(BuildRoutes.encounter_for(&"1-3"))
	assert_true(events.choose(1))
	assert_true(progression.is_choice_open())
	assert_almost_eq(GameState.player_stats.damage_taken_mult, 1.1, 0.001)
	progression.cancel_choices()
	events.offer(BuildRoutes.encounter_for(&"1-5"))
	assert_true(events.choose(0))
	assert_almost_eq(GameState.player_stats.damage_taken_mult, 0.95, 0.001)
	assert_true(GameState.player_stats.move_speed < GameState.base_stats().move_speed)
	assert_null(BuildRoutes.encounter_for(&"2-2"))

func after_each() -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()
	progression = null
	GameState.reset_run()
	await wait_frames(2)
