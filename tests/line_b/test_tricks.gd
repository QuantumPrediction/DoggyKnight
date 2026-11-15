extends "res://tests/line_b/flow_test_base.gd"
## B5、B6 把戲:三選一不重複、固定種子結果相同、數值相加(以基準值計算)與疊加、資料檔合約。

const ALL_TRICKS: Array[StringName] = [&"sit", &"wag", &"fetch", &"shake", &"spin", &"bark"]


func _deck() -> TrickDeck:
	return TrickDeck.new(ALL_TRICKS)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func test_trick_data_files_match_the_contract() -> void:
	var expected := {
		&"sit": [false, {"damage_taken_mult": -0.2}],
		&"wag": [false, {"move_speed": 0.15}],
		&"fetch": [false, {"pickup_radius": 0.5, "exp_mult": 0.2}],
		&"shake": [true, {}],
		&"spin": [true, {}],
		&"bark": [true, {}],
	}
	for id: StringName in expected:
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
		assert_not_null(trick.icon, "%s 的圖示" % id)
		if trick.icon != null:
			assert_eq(trick.icon.resource_path, "res://assets/icons/tricks/%s.png" % id)
		assert_eq(trick.is_ability, expected[id][0], "%s 是否為能力" % id)
		assert_eq(trick.stat_modifiers, expected[id][1], "%s 的 stat_modifiers" % id)


func test_draw_three_distinct_for_many_seeds() -> void:
	var deck := _deck()
	assert_eq(deck.size(), 6)
	var seen := {}
	for s in 300:
		var options := deck.draw(3, _rng(s + 1))
		assert_eq(options.size(), 3)
		var ids := {}
		for t in options:
			ids[t.id] = true
			seen[t.id] = true
		assert_eq(ids.size(), 3, "種子 %d 抽到重複的把戲" % (s + 1))
	assert_eq(seen.size(), 6, "每個把戲都抽得到")


func test_draw_is_reproducible_with_a_seed() -> void:
	var deck := _deck()
	var a := deck.draw(3, _rng(42)).map(func(t: TrickData) -> StringName: return t.id)
	var b := deck.draw(3, _rng(42)).map(func(t: TrickData) -> StringName: return t.id)
	assert_eq(a, b)


func test_draw_more_than_the_pool_returns_whole_pool() -> void:
	var deck := TrickDeck.new([&"sit", &"wag"] as Array[StringName])
	assert_eq(deck.draw(3, _rng(1)).size(), 2)


func test_stat_tricks_are_additive_relative_to_base() -> void:
	var base := GameState.BASE_STATS
	var stats := base.duplicate() as StatBlock
	var deck := _deck()
	TrickDeck.apply_modifiers(stats, base, deck.get_trick(&"wag").stat_modifiers)
	assert_almost_eq(stats.move_speed, 80.5, 0.001, "70 + 70 × 0.15")
	TrickDeck.apply_modifiers(stats, base, deck.get_trick(&"wag").stat_modifiers)
	assert_almost_eq(stats.move_speed, 91.0, 0.001, "兩次:70 + 2 × 10.5(以基準值計算,不是複利)")
	TrickDeck.apply_modifiers(stats, base, deck.get_trick(&"fetch").stat_modifiers)
	assert_almost_eq(stats.pickup_radius, 36.0, 0.001, "24 + 24 × 0.5")
	assert_almost_eq(stats.exp_mult, 1.2, 0.001)
	assert_eq(stats.attack_damage, 10, "沒有提到的數值不變")


func test_sit_stacks_to_0_8_then_0_6_and_has_a_floor() -> void:
	var base := GameState.BASE_STATS
	var stats := base.duplicate() as StatBlock
	var sit := _deck().get_trick(&"sit").stat_modifiers
	TrickDeck.apply_modifiers(stats, base, sit, 0.2)
	assert_almost_eq(stats.damage_taken_mult, 0.8)
	TrickDeck.apply_modifiers(stats, base, sit, 0.2)
	assert_almost_eq(stats.damage_taken_mult, 0.6)
	for i in 5:
		TrickDeck.apply_modifiers(stats, base, sit, 0.2)
	assert_almost_eq(stats.damage_taken_mult, 0.2, 0.0001, "不會低於 min_damage_taken_mult")


func test_integer_fields_round() -> void:
	var base := GameState.BASE_STATS
	var stats := base.duplicate() as StatBlock
	TrickDeck.apply_modifiers(stats, base, {"attack_damage": 0.25})
	assert_eq(stats.attack_damage, 13, "10 + 2.5 → 四捨五入")


func test_unknown_stat_is_ignored() -> void:
	var base := GameState.BASE_STATS
	var stats := base.duplicate() as StatBlock
	TrickDeck.apply_modifiers(stats, base, {"not_a_stat": 1.0})
	assert_almost_eq(stats.move_speed, 70.0)


func test_progression_applies_stat_trick_to_game_state() -> void:
	GameState.reset_run()
	var progression := RunProgression.new()
	progression.setup(load(DIFFICULTY) as DifficultyData, 5)
	add_child(progression)
	progression.reset_run()
	progression.apply_trick(TrickDeck.load_trick(&"sit"))
	progression.apply_trick(TrickDeck.load_trick(&"sit"))
	progression.apply_trick(TrickDeck.load_trick(&"spin"))
	assert_almost_eq(GameState.player_stats.damage_taken_mult, 0.6)
	assert_eq(GameState.active_tricks, [&"sit", &"sit", &"spin"] as Array[StringName], "能力類只記錄 id")
	assert_almost_eq(GameState.BASE_STATS.damage_taken_mult, 1.0, 0.0001, "基準數值不被改")
	remove_child(progression)
	progression.free()
