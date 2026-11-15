extends "res://tests/line_a/combat_test_base.gd"
## A4、A5、A6、A11:敵人資料、死亡訊號、離開群組、擊退與閃白、暈眩、分離、預警、頭目階段與倒下。


func test_enemy_data_files_match_dev_plan() -> void:
	var expected := {
		&"scarecrow": [25, 8, 28.0, 1, "ENEMY_SCARECROW"],
		&"scarecrow_elite": [75, 10, 26.0, 3, "ENEMY_SCARECROW_ELITE"],
		&"crow": [12, 6, 140.0, 1, "ENEMY_CROW"],
		&"black_knight": [450, 18, 40.0, 20, "ENEMY_BLACK_KNIGHT"],
	}
	for id: StringName in expected:
		var data := load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_not_null(data, String(id))
		if data == null:
			continue
		var row: Array = expected[id]
		assert_eq(data.id, id)
		assert_eq(data.max_hp, row[0], "%s 生命" % id)
		assert_eq(data.contact_damage, row[1], "%s 傷害" % id)
		assert_almost_eq(data.move_speed, row[2], 0.001, "%s 速度" % id)
		assert_eq(data.exp_value, row[3], "%s 經驗" % id)
		assert_eq(data.display_name, row[4], "顯示名稱存翻譯鍵")
		assert_ne(tr(data.display_name), data.display_name, "i18n/strings.csv 有這個鍵")
		assert_not_null(data.scene)


func test_spawned_enemy_is_set_up_from_data() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow", Vector2(90, 120))
	assert_true(enemy is ScarecrowEnemy)
	assert_true(enemy.is_in_group(&"enemy"))
	assert_eq(enemy.hp, 25)
	assert_eq(enemy.data.id, &"scarecrow")
	var elite := spawn(&"scarecrow_elite", Vector2(60, 120))
	assert_eq(elite.hp, 75)
	assert_true(elite.visual_scale > 1.2, "精英看起來比較大")


func test_death_leaves_group_immediately_and_emits_once() -> void:
	make_arena()
	var died := watch_signal(EventBus.enemy_died)
	var enemy := spawn(&"scarecrow", Vector2(90, 120))
	var pos := enemy.global_position
	enemy.take_damage(10)
	assert_eq(enemy.hp, 15)
	assert_eq(died.count, 0)
	enemy.take_damage(100)
	assert_false(enemy.is_in_group(&"enemy"), "死亡當下立刻離開群組")
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 0)
	assert_eq(died.count, 1)
	assert_eq(died.last_args(), [&"scarecrow", pos, 1])
	enemy.take_damage(100)
	enemy.die()
	assert_eq(died.count, 1, "enemy_died 只發一次")
	assert_eq(get_tree().get_nodes_in_group(&"exp_orb").size(), 1, "掉落一顆經驗珠")
	var ref: WeakRef = weakref(enemy)
	enemy = null
	var gone := await wait_until(func() -> bool: return ref.get_ref() == null, 60)
	assert_true(gone, "噗一聲之後消失")


func test_spawning_enemy_counts_but_cannot_be_targeted() -> void:
	make_arena(0.3)
	var enemy := spawn(&"scarecrow", Vector2(90, 120))
	assert_true(enemy.is_in_group(&"enemy"), "出場預警期間已算在場上")
	assert_false(enemy.is_targetable())
	var active := await wait_until(func() -> bool: return enemy.is_targetable(), 40)
	assert_true(active, "預警結束後開始行動")


func test_hit_flashes_and_knocks_back() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow", Vector2(90, 120))
	enemy.set_physics_process(false)
	var start := enemy.global_position
	enemy.hit(1, start + Vector2(-10, 0), 110.0)
	assert_eq(enemy._material.get_shader_parameter(&"flash"), 1.0, "閃白")
	enemy.set_physics_process(true)
	await wait_physics(10)
	assert_true(enemy.global_position.x > start.x + 3.0, "被往後擊退")
	assert_eq(enemy._material.get_shader_parameter(&"flash"), 0.0, "閃白很快結束")


func test_stun_freezes_enemy_and_cancels_telegraph() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow", player.global_position + Vector2(0, -40))
	player.set_physics_process(false)
	enemy.stun(0.5)
	var start := enemy.global_position
	await wait_physics(20)
	assert_true(enemy.is_stunned())
	assert_true(enemy.global_position.distance_to(start) < 0.5, "暈眩時不動")
	var recovered := await wait_until(func() -> bool: return not enemy.is_stunned(), 30)
	assert_true(recovered)


func test_separation_keeps_enemies_apart() -> void:
	make_arena()
	player.set_physics_process(false)
	var enemies: Array[EnemyBase] = []
	for i in 6:
		enemies.append(spawn(&"scarecrow", Vector2(90, 120)))
	var spread := INF
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			spread = minf(spread, enemies[i].global_position.distance_to(enemies[j].global_position))
	assert_true(spread >= arena.spawn_spacing - 0.01, "同一點生成多隻時,場地會找附近的空位")
	# 硬把牠們放在同一點,確認分離力會把牠們推開。
	for enemy in enemies:
		enemy.global_position = Vector2(90, 120)
	await wait_physics(60)
	var closest := INF
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			closest = minf(closest, enemies[i].global_position.distance_to(enemies[j].global_position))
	assert_true(closest > 6.0, "疊在同一點的敵人會散開(最近距離 %.1f)" % closest)


