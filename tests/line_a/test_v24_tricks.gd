extends "res://tests/line_a/combat_test_base.gd"
## AV1、AV5:v2.4 的能力把戲(撲擊、打滾、裝死、暴衝)與進化(旋風尾、獅王吼、擊掌連打、流星撲擊)。
## 前半用替身宿主與模擬時間;後半在真的場地裡確認金毛的動作與畫面節點。

const FakeHost := preload("res://tests/line_a/fake_ability_host.gd")
const TUNING: AbilityTuning = preload("res://data/player/ability_tuning.tres")
const STEP := 1.0 / 60.0

var host: FakeHost
var abilities: AbilitySet


func before_each() -> void:
	host = FakeHost.new()
	add_child(host)
	var target := Node2D.new()
	host.add_child(target)
	host.targets.append(target)
	abilities = AbilitySet.new(host, TUNING)


func _simulate(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		abilities.update(STEP)


# --- 替身宿主 ------------------------------------------------------------------------

func test_new_ids_are_abilities_and_stat_tricks_are_not() -> void:
	for id: StringName in [&"pounce", &"roll", &"play_dead", &"zoomies",
			&"tornado_tail", &"lion_roar", &"high_five", &"meteor_pounce"]:
		assert_true(AbilitySet.is_ability(id), "%s 是能力" % id)
	for id: StringName in [&"dig", &"sniff", &"wag", &"sit", &"fetch"]:
		assert_false(AbilitySet.is_ability(id), "%s 是數值類(B 線)" % id)
	assert_eq(AbilitySet.evolution_of(&"zoomies"), &"meteor_pounce")
	assert_eq(AbilitySet.evolution_of(&"sit"), &"lion_roar")
	assert_eq(AbilitySet.evolution_of(&"roll"), &"")


func test_pounce_range_min_distance_and_cooldown() -> void:
	abilities.add_trick(&"pounce")
	var p := abilities.pounce
	assert_almost_eq(p.reach(), 60.0, 0.001)
	assert_false(p.try_pounce(10.0), "敵人已經在身邊就不撲")
	assert_false(p.try_pounce(70.0), "超過 60 像素不撲")
	assert_true(p.try_pounce(40.0), "範圍內就撲")
	assert_false(p.try_pounce(40.0), "冷卻中")
	_simulate(p.cooldown() + 0.05)
	assert_true(p.try_pounce(40.0), "冷卻好了再撲")
	abilities.add_trick(&"pounce")
	assert_almost_eq(p.reach(), 68.0, 0.001, "兩層:範圍 +8")
	assert_almost_eq(p.cooldown(), 1.6 * 0.85, 0.001, "兩層:冷卻 ×0.85")


func test_roll_is_brief_invulnerability_with_cooldown() -> void:
	assert_false(abilities.roll.try_roll(), "沒學不會滾")
	abilities.add_trick(&"roll")
	assert_true(abilities.roll.try_roll())
	assert_true(abilities.is_invulnerable(), "翻滾中無敵")
	assert_true(abilities.speed_mult() > 1.0, "翻滾時稍微加速")
	_simulate(0.32)
	assert_false(abilities.is_invulnerable(), "0.3 秒後結束")
	assert_false(abilities.roll.try_roll(), "冷卻 3 秒")
	_simulate(2.7)
	assert_true(abilities.roll.try_roll())


func test_play_dead_has_one_use_per_stack() -> void:
	assert_false(abilities.play_dead.try_save())
	abilities.add_trick(&"play_dead")
	assert_true(abilities.play_dead.try_save())
	assert_false(abilities.play_dead.try_save(), "每關一次")
	abilities.rebuild([&"play_dead", &"play_dead"])
	assert_eq(abilities.play_dead.uses_left, 2, "兩層:每關兩次")


func test_zoomies_boosts_speed_after_a_kill() -> void:
	abilities.on_kill()
	assert_almost_eq(abilities.speed_mult(), 1.0, 0.001, "沒學不加速")
	abilities.add_trick(&"zoomies")
	abilities.on_kill()
	assert_almost_eq(abilities.speed_mult(), 1.3, 0.001, "打倒敵人後 +30%")
	_simulate(1.9)
	assert_true(abilities.is_zooming())
	abilities.on_kill()
	_simulate(1.9)
	assert_true(abilities.is_zooming(), "再打倒會重新計時")
	_simulate(0.2)
	assert_false(abilities.is_zooming(), "2 秒後結束")


func test_tornado_tail_hits_around_the_player_continuously() -> void:
	abilities.add_trick(&"tornado_tail")
	_simulate(4.6)
	assert_eq(abilities.triggers(&"tornado_tail"), 10, "每 0.45 秒打一次")
	assert_eq(host.hits.size(), 10)
	assert_eq(host.hits[0][1], roundi(10 * TUNING.tornado_damage_mult))
	host.targets.clear()
	_simulate(2.0)
	assert_eq(abilities.triggers(&"tornado_tail"), 10, "附近沒有敵人時不打")


func test_lion_roar_is_a_bigger_bark_that_hurts_and_guards() -> void:
	abilities.add_trick(&"lion_roar")
	assert_almost_eq(abilities.lion_roar.radius(), TUNING.bark_radius * 2.0, 0.001, "範圍是吠叫的兩倍")
	_simulate(8.05)
	assert_eq(abilities.triggers(&"lion_roar"), 1)
	assert_eq(host.hits.size(), 1, "會造成傷害")
	assert_eq(host.hits[0][1], 15)
	assert_eq(host.stuns.size(), 1, "也會震懾")
	assert_almost_eq(abilities.damage_taken_mult(), 0.5, 0.001, "震懾期間受到的傷害減半")
	_simulate(1.6)
	assert_almost_eq(abilities.damage_taken_mult(), 1.0, 0.001, "震懾結束後恢復")
	assert_eq(host.visuals[0][0], &"lion_roar")


func test_high_five_every_third_landed_swing_throws_a_paw() -> void:
	abilities.add_trick(&"high_five")
	var mults: Array[float] = []
	for i in 6:
		mults.append(abilities.on_swing_landed())
	assert_eq(mults, [1.0, 1.0, 1.5, 1.0, 1.0, 1.5] as Array[float])
	assert_eq(host.projectiles.size(), 2, "每第 3 下放一個掌印")
	assert_eq(host.projectiles[0][0], &"paw")
	assert_eq(host.projectiles[0][1], 15, "掌印傷害 = 攻擊力 × 1.5")


func test_meteor_pounce_impacts_on_landing_and_keeps_zoomies() -> void:
	abilities.add_trick(&"meteor_pounce")
	assert_eq(abilities.active_pounce(), abilities.meteor, "流星撲擊取代撲擊")
	assert_true(abilities.meteor.reach() > TUNING.pounce_range, "撲得更遠")
	abilities.meteor.on_land()
	assert_eq(host.hits.size(), 1, "落地衝擊打中附近的敵人")
	assert_eq(host.visuals[0][0], &"meteor")
	abilities.on_kill()
	assert_true(abilities.is_zooming(), "保留暴衝")


func test_evolution_replaces_both_sources_and_does_not_stack() -> void:
	abilities.rebuild([&"spin", &"spin", &"spin", &"wag", &"bark"])
	assert_eq(abilities.stacks(&"spin"), 3)
	assert_true(abilities.evolve(&"tornado_tail"), "第一次進化")
	assert_eq(abilities.stacks(&"spin"), 0, "轉圈由旋風尾取代")
	assert_eq(abilities.stacks(&"tornado_tail"), 1)
	assert_false(abilities.evolve(&"tornado_tail"), "重複收到不會再換")
	assert_true(abilities.add_trick(&"tornado_tail"))
	assert_eq(abilities.stacks(&"tornado_tail"), 1, "進化把戲最多一層")
	abilities.add_trick(&"spin")
	assert_eq(abilities.stacks(&"spin"), 0, "已進化:原把戲不再單獨生效")
	assert_eq(abilities.stacks(&"bark"), 1, "其他把戲不受影響")


func test_rebuild_with_evolutions_suppresses_sources() -> void:
	# B 線會把原把戲從 active_tricks 移除;即使還留著,進化也優先。
	abilities.rebuild([&"lion_roar", &"bark", &"high_five", &"meteor_pounce", &"pounce", &"roll"])
	assert_eq(abilities.stacks(&"lion_roar"), 1)
	assert_eq(abilities.stacks(&"bark"), 0)
	assert_eq(abilities.stacks(&"high_five"), 1)
	assert_eq(abilities.stacks(&"meteor_pounce"), 1)
	assert_eq(abilities.stacks(&"pounce"), 0)
	assert_eq(abilities.stacks(&"roll"), 1)


# --- 真的場地 ------------------------------------------------------------------------

func test_player_rebuilds_evolutions_and_listens_to_trick_evolved() -> void:
	GameState.active_tricks.assign([&"tornado_tail", &"shake", &"shake", &"fetch"])
	make_arena()
	assert_eq(player.abilities.stacks(&"tornado_tail"), 1, "進場時重建進化把戲")
	assert_true(_has_tornado_fx(player), "旋風尾有持續的旋風畫面")
	EventBus.trick_chosen.emit(&"high_five")
	EventBus.trick_evolved.emit(&"high_five")
	assert_eq(player.abilities.stacks(&"shake"), 0, "握手由擊掌連打取代")
	assert_eq(player.abilities.stacks(&"high_five"), 1, "trick_chosen 與 trick_evolved 都收到也只有一層")


func _has_tornado_fx(node: Node) -> bool:
	for child in node.get_children():
		if child is TornadoFx:
			return true
	return false


func test_pounce_leaps_to_a_nearby_enemy_and_swings() -> void:
	GameState.active_tricks.assign([&"pounce"])
	make_arena()
	player.set_move_override(Vector2.ZERO)
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(48, 0))
	enemy.set_physics_process(false)
	var start := player.global_position
	var hp := enemy.hp
	var pounced := await wait_until(func() -> bool: return player.is_pouncing(), 20)
	assert_true(pounced, "停下時撲向 60 像素內的敵人")
	await wait_until(func() -> bool: return not player.is_pouncing(), 30)
	assert_true(player.global_position.distance_to(start) > 20.0, "撲過去了")
	assert_true(enemy.hp < hp, "落地就揮劍")
	assert_eq(player.abilities.triggers(&"pounce"), 1)


