extends "res://tests/line_a/combat_test_base.gd"
## A7:經驗珠被吸過去、拾取時發 exp_collected(原始值)、拾取範圍即時讀取。


func _keep_one_enemy_alive() -> void:
	# 場上沒有敵人時經驗珠會自動飛過來;這些測試要確認「範圍」本身,所以留一隻不會動的敵人。
	var enemy := spawn(&"scarecrow", Vector2(20, 90))
	enemy.set_physics_process(false)


func test_orb_pickup_emits_exp_collected_with_raw_value() -> void:
	make_arena()
	_keep_one_enemy_alive()
	var collected := watch_signal(EventBus.exp_collected)
	var orb := arena.spawn_exp_orb(player.global_position + Vector2(8, 0), 3)
	var done := await wait_until(func() -> bool: return collected.count > 0, 90)
	assert_true(done, "靠近時被吸過去")
	assert_eq(collected.count, 1)
	assert_eq(collected.last_args(), [3], "原始值,exp_mult 由 B 線套用")
	await get_tree().process_frame
	assert_false(is_instance_valid(orb))


func test_pickup_radius_is_read_live() -> void:
	make_arena()
	_keep_one_enemy_alive()
	player.set_physics_process(false)
	var collected := watch_signal(EventBus.exp_collected)
	arena.spawn_exp_orb(player.global_position + Vector2(60, 0), 1)
	await wait_physics(45)
	assert_eq(collected.count, 0, "範圍外不會被吸")
	GameState.player_stats.pickup_radius = 100.0
	var done := await wait_until(func() -> bool: return collected.count > 0, 90)
	assert_true(done, "尋回把戲擴大範圍後立刻生效")


func test_enemy_death_drops_an_orb_the_player_can_pick_up() -> void:
	make_arena()
	var collected := watch_signal(EventBus.exp_collected)
	var enemy := spawn(&"scarecrow", player.global_position + Vector2(0, -12))
	enemy.take_damage(999)
	var done := await wait_until(func() -> bool: return collected.count > 0, 120)
	assert_true(done)
	assert_eq(collected.last_args(), [1])


func test_orbs_fly_in_when_the_arena_is_clear() -> void:
	make_arena()
	player.set_physics_process(false)
	var collected := watch_signal(EventBus.exp_collected)
	arena.spawn_exp_orb(Vector2(160, 100), 2)
	var done := await wait_until(func() -> bool: return collected.count > 0, 180)
	assert_true(done, "清場後自動飛向金毛")


func test_no_pickup_while_player_is_asleep() -> void:
	make_arena()
	var collected := watch_signal(EventBus.exp_collected)
	GameState.vigor = 1
	player.take_damage(5)
	arena.spawn_exp_orb(player.global_position + Vector2(6, 0), 1)
	await wait_physics(60)
	assert_eq(collected.count, 0)
