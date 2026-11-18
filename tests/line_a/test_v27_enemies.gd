extends "res://tests/line_a/fast_combat_test_base.gd"
## v2.7 第四至六章的敵人與中頭目(DEV_PLAN 4.14、第 20 節 AW1、AW3、AW5、AW8、AW9):
## 螃蟹、水母、寄居蟹將軍、雪人兵、雪人隊長、火蜥蜴、影子騎士、提燈鬼火;每章倍率延長為 6 個值;
## 每個新敵人與頭目都打得倒。為了測試總時間,這裡的測試都快轉(fast_combat_test_base.gd)。

const NEW_ENEMIES: Array[StringName] = [&"crab", &"crab_elite", &"jellyfish", &"kraken", &"snowman",
		&"snowman_elite", &"salamander", &"red_dragon", &"white_dragon", &"shadow_knight", &"lantern_wisp",
		&"mordred_duel", &"mordred", &"echo_black_knight", &"echo_green_knight"]


# --- 資料 -----------------------------------------------------------------------------

func test_v27_data_files_names_and_six_chapter_multipliers() -> void:
	for id in NEW_ENEMIES:
		var data := load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_not_null(data, String(id))
		if data == null:
			continue
		assert_eq(data.id, id, "資料 id = 檔名")
		assert_not_null(data.scene, "%s 有場景" % id)
		assert_true(data.max_hp > 0 and data.move_speed > 0.0, "%s 有生命與速度" % id)
		assert_ne(tr(data.display_name), data.display_name, "i18n/strings.csv 有 %s" % data.display_name)
	for id: StringName in [&"bubble", &"ink_blob", &"snowball", &"fireball", &"ice_shard", &"shadow_slash"]:
		var p := load("res://data/enemies/projectiles/%s.tres" % id) as ProjectileData
		assert_not_null(p, "投射物資料 %s" % id)
		if p != null:
			assert_eq(p.fx, id, "圖用 assets/fx/%s" % id)
			assert_not_null(CombatFx.frames(p.fx), "assets/fx/%s 有圖" % id)
	assert_not_null(CombatFx.frames(&"tentacle"), "觸手尖用 assets/fx/tentacle")
	for id: StringName in [&"tristan", &"gawain"]:
		var c := load("res://data/companions/%s.tres" % id) as CompanionData
		assert_not_null(c, "同伴資料 %s" % id)
		if c != null:
			assert_eq(c.id, id)
			assert_ne(tr(c.display_name), c.display_name)
	assert_eq((load("res://data/companions/music_note.tres") as ProjectileData).fx, &"music_note")
	for key: String in ["ENEMY_TWIN_DRAGONS", "BOSS_DRAGON_SULK", "BOSS_MORDRED_FLEE", "BOSS_MORDRED_SHIELD",
			"COMPANION_SHIELD_CALL", "COMPANION_TRISTAN_SHOUT", "COMPANION_GAWAIN_SHOUT"]:
		assert_ne(tr(key), key, "i18n/strings.csv 有 %s" % key)
	# AW8:第六章的敵人用第六個倍率(從資料讀取,不寫死)。
	var scaling := DifficultyScaling.get_default()
	assert_eq(scaling.chapter_hp_mult.size(), GameState.CHAPTER_COUNT)
	make_arena()
	GameState.chapter = GameState.CHAPTER_COUNT
	GameState.level_index = 1
	var crab := spawn(&"crab", Vector2(40, 120))
	var base := (load("res://data/enemies/crab.tres") as EnemyData).max_hp
	assert_eq(crab.max_hp, roundi(base * scaling.hp_ramp_by_level[1] * scaling.chapter_hp(GameState.CHAPTER_COUNT)),
			"第六章:章倍率 × 每關遞增")
	assert_eq(crab.scaled_damage(10), roundi(10 * scaling.damage_ramp_by_level[1] * scaling.chapter_damage(GameState.CHAPTER_COUNT)))


## AW9:每一個新敵人與頭目在場地裡都打得倒(發 enemy_died、離開 enemy 群組)。
## 莫德雷德第一戰不會被打倒(半血逃走),在 test_v27_bosses.gd 另外測。
func test_every_v27_enemy_can_be_defeated() -> void:
	make_fast_arena()
	var died := watch_signal(EventBus.enemy_died)
	var ids: Array[StringName] = []
	for id in NEW_ENEMIES:
		if id != &"mordred_duel":
			ids.append(id)
	var enemies: Array[EnemyBase] = []
	for i in ids.size():
		var e := spawn(ids[i], Vector2(24 + (i % 5) * 33, 96 + (i / 5) * 56))
		assert_not_null(e, "生成 %s" % ids[i])
		enemies.append(e)
	await wait_physics(1)
	var all_gone := await wait_until(func() -> bool:
		CombatFx.time_scale = FAST          # 頭目倒下的慢動作會把倍數設回 1
		var left := false
		for e in enemies:
			if is_instance_valid(e) and e.is_in_group(&"enemy"):
				left = true
				if not e.is_invulnerable():
					e.take_damage(999999)
		return not left, 120)
	assert_true(all_gone, "全部倒下(頭目播完倒下演出、雙龍都坐下)")
	var seen: Array = []
	for args: Array in died.calls:
		seen.append(args[0])
	for id in ids:
		assert_true(seen.has(id), "%s 發了 enemy_died" % id)