func test_meteor_pounce_landing_hurts_enemies_around() -> void:
	GameState.active_tricks.assign([&"meteor_pounce"])
	make_arena()
	player.set_move_override(Vector2.ZERO)
	var a := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -60))
	var b := spawn(&"scarecrow_elite", player.global_position + Vector2(18, -62))
	a.set_physics_process(false)
	b.set_physics_process(false)
	var landed := await wait_until(func() -> bool: return player.abilities.meteor.impacts > 0, 60)
	assert_true(landed, "落地衝擊打中敵人")
	assert_true(a.hp < a.max_hp and b.hp < b.max_hp, "衝擊範圍內的敵人都受傷")


func test_roll_makes_the_player_invulnerable_when_starting_to_move() -> void:
	GameState.active_tricks.assign([&"roll"])
	make_arena()
	player.set_move_override(Vector2.ZERO)
	await wait_physics(2)
	player.set_move_override(Vector2.RIGHT)
	await wait_physics(2)
	assert_true(player.abilities.roll.is_rolling(), "開始移動時翻滾")
	player.take_damage(30)
	assert_eq(GameState.vigor, 100, "翻滾中不會受傷")


func test_play_dead_saves_the_player_once_per_level() -> void:
	GameState.active_tricks.assign([&"play_dead"])
	make_arena()
	var downed := watch_signal(EventBus.player_downed)
	GameState.vigor = 5
	player.take_damage(50)
	assert_eq(GameState.vigor, 1, "改為剩 1 活力")
	assert_false(player.is_downed())
	assert_true(player.is_waking(), "先倒下裝死一下")
	assert_eq(player.play_dead_count, 1)
	player.take_damage(50)
	assert_eq(GameState.vigor, 1, "之後無敵 2 秒")
	await wait_until(func() -> bool: return not player.is_waking(), 60)
	assert_true(player.invuln_left > 1.0, "起身後還有無敵時間")
	player.invuln_left = 0.0
	player.take_damage(50)
	assert_true(player.is_downed(), "每關只有一次")
	assert_eq(downed.count, 1)


