extends "res://tests/line_b/flow_test_base.gd"
## v2.4 BV1:新把戲與進化的資料檔、上限、進化規則、進化選項出現在三選一、選了進化換掉兩個來源。

const BASE_TRICKS: Array[StringName] = [&"sit", &"wag", &"fetch", &"shake", &"spin", &"bark",
		&"pounce", &"roll", &"dig", &"sniff", &"play_dead", &"zoomies"]
## 進化 id → [來源 1, 來源 2]
const EVOLUTIONS: Dictionary = {
	&"tornado_tail": [&"spin", &"wag"],
	&"lion_roar": [&"bark", &"sit"],
	&"high_five": [&"shake", &"fetch"],
	&"meteor_pounce": [&"pounce", &"zoomies"],
}

var progression: RunProgression


func before_each() -> void:
	GameState.reset_run()
	progression = RunProgression.new()
	progression.setup(load(DIFFICULTY) as DifficultyData, 5)
	add_child(progression)
	progression.reset_run()


func after_each() -> void:
	if is_instance_valid(progression):
		progression.queue_free()
	progression = null
	await super.after_each()


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func _ids(options: Array[TrickData]) -> Array[StringName]:
	var result: Array[StringName] = []
	for t in options:
		result.append(t.id)
	return result


func test_all_trick_files_have_text_icons_and_rules() -> void:
	var all: Array[StringName] = BASE_TRICKS.duplicate()
	for id: StringName in EVOLUTIONS:
		all.append(id)
	for id in all:
		var trick := TrickDeck.load_trick(id)
		assert_not_null(trick, "data/tricks/%s.tres" % id)
		if trick == null:
			continue
		var key := String(id).to_upper()
		assert_eq(trick.id, id)
		assert_eq(trick.display_name, "TRICK_%s_NAME" % key)
		assert_eq(trick.description, "TRICK_%s_DESC" % key)
		assert_ne(tr(trick.display_name), trick.display_name, "i18n 有 %s" % trick.display_name)
		assert_ne(tr(trick.description), trick.description, "i18n 有 %s" % trick.description)
		assert_false(tr(trick.description).contains(","), "%s 的說明用全形逗號" % id)
		assert_eq(trick.icon.resource_path if trick.icon != null else "", "res://assets/icons/tricks/%s.png" % id)
		assert_eq(trick.is_evolution, EVOLUTIONS.has(id), "%s 是否為進化" % id)
		if EVOLUTIONS.has(id):
			assert_eq(trick.max_level, 1, "進化把戲只學一次")
		elif id == &"play_dead":
			assert_eq(trick.max_level, 1, "裝死每關一次,只學一次")
		else:
			assert_eq(trick.max_level, 3, "%s 最多 3 級" % id)
	var deck := TrickDeck.new(BASE_TRICKS)
	for evolution_id: StringName in EVOLUTIONS:
		var sources: Array = EVOLUTIONS[evolution_id]
		var found := deck.sources_of(evolution_id)
		found.sort()
		var want: Array = sources.duplicate()
		want.sort()
		assert_eq(found, want, "%s 的來源" % evolution_id)
		var a := TrickDeck.load_trick(sources[0])
		var b := TrickDeck.load_trick(sources[1])
		assert_eq(a.evolution_partner, sources[1])
		assert_eq(b.evolution_partner, sources[0])
		assert_eq(a.evolves_into, evolution_id)
		assert_eq(b.evolves_into, evolution_id)
	# 數值類新把戲(B 線套用)與能力類(A 線)
	assert_false(TrickDeck.load_trick(&"dig").is_ability)
	assert_false(TrickDeck.load_trick(&"sniff").is_ability)
	for id: StringName in [&"pounce", &"roll", &"play_dead", &"zoomies"]:
		assert_true(TrickDeck.load_trick(id).is_ability, "%s 是能力" % id)