# --- AW1 螃蟹、水母、寄居蟹將軍 -------------------------------------------------------------

func test_crab_guard_barely_hurts_and_panting_after_a_pinch_is_the_counter_window() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var crab := spawn(&"crab", player.global_position + Vector2(-22, 0)) as CrabEnemy
	crab.set_physics_process(false)
	crab.target = player
	crab.brain._scuttle()
	assert_true(crab.is_guarding(), "靠近目標時舉起鉗子")
	assert_eq(crab.anim_state, &"guard")
	var hp := crab.hp
	crab.hit(20, player.global_position, 60.0)
	assert_eq(hp - crab.hp, roundi(20 * crab.tuning.guard_damage_mult), "舉鉗子時幾乎打不痛")
	assert_true(crab.tuning.guard_damage_mult <= 0.25)
	# 張開鉗子:扇形預警(這時不舉鉗子),填滿時夾。
	crab.brain.start_tell()
	assert_false(crab.is_guarding())
	assert_eq(crab._telegraph.shape, AttackTelegraph.Shape.SECTOR, "扇形預警")
	assert_true(crab.tell(crab.tuning.pinch_telegraph) >= 0.5, "預警夠長")
	crab.set_physics_process(true)
	await wait_until(func() -> bool: return crab.brain.is_panting(), 30)
	assert_eq(damaged.count, 1, "站著不動被夾到")
	hp = crab.hp
	crab.hit(20, player.global_position, 60.0)
	assert_eq(hp - crab.hp, 20, "夾完喘氣:打得痛(反擊時機)")
	# 看到扇形就走開:夾不到。
	reset_player_hit()
	crab.brain.cancel()
	crab.brain.start_tell()
	await wait_physics(2)
	player.global_position += Vector2(40, 0)
	await wait_until(func() -> bool: return crab.brain.is_panting(), 30)
	assert_eq(damaged.count, 1, "走開就夾不到")


func test_jellyfish_zap_circle_hits_only_who_stays() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var jelly := spawn(&"jellyfish", player.global_position + Vector2(0, -14)) as JellyfishEnemy
	assert_true(jelly.tint.a < 1.0, "半透明")
	jelly.target = player
	jelly._start_charge()
	assert_eq(jelly._telegraph.shape, AttackTelegraph.Shape.CIRCLE, "地上亮圓圈")
	assert_almost_eq(jelly._telegraph.radius, jelly.zap_radius, 0.01, "圓圈 = 放電範圍")
	assert_true(jelly.tell(jelly.zap_telegraph) >= 0.6, "預警夠長")
	await wait_until(func() -> bool: return jelly.phase == JellyfishEnemy.Phase.REST, 30)
	assert_eq(damaged.count, 1, "站在圈裡被電到")
	assert_eq(count_in(arena.get_fx_layer(), ZapFx), 1, "小閃電")
	reset_player_hit()
	jelly.phase = JellyfishEnemy.Phase.DRIFT
	jelly._start_charge()
	await wait_physics(2)
	player.global_position += Vector2(0, 40)
	await wait_until(func() -> bool: return jelly.phase == JellyfishEnemy.Phase.REST, 30)
	assert_eq(damaged.count, 1, "走出圈外就電不到")


func test_crab_elite_harder_shell_and_calls_crabs_at_half() -> void:
	make_fast_arena()
	var appeared := watch_signal(EventBus.boss_appeared)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var elite := spawn(&"crab_elite", Vector2(90, 140)) as CrabEliteBoss
	assert_eq(appeared.last_args(), [&"crab_elite"], "中頭目出場發 boss_appeared")
	assert_true(elite.visual_scale >= 1.4, "放大")
	var crab_tuning := load("res://data/enemies/crab_tuning.tres") as CrabTuning
	assert_true(elite.tuning.guard_damage_mult < crab_tuning.guard_damage_mult, "殼更硬")
	elite.take_damage(elite.max_hp / 2)
	assert_eq(phases.last_args(), [2], "半血進入第二階段")
	assert_true(elite.is_invulnerable(), "舉起雙鉗(短暫停頓)")
	assert_eq(Haptics.last_kind, &"heavy", "手機震動")
	var called := await wait_until(func() -> bool: return elite.alive_summons() == 2, 60)
	assert_true(called, "叫出 2 隻螃蟹")
	assert_eq(elite.brain.extra_pinches, elite.extra_pinches_phase2, "之後連續夾兩下")
	elite._drop_summons()                       # 下面只看寄居蟹將軍自己的預警
	# 看到扇形就走開(中頭目也躲得開)。
	var damaged := watch_signal(EventBus.player_damaged)
	elite.global_position = player.global_position + Vector2(-30, 0)
	elite.target = player
	elite.mode = CrabEliteBoss.Mode.FIGHT
	elite.brain.start_tell()
	await wait_physics(2)
	player.global_position += Vector2(60, 0)
	await wait_until(func() -> bool: return elite.brain.phase != CrabBrain.Phase.TELL, 40)
	assert_eq(damaged.count, 0, "走開就夾不到")


