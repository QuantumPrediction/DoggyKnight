extends "res://tests/line_a/combat_test_base.gd"

const ORIGIN := Vector2(65, 150)
const HP := 1000
const ResultScreen := preload("res://ui/screens/results.gd")


func _start(hero: StringName = &"knight") -> void:
	GameState.hero_class = hero
	GameState.reset_run()
	make_arena()
	player.global_position = Vector2(40, 150)
	player.facing = Vector2.RIGHT
	player.set_physics_process(false)


func after_each() -> void:
	GameState.hero_class = &"knight"
	await super()


func _body(at: Vector2) -> EnemyBase:
	var enemy := spawn(&"scarecrow", at)
	enemy.set_physics_process(false)
	enemy.hp = HP
	return enemy


func _cast(levels: Vector3i, primary: EnemyBase) -> TechniqueVolley:
	return TechniqueVolley.launch(player, primary.global_position, primary.get_instance_id(), Vector2.RIGHT, levels)


func _advance(volley: TechniqueVolley, frames: int) -> void:
	for i in frames:
		if volley.is_queued_for_deletion():
			break
		volley._physics_process(1.0 / 60.0)


func test_multitarget_sword_counts_one_contact_and_misses_count_zero() -> void:
	_start()
	player.abilities.add_trick(&"starfall")
	for i in 3:
		player._swing()
	assert_eq(player.abilities.triggers(&"starfall"), 0)
	_body(ORIGIN)
	_body(ORIGIN + Vector2(0, 2))
	for i in 2:
		player._swing()
	assert_eq(player.abilities.triggers(&"starfall"), 0)
	player._swing()
	assert_eq(player.abilities.triggers(&"starfall"), 1)
	assert_eq(get_tree().get_nodes_in_group(&"friendly_technique").size(), 1)


func _ranged_contacts(hero: StringName) -> void:
	_start(hero)
	player.abilities.add_trick(&"starfall")
	_body(ORIGIN)
	_body(ORIGIN + Vector2(10, 0))
	HeroProjectile.launch(player, Vector2.LEFT)._physics_process(1.0)
	HeroProjectile.launch(player, Vector2.RIGHT, 1.0, true)._physics_process(1.0)
	for i in 2:
		HeroProjectile.launch(player, Vector2.RIGHT)._physics_process(0.6)
	assert_eq(player.abilities.triggers(&"starfall"), 0)
	HeroProjectile.launch(player, Vector2.RIGHT)._physics_process(0.6)
	assert_eq(player.abilities.triggers(&"starfall"), 1)


func test_splash_never_counts_a_second_contact_or_ultimate() -> void:
	_ranged_contacts(&"mage")


func test_pierce_never_counts_a_second_contact_or_ultimate() -> void:
	_ranged_contacts(&"archer")


func test_gale_adds_exactly_one_distinct_arc_hop() -> void:
	_start()
	var primary := _body(ORIGIN)
	var second := _body(ORIGIN + Vector2(0, 32))
	var third := _body(ORIGIN + Vector2(0, 64))
	_cast(Vector3i(1, 0, 0), primary)
	assert_true(second.hp < HP)
	assert_eq(third.hp, HP)
	assert_true(player.abilities.landed_pairs.is_empty())
	var volley := _cast(Vector3i(1, 0, 1), primary)
	assert_true(third.hp < HP)
	assert_eq(volley.arcs.size(), 2)
	assert_eq(primary.hp, HP)
	assert_eq(volley.arcs[0].pair, &"")
	assert_eq(volley.arcs[1].pair, &"arc_gale")
	assert_eq(player.abilities.landed_pairs, {&"arc_gale": 1})


func test_star_compares_positions_at_impact_and_only_a_hit_discharges() -> void:
	_start()
	var primary := _body(ORIGIN)
	var secondary := _body(ORIGIN + Vector2(0, 33))
	var volley := _cast(Vector3i(1, 1, 0), primary)
	var before := secondary.hp
	_advance(volley, 16)
	assert_eq(primary.hp, HP)
	_advance(volley, 7)
	assert_true(primary.hp < HP)
	assert_true(secondary.hp < before)
	assert_eq(player.abilities.landed_pairs, {&"arc_star": 1})
	assert_eq(volley.arcs.back().pair, &"arc_star")
	var miss := _cast(Vector3i(1, 1, 0), primary)
	before = secondary.hp
	primary.global_position += Vector2(-52, 0)
	_advance(miss, 25)
	assert_eq(secondary.hp, before, "a missed falling star cannot release lightning")
	assert_eq(player.abilities.landed_pairs, {&"arc_star": 1})


