extends "res://tests/line_a/combat_test_base.gd"
## v2.3 深化(AS1 至 AS8):弓兵、空盔甲兵、稻草人隊長、黑騎士新招式、投射物與鬥牛犬擋箭、
## boss_appeared、難度倍數、進攻名額與合作(交叉火力、夾擊)。


func before_each() -> void:
	Haptics.reset_for_tests()
	CombatFx.set_feel(null)
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.level_index = 0


func after_each() -> void:
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	CombatFx.set_feel(null)
	await super()


func _projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group(EnemyProjectile.GROUP)


# --- 資料(AS1 至 AS3、AS8) -------------------------------------------------------------

func test_new_enemy_data_files_match_dev_plan() -> void:
	var expected := {
		&"scarecrow_archer": [18, 7, 24.0, 2, "ENEMY_SCARECROW_ARCHER"],
		&"armored_husk": [70, 12, 22.0, 4, "ENEMY_ARMORED_HUSK"],
		&"scarecrow_captain": [320, 12, 30.0, 12, "ENEMY_SCARECROW_CAPTAIN"],
	}
	for id: StringName in expected:
		var data := load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_not_null(data, String(id))
		if data == null:
			continue
		var row: Array = expected[id]
		assert_eq(data.id, id, "資料 id = 角色代號")
		assert_eq(data.max_hp, row[0], "%s 生命" % id)
		assert_eq(data.contact_damage, row[1], "%s 傷害" % id)
		assert_almost_eq(data.move_speed, row[2], 0.001, "%s 速度" % id)
		assert_eq(data.exp_value, row[3], "%s 經驗" % id)
		assert_eq(data.display_name, row[4])
		assert_ne(tr(data.display_name), data.display_name, "i18n/strings.csv 有 %s" % row[4])
	assert_ne(tr("COMPANION_BULLDOG_CLANG"), "COMPANION_BULLDOG_CLANG")
	for id: StringName in [&"arrow", &"sword_wave", &"pitchfork"]:
		var p := load("res://data/enemies/projectiles/%s.tres" % id) as ProjectileData
		assert_not_null(p, "投射物資料 %s" % id)
		assert_true(p.speed > 0.0 and p.max_range > 0.0)
		assert_true(p.blockable, "鬥牛犬的盾擋得住 %s" % id)


# --- AS1 弓兵 ------------------------------------------------------------------------

func test_archer_aims_for_a_readable_time_then_shoots_an_arrow() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var archer := spawn(&"scarecrow_archer", player.global_position + Vector2(0, -80)) as ArcherEnemy
	archer._cooldown_left = 0.1
	var aiming := await wait_until(func() -> bool: return archer.phase == ArcherEnemy.Phase.AIM, 60)
	assert_true(aiming, "冷卻好了就瞄準")
	assert_not_null(archer._telegraph, "瞄準時畫出預警線")
	assert_eq(archer._telegraph.shape, AttackTelegraph.Shape.LINE)
	assert_true(archer._telegraph.direction.dot(Vector2.DOWN) > 0.95, "預警線指向金毛")
	var frames := 0
	while archer.phase == ArcherEnemy.Phase.AIM and frames < 120:
		await get_tree().physics_frame
		frames += 1
	assert_true(frames >= 30, "預警至少 0.5 秒(實際 %d 格)" % frames)
	assert_eq(archer.shots_fired, 1, "預警結束後放箭")
	assert_eq(_projectiles().size(), 1, "箭在場上(看得見)")
	assert_eq(damaged.count, 0, "箭還在飛")
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 90)
	assert_true(hit, "站著不動會被射中")
	assert_eq(damaged.last_args(), [7], "箭的傷害 7")