# --- AW3 雪人兵、雪人隊長、火蜥蜴 -----------------------------------------------------------

func test_snowball_shadow_marks_the_landing_spot_first() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var snowman := spawn(&"snowman", player.global_position + Vector2(0, -80)) as SnowmanEnemy
	snowman.target = player
	snowman.set_physics_process(false)          # 只看這一顆(雪球自己會飛)
	snowman.brain.start_throw()
	var shot := first_in(arena.get_ground_layer(), LobbedShot) as LobbedShot
	assert_not_null(shot, "落點先出現影子")
	assert_true(shot.global_position.distance_to(player.global_position) < 1.0, "落點 = 金毛現在的位置")
	assert_eq(shot.data.id, &"snowball")
	assert_true(shot.warning_time() >= 0.9, "影子亮得夠久(%.2f 秒)" % shot.warning_time())
	await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), LobbedShot) == 0, 40)
	assert_eq(damaged.count, 1, "站著不動被雪球打中")
	reset_player_hit()
	snowman.brain.phase = SnowmanBrain.Phase.MOVE
	snowman.brain.start_throw()
	shot = first_in(arena.get_ground_layer(), LobbedShot) as LobbedShot
	await wait_physics(2)
	player.global_position += Vector2(30, 0)
	await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), LobbedShot) == 0, 40)
	assert_eq(damaged.count, 1, "看到影子就走開")


func test_snowman_elite_throws_three_with_gaps_and_calls_snowmen() -> void:
	make_fast_arena()
	var appeared := watch_signal(EventBus.boss_appeared)
	var damaged := watch_signal(EventBus.player_damaged)
	var elite := spawn(&"snowman_elite", player.global_position + Vector2(0, -90)) as SnowmanEliteBoss
	assert_eq(appeared.last_args(), [&"snowman_elite"])
	elite.target = player
	elite.mode = SnowmanEliteBoss.Mode.FIGHT
	elite.set_physics_process(false)            # 只看這一輪(雪球自己會飛)
	assert_eq(elite.brain.ball_count(), 3, "一次丟三顆")
	elite.brain.start_throw()
	var shots: Array[LobbedShot] = []
	for child in arena.get_ground_layer().get_children():
		if child is LobbedShot:
			shots.append(child as LobbedShot)
	assert_eq(shots.size(), 3, "三個落點都有影子")
	for i in shots.size():
		for j in range(i + 1, shots.size()):
			assert_true(shots[i].global_position.distance_to(shots[j].global_position) >= elite.tuning.ball_spread - 1.0, "落點散開")
	# 看到影子就往上走開(三顆都躲得開)。
	await wait_physics(2)
	player.global_position += Vector2(0, -40)
	await wait_until(func() -> bool: return arena.get_ground_layer().get_children().filter(
			func(c: Node) -> bool: return c is LobbedShot and is_instance_valid(c)).is_empty(), 50)
	assert_eq(damaged.count, 0, "走開就打不中")
	elite._start_summon()
	elite._summon()
	assert_eq(elite.alive_summons(), 2, "堆出 2 個雪人兵")
	elite.take_damage(elite.max_hp / 2)
	assert_eq(elite.brain.ball_count(), 3 + elite.extra_balls_phase2, "第二階段一次丟更多")


func test_salamander_dash_leaves_short_embers_that_burn_once() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var sal := spawn(&"salamander", player.global_position + Vector2(-70, -40)) as SalamanderEnemy
	sal.target = player
	sal.start_tell()
	assert_eq(sal._telegraph.shape, AttackTelegraph.Shape.LINE, "紅線預警")
	assert_true(sal.tell(sal.dash_telegraph) >= 0.5, "預警夠長")
	await wait_physics(2)
	player.global_position += Vector2(0, 40)
	await wait_until(func() -> bool: return sal.phase == SalamanderEnemy.Phase.RECOVER, 40)
	sal.set_physics_process(false)              # 只看這一次衝刺
	assert_eq(damaged.count, 0, "走開就撞不到")
	assert_true(sal.embers_dropped >= 3, "身後留下小火苗(%d 個)" % sal.embers_dropped)
	var ember := first_in(arena.get_ground_layer(), EmberPatch) as EmberPatch
	assert_not_null(ember)
	await wait_until(func() -> bool: return ember.is_armed(), 10)
	player.global_position = ember.global_position
	await wait_physics(2)
	assert_eq(damaged.count, 1, "踩到火苗被燙一下")
	reset_player_hit()
	await wait_physics(2)
	assert_eq(damaged.count, 1, "同一個火苗只燙一次")
	var gone := await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), EmberPatch) == 0, 40)
	assert_true(gone, "火苗很快熄掉")