func test_difficulty_pool_has_all_base_tricks_and_no_evolutions() -> void:
	var d := load(DIFFICULTY) as DifficultyData
	assert_eq(d.trick_pool, BASE_TRICKS + AttackTechniques.IDS)
	var deck := TrickDeck.new(d.trick_pool)
	assert_eq(deck.size(), 15)
	assert_eq(deck.evolution_ids().size(), 4)


func test_maxed_trick_is_not_offered_again() -> void:
	var deck := TrickDeck.new(BASE_TRICKS)
	var owned: Array[StringName] = [&"roll", &"roll", &"roll", &"play_dead"]
	assert_true(deck.is_maxed(&"roll", owned))
	assert_true(deck.is_maxed(&"play_dead", owned))
	for s in 200:
		var ids := _ids(deck.draw(3, _rng(s + 1), owned))
		assert_false(ids.has(&"roll"), "滿級的打滾不再出現")
		assert_false(ids.has(&"play_dead"), "裝死只學一次")


func test_evolution_is_offered_first_when_eligible() -> void:
	var deck := TrickDeck.new(BASE_TRICKS)
	var owned: Array[StringName] = [&"spin", &"spin", &"spin"]
	assert_true(deck.eligible_evolutions(owned).is_empty(), "還沒有搭檔:不能進化")
	owned.append(&"wag")
	var eligible := deck.eligible_evolutions(owned)
	assert_eq(eligible.size(), 1)
	assert_eq(eligible[0].id, &"tornado_tail")
	for s in 50:
		var options := deck.draw(3, _rng(s + 1), owned)
		assert_eq(options[0].id, &"tornado_tail", "進化一定出現,而且排第一")
		assert_eq(options.size(), 3)
		assert_false(_ids(options).has(&"spin"), "滿級的來源不再出現")
	# 搭檔先滿級也可以
	assert_eq(deck.eligible_evolutions([&"sit", &"sit", &"sit", &"bark"])[0].id, &"lion_roar")


func test_evolution_never_appears_in_normal_draws() -> void:
	var deck := TrickDeck.new(BASE_TRICKS)
	for s in 300:
		for t in deck.draw(3, _rng(s + 1), [&"spin", &"wag"]):
			assert_false(t.is_evolution, "沒到條件時不會抽到進化")


func test_choosing_evolution_replaces_both_sources() -> void:
	var evolved := watch_signal(EventBus.trick_evolved)
	for id: StringName in [&"spin", &"spin", &"wag", &"wag", &"sit"]:
		progression.apply_trick(TrickDeck.load_trick(id))
	assert_almost_eq(GameState.player_stats.move_speed, 91.0, 0.01, "搖尾巴兩次")
	progression.apply_trick(TrickDeck.load_trick(&"spin"))
	progression.apply_trick(TrickDeck.load_trick(&"tornado_tail"))
	assert_eq(GameState.active_tricks, [&"sit", &"tornado_tail"] as Array[StringName], "兩個來源全部換成進化")
	assert_eq(evolved.count, 1)
	assert_eq(evolved.last_args(), [&"tornado_tail"])
	assert_almost_eq(GameState.player_stats.move_speed, 70.0 * 1.45, 0.01, "旋風尾取代搖尾巴的速度(= 滿級 +45%)")
	assert_almost_eq(GameState.player_stats.damage_taken_mult, 0.8, 0.0001, "其他把戲不受影響")
	var deck := progression.get_deck()
	for s in 100:
		var ids := _ids(deck.draw(3, _rng(s + 1), GameState.active_tricks))
		assert_false(ids.has(&"spin") or ids.has(&"wag") or ids.has(&"tornado_tail"), "進化之後來源與進化都不再出現")


