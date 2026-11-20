extends "res://tests/line_b/flow_test_base.gd"

func test_level_boundary_roundtrip_preserves_build_modifiers_and_rng() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	flow.progression.apply_trick(TrickDeck.load_trick(&"sit"))
	flow.progression.add_run_modifier({"attack_damage": .15})
	GameState.hero_level = 5
	flow.progression.bonus_trick_levels = 1
	assert_true(await play_until_level_ends())
	var stored := read_save()
	assert_true(int(stored.checkpoint.hero_level) >= 5)
	assert_true(stored.checkpoint.tricks.has("sit"))
	var expected: Dictionary = stored.checkpoint.duplicate(true)
	flow.queue_free()
	flow = null
	await wait_frames(2)
	make_flow(true)
	await wait_frames(1)
	flow.continue_game()
	assert_eq(GameState.hero_level, expected.hero_level)
	assert_eq(Array(GameState.active_tricks), expected.tricks.map(func(x: Variant) -> StringName: return StringName(x)))
	assert_eq(flow.progression.bonus_trick_levels, expected.bonus_trick_levels)
	assert_eq(flow.progression.run_modifiers, expected.run_modifiers)
	assert_eq(flow.progression.rng.state, int(expected.rng))

func test_first_level_checkpoint_exists_and_unsaved_rewards_roll_back() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(flow.has_save())
	var banked := GameState.snacks
	flow.rewards.add_snacks(30)
	flow.progression.apply_trick(TrickDeck.load_trick(&"wag"))
	flow.save_now()
	assert_eq(read_save().snacks, banked)
	flow.show_title()
	assert_eq(GameState.snacks, banked)
	flow.continue_game()
	assert_false(GameState.active_tricks.has(&"wag"))

func test_clear_award_is_once_and_persisted_with_next_checkpoint() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_true(await play_until_level_ends())
	var before := GameState.equipment.duplicate(true)
	flow._on_level_cleared()
	assert_eq(GameState.equipment, before)
	var saved := read_save()
	assert_eq(saved.equipment.coins, EquipmentInventory.RULES.starting_coins + EquipmentInventory.RULES.level_coins)
	assert_eq(saved.level_index, 1)
	assert_false(saved.checkpoint.is_empty())

func test_failed_store_write_rolls_back_purchase() -> void:
	make_flow()
	await wait_frames(1)
	var before := GameState.equipment.duplicate(true)
	flow.save_store.simulate_crash_during_write = true
	var result := flow._equipment_transaction("buy", "training_sword", "knight", "", "coins")
	assert_false(result.ok)
	assert_eq(GameState.equipment, before)

func test_corrupt_checkpoint_and_legacy_profile_are_safe() -> void:
	assert_true(AdventureCheckpoint.sanitize({"tricks": 4}).is_empty())
	var old := SaveStore.sanitize({"version": 7, "level_index": 3})
	assert_true(old.checkpoint.is_empty())
	assert_eq(old.equipment.coins, 250)
	assert_eq(old.equipment.owned, {})

func test_resumed_camp_applies_new_loadout_on_departure() -> void:
	make_flow()
	await wait_frames(1)
	assert_true(await start_new_game())
	var data := read_save()
	data.level_index = 2
	data.camp_pending = true
	data.equipment.owned = {"training_sword": 5}
	assert_true(flow.save_store.write_data(data))
	flow.queue_free()
	flow = null
	await wait_frames(2)
	make_flow(true)
	await wait_frames(1)
	flow.continue_game()
	assert_eq(flow.state, FlowMain.State.CAMP)
	assert_true(flow._equipment_transaction("equip", "training_sword", "knight", "weapon", "coins").ok)
	assert_true(flow._equipment_transaction("attune", "training_sword", "knight", "wind", "coins").ok)
	EventBus.camp_left.emit()
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_equipment.owned.get("training_sword", 0), 5)
	assert_eq(EquipmentInventory.element_of(GameState.run_equipment, "training_sword"), "wind")

func test_engraving_survives_reload_but_waits_for_next_stage_after_retry() -> void:
	make_flow()
	await wait_frames(1)
	GameState.equipment.owned = {"training_sword": 1, "quilted_vest": 1}
	GameState.equipment.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}}
	assert_true(await start_new_game())
	assert_eq(EquipmentInventory.resonance(GameState.run_equipment, "knight"), "earth")
	flow.show_title()
	assert_true(flow._equipment_transaction("attune", "training_sword", "knight", "fire", "coins").ok)
	var saved := read_save()
	assert_eq(saved.version, 10)
	assert_eq(saved.equipment.elements.training_sword, "fire")
	assert_eq(saved.checkpoint.equipment.elements.training_sword, "earth")
	flow.queue_free()
	flow = null
	await wait_frames(2)
	make_flow(true)
	await wait_frames(1)
	flow.continue_game()
	assert_true(await wait_until(in_level))
	assert_eq(EquipmentInventory.resonance(GameState.run_equipment, "knight"), "earth")
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.retry_level()
	assert_true(await wait_until(in_level))
	assert_eq(EquipmentInventory.resonance(GameState.run_equipment, "knight"), "earth")
	assert_true(await play_until_level_ends())
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(EquipmentInventory.element_of(GameState.run_equipment, "training_sword"), "fire")
	assert_eq(EquipmentInventory.resonance(GameState.run_equipment, "knight"), "")

func test_engraving_write_failure_rolls_back_shared_item_and_disk() -> void:
	make_flow()
	await wait_frames(1)
	GameState.equipment.owned = {"quilted_vest": 4}
	GameState.equipment.loadouts = {"knight": {"armor": "quilted_vest"}, "mage": {"armor": "quilted_vest"}}
	GameState.equipment = EquipmentInventory.sanitize(GameState.equipment)
	assert_true(flow.save_now())
	var before := GameState.equipment.duplicate(true)
	flow.save_store.simulate_crash_during_write = true
	assert_false(flow._equipment_transaction("attune", "quilted_vest", "knight", "water", "coins").ok)
	assert_eq(GameState.equipment, before)
	assert_eq(read_save().equipment, before)

func test_retry_keeps_checkpoint_equipment_until_next_stage() -> void:
	make_flow()
	await wait_frames(1)
	GameState.equipment.owned = {"training_sword": 1}
	GameState.equipment.loadouts = {"knight": {"weapon": "training_sword"}}
	assert_true(await start_new_game())
	flow.show_title()
	GameState.equipment.coins = 1000
	for i in 4:
		assert_true(flow._equipment_transaction("upgrade", "training_sword", "knight", "", "coins").ok)
	flow.continue_game()
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_equipment.owned.training_sword, 1, "continue uses the stage's existing loadout")
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	flow.retry_level()
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_equipment.owned.training_sword, 1, "retry must not activate title upgrades early")
	assert_true(await play_until_level_ends())
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(GameState.run_equipment.owned.training_sword, 5, "the next stage adopts the new loadout")
