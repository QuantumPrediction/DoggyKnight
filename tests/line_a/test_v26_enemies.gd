extends "res://tests/line_a/combat_test_base.gd"
## v2.6 第二、三章的敵人(DEV_PLAN 4.13、第 19 節 AV1 至 AV5、AV9、AV10):
## 石像鬼、魔法書、狐火、影狼、石像鬼統領、幻影黑騎士;每章難度倍率;每個新敵人都打得倒。


func before_each() -> void:
	Haptics.reset_for_tests()
	CombatFx.set_feel(null)
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.mode = &"story"
	GameState.chapter = 1
	GameState.level_index = 0


func after_each() -> void:
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.mode = &"story"
	GameState.chapter = 1
	CombatFx.set_feel(null)
	await super()


func _projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group(EnemyProjectile.GROUP)


## 等到 enemy 的預警結束(或超過 max_frames),傳回經過幾格。
func _frames_while(condition: Callable, max_frames: int) -> int:
	var frames := 0
	while condition.call() and frames < max_frames:
		await get_tree().physics_frame
		frames += 1
	return frames


# --- 資料 -----------------------------------------------------------------------------

func test_new_enemy_data_files_and_names() -> void:
	for id: StringName in [&"gargoyle", &"gargoyle_elite", &"spellbook", &"foxfire", &"shadow_wolf",
			&"phantom_knight", &"green_knight", &"morgana", &"morgana_clone"]:
		var data := load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_not_null(data, String(id))
		if data == null:
			continue
		assert_eq(data.id, id, "資料 id = 檔名")
		assert_not_null(data.scene, "%s 有場景" % id)
		assert_true(data.max_hp > 0 and data.move_speed > 0.0, "%s 有生命與速度" % id)
		assert_ne(tr(data.display_name), data.display_name, "i18n/strings.csv 有 %s" % data.display_name)
	assert_not_null(CombatFx.frames(&"fox_flame"), "狐火雨用 assets/fx/fox_flame")
	for id: StringName in [&"magic_orb", &"thorn", &"moon_orb"]:
		var p := load("res://data/enemies/projectiles/%s.tres" % id) as ProjectileData
		assert_not_null(p, "投射物資料 %s" % id)
		if p != null:
			assert_eq(p.fx, id, "圖用 assets/fx/%s" % id)
			assert_not_null(CombatFx.frames(p.fx), "assets/fx/%s 有圖" % id)
			assert_true(p.blockable, "鬥牛犬的盾擋得住 %s" % id)
	var crow := load("res://data/enemies/crow.tres") as EnemyData
	var gargoyle := load("res://data/enemies/gargoyle.tres") as EnemyData
	assert_almost_eq(float(gargoyle.max_hp) / float(crow.max_hp), 2.5, 0.2, "石像鬼的生命約烏鴉的 2.5 倍")
	var knight := load("res://data/enemies/black_knight.tres") as EnemyData
	var phantom := load("res://data/enemies/phantom_knight.tres") as EnemyData
	assert_almost_eq(float(phantom.max_hp) / float(knight.max_hp), 0.6, 0.05, "幻影黑騎士的生命約黑騎士的 60%")


## AV10:每一個新敵人與頭目在場地裡都打得倒(發 enemy_died、離開 enemy 群組)。
func test_every_new_enemy_can_be_defeated() -> void:
	make_arena()
	player.set_physics_process(false)
	var died := watch_signal(EventBus.enemy_died)
	var ids: Array[StringName] = [&"gargoyle", &"spellbook", &"foxfire", &"shadow_wolf", &"gargoyle_elite",
			&"phantom_knight", &"green_knight", &"morgana"]
	var enemies: Array[EnemyBase] = []
	for i in ids.size():
		var at := Vector2(30 + (i % 4) * 40, 100 + (i / 4) * 60)
		var e := spawn(ids[i], at)
		assert_not_null(e, "生成 %s" % ids[i])
		enemies.append(e)
	await wait_physics(2)
	for e in enemies:
		if e.has_method(&"is_stone") and bool(e.call(&"is_stone")):
			e.get(&"flight").set(&"phase", GargoyleFlight.Phase.HOVER)
		e.take_damage(999999)
	var all_gone := await wait_until(func() -> bool:
		for e in enemies:
			if is_instance_valid(e) and e.is_in_group(&"enemy"):
				return false
		return true, 180)
	assert_true(all_gone, "全部倒下(頭目播完倒下演出)")
	var seen: Array = []
	for args: Array in died.calls:
		seen.append(args[0])
	for id in ids:
		assert_true(seen.has(id), "%s 發了 enemy_died" % id)


