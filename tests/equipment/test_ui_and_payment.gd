extends "res://tests/line_b/flow_test_base.gd"

func test_shop_confirmation_and_back_navigation() -> void:
	make_flow()
	await wait_frames(1)
	EventBus.equipment_requested.emit()
	await wait_frames(2)
	var screen: EquipmentScreen = flow.get("_equipment_screen")
	assert_not_null(screen)
	var before := GameState.equipment.duplicate(true)
	screen.show_item("training_sword")
	screen._ask("buy", "", "coins")
	assert_eq(GameState.equipment, before, "preview does not spend")
	screen._confirm_transaction()
	assert_eq(GameState.equipment.owned.get("training_sword", 0), 1)
	assert_eq(GameState.equipment.coins, 110)
	assert_eq(read_save().equipment.owned.get("training_sword", 0), 1)
	AppLifecycle.simulate_back()
	await wait_frames(2)
	assert_not_null(flow.get("_equipment_screen"), "first back returns to inventory")
	AppLifecycle.simulate_back()
	await wait_frames(2)
	assert_null(flow.get("_equipment_screen"))
	assert_null(flow.get_quit_dialog())

func test_disabled_payment_does_not_grant_currency() -> void:
	var provider := PlatformIap.new()
	add_child(provider)
	var before := GameState.equipment.duplicate(true)
	assert_eq(GemStore.request(&"gems_120", provider).status, "unavailable")
	assert_eq(GemStore.request(&"fake", provider).status, "invalid_product")
	assert_eq(GameState.equipment, before)
	assert_eq(GemStore.packs().size(), 3)
	provider.queue_free()

func test_engraving_preview_cancel_confirmation_and_shared_class_notice() -> void:
	make_flow()
	await wait_frames(1)
	GameState.equipment.owned = {"training_sword": 2, "quilted_vest": 4}
	GameState.equipment.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}, "mage": {"armor": "quilted_vest"}}
	EventBus.equipment_requested.emit()
	await wait_frames(2)
	var screen: EquipmentScreen = flow.get("_equipment_screen")
	screen.show_item("quilted_vest")
	screen._open_elements()
	screen._choose_element("water")
	var before := GameState.equipment.duplicate(true)
	assert_true(screen._shared_element_notice("quilted_vest").contains("法師"))
	screen._ask("attune", "water", "coins")
	assert_eq(GameState.equipment, before)
	assert_true(screen.back())
	assert_eq(GameState.equipment, before, "back cancels pending engraving")
	assert_true(screen._confirm.is_empty())
	screen._open_elements()
	screen._choose_element("water")
	screen._ask("attune", "water", "coins")
	screen.selected = "training_sword" # stale selection must not redirect confirmation
	screen._confirm_transaction()
	assert_eq(GameState.equipment.elements.quilted_vest, "water")
	assert_eq(EquipmentInventory.element_of(GameState.equipment, "training_sword"), "earth")
	assert_eq(GameState.equipment.coins, before.coins)
	assert_eq(GameState.equipment.owned.quilted_vest, 4)
	assert_eq(read_save().equipment.elements.quilted_vest, "water")

func test_combat_hud_shows_stage_resonance_not_pending_armory_changes() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.equipment.owned = {"training_sword": 1, "quilted_vest": 1}
	GameState.equipment.loadouts = {"knight": {"weapon": "training_sword", "armor": "quilted_vest"}}
	GameState.reset_run()
	GameState.equipment.elements = {"training_sword": "fire", "quilted_vest": "fire"}
	var hud: Control = load("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	await wait_frames(1)
	assert_eq(hud.get("active_element"), "earth")
	assert_true(hud.get("resonance_icon").visible)
	GameState.run_equipment = EquipmentInventory.loadout(GameState.equipment, "knight")
	EventBus.level_started.emit(&"1-2")
	assert_eq(hud.get("active_element"), "fire")
	GameState.run_equipment.loadouts.knight.erase("armor")
	EventBus.level_started.emit(&"1-3")
	assert_false(hud.get("resonance_icon").visible)
	hud.queue_free()
	await wait_frames(1)