func test_arrow_misses_when_goldie_steps_aside_after_the_lock() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var archer := spawn(&"scarecrow_archer", player.global_position + Vector2(0, -80)) as ArcherEnemy
	archer._cooldown_left = 0.0
	await wait_until(func() -> bool: return archer.phase == ArcherEnemy.Phase.AIM, 60)
	# 預警線鎖定之後才走開(線不再跟著轉)。
	await wait_until(func() -> bool: return archer._telegraph != null and archer._telegraph.progress > archer.aim_track_ratio + 0.05, 60)
	player.global_position += Vector2(22, 0)
	await wait_until(func() -> bool: return archer.shots_fired > 0, 60)
	await wait_physics(70)
	assert_eq(damaged.count, 0, "看到預警線就走開,箭射不中")


func test_archer_backs_away_when_goldie_comes_close() -> void:
	make_arena()
	player.set_physics_process(false)
	var archer := spawn(&"scarecrow_archer", player.global_position + Vector2(0, -30)) as ArcherEnemy
	archer._cooldown_left = 99.0
	var start := archer.global_position.distance_to(player.global_position)
	await wait_physics(90)
	var after := archer.global_position.distance_to(player.global_position)
	assert_true(after > start + 15.0, "金毛靠近時後退(%.0f → %.0f)" % [start, after])


# --- AS5 投射物與鬥牛犬的盾 ---------------------------------------------------------------

func test_bulldog_shield_blocks_arrows_sword_waves_and_pitchforks() -> void:
	make_arena()
	player.set_physics_process(false)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.global_position = player.global_position + Vector2(0, -30)
	var dummy := spawn(&"scarecrow_elite", dog.global_position + Vector2(0, -16))
	dummy.set_physics_process(false)
	var guarding := await wait_until(func() -> bool: return dog.is_taunting(), 120)
	assert_true(guarding, "鬥牛犬舉盾")
	dog.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var count := 0
	for id: StringName in [&"arrow", &"sword_wave", &"pitchfork"]:
		var data := load("res://data/enemies/projectiles/%s.tres" % id) as ProjectileData
		var from := dog.global_position + Vector2(-60, 0)
		var p := EnemyProjectile.launch(arena, data, from, Vector2.RIGHT, 120.0, 9)
		var ref: WeakRef = weakref(p)
		var stopped := await wait_until(func() -> bool:
			var q := ref.get_ref() as EnemyProjectile
			return q == null or q.blocked, 90)
		count += 1
		assert_true(stopped and ref.get_ref() != null and p.blocked, "%s 被盾擋下" % id)
		assert_eq(dog.blocks, count, "鬥牛犬記得擋了幾個")
		if count == 1:
			assert_true(dog._bubble != null and is_instance_valid(dog._bubble), "頭上冒「鏘!」")
			if dog._bubble != null and is_instance_valid(dog._bubble):
				assert_eq(dog._bubble.text, tr("COMPANION_BULLDOG_CLANG"))
	assert_eq(dog.damage_taken_total, 0, "擋下時不受傷")
	assert_eq(damaged.count, 0)


func test_projectile_hits_each_victim_once_and_stops_at_the_wall() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var wave := load("res://data/enemies/projectiles/sword_wave.tres") as ProjectileData
	var from := player.global_position + Vector2(-50, 0)
	var length := EnemyProjectile.travel_length(from, Vector2.RIGHT, wave.max_range)
	assert_true(length < wave.max_range, "撞到場地邊緣就停(%.0f)" % length)
	var ref: WeakRef = weakref(EnemyProjectile.launch(arena, wave, from, Vector2.RIGHT, length, 14))
	var gone := await wait_until(func() -> bool: return ref.get_ref() == null, 180)
	assert_true(gone, "飛到牆邊後消失")
	assert_eq(damaged.count, 1, "劍氣穿透,但每個角色只打一次")
	assert_eq(damaged.last_args(), [14])
	assert_true(player.global_position.x < Layout.ARENA_RECT.end.x)


# --- AS2 空盔甲兵 ---------------------------------------------------------------------

