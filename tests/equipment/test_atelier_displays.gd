extends "res://tests/line_b/flow_test_base.gd"

const CaseArt := preload("res://ui/equipment/atelier_art.gd")

func _enter_workshop() -> EquipmentScreen:
	SaveStore.new(SAVE_PATH).delete()
	flow = load(MAIN_SCENE).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	add_child(flow)
	await wait_frames(2)
	flow.get_screen().get("_equipment_button").pressed.emit()
	await wait_frames(2)
	return flow.get("_equipment_screen")

func _shop_item(screen: EquipmentScreen, id: String) -> Button:
	return screen._list.find_child("Item_" + id, true, false) as Button

func _find_button(parent: Node, text: String) -> Button:
	for button: Node in parent.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null

func test_first_visit_opens_affordable_equipment_without_a_catalog_button() -> void:
	var screen := await _enter_workshop()
	assert_eq(screen.tab, "common")
	var first := _shop_item(screen, "training_sword")
	assert_not_null(first)
	assert_not_null(_shop_item(screen, "quilted_vest"))
	assert_null(_shop_item(screen, "sunblade"))
	assert_eq(screen._price(EquipmentInventory.item("training_sword")), "140 金幣")
	assert_true(first.visible)
	assert_true(first.size.y >= 24)
	screen._tab_buttons.owned.pressed.emit()
	assert_null(_find_button(screen, "挑選第一套裝備"))
	assert_not_null(screen._list.get_node_or_null("FittingRoom/Hero"))
	screen._tab_buttons.epic.pressed.emit()
	assert_not_null(_shop_item(screen, "sunblade"))
	var blade := EquipmentInventory.item("sunblade")
	assert_true(screen._price(blade).contains("或"))
	assert_eq(screen._purchase_note(blade, {"coins": 0, "gems": blade.gems}), "可用寶石購買")
	assert_eq(screen._purchase_note(blade, {"coins": blade.coins, "gems": 0}), "可用金幣購買")
	assert_true(screen._purchase_note(blade, GameState.equipment).contains("金幣或"))
	assert_true(screen._availability(EquipmentInventory.item("avalon_grail"), GameState.equipment).contains("章開放"))

func test_current_and_max_fitting_are_read_only_then_real_trade_uses_the_actual_level() -> void:
	var screen := await _enter_workshop()
	var before := GameState.equipment.duplicate(true)
	_shop_item(screen, "training_sword").pressed.emit()
	var figure: WornGearPreview = screen._details.get_node("FittingRoom/Hero")
	assert_eq(figure._appearance.weapon_grade, 1)
	screen._details.get_node("FittingOptions/current").pressed.emit()
	figure = screen._details.get_node("FittingRoom/Hero")
	assert_eq(figure._appearance.weapon_grade, 0)
	screen._details.get_node("FittingOptions/max").pressed.emit()
	figure = screen._details.get_node("FittingRoom/Hero")
	assert_true(figure._appearance.weapon_grade > 1)
	assert_eq(GameState.equipment, before)
	_find_button(screen._actions, "140 金幣").pressed.emit()
	assert_eq(GameState.equipment, before)
	_find_button(screen._actions, "確認").pressed.emit()
	assert_eq(GameState.equipment.owned.training_sword, 1)
	assert_eq(GameState.equipment.coins, 110)
	_find_button(screen._actions, "裝備至武器").pressed.emit()
	assert_eq(GameState.equipment.loadouts.knight.weapon, "training_sword")
	_find_button(screen._actions, "鍛造  50 金幣").pressed.emit()
	_find_button(screen._actions, "確認").pressed.emit()
	assert_eq(GameState.equipment.owned.training_sword, 2)
	assert_eq(GameState.equipment.coins, 60)
	assert_eq(read_save().equipment, GameState.equipment)
	assert_eq(screen._availability(EquipmentInventory.item("training_sword"), GameState.equipment), "鍛造缺金幣")