# --- AW5 影子騎士、提燈鬼火 ---------------------------------------------------------------

func test_shadow_knight_shield_blocks_the_front_and_turns_slowly() -> void:
	make_fast_arena()
	var knight := spawn(&"shadow_knight", player.global_position + Vector2(0, -24)) as ShadowKnightEnemy
	knight.set_physics_process(false)
	knight.shield_dir = (player.global_position - knight.global_position).normalized()
	var hp := knight.hp
	knight.hit(20, player.global_position, 60.0)
	assert_eq(hp - knight.hp, roundi(20 * knight.shield_damage_mult), "正面打在盾牌上只剩一小部分")
	assert_true(knight.shield_damage_mult > 0.0 and knight.shield_damage_mult < 0.5, "盾牌大幅減傷")
	hp = knight.hp
	knight.hit(12, knight.global_position - knight.shield_dir * 20.0, 60.0)
	assert_eq(hp - knight.hp, 12, "從背後打得痛")
	hp = knight.hp
	knight.hit(12, knight.global_position + knight.shield_dir.orthogonal() * 20.0, 60.0)
	assert_eq(hp - knight.hp, 12, "從側面打得痛")
	# 慢慢轉身:繞到背後,一秒內轉不過來。
	knight.target = player
	var before := knight.shield_dir
	player.global_position = knight.global_position - knight.shield_dir * 24.0
	knight._turn_shield(0.5, knight.shield_turn_deg)
	var turned := rad_to_deg(absf(before.angle_to(knight.shield_dir)))
	assert_almost_eq(turned, knight.shield_turn_deg * 0.5, 0.5, "每秒最多轉 %.0f 度" % knight.shield_turn_deg)
	assert_true(knight.shield_turn_deg < 180.0)
	# 揮劍:扇形預警,走開就打不中。
	var damaged := watch_signal(EventBus.player_damaged)
	knight.shield_dir = (player.global_position - knight.global_position).normalized()
	knight._start_tell()
	assert_eq(knight._telegraph.shape, AttackTelegraph.Shape.SECTOR)
	assert_true(knight.tell(knight.swing_telegraph) >= 0.6)
	knight.set_physics_process(true)
	await wait_physics(2)
	player.global_position += Vector2(50, 0)
	await wait_until(func() -> bool: return knight.phase != ShadowKnightEnemy.Phase.TELL, 30)
	assert_eq(damaged.count, 0, "看到扇形就走開")


func test_lantern_wisp_heals_nearby_enemies_but_not_bosses_and_is_a_priority_target() -> void:
	make_fast_arena()
	var wisp := spawn(&"lantern_wisp", Vector2(60, 110)) as LanternWispEnemy
	var crow := spawn(&"scarecrow", Vector2(80, 110))
	var elite := spawn(&"crab_elite", Vector2(40, 140))
	for e: EnemyBase in [wisp, crow, elite]:
		e.set_physics_process(false)
	crow.take_damage(15)
	elite.take_damage(40)
	var crow_hp := crow.hp
	var elite_hp := elite.hp
	assert_eq(wisp.heal_targets().size(), 1, "範圍內只有一般的敵人會被回復")
	wisp._release_heal()
	assert_true(crow.hp > crow_hp, "回復附近的敵人(%d → %d)" % [crow_hp, crow.hp])
	assert_true(crow.hp <= crow.max_hp)
	assert_eq(elite.hp, elite_hp, "頭目、中頭目不回復")
	assert_eq(wisp.heals, 1)
	# 優先目標:金毛找目標時,鬼火比稍微近一點的敵人優先。
	player.global_position = Vector2(90, 200)
	wisp.global_position = Vector2(90, 176)
	crow.global_position = Vector2(80, 184)
	assert_true(wisp.is_priority_target())
	assert_eq(player._nearest_enemy(60.0), wisp, "先打提燈鬼火")
	# 逃跑:金毛靠近就飄走。
	wisp.set_physics_process(true)
	var start := wisp.global_position.distance_to(player.global_position)
	await wait_physics(10)
	assert_true(wisp.global_position.distance_to(player.global_position) > start + 4.0, "遠離金毛")
