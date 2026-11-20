extends "res://tests/line_a/combat_test_base.gd"

func before_each() -> void:
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}

func after_each() -> void:
	GameState.equipment = EquipmentInventory.defaults()
	GameState.hero_class = &"knight"
	await super.after_each()

func test_equipped_staff_modifies_real_projectiles() -> void:
	GameState.hero_class = &"mage"
	GameState.equipment.owned = {"moonstaff": 9}
	GameState.equipment.loadouts = {"mage": {"weapon": "moonstaff"}}
	GameState.reset_run()
	make_arena()
	var spell := HeroProjectile.launch(player, Vector2.RIGHT)
	assert_almost_eq(spell.loadout.splash_radius, player.loadout.splash_radius + 15.0)
	assert_ne(spell.loadout, player.loadout, "per-shot data must not mutate shared class resource")
	spell.queue_free()

func test_equipped_bow_adds_two_targets_at_level_nine() -> void:
	GameState.hero_class = &"archer"
	GameState.equipment.owned = {"stormbow": 9}
	GameState.equipment.loadouts = {"archer": {"weapon": "stormbow"}}
	GameState.reset_run()
	make_arena()
	var arrow := HeroProjectile.launch(player, Vector2.RIGHT)
	assert_eq(arrow.loadout.max_hits, player.loadout.max_hits + 2)
	assert_ne(arrow.loadout, player.loadout)
	arrow.queue_free()

func test_companion_signal_charges_real_player_next_hit_only() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment.owned = {"pack_bell": 1}
	GameState.equipment.loadouts = {"knight": {"treasure_a": "pack_bell"}}
	GameState.reset_run()
	make_arena()
	EventBus.companion_blocked.emit(player.global_position + Vector2(10, 0))
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.3)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.0)
	EventBus.companion_blocked.emit(player.global_position)
	assert_almost_eq(player.equipment_combat.consume_attack(), 1.0, .0001, "cooldown prevents repeated shield farming")

func test_wave_heal_and_armor_reduction_reach_real_player() -> void:
	GameState.equipment.owned = {"hearth_heart": 1, "oathplate": 1}
	GameState.equipment.loadouts = {"knight": {"armor": "oathplate", "treasure_a": "hearth_heart"}}
	GameState.hero_class = &"knight"
	GameState.reset_run()
	make_arena()
	GameState.vigor = 50
	EventBus.wave_cleared.emit(0)
	assert_eq(GameState.vigor, 54)
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(GameState.vigor, 41, "oathplate proc reduces first hit to 13")

func test_forged_cadence_reaches_melee_and_projectile_cooldown() -> void:
	for hero in ["knight", "archer"]:
		var id := "training_sword" if hero == "knight" else "stormbow"
		GameState.hero_class = StringName(hero)
		GameState.equipment = EquipmentInventory.defaults()
		GameState.equipment.owned[id] = 2
		GameState.equipment.loadouts[hero] = {"weapon": id}
		GameState.reset_run()
		var progression := RunProgression.new()
		progression.setup(load("res://game/progression/difficulty.tres"))
		progression.rebuild_stats()
		make_arena()
		spawn(&"scarecrow", player.global_position + Vector2(35, 0))
		player._swing()
		var windup: float = player.tuning.attack_windup if hero == "knight" else player.loadout.windup
		var base_interval := HeroClasses.get_data(StringName(hero)).stats.attack_interval
		assert_almost_eq(player.get("_attack_cooldown"), base_interval * (0.99 if hero == "knight" else 0.95) - windup)
		progression.free()
		await super.after_each()

func _element_arena(hero: String, element: String) -> void:
	GameState.hero_class = StringName(hero)
	GameState.equipment = EquipmentInventory.defaults()
	var weapon: String = {"knight": "training_sword", "mage": "apprentice_staff", "archer": "ash_bow"}[hero]
	GameState.equipment.owned = {weapon: 1, "quilted_vest": 1}
	GameState.equipment.loadouts = {hero: {"weapon": weapon, "armor": "quilted_vest"}}
	GameState.equipment.elements = {weapon: element, "quilted_vest": element}
	GameState.reset_run()
	var progression := RunProgression.new()
	progression.setup(load("res://game/progression/difficulty.tres"))
	progression.rebuild_stats()
	progression.free()
	make_arena()

func test_earth_resonance_reduces_real_damage_then_waits_for_cooldown() -> void:
	_element_arena("knight", "earth")
	var before := GameState.vigor
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(before - GameState.vigor, 14, "20 * .92 rounded then 20% shield rounded")
	before = GameState.vigor
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(before - GameState.vigor, 18)
	player.equipment_combat.tick(12.0, false)
	before = GameState.vigor
	player.invuln_left = 0
	player.take_damage(20)
	assert_eq(before - GameState.vigor, 14)

func test_water_restores_real_vigor_on_wave_and_ultimate_for_all_classes() -> void:
	for hero in EquipmentInventory.HEROES:
		_element_arena(hero, "water")
		GameState.vigor = 20
		var amount := roundi(GameState.player_stats.max_vigor * .03)
		EventBus.wave_cleared.emit(1)
		assert_eq(GameState.vigor, 20 + amount)
		player.loyalty = player.tuning.loyalty_max
		assert_true(player.use_ultimate())
		assert_eq(GameState.vigor, 20 + amount * 2)
		assert_almost_eq(player.loyalty_gain_mult(), 1.08)
		await super.after_each()

func test_fire_damage_and_counter_are_consumed_by_actual_player_hit_path() -> void:
	for hero in EquipmentInventory.HEROES:
		_element_arena(hero, "fire")
		player.ability_tuning = player.ability_tuning.duplicate()
		player.ability_tuning.sniff_crit_chance = 0.0
		player.invuln_left = 0
		player.take_damage(1)
		var damage := CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus, 1.2)
		assert_eq(player.projectile_impact_damage(1.0, false), damage)
		assert_eq(player.projectile_impact_damage(1.0, false), CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus))
		await super.after_each()

func test_wind_changes_real_cooldown_and_move_stop_charge_for_all_classes() -> void:
	for hero in EquipmentInventory.HEROES:
		_element_arena(hero, "wind")
		var base := HeroClasses.get_data(StringName(hero)).stats
		assert_almost_eq(GameState.player_stats.attack_interval, base.attack_interval * .94)
		assert_almost_eq(GameState.player_stats.move_speed, base.move_speed * 1.06)
		spawn(&"scarecrow", player.global_position + Vector2(27, 0))
		player._swing()
		var windup: float = player.tuning.attack_windup if hero == "knight" else player.loadout.windup
		assert_almost_eq(player.get("_attack_cooldown"), base.attack_interval * .94 - windup)
		player.equipment_combat.tick(1.5, true)
		player.equipment_combat.tick(.01, false)
		assert_almost_eq(player.equipment_combat.consume_attack(), 1.15)
		assert_almost_eq(player.equipment_combat.consume_attack(), 1.0)
		await super.after_each()
