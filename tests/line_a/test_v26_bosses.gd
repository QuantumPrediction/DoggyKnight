extends "res://tests/line_a/combat_test_base.gd"
## v2.6 頭目與新同伴(DEV_PLAN 第 19 節 AV6 至 AV8、AV10):綠騎士、摩根娜(三個階段、鏡像分身、月光束)、
## 蘭斯洛特(突刺、和鬥牛犬同時在場不重疊)。每個頭目至少有一個「看到預警就躲得開」的測試。


func before_each() -> void:
	Haptics.reset_for_tests()
	CombatFx.set_feel(null)
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.mode = &"story"
	GameState.chapter = 1
	GameState.level_index = 0


func after_each() -> void:
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	CombatFx.set_feel(null)
	await super()


func _projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group(EnemyProjectile.GROUP)


func _frames_while(condition: Callable, max_frames: int) -> int:
	var frames := 0
	while condition.call() and frames < max_frames:
		await get_tree().physics_frame
		frames += 1
	return frames


func _count_in(layer: Node, script_class: Variant) -> int:
	var n := 0
	for child in layer.get_children():
		if is_instance_of(child, script_class):
			n += 1
	return n


# --- AV6 綠騎士 ---------------------------------------------------------------------------

func test_green_knight_whip_long_red_line_hits_when_standing_and_misses_when_stepping_aside() -> void:
	make_arena()
	player.set_physics_process(false)
	var appeared := watch_signal(EventBus.boss_appeared)
	var damaged := watch_signal(EventBus.player_damaged)
	var gk := spawn(&"green_knight", player.global_position + Vector2(0, -80)) as GreenKnightBoss
	assert_eq(appeared.last_args(), [&"green_knight"], "出場發 boss_appeared")
	gk.target = player
	gk._start_whip(1)
	assert_eq(gk._telegraph.shape, AttackTelegraph.Shape.LINE, "長紅線預警")
	assert_true(gk._telegraph.length >= 100.0, "長長的一條(%.0f)" % gk._telegraph.length)
	var frames := await _frames_while(func() -> bool: return gk.phase == GreenKnightBoss.Phase.WHIP_TELL, 120)
	assert_true(frames >= 48, "預警約 0.9 秒(%d 格)" % frames)
	assert_eq(damaged.count, 1, "站著不動被藤鞭打中")
	assert_true(_count_in(arena.get_fx_layer(), VineLash) == 1, "藤鞭甩出去")
	player.invuln_left = 0.0
	gk.set_physics_process(false)
	gk._cancel_attack()
	gk._start_whip(1)
	gk.set_physics_process(true)
	await wait_physics(15)
	player.global_position += Vector2(24, 0)
	await wait_until(func() -> bool: return gk.phase != GreenKnightBoss.Phase.WHIP_TELL, 90)
	assert_eq(damaged.count, 1, "看到紅線就走開,藤鞭打不中")


func test_green_knight_thorn_ring_and_summon() -> void:
	make_arena()
	player.set_physics_process(false)
	var gk := spawn(&"green_knight", Vector2(90, 150)) as GreenKnightBoss
	gk.target = player
	gk.set_physics_process(false)
	gk._start_thorns()
	assert_eq(gk._thorn_lines.size(), 8, "荊棘環:8 條放射的預警線")
	assert_true(gk._tell_time(gk.thorn_telegraph) >= 0.7)
	gk._release_thorns()
	assert_eq(_projectiles().size(), 8, "8 根荊棘")
	assert_eq((_projectiles()[0] as EnemyProjectile).data.id, &"thorn")
	gk._start_summon()
	assert_eq(gk._summon_marks.size(), 2, "兩個紫色魔法圈")
	gk._summon()
	assert_eq(gk.alive_summons(), 2, "叫出 2 隻稻草人")