func test_zoomies_makes_the_player_faster_after_a_kill() -> void:
	GameState.active_tricks.assign([&"zoomies"])
	make_arena()
	var enemy := spawn(&"scarecrow", Vector2(20, 90))
	enemy.set_physics_process(false)
	player.set_move_override(Vector2.UP)
	await wait_physics(10)
	var normal := player.velocity.length()
	enemy.die()
	await wait_physics(10)
	assert_true(player.velocity.length() > normal * 1.2, "打倒敵人後跑得更快")
	assert_almost_eq(GameState.player_stats.move_speed, 70.0, 0.001, "不改 player_stats(B 線的)")


func test_lion_roar_halves_damage_while_enemies_are_stunned() -> void:
	GameState.active_tricks.assign([&"lion_roar"])
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -40))
	enemy.set_physics_process(false)
	player.abilities.lion_roar.timer = TUNING.roar_cooldown
	await wait_physics(2)
	assert_eq(player.abilities.triggers(&"lion_roar"), 1)
	assert_true(enemy.hp < enemy.max_hp, "獅王吼造成傷害")
	player.take_damage(20)
	assert_eq(GameState.vigor, 90, "震懾期間減傷 50%")


func test_high_five_paw_print_flies_to_an_enemy() -> void:
	GameState.active_tricks.assign([&"high_five"])
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(50, -30))
	enemy.set_physics_process(false)
	var hp := enemy.hp
	player.ability_projectile(&"paw", 15)
	assert_eq(get_tree().get_nodes_in_group(PawPrint.GROUP).size(), 1)
	var hit := await wait_until(func() -> bool: return enemy.hp < hp, 60)
	assert_true(hit, "掌印飛過去打中")
	assert_eq(hp - enemy.hp, 15)