func test_husk_is_not_knocked_back_and_shrugs_off_half_the_bark() -> void:
	make_arena()
	player.set_physics_process(false)
	var husk := spawn(&"armored_husk", player.global_position + Vector2(0, -70)) as HuskEnemy
	husk._cooldown_left = 99.0
	husk.set_physics_process(false)
	var start := husk.global_position
	husk.hit(5, start + Vector2(-10, 0), 200.0)
	husk.set_physics_process(true)
	await wait_physics(8)
	assert_true(husk.global_position.distance_to(start) < 3.0, "推不動(只有自己走的一點點)")
	husk.stun(1.5)
	assert_almost_eq(husk._stun_left, 0.75, 0.001, "吠叫只震懾一半時間")


func test_husk_telegraphs_a_shield_bash_then_dashes() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var husk := spawn(&"armored_husk", player.global_position + Vector2(0, -44)) as HuskEnemy
	husk._cooldown_left = 0.05
	var telling := await wait_until(func() -> bool: return husk.phase == HuskEnemy.Phase.TELEGRAPH, 30)
	assert_true(telling, "冷卻好了就預警")
	assert_eq(husk._telegraph.shape, AttackTelegraph.Shape.LINE, "紅線預警")
	var frames := 0
	while husk.phase == HuskEnemy.Phase.TELEGRAPH and frames < 120:
		await get_tree().physics_frame
		frames += 1
	assert_true(frames >= 34, "預警約 0.6 秒(%d 格)" % frames)
	assert_eq(damaged.count, 0, "預警期間不會受傷")
	var start := husk.global_position
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 40)
	assert_true(hit, "衝撞撞到站著不動的金毛")
	assert_eq(damaged.last_args(), [12])
	await wait_until(func() -> bool: return husk.phase == HuskEnemy.Phase.RECOVER, 40)
	var dashed := husk.global_position.distance_to(start)
	assert_true(dashed > 40.0 and dashed < 70.0, "衝約 60 像素(%.0f)" % dashed)


func test_husk_death_scatters_armour_and_a_blue_wisp_flies_off() -> void:
	make_arena()
	var died := watch_signal(EventBus.enemy_died)
	var husk := spawn(&"armored_husk", Vector2(90, 140))
	husk.take_damage(999)
	assert_eq(died.count, 1)
	assert_eq(died.last_args()[2], 4, "經驗 4")
	var remains: Node = null
	for child in arena.get_ground_layer().get_children():
		if child.get(&"helmet_settled") != null:
			remains = child
	assert_not_null(remains, "盔甲散開")
	var wisps := 0
	for child in arena.get_fx_layer().get_children():
		if child is MagicWisp:
			wisps += 1
	assert_eq(wisps, 1, "一縷藍色火光飛走")
	var ref: WeakRef = weakref(remains)
	remains = null
	var faded := await wait_until(func() -> bool: return ref.get_ref() == null, 240)
	assert_true(faded, "小盔甲幾秒後淡出(不會留滿地)")


# --- AS3 稻草人隊長 -------------------------------------------------------------------

func test_captain_announces_itself_for_the_boss_bar() -> void:
	make_arena(-1.0)
	var appeared := watch_signal(EventBus.boss_appeared)
	var hp := watch_signal(EventBus.boss_hp_changed)
	var captain := spawn(&"scarecrow_captain", Vector2(90, 120)) as CaptainBoss
	assert_eq(appeared.count, 1, "出場時發 boss_appeared")
	assert_eq(appeared.last_args(), [&"scarecrow_captain"])
	assert_eq(hp.last_args(), [captain.max_hp, captain.max_hp], "也發 boss_hp_changed")
	assert_eq(tr("ENEMY_" + String(appeared.last_args()[0]).to_upper()), "稻草人隊長", "HUD 用這個鍵顯示名字")
	assert_false(captain.is_targetable(), "冒出地面時無敵")
	var up := await wait_until(func() -> bool: return captain.is_targetable(), 120)
	assert_true(up)
	assert_eq(appeared.count, 1, "只發一次")
	captain.take_damage(20)
	assert_eq(hp.last_args(), [captain.max_hp - 20, captain.max_hp])


