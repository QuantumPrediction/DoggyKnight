extends "res://tests/line_a/combat_test_base.gd"
## AV2、AV3、AV4、AV5:寶箱、零食與可愛的復活。

const LOOT: LootTuning = preload("res://data/enemies/loot_tuning.tres")


func after_each() -> void:
	Loot.set_tuning(null)
	GameState.meta_upgrades = {}
	await super()


func _tuning(chest: float, snack: float) -> LootTuning:
	var t := LOOT.duplicate() as LootTuning
	t.chest_chance = chest
	t.chest_chance_max = maxf(chest, t.chest_chance_max)
	t.snack_chance = snack
	t.snack_chance_max = maxf(snack, t.snack_chance_max)
	t.luck_bonus_per_level = 0.0
	Loot.set_tuning(t)
	return t


func _keep_one_enemy_alive() -> EnemyBase:
	var enemy := spawn(&"scarecrow", Vector2(20, 90))
	enemy.set_physics_process(false)
	return enemy


# --- 掉落規則 -----------------------------------------------------------------------

func test_luck_and_dig_raise_drop_chances() -> void:
	var chest0 := Loot.chest_chance()
	var snack0 := Loot.snack_chance()
	assert_almost_eq(chest0, LOOT.chest_chance, 0.0001)
	assert_true(chest0 < 0.05, "一般敵人極少掉寶箱")
	GameState.meta_upgrades = {"luck": 3}
	assert_eq(Loot.luck_level(), 3, "鍵是 String 也讀得到")
	assert_almost_eq(Loot.chest_chance(), LOOT.chest_chance * 1.45, 0.0001, "luck 每級 +15%")
	assert_true(Loot.snack_chance() > snack0, "luck 提高零食機率")
	GameState.meta_upgrades = {&"luck": 0}
	GameState.active_tricks.assign([&"dig"])
	assert_almost_eq(Loot.snack_chance(), snack0 * 1.5, 0.0001, "挖寶:零食機率 +50%")
	GameState.meta_upgrades = {&"luck": 99}
	assert_almost_eq(Loot.chest_chance(), LOOT.chest_chance_max, 0.0001, "有上限")


func test_guaranteed_chest_tiers() -> void:
	assert_eq(Loot.guaranteed_chest_tier(&"scarecrow_elite", true, false), 1, "精英必掉精英寶箱")
	assert_eq(Loot.guaranteed_chest_tier(&"scarecrow_captain", false, true), 2, "中頭目必掉")
	assert_eq(Loot.guaranteed_chest_tier(&"black_knight", false, true), 2, "頭目必掉")
	assert_eq(Loot.guaranteed_chest_tier(&"scarecrow", false, false), -1, "一般敵人不是必掉")
	assert_eq(Loot.guaranteed_chest_tier(&"someone_new", true, false), 1, "其他精英也必掉")


# --- 寶箱 ---------------------------------------------------------------------------

func test_elite_drops_a_chest_that_opens_on_touch() -> void:
	_tuning(0.0, 0.0)
	make_arena()
	_keep_one_enemy_alive()
	player.set_physics_process(false)
	var collected := watch_signal(EventBus.chest_collected)
	var elite := spawn(&"scarecrow_elite", player.global_position + Vector2(40, -40))
	elite.die()
	await wait_physics(2)
	var chests := arena.get_chests()
	assert_eq(chests.size(), 1, "精英倒下掉一個寶箱")
	var chest := chests[0] as TreasureChest
	assert_eq(chest.tier, 1)
	await wait_physics(40)
	assert_eq(collected.count, 0, "還有敵人時寶箱不會自己飛過來")
	player.global_position = chest.global_position + Vector2(4, 0)
	var opened := await wait_until(func() -> bool: return collected.count > 0, 10)
	assert_true(opened, "金毛碰到就打開")
	assert_eq(collected.last_args(), [1])
	assert_true(chest.is_open())
	await wait_physics(5)
	assert_eq(collected.count, 1, "只發一次")
	var ref: WeakRef = weakref(chest)
	chest = null
	var gone := await wait_until(func() -> bool: return ref.get_ref() == null, 90)
	assert_true(gone, "打開後淡出消失")


func test_chests_slide_to_the_player_when_the_arena_is_clear() -> void:
	_tuning(0.0, 0.0)
	make_arena()
	player.set_physics_process(false)
	var collected := watch_signal(EventBus.chest_collected)
	arena.spawn_chest(Vector2(40, 100), 2)
	var done := await wait_until(func() -> bool: return collected.count > 0, 240)
	assert_true(done, "場上沒有敵人時自己滑向金毛")
	assert_eq(collected.last_args(), [2])