func test_sniff_adds_crit_chance() -> void:
	make_arena()
	assert_almost_eq(player.crit_chance(), 0.0, 0.0001)
	GameState.active_tricks.assign([&"sniff", &"sniff"])
	assert_almost_eq(player.crit_chance(), 0.16, 0.0001, "每層 +8%")
	var many: Array[StringName] = []
	for i in 13:
		many.append(&"sniff")
	GameState.active_tricks.assign(many)
	player.set_move_override(Vector2.ZERO)
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(16, 0))
	enemy.set_physics_process(false)
	var crit := await wait_until(func() -> bool: return player.crit_count > 0, 60)
	assert_true(crit, "暴擊率滿了一定暴擊")
	assert_eq(enemy.max_hp - enemy.hp, roundi(10 * TUNING.crit_multiplier), "暴擊 ×1.5")


func test_evolution_has_a_visual_flourish() -> void:
	GameState.active_tricks.assign([&"bark", &"sit"])
	make_arena()
	var rings_before := get_tree().get_nodes_in_group(RingFx.GROUP).size()
	EventBus.trick_evolved.emit(&"lion_roar")
	assert_true(get_tree().get_nodes_in_group(RingFx.GROUP).size() > rings_before, "進化時有光圈")
	assert_eq(player.abilities.stacks(&"bark"), 0)
	assert_eq(player.abilities.stacks(&"lion_roar"), 1)