# --- AV9 每章難度 ------------------------------------------------------------------------

func test_chapter_multipliers_stack_with_the_level_ramp_in_story_mode_only() -> void:
	var scaling := DifficultyScaling.get_default()
	assert_eq(scaling.chapter_hp_mult.size(), 3)
	for i in 3:
		assert_almost_eq(scaling.chapter_hp(i + 1), [1.0, 1.3, 1.6][i], 0.001, "第 %d 章生命倍率" % (i + 1))
	assert_almost_eq(scaling.chapter_damage(1), 1.0, 0.001, "第一章傷害 ×1.0")
	assert_almost_eq(scaling.chapter_damage(2), 1.2, 0.001, "第二章傷害 ×1.2")
	assert_almost_eq(scaling.chapter_damage(3), 1.4, 0.001, "第三章傷害 ×1.4")
	make_arena()
	GameState.level_index = 2
	var ramp_hp := scaling.hp_ramp_by_level[2]
	var ramp_dmg := scaling.damage_ramp_by_level[2]
	var c1 := spawn(&"scarecrow", Vector2(40, 100))
	assert_eq(c1.max_hp, roundi(25 * ramp_hp), "第一章:只有每關的遞增")
	GameState.chapter = 3
	var c3 := spawn(&"scarecrow", Vector2(140, 100))
	assert_eq(c3.max_hp, roundi(25 * ramp_hp * 1.6), "第三章:章倍率 × 每關遞增")
	assert_eq(c3.data.contact_damage, roundi(8 * ramp_dmg * 1.4))
	var boss := spawn(&"green_knight", Vector2(90, 140))
	assert_eq(boss.max_hp, roundi(700 * ramp_hp * 1.6), "頭目也套用章倍率")
	assert_eq(boss.scaled_damage(10), roundi(10 * ramp_dmg * 1.4), "不在資料檔的傷害也套用")
	GameState.difficulty = &"hard"
	var hard := spawn(&"scarecrow", Vector2(40, 200))
	var hard_mode := scaling.mode(&"hard")
	assert_eq(hard.max_hp, roundi(25 * hard_mode.hp_mult * ramp_hp * 1.6), "和困難模式也相乘")
	GameState.difficulty = &"normal"
	GameState.mode = &"endless"
	var endless := spawn(&"scarecrow", Vector2(140, 200))
	assert_eq(endless.max_hp, 25, "無盡試煉不套用章倍率")
	assert_eq((load("res://data/enemies/scarecrow.tres") as EnemyData).max_hp, 25, "資料檔沒有被改")


# --- AV1 石像鬼 ---------------------------------------------------------------------------

func test_gargoyle_turns_to_stone_unhittable_and_unpushable() -> void:
	make_arena()
	player.set_physics_process(false)
	var g := spawn(&"gargoyle", player.global_position + Vector2(0, -70)) as GargoyleEnemy
	await wait_physics(1)
	g.flight.start_stone()
	assert_true(g.is_stone(), "變成石頭")
	assert_eq(g.sprite.animation, &"stone", "播 stone")
	var hp := g.hp
	var start := g.global_position
	g.hit(50, start + Vector2(-10, 0), 200.0)
	assert_eq(g.hp, hp, "打不動")
	assert_eq(g.flight.clangs, 1, "受擊「鏘」")
	assert_true(g.get_children().any(func(c: Node) -> bool: return c is SpeechBubble), "頭上冒「鏘!」")
	g.stun(2.0)
	assert_false(g.is_stunned(), "石頭不會被震懾")
	await wait_physics(10)
	assert_true(g.global_position.distance_to(start) < 1.0, "推不動、不會動")
	var back := await wait_until(func() -> bool: return not g.is_stone(), 120)
	assert_true(back, "約 1.5 秒後變回來")
	g.take_damage(5)
	assert_eq(g.hp, hp - 5, "變回來就打得動")
	assert_almost_eq(g.tuning.stone_interval, 4.0, 0.5, "約每 4 秒變一次")