func test_green_knight_hat_off_at_half_then_faster_double_whip_and_kneels_when_defeated() -> void:
	make_arena()
	player.set_physics_process(false)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var gk := spawn(&"green_knight", player.global_position + Vector2(0, -80)) as GreenKnightBoss
	gk.target = player
	var speed1 := gk._speed_mult()
	gk.take_damage(gk.max_hp / 2)
	assert_eq(phases.last_args(), [2], "半血進入第二階段")
	assert_eq(gk.phase, GreenKnightBoss.Phase.HAT_OFF, "播 hat_off,停一下")
	assert_eq(gk.sprite.animation, &"hat_off")
	assert_false(gk.hat_on)
	assert_true(gk.is_invulnerable(), "帽子掉下時無敵(短暫停頓)")
	assert_eq(Haptics.last_kind, &"heavy", "手機震動")
	assert_eq(_count_in(arena.get_ground_layer(), LeafHat), 1, "葉子帽掉在地上")
	await wait_until(func() -> bool: return gk.phase != GreenKnightBoss.Phase.HAT_OFF, 120)
	assert_almost_eq(gk._speed_mult() / speed1, 1.25, 0.01, "之後速度 +25%")
	# C 線的沒戴帽子版本(<動畫>_bare):有就播,沒有就播原本的。
	var frames := gk.sprite.sprite_frames.duplicate() as SpriteFrames
	if not frames.has_animation(&"idle_bare"):
		frames.add_animation(&"idle_bare")
		frames.add_frame(&"idle_bare", frames.get_frame_texture(&"idle", 0))
	gk.sprite.sprite_frames = frames
	assert_eq(gk.bare_animation(&"idle"), &"idle_bare", "帽子掉了:播 idle_bare")
	assert_eq(gk.bare_animation(&"hat_off"), &"hat_off", "沒有 _bare 版本就播原本的")
	gk._play(&"idle", true)
	assert_eq(gk.sprite.animation, &"idle_bare")
	assert_eq(gk.current_thorn_count(), gk.thorn_count_phase2)
	assert_true(gk.current_thorn_count() <= 12)
	gk.set_physics_process(false)
	gk._cancel_attack()
	gk._start_whip(gk.whips_phase2)
	gk.set_physics_process(true)
	var twice := await wait_until(func() -> bool: return gk.whips_released >= 2, 180)
	assert_true(twice, "藤鞭連續兩次(每一鞭都有預警)")
	gk.take_damage(99999)
	var gone := await wait_until(func() -> bool: return not gk.is_in_group(&"enemy"), 120)
	assert_true(gone)
	assert_eq(_count_in(arena.get_ground_layer(), DefeatPose), 1, "單膝跪在地上(不是受傷)")
	assert_eq(_count_in(arena.get_ground_layer(), LeafHat), 1, "帽子還在地上")


# --- AV7 摩根娜 ---------------------------------------------------------------------------

func test_morgana_teleport_shows_a_moon_circle_first() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var appeared := watch_signal(EventBus.boss_appeared)
	var m := spawn(&"morgana", player.global_position + Vector2(0, -90)) as MorganaBoss
	assert_eq(appeared.last_args(), [&"morgana"], "出場發 boss_appeared")
	m.target = player
	m._start_teleport()
	var dest := m._teleport_to
	assert_eq(m._marks.size(), 1, "目的地先亮月光圈")
	assert_true((m._marks[0] as Node2D).global_position.distance_to(dest) < 0.5)
	assert_true(dest.distance_to(player.global_position) >= m.teleport_min - 1.0, "不會直接出現在金毛身上")
	var frames := await _frames_while(func() -> bool: return m.phase == MorganaBoss.Phase.TELEPORT_TELL, 90)
	assert_true(frames >= 40, "月光圈約 0.7 秒(%d 格)" % frames)
	assert_true(m.global_position.distance_to(dest) < 1.0, "在圈中出現")
	assert_eq(m.teleports_done, 1)
	assert_eq(damaged.count, 0, "站在圈外不會受傷")


func test_morgana_foxfire_rain_circles_hit_only_who_stays() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var m := spawn(&"morgana", Vector2(90, 100)) as MorganaBoss
	m.target = player
	m.set_physics_process(false)
	assert_eq(m.current_rain_count(), 5, "第一階段 5 個")
	m._start_rain()
	assert_eq(_count_in(arena.get_ground_layer(), FallingFlame), 5, "5 個預警圈")
	var points := m.pick_rain_points(8)
	assert_eq(points.size(), 8, "第三階段 8 個落點也放得下")
	for i in points.size():
		for j in range(i + 1, points.size()):
			assert_true(points[i].distance_to(points[j]) >= m.rain_spacing - 0.01, "落點彼此分開")
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 120)
	assert_true(hit, "站在圈裡被狐火打中")
	await wait_until(func() -> bool: return _count_in(arena.get_ground_layer(), FallingFlame) == 0, 90)
	player.invuln_left = 0.0
	var start := player.global_position
	m._start_rain()
	await wait_physics(10)
	player.global_position = start + Vector2(0, -90)
	await wait_until(func() -> bool: return _count_in(arena.get_ground_layer(), FallingFlame) == 0, 150)
	assert_eq(damaged.count, 1, "看到預警圈就走開,打不中")