func test_captain_sweep_rally_and_boomerang_pitchfork() -> void:
	make_arena()
	player.set_physics_process(false)
	var captain := spawn(&"scarecrow_captain", player.global_position + Vector2(0, -90)) as CaptainBoss
	captain.target = player
	captain._start_sweep()
	assert_eq(captain._telegraph.shape, AttackTelegraph.Shape.SECTOR, "橫掃:扇形預警")
	assert_true(captain._tell_time(captain.sweep_telegraph) >= 0.5)
	captain._cancel_attack()
	captain._start_rally()
	assert_eq(captain._rally_marks.size(), 3, "號令:三個紫色魔法圈")
	assert_eq(captain._rally_marks[0].color, AttackTelegraph.MAGIC)
	captain._rally()
	assert_eq(captain.alive_summons(), 3, "叫出 3 隻稻草人兵")
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 4)
	for s in captain._summons:
		s.set_physics_process(false)
	captain._go_idle()
	captain.set_physics_process(false)
	captain._start_throw()
	assert_eq(captain._telegraph.shape, AttackTelegraph.Shape.LINE, "擲乾草叉:直線預警")
	var damaged := watch_signal(EventBus.player_damaged)
	captain._throw()
	assert_false(captain.fork_in_hand)
	assert_eq(_projectiles().size(), 1, "乾草叉飛出去")
	captain.set_physics_process(true)
	var back := await wait_until(func() -> bool:
		player.invuln_left = 0.0       # 只看乾草叉的路線,不看受擊後的無敵時間
		return captain.fork_in_hand, 240)
	assert_true(back, "乾草叉飛回隊長手上")
	assert_eq(damaged.count, 2, "去回都打中站著不動的金毛")


func test_captain_phase_two_then_defeat_drops_a_purple_feather() -> void:
	make_arena()
	player.set_physics_process(false)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var died := watch_signal(EventBus.enemy_died)
	var captain := spawn(&"scarecrow_captain", Vector2(90, 120)) as CaptainBoss
	captain.target = player
	captain.take_damage(captain.max_hp / 2)
	assert_eq(captain.boss_phase, 2)
	assert_eq(phases.last_args(), [2])
	assert_eq(captain.phase, CaptainBoss.Phase.SHOUT, "一半生命時吶喊")
	assert_true(captain.is_invulnerable())
	await wait_until(func() -> bool: return captain.phase != CaptainBoss.Phase.SHOUT, 90)
	assert_true(captain._tell_time(1.0) < 1.0, "第二階段預警變短")
	captain._start_rally()
	captain._rally()
	assert_eq(captain.alive_summons(), 3)
	captain.take_damage(9999)
	assert_eq(died.count, 3, "隊長倒下時,叫來的稻草人兵一起倒下")
	assert_true(captain.is_defeat_playing())
	var gone := await wait_until(func() -> bool: return not captain.is_in_group(&"enemy"), 90)
	assert_true(gone, "演出後離開 enemy 群組")
	assert_eq(died.last_args()[0], &"scarecrow_captain")
	var feather: PurpleFeather = null
	for node in arena.get_fx_layer().get_children():
		if node is PurpleFeather:
			feather = node
	assert_not_null(feather, "紫色羽毛飄落")
	var y0 := feather.global_position.y
	await wait_physics(30)
	assert_true(feather.global_position.y > y0 and not feather.landed, "慢慢地往下飄")
	var landed := await wait_until(func() -> bool: return feather.landed, 300)
	assert_true(landed, "落到地上")


# --- AS4 黑騎士的新招式 -------------------------------------------------------------------