func test_other_classes_and_treasures_show_the_matching_art_and_real_slot() -> void:
	var screen := await _enter_workshop()
	screen._class_buttons.mage.pressed.emit()
	assert_null(_shop_item(screen, "training_sword"))
	_shop_item(screen, "apprentice_staff").pressed.emit()
	var figure: WornGearPreview = screen._details.get_node("FittingRoom/Hero")
	assert_eq(figure._appearance.hero, "mage")
	screen.back()
	screen._tab_buttons.epic.pressed.emit()
	var before := GameState.equipment.duplicate(true)
	_shop_item(screen, "pack_bell").pressed.emit()
	assert_not_null(screen._details.get_node_or_null("TreasureDisplay"))
	assert_null(screen._details.get_node_or_null("FittingOptions"))
	_find_button(screen._details, "比較寶物二").pressed.emit()
	assert_eq(screen._preview_slot, "treasure_b")
	assert_eq(GameState.equipment, before)

func test_cabinet_copy_clears_the_figure_and_epic_purchase_stays_in_safe_area() -> void:
	var screen := await _enter_workshop()
	screen._tab_buttons.epic.pressed.emit()
	var first := _shop_item(screen, "sunblade")
	await wait_frames(4)
	var caption := first.find_child("Caption", true, false) as Control
	var item := first.find_child("Specimen", true, false) as Control
	assert_true(item.get_global_rect().end.x <= caption.get_global_rect().position.x)
	first.pressed.emit()
	var options := screen._details.get_node("FittingOptions")
	var focus := options.get_node("max") as Button
	focus.grab_focus()
	focus.pressed.emit()
	await wait_frames(4)
	assert_true(focus.has_focus())
	assert_true(is_same(options, screen._details.get_node("FittingOptions")))
	var cabinet := screen._details.get_node("FittingRoom") as Control
	var picture := cabinet.get_node("Hero") as Control
	caption = cabinet.get_node("Caption") as Control
	assert_true(picture.get_global_rect().end.x <= caption.get_global_rect().position.x)
	assert_true(cabinet.get_global_rect().encloses(caption.get_global_rect()))
	assert_true(SafeArea.get_safe_rect().encloses(screen._actions.get_global_rect()))
	assert_true(SafeArea.get_safe_rect().encloses(screen._root.get_global_rect()))

func test_all_display_cases_and_symbols_are_distinct_valid_regions() -> void:
	var regions: Array[Rect2] = []
	for kind: String in ["owned", "common", "epic"]:
		var cabinet := CaseArt.case_art(kind)
		var tile := cabinet.texture as AtlasTexture
		assert_false(regions.has(tile.region))
		assert_true(Rect2(Vector2.ZERO, tile.atlas.get_size()).encloses(tile.region))
		regions.append(tile.region)
		cabinet.free()
	regions.clear()
	for id: String in ["coins", "gems", "shards", "weapon", "armor", "treasure_a"]:
		var tile := CaseArt.emblem(id) as AtlasTexture
		assert_false(regions.has(tile.region))
		assert_true(Rect2(Vector2.ZERO, tile.atlas.get_size()).encloses(tile.region))
		regions.append(tile.region)

func test_maximum_wallet_keeps_all_three_exact_balances_inside_the_safe_area() -> void:
	var screen := await _enter_workshop()
	for key: String in ["coins", "gems", "shards"]:
		GameState.equipment[key] = EquipmentInventory.LIMIT
	screen.refresh()
	await wait_frames(6)
	var safe := SafeArea.get_safe_rect()
	assert_true(safe.encloses(screen._root.get_global_rect()))
	for box: Control in screen._wallet.get_children():
		assert_true(safe.encloses(box.get_global_rect()))
		var balance := box.find_children("*", "Label", true, false)[0] as Label
		assert_true(balance.text.ends_with(str(EquipmentInventory.LIMIT)))