func test_normal_enemies_rarely_drop_chests_and_the_cap_holds() -> void:
	var t := _tuning(1.0, 0.0)
	t.max_random_chests = 2
	make_arena()
	_keep_one_enemy_alive()
	player.set_physics_process(false)
	for i in 4:
		spawn(&"scarecrow", Vector2(40 + 20 * i, 120)).die()
	await wait_physics(1)
	assert_eq(arena.get_chests().size(), 2, "隨機寶箱同時最多 2 個")
	assert_eq((arena.get_chests()[0] as TreasureChest).tier, 0, "一般敵人掉普通寶箱")
	arena.clear()
	_tuning(0.0, 0.0)
	_keep_one_enemy_alive()
	spawn(&"scarecrow", Vector2(60, 120)).die()
	await wait_physics(1)
	assert_eq(arena.get_chests().size(), 0, "機率 0 不掉")


# --- 零食 ---------------------------------------------------------------------------

func test_snacks_drop_get_pulled_in_and_emit_snack_collected() -> void:
	_tuning(0.0, 1.0)
	make_arena()
	_keep_one_enemy_alive()
	var collected := watch_signal(EventBus.snack_collected)
	# 零食彈出 5 至 12 像素:從 8 像素外彈出,最遠也在拾取範圍(24)之內(以前用 14,偶爾彈到範圍外)。
	var enemy := spawn(&"scarecrow", player.global_position + Vector2(0, -8))
	enemy.die()
	await wait_physics(1)
	assert_eq(arena.get_snacks().size(), 1, "掉了一個零食")
	var done := await wait_until(func() -> bool: return collected.count > 0, 120)
	assert_true(done, "被吸向金毛")
	assert_eq(collected.last_args(), [1])


func test_dig_snacks_heal_the_player() -> void:
	make_arena()
	_keep_one_enemy_alive()
	GameState.active_tricks.assign([&"dig"])
	GameState.vigor = 50
	var collected := watch_signal(EventBus.snack_collected)
	arena.spawn_snack(player.global_position + Vector2(6, 0), 1)
	await wait_until(func() -> bool: return collected.count > 0, 90)
	assert_eq(GameState.vigor, 50 + LOOT.dig_heal, "挖寶:吃到零食回復 2 活力")


func test_elite_drops_guaranteed_snacks() -> void:
	_tuning(0.0, 0.0)
	make_arena()
	_keep_one_enemy_alive()
	player.set_physics_process(false)
	spawn(&"scarecrow_elite", Vector2(90, 120)).die()
	await wait_physics(1)
	assert_eq(arena.get_snacks().size(), int(LOOT.guaranteed_snacks[&"scarecrow_elite"]))


func test_clear_removes_chests_and_snacks() -> void:
	make_arena()
	arena.spawn_chest(Vector2(40, 100), 0)
	arena.spawn_snack(Vector2(60, 100))
	arena.clear()
	assert_eq(arena.get_chests().size(), 0)
	assert_eq(arena.get_snacks().size(), 0)


# --- 復活 ---------------------------------------------------------------------------

func test_revive_is_cute_and_pushes_enemies_away() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow", player.global_position + Vector2(16, 0))
	GameState.vigor = 1
	player.take_damage(5)
	assert_true(player.is_downed())
	var before := enemy.global_position.distance_to(player.global_position)
	player.revive()
	assert_false(player.is_downed())
	assert_eq(player.revive_count, 1)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "活力回滿")
	assert_true(player.is_waking(), "先伸懶腰醒來")
	assert_true(enemy.is_stunned(), "附近的敵人被震暈")
	assert_true(player.invuln_left >= player.tuning.revive_invuln_time - 0.01, "醒來後無敵")
	player.set_move_override(Vector2.LEFT)
	var at := player.global_position
	await wait_physics(10)
	assert_true(player.global_position.distance_to(at) < 0.5, "醒來的演出期間不能動")
	await wait_until(func() -> bool: return not player.is_waking(), 60)
	assert_true(enemy.global_position.distance_to(player.global_position) > before, "被震開")
	await wait_physics(10)
	assert_true(player.global_position.distance_to(at) > 2.0, "醒來後可以動")
	player.take_damage(30)
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor, "無敵中不受傷")


func test_loyalty_training_speeds_up_loyalty_gain() -> void:
	make_arena()
	player.add_loyalty(10.0)
	assert_almost_eq(player.loyalty, 10.0, 0.001)
	GameState.meta_upgrades = {"loyalty": 3}
	player.add_loyalty(10.0)
	assert_almost_eq(player.loyalty, 23.0, 0.001, "忠誠訓練每級 +10%")