func test_black_knight_announces_and_phase_two_sword_wave_and_husks() -> void:
	make_arena()
	player.set_physics_process(false)
	var appeared := watch_signal(EventBus.boss_appeared)
	var boss := spawn(&"black_knight", player.global_position + Vector2(0, -100)) as BlackKnightBoss
	assert_eq(appeared.last_args(), [&"black_knight"], "出場時發 boss_appeared")
	boss.target = player
	assert_eq(boss.current_summon(), &"scarecrow", "第一階段召喚稻草人兵")
	boss._start_slam()
	boss._slam()
	assert_false(boss._wave_pending, "第一階段重劈後沒有劍氣")
	boss._go_idle()
	boss.take_damage(boss.max_hp / 2)
	assert_eq(boss.boss_phase, 2)
	assert_eq(boss.current_summon(), &"armored_husk", "第二階段召喚空盔甲兵")
	await wait_until(func() -> bool: return boss.phase != BlackKnightBoss.Phase.ROAR, 90)
	boss.set_physics_process(false)
	boss._start_slam()
	boss._slam()
	assert_true(boss._wave_pending, "第二階段重劈之後放劍氣")
	boss.set_physics_process(true)
	var telling := await wait_until(func() -> bool: return boss.phase == BlackKnightBoss.Phase.WAVE_TELL, 40)
	assert_true(telling, "劍氣先有直線預警")
	assert_eq(boss._telegraph.shape, AttackTelegraph.Shape.LINE)
	assert_true(boss._tell_time(boss.wave_telegraph) >= 0.5, "一般模式預警至少 0.5 秒")
	var released := await wait_until(func() -> bool: return _projectiles().size() > 0, 60)
	assert_true(released, "沿線射出劍氣")
	var wave := _projectiles()[0] as EnemyProjectile
	assert_eq(wave.data.id, &"sword_wave")
	boss._start_summon()
	boss._summon()
	var husks := 0
	for e in get_tree().get_nodes_in_group(&"enemy"):
		if e is HuskEnemy:
			husks += 1
	assert_eq(husks, 2, "召喚 2 隻空盔甲兵")


# --- AS6 難度 -----------------------------------------------------------------------------

func test_hard_mode_scales_stats_and_telegraphs_without_touching_the_data_file() -> void:
	make_arena()
	var mode := DifficultyScaling.get_default().mode(&"hard")
	assert_almost_eq(mode.hp_mult, 1.5, 0.05, "困難:生命約 ×1.5")
	assert_almost_eq(mode.damage_mult, 1.4, 0.05, "困難:傷害約 ×1.4")
	assert_almost_eq(mode.telegraph_mult, 0.8, 0.05, "困難:預警約 ×0.8")
	var normal := spawn(&"scarecrow", Vector2(40, 100)) as ScarecrowEnemy
	assert_eq(normal.hp, 25)
	assert_eq(normal.tell(1.0), 1.0, "一般模式 = 1.0")
	GameState.difficulty = &"hard"
	var hard := spawn(&"scarecrow", Vector2(140, 100)) as ScarecrowEnemy
	assert_eq(hard.hp, roundi(25 * mode.hp_mult))
	assert_eq(hard.data.contact_damage, roundi(8 * mode.damage_mult))
	assert_almost_eq(hard.data.move_speed, 28.0 * mode.speed_mult, 0.01)
	assert_almost_eq(hard.tell(0.5), 0.5 * mode.telegraph_mult, 0.001)
	assert_almost_eq(hard.rest(1.0), mode.interval_mult, 0.001)
	assert_eq((load("res://data/enemies/scarecrow.tres") as EnemyData).max_hp, 25, "資料檔沒有被改")
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	assert_eq(boss.max_hp, roundi(780 * mode.boss_hp_mult), "頭目用 boss_hp_mult")
	assert_eq(boss.scaled_damage(boss.slam_damage), roundi(20 * mode.damage_mult))
	assert_true(arena.attack_slot_limit(DifficultyScaling.MELEE) > DifficultyScaling.get_default().slot_limit(
			DifficultyScaling.MELEE, 0, DifficultyScaling.get_default().mode(&"normal")), "困難:同時進攻的敵人多一隻")


# --- AS7 合作:進攻名額、交叉火力、夾擊 ------------------------------------------------------