func test_gargoyle_swoop_is_telegraphed_and_dodgeable() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var g := spawn(&"gargoyle", player.global_position + Vector2(0, -70)) as GargoyleEnemy
	await wait_physics(1)
	g.target = player
	g.flight._stone_left = 99.0
	g.flight.start_tell()
	assert_eq(g._telegraph.shape, AttackTelegraph.Shape.LINE, "紅線預警")
	assert_true(g._telegraph.direction.dot(Vector2.DOWN) > 0.95, "朝著金毛")
	var frames := await _frames_while(func() -> bool: return g.flight.phase == GargoyleFlight.Phase.TELL, 120)
	assert_true(frames >= 36, "預警至少 0.6 秒(%d 格)" % frames)
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 60)
	assert_true(hit, "站著不動會被撞到")
	# 第二次:看到紅線就走開。
	player.invuln_left = 0.0
	await wait_until(func() -> bool: return g.flight.phase == GargoyleFlight.Phase.HOVER, 120)
	var count := damaged.count
	g.flight.start_tell()
	await wait_physics(12)
	player.global_position += g.flight._dir.orthogonal() * 24.0
	await wait_until(func() -> bool: return g.flight.phase == GargoyleFlight.Phase.RECOVER, 120)
	assert_eq(damaged.count, count, "看到紅線就走開,撞不到")


# --- AV2 魔法書 ---------------------------------------------------------------------------

func test_spellbook_fan_has_gaps_and_more_orbs_on_hard() -> void:
	make_arena()
	player.set_physics_process(false)
	var book := spawn(&"spellbook", player.global_position + Vector2(0, -90)) as SpellbookEnemy
	assert_true(book.keep_min >= 70.0 and book.keep_max <= 110.0, "保持 70 至 110 像素")
	assert_eq(book.current_orb_count(), 3, "一般 3 顆")
	assert_true(book.gap_at(book.keep_min) >= 8.0, "在最近的距離,光球之間仍有可以鑽過的空隙(%.1f 像素)" % book.gap_at(book.keep_min))
	GameState.difficulty = &"hard"
	assert_eq(book.current_orb_count(), 5, "困難模式 5 顆")
	GameState.difficulty = &"normal"
	GameState.level_index = book.strong_from_level
	assert_eq(book.current_orb_count(), 5, "後段關卡 5 顆")
	GameState.level_index = 0
	book.target = player
	book._cooldown_left = 0.0
	var casting := await wait_until(func() -> bool: return book.phase == SpellbookEnemy.Phase.CAST, 30)
	assert_true(casting, "冷卻好了就施法")
	assert_eq(book._lines.size(), 3, "三條扇形預警線")
	var frames := await _frames_while(func() -> bool: return book.phase == SpellbookEnemy.Phase.CAST, 120)
	assert_true(frames >= 45, "預警約 0.85 秒(%d 格)" % frames)
	assert_eq(book.orbs_fired, 3)
	assert_eq(_projectiles().size(), 3, "三顆光球沿預警線飛")
	assert_eq((_projectiles()[0] as EnemyProjectile).data.id, &"magic_orb")


func test_spellbook_backs_away_and_orbs_miss_when_standing_in_a_gap() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var book := spawn(&"spellbook", player.global_position + Vector2(0, -40)) as SpellbookEnemy
	book._cooldown_left = 99.0
	var start := book.global_position.distance_to(player.global_position)
	await wait_physics(60)
	assert_true(book.global_position.distance_to(player.global_position) > start + 10.0, "金毛靠近就往後飄")
	book.global_position = player.global_position + Vector2(0, -90)
	book.target = player
	book._start_cast()
	# 站到中間那顆與旁邊那顆之間(兩條線的角平分線上)。
	var mid := book._dirs[1].rotated(deg_to_rad(book.fan_step_deg) * 0.5)
	player.global_position = book.global_position + mid * 90.0
	await wait_until(func() -> bool: return book.phase != SpellbookEnemy.Phase.CAST, 90)
	await wait_physics(80)
	assert_eq(damaged.count, 0, "站在空隙裡,光球打不中")


# --- AV3 狐火 ---------------------------------------------------------------------------