func test_scarecrow_telegraphs_before_hitting() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var scarecrow := spawn(&"scarecrow", player.global_position + Vector2(30, 0)) as ScarecrowEnemy
	var telegraphing := await wait_until(func() -> bool:
		return scarecrow.phase == ScarecrowEnemy.Phase.TELEGRAPH, 90)
	assert_true(telegraphing, "走近後開始預警")
	assert_not_null(scarecrow._telegraph, "畫出預警範圍")
	assert_eq(damaged.count, 0, "預警期間還沒打中")
	await wait_physics(12)
	assert_eq(damaged.count, 0, "0.2 秒時還沒打中")
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 30)
	assert_true(hit, "0.4 秒後揮擊打中")
	assert_eq(damaged.last_args(), [8])


func test_crow_shows_line_then_dives() -> void:
	make_arena()
	player.set_physics_process(false)
	var crow := spawn(&"crow", Vector2(40, 100)) as CrowEnemy
	var telegraph := await wait_until(func() -> bool: return crow.phase == CrowEnemy.Phase.TELEGRAPH, 300)
	assert_true(telegraph, "盤旋後鎖定")
	assert_not_null(crow._telegraph, "預警線")
	assert_eq(crow._telegraph.shape, AttackTelegraph.Shape.LINE)
	var dive := await wait_until(func() -> bool: return crow.phase == CrowEnemy.Phase.DIVE, 60)
	assert_true(dive, "預警後俯衝")
	assert_null(crow._telegraph, "俯衝時預警線消失")


func test_boss_enters_phase_two_at_half_hp() -> void:
	make_arena()
	var phases := watch_signal(EventBus.boss_phase_changed)
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	assert_eq(phases.count, 1, "出場時發 boss_phase_changed(1)")
	assert_eq(phases.last_args(), [1])
	boss.take_damage(224)
	assert_eq(boss.boss_phase, 1, "226/450 還在第一階段")
	boss.take_damage(1)
	assert_eq(boss.boss_phase, 2, "225/450 = 50% 進入第二階段")
	assert_eq(phases.count, 2)
	assert_eq(phases.last_args(), [2])
	boss.take_damage(50)
	assert_eq(phases.count, 2, "只發一次")
	assert_true(boss._tell_time(1.0) < 1.0, "第二階段預警變短")


func test_boss_summons_through_arena_and_defeat_scatters_armor() -> void:
	make_arena()
	var died := watch_signal(EventBus.enemy_died)
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	boss.target = player
	boss._start_summon()
	assert_eq(boss._summon_marks.size(), 2, "召喚前先畫兩個魔法圈")
	boss._summon()
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 3, "召喚兩隻稻草人兵(也算在場上)")
	assert_eq(boss.alive_summons(), 2)
	boss.take_damage(9999)
	assert_eq(died.count, 3, "頭目倒下時召喚的稻草人兵也一起倒下")
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 0)
	var boss_death: Array = died.calls[0]
	assert_eq(boss_death[0], &"black_knight")
	assert_eq(boss_death[2], 20)
	var orb_total := 0
	for orb in get_tree().get_nodes_in_group(&"exp_orb"):
		orb_total += int(orb.get(&"value"))
	assert_eq(orb_total, 20 + 2, "頭目 20 點 + 兩隻稻草人各 1 點")
	var remains: Node = null
	for child in arena.get_ground_layer().get_children():
		if child.get(&"helmet_settled") != null:
			remains = child
	assert_not_null(remains, "盔甲散落一地")
	var settled := await wait_until(func() -> bool: return bool(remains.get(&"helmet_settled")), 180)
	assert_true(settled, "頭盔滾完翻過來,裡面是空的")


func test_boss_moves_are_telegraphed() -> void:
	make_arena()
	player.set_physics_process(false)
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	boss.target = player
	boss._start_charge()
	assert_eq(boss._telegraph.shape, AttackTelegraph.Shape.LINE, "衝鋒前畫直線")
	boss._cancel_attack()
	boss._start_slam()
	assert_eq(boss._telegraph.shape, AttackTelegraph.Shape.CIRCLE, "重劈前畫圓圈")
	var damaged := watch_signal(EventBus.player_damaged)
	player.global_position = boss.global_position + Vector2(0, 30)
	await wait_physics(30)
	assert_eq(damaged.count, 0, "預警中不會受傷")
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 40)
	assert_true(hit, "站在圈內會被重劈打中")
	assert_eq(damaged.last_args(), [22])


func test_telegraphing_scarecrow_is_not_knocked_back() -> void:
	make_arena()
	player.set_physics_process(false)
	var scarecrow := spawn(&"scarecrow", player.global_position + Vector2(30, 0)) as ScarecrowEnemy
	await wait_until(func() -> bool: return scarecrow.phase == ScarecrowEnemy.Phase.TELEGRAPH, 90)
	var pos := scarecrow.global_position
	scarecrow.hit(1, player.global_position, 110.0)
	await wait_physics(6)
	assert_true(scarecrow.global_position.distance_to(pos) < 0.5, "已經預警的攻擊不會被一般攻擊打斷")
	scarecrow.stun(0.5)
	assert_ne(scarecrow.phase, ScarecrowEnemy.Phase.TELEGRAPH, "吠叫的暈眩可以打斷")
	assert_null(scarecrow._telegraph)