func test_disc_sweeps_forward_only_and_leaves_one_secondary_star() -> void:
	_start()
	var main := _body(ORIGIN)
	var first := _body(ORIGIN + Vector2(17, 0))
	var second := _body(ORIGIN + Vector2(32, 0))
	var third := _body(ORIGIN + Vector2(49, 0))
	var behind := _body(ORIGIN - Vector2(17, 0))
	var ally := Node2D.new()
	ally.add_to_group(&"companion")
	arena.add_child(ally)
	ally.global_position = first.global_position
	var volley := _cast(Vector3i(0, 1, 1), main)
	_advance(volley, 16)
	assert_eq(volley.blade_hits, 2)
	assert_eq(volley.stars.size(), 2)
	assert_true(player.abilities.landed_pairs.is_empty(), "planting a secondary star is not a hit")
	assert_true(first.hp < HP and second.hp < HP)
	assert_eq(third.hp, HP)
	assert_eq(behind.hp, HP)
	var before := first.hp
	_advance(volley, 40)
	assert_true(first.hp < before)
	assert_true(volley.is_queued_for_deletion())
	assert_eq(player.abilities.triggers(&"starfall"), 0)
	assert_eq(player.abilities.landed_pairs, {&"gale_star": 1}, "one echo strike even if two enemies lose HP")


func test_solo_star_rank_and_exit_discard_pending_marks() -> void:
	_start()
	var boss := _body(ORIGIN)
	var volley := _cast(Vector3i(0, 1, 0), boss)
	_advance(volley, 30)
	var first := HP - boss.hp
	boss.hp = HP
	volley = _cast(Vector3i(0, 3, 0), boss)
	_advance(volley, 30)
	assert_true(HP - boss.hp > first)
	volley = _cast(Vector3i(0, 3, 0), boss)
	var before := boss.hp
	player.celebrating = true
	_advance(volley, 60)
	assert_eq(boss.hp, before)
	assert_true(volley.is_queued_for_deletion())
	assert_true(player.abilities.landed_pairs.is_empty())


func test_blocked_extra_bolt_cannot_award_a_mark_but_a_killing_bolt_can() -> void:
	_start()
	var main := _body(ORIGIN)
	_body(ORIGIN + Vector2(0, 32))
	var stone := spawn(&"gargoyle", ORIGIN + Vector2(0, 64)) as GargoyleEnemy
	stone.set_physics_process(false)
	stone.flight.phase = GargoyleFlight.Phase.STONE
	var hp := stone.hp
	var volley := _cast(Vector3i(1, 0, 1), main)
	assert_eq(volley.arcs.size(), 2)
	assert_eq(stone.hp, hp)
	assert_eq(volley.arcs[1].pair, &"")
	assert_true(player.abilities.landed_pairs.is_empty())
	stone.flight.phase = GargoyleFlight.Phase.HOVER
	stone.hp = 1
	volley = _cast(Vector3i(1, 0, 1), main)
	assert_eq(stone.hp, 0)
	assert_eq(volley.arcs[1].pair, &"arc_gale")
	assert_eq(player.abilities.landed_pairs, {&"arc_gale": 1})


func test_an_echo_whose_targets_move_away_is_not_counted() -> void:
	_start()
	var main := _body(ORIGIN)
	var other := _body(ORIGIN + Vector2(27, 0))
	var volley := _cast(Vector3i(0, 1, 1), main)
	_advance(volley, 13)
	assert_eq(volley.stars.size(), 2)
	other.global_position += Vector2(0, 60)
	_advance(volley, 40)
	assert_true(player.abilities.landed_pairs.is_empty())


func test_all_three_marks_share_a_room_but_never_recurse_or_cross_rooms() -> void:
	_start()
	var main := _body(ORIGIN)
	_body(ORIGIN + Vector2(17, 0))
	_body(ORIGIN + Vector2(34, 0))
	var volley := _cast(Vector3i(1, 1, 1), main)
	_advance(volley, 80)
	assert_eq(player.abilities.landed_pairs, {&"arc_gale": 1, &"arc_star": 1, &"gale_star": 1})
	player.take_damage(1000000)
	assert_true(player.is_downed())
	player.revive()
	assert_false(player.is_downed())
	assert_eq(player.abilities.landed_pairs.size(), 3)
	var old_arena := arena
	remove_child(old_arena)
	old_arena.queue_free()
	make_arena()
	assert_true(player.abilities.landed_pairs.is_empty())