func test_morgana_fan_has_gaps() -> void:
	make_arena()
	player.set_physics_process(false)
	var m := spawn(&"morgana", player.global_position + Vector2(0, -80)) as MorganaBoss
	m.target = player
	m.set_physics_process(false)
	m._start_fan()
	assert_eq(m._marks.size(), m.fan_count, "扇形預警線")
	assert_true(m.fan_gap_at(m.keep_min) >= 8.0, "最近的距離仍有空隙(%.1f)" % m.fan_gap_at(m.keep_min))
	m._release_fan()
	assert_eq(_projectiles().size(), m.fan_count)
	assert_eq((_projectiles()[0] as EnemyProjectile).data.id, &"moon_orb")


func test_morgana_mirror_clones_from_66_percent() -> void:
	make_arena()
	player.set_physics_process(false)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var m := spawn(&"morgana", player.global_position + Vector2(0, -90)) as MorganaBoss
	m.target = player
	m.take_damage(m.max_hp - roundi(m.max_hp * 0.66) + 1)
	assert_eq(phases.last_args(), [2], "66% 進入第二階段")
	assert_eq(m.phase, MorganaBoss.Phase.SHIFT, "停下施法(短暫停頓)")
	assert_true(m.is_invulnerable())
	assert_eq(Haptics.last_kind, &"heavy")
	var called := await wait_until(func() -> bool: return m.alive_summons() == 2, 180)
	assert_true(called, "叫出 2 個鏡像分身")
	var clone: MorganaClone = null
	for s in m._summons:
		if is_instance_valid(s):
			clone = s as MorganaClone
	assert_not_null(clone)
	assert_true(clone.tint.a < 0.8, "分身半透明")
	clone._phase_left = 0.0
	var aiming := await wait_until(func() -> bool: return clone.phase == MorganaClone.Phase.AIM, 30)
	assert_true(aiming, "分身也先畫預警線")
	assert_eq(clone._telegraph.shape, AttackTelegraph.Shape.LINE)
	await wait_until(func() -> bool: return clone.shots > 0, 90)
	var orb := _projectiles()[_projectiles().size() - 1] as EnemyProjectile
	assert_true(orb.damage < m.scaled_damage(m.moon_orb.damage), "分身的光球比較弱")
	var died := watch_signal(EventBus.enemy_died)
	clone.take_damage(1)
	assert_eq(died.count, 1, "一下就打散")


func test_morgana_rotating_beam_from_33_percent_is_avoidable() -> void:
	make_arena()
	player.set_physics_process(false)
	var damaged := watch_signal(EventBus.player_damaged)
	var m := spawn(&"morgana", Vector2(90, 110)) as MorganaBoss
	var phases := watch_signal(EventBus.boss_phase_changed)
	m.target = player
	m.beam_sweep_deg = 90.0
	m.beam_speed_deg = 120.0
	m.take_damage(m.max_hp - roundi(m.max_hp * 0.33) + 1)
	assert_eq(phases.calls.map(func(a: Array) -> int: return a[0]), [2, 3], "一下打到 33% 也依次進入第二、三階段")
	assert_eq(m.boss_phase, 3)
	var telling := await wait_until(func() -> bool: return m.phase == MorganaBoss.Phase.BEAM_TELL, 120)
	assert_true(telling, "第三階段開始就預警月光束")
	var line_mark := false
	for mark in m._marks:
		if mark is AttackTelegraph and (mark as AttackTelegraph).shape == AttackTelegraph.Shape.LINE:
			line_mark = true
	assert_true(line_mark, "紅線預警(起點)")
	assert_true(m._tell_time(m.beam_telegraph) >= 0.75, "預警夠長")
	# 站到扇形(會掃過的範圍)的另一邊:光束轉不到。
	var start := Vector2.from_angle(m.beam_angle)
	var safe := m.global_position + start.rotated(m._beam_sign * deg_to_rad(60.0)) * 50.0
	player.global_position = CombatMath.clamp_to_arena(safe, 8.0)
	var beamed := await wait_until(func() -> bool: return m.is_beaming(), 90)
	assert_true(beamed, "預警後光束開始轉")
	await wait_until(func() -> bool: return not m.is_beaming(), 120)
	assert_eq(damaged.count, 0, "站在扇形外,光束掃不到")
	assert_eq(m.moves_started[&"beam"], 1)