func test_level_up_offer_includes_evolution_and_choosing_it_emits_trick_evolved() -> void:
	for id: StringName in [&"shake", &"shake", &"shake", &"fetch"]:
		progression.apply_trick(TrickDeck.load_trick(id))
	progression.begin_level()
	var offered := watch_signal(EventBus.trick_offered)
	var evolved := watch_signal(EventBus.trick_evolved)
	EventBus.exp_collected.emit(5)
	await wait_frames(1)
	assert_eq(offered.count, 1)
	var options: Array = offered.last_args()[0]
	assert_eq((options[0] as TrickData).id, &"high_five", "升級三選一有進化(介面標「進化!」:is_evolution)")
	assert_true((options[0] as TrickData).is_evolution)
	EventBus.trick_chosen.emit(&"high_five")
	assert_eq(evolved.last_args(), [&"high_five"])
	assert_eq(GameState.active_tricks, [&"high_five"] as Array[StringName])
	assert_eq(progression.tricks_this_level, [&"high_five"] as Array[StringName])
	assert_almost_eq(GameState.player_stats.pickup_radius, 24.0 * 2.5, 0.01)
	assert_almost_eq(GameState.player_stats.exp_mult, 1.6, 0.001)


func test_bonus_trick_levels_add_copies_up_to_the_cap() -> void:
	progression.bonus_trick_levels = 1
	progression.apply_trick(TrickDeck.load_trick(&"wag"))
	assert_eq(GameState.active_tricks, [&"wag", &"wag"] as Array[StringName], "下一個把戲升兩級")
	assert_almost_eq(GameState.player_stats.move_speed, 91.0, 0.01)
	assert_eq(progression.bonus_trick_levels, 0, "用完歸零")
	progression.bonus_trick_levels = 5
	progression.apply_trick(TrickDeck.load_trick(&"wag"))
	assert_eq(TrickDeck.count_in(GameState.active_tricks, &"wag"), 3, "不超過上限")


func test_extra_bonus_sums_non_stat_modifiers() -> void:
	progression.apply_trick(TrickDeck.load_trick(&"sniff"))
	progression.apply_trick(TrickDeck.load_trick(&"sniff"))
	progression.apply_trick(TrickDeck.load_trick(&"dig"))
	assert_almost_eq(TrickDeck.extra_bonus(&"crit_chance"), 0.16, 0.0001, "嗅嗅 ×2:暴擊率 +16%(A 線讀)")
	assert_almost_eq(TrickDeck.extra_bonus(&"snack_chance"), 0.5, 0.0001, "挖寶:零食機率 +50%(A 線讀)")
	assert_almost_eq(TrickDeck.extra_bonus(&"snack_heal"), 2.0, 0.0001)
	assert_almost_eq(GameState.player_stats.pickup_radius, 24.0 * 1.6, 0.01, "嗅嗅的拾取範圍由 B 線套用")


func test_owned_weight_favors_owned_tricks() -> void:
	var deck := TrickDeck.new(BASE_TRICKS)
	var owned: Array[StringName] = [&"bark"]
	var plain := 0
	var weighted := 0
	for s in 400:
		if _ids(deck.draw(3, _rng(s + 1), owned)).has(&"bark"):
			plain += 1
	deck.owned_weight = 3.0
	for s in 400:
		if _ids(deck.draw(3, _rng(s + 1), owned)).has(&"bark"):
			weighted += 1
	assert_true(weighted > plain + 60, "學過的把戲比較常出現(%d → %d)" % [plain, weighted])


func test_snapshot_restores_run_modifiers_and_evolution() -> void:
	for id: StringName in [&"pounce", &"pounce", &"pounce", &"zoomies"]:
		progression.apply_trick(TrickDeck.load_trick(id))
	var snapshot := progression.take_snapshot()
	progression.apply_trick(TrickDeck.load_trick(&"meteor_pounce"))
	progression.add_run_modifier({"attack_damage": 0.3})
	assert_eq(GameState.player_stats.attack_damage, 13)
	progression.restore_snapshot(snapshot)
	assert_eq(GameState.active_tricks, [&"pounce", &"pounce", &"pounce", &"zoomies"] as Array[StringName])
	assert_eq(GameState.player_stats.attack_damage, 10)
	assert_true(progression.run_modifiers.is_empty())