func test_foxfire_is_fragile_warns_then_bursts() -> void:
	make_arena()
	player.set_physics_process(false)
	var died := watch_signal(EventBus.enemy_died)
	var damaged := watch_signal(EventBus.player_damaged)
	GameState.chapter = 3
	GameState.difficulty = &"hard"
	var tough := spawn(&"foxfire", Vector2(30, 90)) as FoxfireEnemy
	tough.take_damage(1)
	assert_true(tough.is_dead(), "很脆:一下打倒(第三章困難模式也一樣)")
	assert_eq(died.count, 1)
	GameState.chapter = 1
	GameState.difficulty = &"normal"
	var fox := spawn(&"foxfire", player.global_position + Vector2(0, -50)) as FoxfireEnemy
	var warned := await wait_until(func() -> bool: return fox.phase == FoxfireEnemy.Phase.WARN, 120)
	assert_true(warned, "追到金毛附近就停下")
	assert_eq(fox._telegraph.shape, AttackTelegraph.Shape.CIRCLE, "地上亮預警圈")
	var frames := await _frames_while(func() -> bool: return fox.phase == FoxfireEnemy.Phase.WARN and not fox.is_dead(), 90)
	assert_true(frames >= 33, "預警約 0.6 秒(%d 格)" % frames)
	assert_true(fox.burst_away, "爆開")
	assert_eq(damaged.count, 1, "站在圈裡會受傷")
	assert_false(fox.is_in_group(&"enemy"), "爆開後離開 enemy 群組")
	assert_eq(died.count, 1, "爆開不算被打倒(不發 enemy_died、不掉經驗)")


func test_foxfire_killed_while_warning_never_bursts_and_stops_after_chasing() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var fox := spawn(&"foxfire", player.global_position + Vector2(0, -24)) as FoxfireEnemy
	await wait_until(func() -> bool: return fox.phase == FoxfireEnemy.Phase.WARN, 60)
	fox.take_damage(1)
	assert_true(fox.is_dead())
	assert_false(fox.burst_away)
	await wait_physics(50)
	assert_eq(damaged.count, 0, "打倒的不會爆")
	# 追不到也會在 4 秒後停下預警(這裡把追蹤時間調短來測)。
	var far := spawn(&"foxfire", Vector2(20, 80)) as FoxfireEnemy
	far.max_chase_time = 0.3
	var stopped := await wait_until(func() -> bool: return far.phase == FoxfireEnemy.Phase.WARN, 60)
	assert_true(stopped, "追了一段時間就停下預警")
	assert_true(far.global_position.distance_to(player.global_position) > far.burst_radius + 10.0, "離得遠時爆開打不到")
	var tell_pos := far.global_position
	await wait_until(func() -> bool: return far.burst_away, 60)
	assert_true(tell_pos.distance_to(far.global_position) < 0.5, "預警時不再移動(圈的位置固定)")
	assert_eq(damaged.count, 0, "圈外不會受傷")
	assert_almost_eq((load("res://game/actors/enemies/foxfire.tscn").instantiate() as FoxfireEnemy).max_chase_time, 4.0, 0.01, "預設追 4 秒")


# --- AV4 影狼 ---------------------------------------------------------------------------

func test_shadow_wolves_take_turns_dash_on_a_red_line() -> void:
	make_arena()
	player.set_physics_process(false)
	GameState.level_index = 5
	var damaged := watch_signal(EventBus.player_damaged)
	var wolves: Array[ShadowWolfEnemy] = []
	for i in 3:
		var w := spawn(&"shadow_wolf", player.global_position + Vector2.from_angle(TAU * i / 3.0 - PI * 0.5) * 70.0) as ShadowWolfEnemy
		w._cooldown_left = 0.05 * i
		wolves.append(w)
	var most := 0
	var tells := 0
	for f in 150:
		await get_tree().physics_frame
		player.invuln_left = 0.0
		var now := 0
		for w in wolves:
			if w.phase == ShadowWolfEnemy.Phase.TELL or w.phase == ShadowWolfEnemy.Phase.DASH:
				now += 1
				if w.phase == ShadowWolfEnemy.Phase.TELL and w._telegraph != null:
					assert_eq(w._telegraph.shape, AttackTelegraph.Shape.LINE)
		most = maxi(most, now)
	for w in wolves:
		tells += w.dashes
	assert_eq(most, 1, "同一時間只有一隻衝鋒(輪流)")
	assert_true(tells >= 2, "輪流衝了 %d 次" % tells)
	assert_true(damaged.count >= 1, "站著不動會被衝到")


