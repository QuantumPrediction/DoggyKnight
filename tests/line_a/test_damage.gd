extends "res://tests/line_a/combat_test_base.gd"
## A2、A3:傷害公式(含 next_level_bonus 與 damage_taken_mult)、活力、無敵時間、player_downed。


func test_player_damage_formula() -> void:
	var stats := StatBlock.new()
	assert_eq(CombatMath.player_damage(stats, 0.0), 10, "基準攻擊力")
	assert_eq(CombatMath.player_damage(stats, 0.1), 11, "下一關加成 +10%")
	assert_eq(CombatMath.player_damage(stats, 0.15), 12, "11.5 四捨五入")
	assert_eq(CombatMath.player_damage(stats, 0.0, 2.0), 20, "握手雙倍")
	assert_eq(CombatMath.player_damage(stats, 0.05, 2.0), 21)
	stats.attack_damage = 1
	assert_eq(CombatMath.player_damage(stats, 0.0, 0.1), 1, "最少 1")


func test_damage_taken_formula() -> void:
	var stats := StatBlock.new()
	assert_eq(CombatMath.damage_taken(8, stats), 8)
	stats.damage_taken_mult = 0.8
	assert_eq(CombatMath.damage_taken(8, stats), 6, "坐下:8 × 0.8 = 6.4")
	assert_eq(CombatMath.damage_taken(22, stats), 18, "22 × 0.8 = 17.6")
	assert_eq(CombatMath.damage_taken(1, stats), 1, "最少 1")
	assert_eq(CombatMath.damage_taken(0, stats), 0)


func test_player_announces_vigor_and_loyalty_on_enter() -> void:
	var vigor := watch_signal(EventBus.vigor_changed)
	var loyalty := watch_signal(EventBus.loyalty_changed)
	GameState.vigor = 70
	make_arena()
	assert_eq(vigor.count, 1, "進場時發一次 vigor_changed")
	assert_eq(vigor.last_args(), [70, 100])
	assert_eq(loyalty.count, 1)
	assert_eq(loyalty.last_args(), [0.0, 100.0])


func test_take_damage_applies_mult_writes_vigor_and_emits() -> void:
	make_arena()
	var vigor := watch_signal(EventBus.vigor_changed)
	var damaged := watch_signal(EventBus.player_damaged)
	GameState.player_stats.damage_taken_mult = 0.8
	player.take_damage(10)
	assert_eq(GameState.vigor, 92)
	assert_eq(damaged.last_args(), [8])
	assert_eq(vigor.last_args(), [92, 100])
	player.take_damage(10)
	assert_eq(GameState.vigor, 92, "無敵時間內不再受傷")
	assert_true(player.invuln_left > 0.0)
	player.invuln_left = 0.0
	player.take_damage(10)
	assert_eq(GameState.vigor, 84)
	assert_eq(vigor.count, 2)


func test_invulnerability_wears_off_and_player_blinks() -> void:
	make_arena()
	player.take_damage(5)
	await wait_physics(6)
	var blinked := false
	for i in 20:
		if not player.sprite.visible:
			blinked = true
		await get_tree().physics_frame
	assert_true(blinked, "受擊後閃爍")
	await wait_physics(40)
	assert_eq(player.invuln_left, 0.0, "無敵時間結束")
	assert_true(player.sprite.visible)


func test_heal_caps_at_max_vigor() -> void:
	make_arena()
	GameState.vigor = 50
	var vigor := watch_signal(EventBus.vigor_changed)
	player.heal(30)
	assert_eq(GameState.vigor, 80)
	player.heal(100)
	assert_eq(GameState.vigor, 100)
	assert_eq(vigor.last_args(), [100, 100])


func test_player_downed_once_and_falls_asleep() -> void:
	make_arena()
	var downed := watch_signal(EventBus.player_downed)
	GameState.vigor = 5
	player.take_damage(50)
	assert_eq(GameState.vigor, 0)
	assert_eq(downed.count, 1)
	assert_true(player.is_downed())
	player.invuln_left = 0.0
	player.take_damage(10)
	player.take_damage(10)
	assert_eq(downed.count, 1, "player_downed 只發一次")
	player.heal(10)
	assert_eq(GameState.vigor, 0, "睡著後不回復(重試由 B 線重設活力)")
	await wait_physics(3)
	assert_eq(player.sprite.animation, &"sleep")
	assert_eq(player.velocity, Vector2.ZERO)
	assert_false(player.joystick.enabled, "睡著後不能操作")


func test_swing_damage_uses_live_stats_and_next_level_bonus() -> void:
	make_arena()
	GameState.next_level_bonus = 0.5
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(18, 0))
	enemy.set_physics_process(false)
	var landed := await wait_until(func() -> bool: return enemy.hp < 75, 60)
	assert_true(landed, "停下時自動攻擊附近的敵人")
	assert_eq(enemy.hp, 75 - 15, "10 × (1 + 0.5) = 15")
	assert_eq(player.last_swing_damage, 15)
	GameState.player_stats.attack_damage = 20
	var hp_before := enemy.hp
	landed = await wait_until(func() -> bool: return enemy.hp < hp_before, 60)
	assert_true(landed)
	assert_eq(hp_before - enemy.hp, 30, "把戲在關卡中改變數值,下一下立刻生效")


func test_swings_build_loyalty() -> void:
	make_arena()
	var loyalty := watch_signal(EventBus.loyalty_changed)
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(-18, 0))
	enemy.set_physics_process(false)
	await wait_until(func() -> bool: return loyalty.count > 0, 60)
	assert_almost_eq(player.loyalty, player.tuning.loyalty_per_hit, 0.001)
	assert_eq(loyalty.last_args(), [player.tuning.loyalty_per_hit, player.tuning.loyalty_max])


func test_revive_wakes_the_player_up() -> void:
	make_arena()
	GameState.vigor = 1
	player.take_damage(5)
	assert_true(player.is_downed())
	var vigor := watch_signal(EventBus.vigor_changed)
	player.revive()
	assert_false(player.is_downed())
	assert_eq(GameState.vigor, 100)
	assert_eq(vigor.last_args(), [100, 100])
	assert_true(player.joystick.enabled)