func test_morgana_defeat_sits_down_and_clears_clones_and_flames() -> void:
	make_arena()
	player.set_physics_process(false)
	var m := spawn(&"morgana", Vector2(90, 110)) as MorganaBoss
	m.target = player
	m.set_physics_process(false)
	m.take_damage(m.max_hp / 2)
	m._cancel_attack()
	m._start_clones()
	m._call_clones()
	m._start_rain()
	assert_eq(m.alive_summons(), 2)
	m.set_physics_process(true)
	m.take_damage(99999)
	assert_eq(m.sprite.animation, &"down", "倒下播 down")
	assert_eq(m.alive_summons(), 0, "分身一起散掉")
	var pending := 0
	for child in arena.get_ground_layer().get_children():
		if child is FallingFlame and (child as FallingFlame).is_pending():
			pending += 1
	assert_eq(pending, 0, "還沒落下的狐火熄掉")
	await wait_until(func() -> bool: return not m.is_in_group(&"enemy"), 150)
	assert_eq(_count_in(arena.get_ground_layer(), DefeatPose), 1, "坐在地上(不是受傷)")


# --- AV8 蘭斯洛特 -------------------------------------------------------------------------

func test_lancelot_and_bulldog_stand_on_both_sides_without_overlapping() -> void:
	make_arena()
	player.set_physics_process(false)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	var lance := arena.spawn_companion(&"lancelot") as LancelotCompanion
	assert_not_null(lance, "data/companions/lancelot.tres")
	assert_eq(lance.companion_id, &"lancelot")
	assert_true(lance.is_in_group(&"companion"))
	assert_true(signf(dog.global_position.x - player.global_position.x) != signf(lance.global_position.x - player.global_position.x),
			"一左一右出現")
	lance.global_position = dog.global_position + Vector2(1, 0)
	await wait_physics(60)
	var gap := dog.global_position.distance_to(lance.global_position)
	assert_true(gap >= dog.body_radius + lance.body_radius, "不會重疊(相距 %.1f)" % gap)
	assert_true(signf(dog.global_position.x - player.global_position.x) != signf(lance.global_position.x - player.global_position.x),
			"站在金毛的兩邊")
	assert_eq(arena.spawn_companion(&"lancelot"), lance, "同一位同伴不會重複生成")


func test_lancelot_dashes_at_the_nearest_enemy_then_returns() -> void:
	make_arena()
	player.set_physics_process(false)
	var lance := arena.spawn_companion(&"lancelot") as LancelotCompanion
	assert_almost_eq(lance.dash_interval, 3.0, 0.5, "約每 3 秒突刺")
	lance._dash_timer = lance.dash_interval - 0.05
	var dummy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -50))
	dummy.set_physics_process(false)
	var hp := dummy.hp
	var dashed := await wait_until(func() -> bool: return lance.dash_hits > 0, 90)
	assert_true(dashed, "向最近的敵人突刺")
	assert_eq(lance.sprite.animation, &"attack")
	assert_true(dummy.hp < hp, "刺中造成傷害")
	var back := await wait_until(func() -> bool:
		return lance.mode == LancelotCompanion.Mode.FOLLOW and lance.global_position.distance_to(player.global_position) < 26.0, 120)
	assert_true(back, "回到金毛身邊")


func test_lancelot_never_goes_down() -> void:
	make_arena()
	player.set_physics_process(false)
	var lance := arena.spawn_companion(&"lancelot") as LancelotCompanion
	lance.daze_time = 0.3
	lance.take_damage(999)
	assert_true(lance.is_dazed(), "受到很多傷害只會暈一下")
	assert_true(lance.is_in_group(&"companion"))
	var up := await wait_until(func() -> bool: return not lance.is_dazed(), 40)
	assert_true(up, "自己站起來")