func test_attack_slots_limit_simultaneous_melee_attackers_by_level() -> void:
	make_arena()
	player.set_physics_process(false)
	var scaling := DifficultyScaling.get_default()
	assert_eq(arena.attack_slot_limit(DifficultyScaling.MELEE), scaling.melee_slots_by_level[0])
	GameState.level_index = 5
	assert_eq(arena.attack_slot_limit(DifficultyScaling.MELEE), scaling.melee_slots_by_level[5], "後段關卡上限較高")
	assert_true(scaling.melee_slots_by_level[5] > scaling.melee_slots_by_level[0])
	GameState.level_index = 0
	var limit := arena.attack_slot_limit(DifficultyScaling.MELEE)
	var crowd: Array[ScarecrowEnemy] = []
	for i in 5:
		var dir := Vector2.from_angle(TAU * float(i) / 5.0)
		crowd.append(spawn(&"scarecrow", player.global_position + dir * 34.0) as ScarecrowEnemy)
	var most := 0
	var attacks := 0
	for f in 240:
		await get_tree().physics_frame
		var now := 0
		for s in crowd:
			if s.phase == ScarecrowEnemy.Phase.TELEGRAPH or s.phase == ScarecrowEnemy.Phase.SWING:
				now += 1
		most = maxi(most, now)
		attacks = 0
		for s in crowd:
			attacks += s.attacks_started
	assert_true(most <= limit, "同時出手的近戰敵人不超過 %d(最多 %d)" % [limit, most])
	assert_true(attacks > limit, "名額空出來時其他稻草人接著出手(共 %d 次)" % attacks)


func test_archers_crossfire_with_melee_in_later_levels() -> void:
	make_arena()
	player.set_physics_process(false)
	var archer := spawn(&"scarecrow_archer", player.global_position + Vector2(-70, -40)) as ArcherEnemy
	var scarecrow := spawn(&"scarecrow", player.global_position + Vector2(30, 0)) as ScarecrowEnemy
	archer._cooldown_left = 0.9
	await wait_until(func() -> bool: return scarecrow.phase == ScarecrowEnemy.Phase.TELEGRAPH, 60)
	await wait_physics(2)
	assert_eq(archer.phase, ArcherEnemy.Phase.MOVE, "前段關卡:弓兵照自己的節奏")
	arena.clear()
	await wait_physics(2)
	GameState.level_index = DifficultyScaling.get_default().crossfire_from_level
	archer = spawn(&"scarecrow_archer", player.global_position + Vector2(-70, -40)) as ArcherEnemy
	scarecrow = spawn(&"scarecrow", player.global_position + Vector2(30, 0)) as ScarecrowEnemy
	archer._cooldown_left = 0.9
	await wait_until(func() -> bool: return scarecrow.phase == ScarecrowEnemy.Phase.TELEGRAPH, 60)
	var joined := await wait_until(func() -> bool: return archer.phase == ArcherEnemy.Phase.AIM, 5)
	assert_true(joined, "後段關卡:近戰同伴出招時,冷卻快好的弓兵立刻瞄準(交叉火力)")
	assert_eq(archer.crossfire_aims, 1)


func test_pincer_makes_waiting_scarecrows_attack_together_in_later_levels() -> void:
	make_arena()
	player.set_physics_process(false)
	GameState.level_index = DifficultyScaling.get_default().pincer_from_level
	var a := spawn(&"scarecrow", player.global_position + Vector2(-60, 0)) as ScarecrowEnemy
	var b := spawn(&"scarecrow", player.global_position + Vector2(34, 6)) as ScarecrowEnemy
	b.set_physics_process(false)
	a.target = player
	b.target = player
	a._start_telegraph(player.global_position - a.global_position)
	assert_eq(b.phase, ScarecrowEnemy.Phase.TELEGRAPH, "附近等著的同伴一起出手(夾擊)")
	assert_true(b.is_attacking_target(player))
	a._cancel_attack()
	b._cancel_attack()
	GameState.level_index = 0
	b.phase = ScarecrowEnemy.Phase.APPROACH
	a.phase = ScarecrowEnemy.Phase.APPROACH
	a._start_telegraph(player.global_position - a.global_position)
	assert_eq(b.phase, ScarecrowEnemy.Phase.APPROACH, "前段關卡沒有夾擊")