func test_result_reuses_the_three_card_illustrations_and_only_shows_real_pairs() -> void:
	var result := (load("res://ui/screens/results.tscn") as PackedScene).instantiate() as ResultScreen
	add_child(result)
	result.setup({"tricks": AttackTechniques.IDS, "landed_pairs": {&"arc_star": 19, &"gale_star": 2}})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(result.pairs_box.get_child_count(), 3)
	assert_eq(result.pairs_box.get_node("arc_star").get_child(2).text, tr("UI_PAIR_COUNT") % 19)
	assert_eq(result.pairs_box.get_node("gale_star").get_child(0).texture.region, Rect2(192, 0, 96, 96))
	for i in AttackTechniques.IDS.size():
		var icon := result.tricks_row.get_child(i).get_child(0) as TextureRect
		assert_eq(icon.texture, TrickDeck.load_trick(AttackTechniques.IDS[i]).icon)
		assert_eq(icon.size, Vector2(16, 16))
	result.setup({"tricks": [], "landed_pairs": {&"arc_gale": 0}})
	assert_false(result.pairs_box.visible)
	result.setup({})
	assert_eq(result.pairs_box.get_child_count(), 0)


func test_full_pair_report_and_chapter_departure_fit_the_notched_screen() -> void:
	var prior := SafeArea.simulate_notch
	SafeArea.simulate_notch = true
	var result := (load("res://ui/screens/results.tscn") as PackedScene).instantiate() as ResultScreen
	add_child(result)
	result.setup({"tricks": AttackTechniques.IDS, "chapter": 1, "is_final": true, "stars": 3,
			"landed_pairs": {&"arc_star": 17, &"arc_gale": 9, &"gale_star": 10}})
	for i in 6:
		await get_tree().process_frame
	result._anim_tween.kill()
	result._panel.scale = Vector2.ONE
	result._layout()
	var safe := SafeArea.get_safe_rect()
	var go := result.continue_button.get_global_rect()
	var rest := result._rest_button.get_global_rect()
	assert_true(safe.encloses(go) and safe.encloses(rest))
	assert_false(go.intersects(rest))
	for star in result.star_rects:
		assert_eq(star.size, Vector2(26, 26))
	assert_eq(result.pairs_box.get_child_count(), 4)
	for id in AttackTechniques.PAIR_IDS:
		var row := result.pairs_box.get_node(NodePath(id)) as HBoxContainer
		assert_true(result._scroll.get_global_rect().encloses(row.get_global_rect()))
		assert_false(row.get_child(1).get_global_rect().intersects(row.get_child(2).get_global_rect()))
	SafeArea.simulate_notch = prior


func test_cards_preserve_evolution_and_route_and_explain_both_pairs() -> void:
	var deck := TrickDeck.new((load("res://game/progression/difficulty.tres") as DifficultyData).trick_pool)
	var offer: Array[TrickData] = [deck.get_trick(&"tornado_tail"), deck.get_trick(&"spin"), deck.get_trick(&"dig")]
	var route := BuildRoutes.get_route(&"bulwark")
	offer[1] = deck.get_trick(route.preferred[0])
	var next := AttackTechniques.guide_offer(offer, deck, [], &"knight", 2, route.id)
	assert_eq(next[0], offer[0])
	assert_eq(next[1], offer[1])
	assert_eq(next[2].id, &"gale_disc")
	next = AttackTechniques.guide_offer(offer, deck, [&"gale_disc"], &"knight", 3, route.id)
	assert_eq(next[2].id, &"arc_rune")
	assert_eq(AttackTechniques.pair_hints(&"arc_rune", [&"starfall", &"gale_disc"]).size(), 2)
	for id in AttackTechniques.IDS:
		assert_true(deck.has_trick(id))
		assert_true(deck.is_maxed(id, [id, id, id]))

func test_large_painted_card_icons_fit_the_visible_cards_after_layout() -> void:
	var menu := (load("res://ui/trick_choice/trick_choice.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	var cards: Array[TrickData] = []
	for id in AttackTechniques.IDS:
		cards.append(TrickDeck.load_trick(id))
	menu.show_options(cards)
	await get_tree().process_frame
	await get_tree().process_frame
	for card: Button in menu.cards:
		var image := card.get_node("CardIcon") as TextureRect
		assert_eq(image.size, Vector2(32, 32))
		assert_true(Rect2(Vector2.ZERO, card.size).encloses(image.get_rect()))