func test_shadow_wolf_dash_misses_after_stepping_off_the_line_and_falls_into_leaves() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var w := spawn(&"shadow_wolf", player.global_position + Vector2(-70, 0)) as ShadowWolfEnemy
	await wait_physics(1)
	w.target = player
	w._start_tell()
	var frames := await _frames_while(func() -> bool:
		if w.phase == ShadowWolfEnemy.Phase.TELL and w._phase_left < 0.3 and player.global_position.y > 200.0:
			player.global_position += Vector2(0, -22)
		return w.phase == ShadowWolfEnemy.Phase.TELL, 120)
	assert_true(frames >= 40, "紅線預警約 0.75 秒(%d 格)" % frames)
	await wait_until(func() -> bool: return w.phase == ShadowWolfEnemy.Phase.RECOVER, 60)
	assert_eq(damaged.count, 0, "走開就衝不到")
	w.take_damage(999)
	assert_eq(w.sprite.animation, &"down", "倒下播 down")
	var leaves := await wait_until(func() -> bool:
		return arena.get_fx_layer().get_children().any(func(c: Node) -> bool: return c is BitsScatter), 60)
	assert_true(leaves, "散成落葉")


# --- AV5 中頭目 ---------------------------------------------------------------------------

func test_gargoyle_elite_is_a_big_boss_that_calls_two_gargoyles_at_half() -> void:
	make_arena()
	player.set_physics_process(false)
	var appeared := watch_signal(EventBus.boss_appeared)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var boss := spawn(&"gargoyle_elite", player.global_position + Vector2(0, -100)) as GargoyleEliteBoss
	assert_eq(appeared.last_args(), [&"gargoyle_elite"], "出場發 boss_appeared")
	assert_almost_eq(boss.visual_scale, 1.5, 0.01, "放大 1.5 倍")
	var small := load("res://data/enemies/gargoyle.tres") as EnemyData
	assert_true(boss.max_hp >= small.max_hp * 8, "生命高")
	await wait_until(func() -> bool: return boss.mode == GargoyleEliteBoss.Mode.FLY, 90)
	boss.target = player
	boss.flight.start_tell()
	assert_true(boss.flight._tell_total >= 0.75, "俯衝預警比小石像鬼長")
	boss._cancel_attack()
	boss.take_damage(boss.max_hp / 2 + 1)
	assert_eq(phases.last_args(), [2])
	assert_eq(boss.mode, GargoyleEliteBoss.Mode.ROAR, "半血先停下尖叫(短暫無敵)")
	assert_true(boss.is_invulnerable())
	assert_eq(Haptics.last_kind, &"heavy", "手機震動")
	var summoned := await wait_until(func() -> bool: return boss.summons_called > 0, 150)
	assert_true(summoned, "尖叫後召喚")
	assert_eq(boss.alive_summons(), 2, "叫出 2 隻石像鬼")
	assert_eq(boss.flight.chain_swoops, 1, "第二階段落地後再俯衝一次")
	boss.take_damage(99999)
	await wait_until(func() -> bool: return not boss.is_in_group(&"enemy"), 90)
	assert_eq(boss.alive_summons(), 0, "統領倒下時,叫來的石像鬼一起碎掉")


func test_phantom_knight_is_a_faster_translucent_black_knight() -> void:
	make_arena()
	player.set_physics_process(false)
	var appeared := watch_signal(EventBus.boss_appeared)
	var knight := spawn(&"black_knight", Vector2(50, 120)) as BlackKnightBoss
	var phantom := spawn(&"phantom_knight", Vector2(130, 120)) as BlackKnightBoss
	assert_eq(appeared.last_args(), [&"phantom_knight"], "出場發 boss_appeared")
	assert_true(phantom.phantom)
	assert_true(phantom.tint.a < 0.9, "半透明")
	assert_true(phantom.tint.b > phantom.tint.g, "紫色")
	assert_almost_eq(phantom._speed_mult() / knight._speed_mult(), 1.3, 0.01, "速度 ×1.3")
	assert_almost_eq(phantom._tell_time(1.0) / knight._tell_time(1.0), 0.8, 0.01, "預警 ×0.8")
	assert_true(phantom._tell_time(phantom.charge_telegraph) >= 0.6, "衝鋒預警仍有 0.6 秒以上")
	phantom.take_damage(99999)
	await wait_until(func() -> bool: return not phantom.is_in_group(&"enemy"), 90)
	var mist := arena.get_fx_layer().get_children().any(func(c: Node) -> bool: return c is BitsScatter)
	assert_true(mist, "散成紫色霧")
	var remains := arena.get_ground_layer().get_children().any(func(c: Node) -> bool: return c.get(&"helmet_settled") != null)
	assert_false(remains, "沒有盔甲碎片")
