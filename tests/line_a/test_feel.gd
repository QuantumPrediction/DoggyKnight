extends "res://tests/line_a/combat_test_base.gd"
## AP11(M3 打磨):連擊計時與里程碑、boss_hp_changed 發出時機、頭目出場與第二階段無敵、
## 震動呼叫、特效數量上限,以及 AP1 至 AP10 的關鍵行為(鏡頭、傷害數字、稻草人打得中金毛、
## 慢動作、過關歡呼、鬥牛犬的「汪!」、烏鴉接連俯衝、稻草人包圍)。


func before_each() -> void:
	Haptics.reset_for_tests()
	CombatFx.set_feel(null)


func after_each() -> void:
	CombatFx.set_feel(null)
	await super()


# --- AP4 連擊 --------------------------------------------------------------------

func test_combo_counts_kills_and_lapses_after_the_window() -> void:
	make_arena()
	var combo := arena.combo
	combo.set_physics_process(false)
	var changed := watch_signal(EventBus.combo_changed)
	for i in 3:
		combo.add_kill()
		combo.step(1.0)
	assert_eq(combo.count, 3, "每次相隔 1 秒(< 2 秒):連擊累積")
	assert_eq(changed.count, 3)
	assert_eq(changed.last_args(), [3])
	combo.step(0.9)
	assert_eq(combo.count, 3, "還在 2 秒之內")
	combo.step(0.2)
	assert_eq(combo.count, 0, "超過 2 秒沒有擊倒:連擊中斷")
	assert_eq(changed.last_args(), [0], "中斷時發 combo_changed(0)")
	assert_eq(changed.count, 4)
	combo.step(5.0)
	assert_eq(changed.count, 4, "已經是 0 時不再重複發")


func test_combo_listens_to_enemy_died() -> void:
	make_arena()
	var changed := watch_signal(EventBus.combo_changed)
	spawn(&"scarecrow", Vector2(40, 100)).take_damage(999)
	spawn(&"scarecrow", Vector2(140, 100)).take_damage(999)
	assert_eq(arena.combo.count, 2)
	assert_eq(changed.calls, [[1], [2]])


func test_combo_milestones_add_loyalty() -> void:
	make_arena()
	var combo := arena.combo
	combo.set_physics_process(false)
	var feel := CombatFx.feel()
	for i in 4:
		combo.add_kill()
	assert_eq(player.loyalty, 0.0, "4 連擊還沒有獎勵")
	combo.add_kill()
	assert_eq(combo.milestones_hit, 1, "5 連擊是里程碑")
	assert_almost_eq(player.loyalty, feel.combo_milestone_loyalty[0], 0.001, "加忠誠度")
	for i in 5:
		combo.add_kill()
	assert_eq(combo.milestones_hit, 2, "10 連擊")
	for i in 10:
		combo.add_kill()
	assert_eq(combo.milestones_hit, 3, "20 連擊")
	var total := feel.combo_milestone_loyalty[0] + feel.combo_milestone_loyalty[1] + feel.combo_milestone_loyalty[2]
	assert_almost_eq(player.loyalty, minf(total, player.tuning.loyalty_max), 0.001)
	for i in 10:
		combo.add_kill()
	assert_eq(combo.milestones_hit, 4, "之後每 10 連擊再獎勵一次(30)")
	assert_eq(combo.loyalty_for(29), 0.0)
	assert_eq(combo.loyalty_for(40), feel.combo_repeat_loyalty)


func test_combo_resets_to_zero_when_the_arena_goes_away() -> void:
	make_arena()
	arena.combo.add_kill()
	var changed := watch_signal(EventBus.combo_changed)
	remove_child(arena)
	assert_eq(changed.last_args(), [0], "場地離開時讓 HUD 的連擊歸零")
	add_child(arena)


# --- AP5 頭目 ---------------------------------------------------------------------

func test_boss_walks_in_invulnerable_and_announces_hp() -> void:
	make_arena(-1.0)
	var hp_changes := watch_signal(EventBus.boss_hp_changed)
	var damaged := watch_signal(EventBus.player_damaged)
	player.set_physics_process(false)
	var boss := spawn(&"black_knight", Vector2(40, 200)) as BlackKnightBoss
	assert_true(boss.is_walking_in(), "從城門走進來")
	assert_true(boss.global_position.y < Layout.ARENA_RECT.position.y, "起點在戰鬥區上方(橋頭城門)")
	assert_eq(hp_changes.count, 1, "出場時發 boss_hp_changed")
	assert_eq(hp_changes.last_args(), [700, 700])
	assert_true(boss.is_in_group(&"enemy"), "走進來時已算在場上")
	assert_false(boss.is_targetable())
	boss.take_damage(100)
	assert_eq(boss.hp, 700, "出場時無敵")
	await wait_physics(45)
	assert_true(boss.is_walking_in(), "大約 1.5 秒")
	var arrived := await wait_until(func() -> bool: return boss.is_targetable(), 90)
	assert_true(arrived, "走到定點後開打")
	assert_true(Layout.ARENA_RECT.has_point(boss.global_position))
	assert_eq(hp_changes.last_args(), [700, 700])
	assert_eq(damaged.count, 0, "出場時不攻擊")
	boss.take_damage(30)
	assert_eq(hp_changes.last_args(), [670, 700], "每次受傷都發 boss_hp_changed")
	boss.take_damage(5)
	assert_eq(hp_changes.last_args(), [665, 700])


func test_boss_phase_two_roar_is_invulnerable_and_glows() -> void:
	make_arena()
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	var hp_changes := watch_signal(EventBus.boss_hp_changed)
	boss.take_damage(boss.max_hp / 2)
	assert_eq(boss.boss_phase, 2)
	assert_eq(boss.phase, BlackKnightBoss.Phase.ROAR, "進入第二階段時怒吼")
	assert_true(boss.is_invulnerable(), "怒吼時短暫無敵")
	assert_false(boss.is_targetable())
	var hp := boss.hp
	boss.take_damage(40)
	assert_eq(boss.hp, hp, "怒吼時打不痛")
	assert_eq(hp_changes.count, 1)
	var done := await wait_until(func() -> bool: return boss.phase != BlackKnightBoss.Phase.ROAR, 120)
	assert_true(done, "怒吼結束")
	assert_false(boss.is_invulnerable())
	boss.take_damage(10)
	assert_eq(boss.hp, hp - 10)
	assert_true(boss._glow_amount > 0.0, "第二階段盔甲發紅光")


func test_boss_defeat_holds_about_a_second_with_slow_motion() -> void:
	make_arena()
	var boss := spawn(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	var hp_changes := watch_signal(EventBus.boss_hp_changed)
	boss.take_damage(9999)
	assert_eq(hp_changes.last_args(), [0, 700], "生命歸零也發 boss_hp_changed")
	assert_true(arena.is_slow_motion(), "慢動作")
	assert_true(CombatFx.time_scale < 1.0)
	assert_eq(Haptics.last_kind, &"heavy", "打倒頭目:heavy 震動")
	var start := Time.get_ticks_msec()
	var gone := await wait_until(func() -> bool: return not boss.is_in_group(&"enemy"), 150)
	var held := float(Time.get_ticks_msec() - start) / 1000.0
	assert_true(gone)
	assert_true(held >= 0.6 and held <= 1.5, "大約 1 秒後才離開 enemy 群組(%.2f 秒)" % held)
	var normal := await wait_until(func() -> bool: return CombatFx.time_scale >= 1.0, 120)
	assert_true(normal, "慢動作結束後回到正常速度")


func test_slow_motion_ends_when_the_arena_leaves() -> void:
	make_arena()
	arena.slow_motion(0.3, 5.0)
	assert_almost_eq(CombatFx.time_scale, 0.3, 0.001)
	remove_child(arena)
	assert_eq(CombatFx.time_scale, 1.0, "場地離開時一定回到正常速度")
	add_child(arena)


# --- AP9 震動 ---------------------------------------------------------------------

func test_haptics_for_hit_ultimate_and_boss_slam() -> void:
	make_arena()
	player.take_damage(5)
	assert_eq(Haptics.last_kind, &"medium", "金毛被擊中:medium")
	Haptics.reset_for_tests()
	player.add_loyalty(999.0)
	player.use_ultimate()
	var struck := await wait_until(func() -> bool: return Haptics.last_kind == &"heavy", 60)
	assert_true(struck, "必殺技斬下:heavy")
	Haptics.reset_for_tests()
	var boss := spawn(&"black_knight", Vector2(90, 150)) as BlackKnightBoss
	boss.target = player
	boss._start_slam()
	boss._slam()
	assert_eq(Haptics.last_kind, &"heavy", "頭目重劈:heavy")


func test_haptics_respect_the_setting() -> void:
	make_arena()
	GameState.haptics_on = false
	player.take_damage(5)
	assert_eq(Haptics.play_count, 0, "震動關掉時不震")
	GameState.haptics_on = true


# --- AP6 必殺技 -------------------------------------------------------------------

func test_ultimate_darkens_freezes_enemies_then_strikes() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(50, 0))
	var far := spawn(&"crow", Vector2(20, 80))
	player.add_loyalty(999.0)
	assert_true(player.use_ultimate())
	var overlay: ScreenTint = null
	for child in arena.get_children():
		if child is ScreenTint:
			overlay = child
	assert_not_null(overlay, "畫面變暗")
	assert_true(overlay.pillar, "光柱")
	assert_true(player.z_index > overlay.z_index, "金毛在暗幕之上,不會被蓋住")
	assert_true(enemy._hitstop_left > 0.0 and far._hitstop_left > 0.0, "所有敵人短暫停頓")
	assert_true(player.invuln_left > 0.0, "蓄力時無敵")
	var pos := enemy.global_position
	await wait_physics(5)
	assert_true(enemy.global_position.distance_to(pos) < 0.5, "停頓中不會動")
	var hp := enemy.hp
	var struck := await wait_until(func() -> bool: return enemy.hp < hp, 40)
	assert_true(struck, "斬下")
	assert_eq(player.z_index, 0)


# --- 特效上限(品質標準 5) ------------------------------------------------------------

func test_particles_and_damage_numbers_are_capped() -> void:
	make_arena()
	var feel := CombatFx.feel()
	var before := CombatFx.particles_alive()
	for i in feel.max_particles + 20:
		CombatFx.particles(player, &"hit_burst", Vector2(90, 150))
	assert_true(CombatFx.particles_alive() <= maxi(feel.max_particles, before), "粒子同時最多 %d 個" % feel.max_particles)
	var important := CombatFx.particles(player, &"ultimate_burst", Vector2(90, 150), false, true)
	assert_not_null(important, "必殺技等重要特效不受上限限制")
	for i in feel.max_damage_numbers + 15:
		CombatFx.damage_number(player, 7, Vector2(90, 150))
	await get_tree().process_frame
	var numbers := 0
	for node in get_tree().get_nodes_in_group(DamageNumber.GROUP):
		if not node.is_queued_for_deletion():
			numbers += 1
	assert_true(numbers <= feel.max_damage_numbers, "傷害數字同時最多 %d 個(%d)" % [feel.max_damage_numbers, numbers])


func test_particle_counter_goes_back_down() -> void:
	make_arena()
	var before := CombatFx.particles_alive()
	CombatFx.particles(player, &"footstep_dust", Vector2(90, 150), true)
	assert_eq(CombatFx.particles_alive(), before + 1)
	arena.clear()
	await get_tree().process_frame
	assert_eq(CombatFx.particles_alive(), before, "清場後計數歸位")


# --- AP2 命中回饋 ------------------------------------------------------------------

func test_hits_pop_damage_numbers_and_squash() -> void:
	make_arena()
	var enemy := spawn(&"scarecrow_elite", Vector2(60, 120))
	enemy.set_physics_process(false)
	enemy.hit(12, enemy.global_position + Vector2(-10, 0), 0.0)
	var number := _last_number()
	assert_not_null(number, "跳出傷害數字")
	assert_eq(number.value, 12)
	assert_eq(number.style, DamageNumber.Style.NORMAL)
	assert_true(enemy.sprite.scale.x > enemy.visual_scale and enemy.sprite.scale.y < enemy.visual_scale,
			"被打中時擠壓變形")
	enemy.hit(24, enemy.global_position + Vector2(-10, 0), 0.0, DamageNumber.Style.CRIT)
	assert_eq(_last_number().style, DamageNumber.Style.CRIT, "握手的雙倍傷害用大字")


func test_shake_crit_uses_the_big_number() -> void:
	make_arena()
	player.abilities.add_trick(&"shake")
	player.abilities.shake._since_trigger = player.abilities.shake.interval() - 1
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(18, 0))
	enemy.set_physics_process(false)
	var landed := await wait_until(func() -> bool: return enemy.hp < 75, 60)
	assert_true(landed)
	assert_eq(_last_number().style, DamageNumber.Style.CRIT)
	assert_eq(_last_number().value, 20)


# --- AP1 鏡頭 ---------------------------------------------------------------------

func test_trauma_shakes_then_settles_and_swing_nudges() -> void:
	make_arena()
	arena.add_trauma(0.4)
	arena.add_trauma(0.4)
	assert_almost_eq(arena.trauma, 0.8, 0.001, "震動量會累積")
	arena.add_trauma(1.0)
	assert_eq(arena.trauma, 1.0, "最多 1")
	var moved := false
	for i in 10:
		await get_tree().process_frame
		if arena.camera_offset() != Vector2.ZERO:
			moved = true
	assert_true(moved, "鏡頭會晃")
	var settled := await wait_until(func() -> bool: return arena.trauma == 0.0 and arena.camera_offset() == Vector2.ZERO, 120)
	assert_true(settled, "震動量衰減後鏡頭回到中間")
	assert_eq(arena.camera_offset(), arena.camera_offset().round(), "偏移是整數像素")
	arena.nudge(Vector2.RIGHT, 3.0)
	arena._update_camera(1.0 / 60.0)
	assert_true(arena.camera_offset().x > 0.0, "揮劍時鏡頭推向攻擊方向")
	var back := await wait_until(func() -> bool: return arena.camera_offset() == Vector2.ZERO, 60)
	assert_true(back, "然後回到中間")


func test_getting_hit_adds_trauma() -> void:
	make_arena()
	player.take_damage(5)
	assert_true(arena.trauma > 0.0)


# --- AP3 稻草人打得中站著的金毛 -----------------------------------------------------

func test_a_single_scarecrow_can_hit_a_stationary_goldie() -> void:
	make_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	player.set_move_override(Vector2.ZERO)
	spawn(&"scarecrow", player.global_position + Vector2(0, -60))
	var hit := await wait_until(func() -> bool: return damaged.count > 0, 240)
	assert_true(hit, "站著不動的金毛會被單獨一隻稻草人兵打中(金毛自動攻擊、擊退都正常)")


# --- AP7 敵人 ---------------------------------------------------------------------

func test_scarecrows_surround_instead_of_lining_up() -> void:
	make_arena()
	player.set_physics_process(false)
	var center := player.global_position
	var crowd: Array[ScarecrowEnemy] = []
	for i in 4:
		var s := spawn(&"scarecrow", Vector2(30 + i * 40, 90)) as ScarecrowEnemy
		s.attack_trigger_range = 4.0     # 只看走位,不讓牠們停下來攻擊
		crowd.append(s)
	await wait_physics(480)
	var angles: Array[float] = []
	for s in crowd:
		angles.append((s.global_position - center).angle())
	angles.sort()
	var widest := 0.0
	for i in angles.size():
		var next := angles[(i + 1) % angles.size()] + (TAU if i == angles.size() - 1 else 0.0)
		widest = maxf(widest, next - angles[i])
	assert_true(widest < PI * 1.5, "四隻稻草人分散在金毛四周(最大空隙 %.0f 度)" % rad_to_deg(widest))


func test_crow_can_call_a_wingman() -> void:
	make_arena()
	player.set_physics_process(false)
	var a := spawn(&"crow", Vector2(30, 90)) as CrowEnemy
	var b := spawn(&"crow", Vector2(150, 90)) as CrowEnemy
	a.pair_dive_chance = 1.0
	b.pair_dive_chance = 0.0
	var circling := await wait_until(func() -> bool:
		return a.phase == CrowEnemy.Phase.CIRCLE and b.phase == CrowEnemy.Phase.CIRCLE, 120)
	assert_true(circling)
	b._phase_left = 99.0
	a._phase_left = 0.0
	var told := await wait_until(func() -> bool: return a.phase == CrowEnemy.Phase.TELEGRAPH, 10)
	assert_true(told)
	assert_eq(a.pair_dives_called, 1, "叫另一隻接著俯衝")
	var follow := await wait_until(func() -> bool: return b.phase == CrowEnemy.Phase.TELEGRAPH, 40)
	assert_true(follow, "第二隻稍後也預警、俯衝")
	assert_not_null(b._telegraph, "第二隻也有自己的預警線")


func test_enemies_rise_from_the_ground_and_elite_has_an_aura() -> void:
	make_arena(0.3)
	var elite := spawn(&"scarecrow_elite", Vector2(60, 120))
	assert_true(elite.elite)
	assert_true(elite.sprite.scale.y < elite.visual_scale * 0.5, "從地面冒出(一開始很扁)")
	assert_false(elite.is_targetable())
	elite.take_damage(10)
	assert_eq(elite.hp, 75, "冒出地面時打不到")
	var up := await wait_until(func() -> bool: return elite.is_targetable(), 40)
	assert_true(up)
	assert_false(spawn(&"scarecrow", Vector2(120, 120)).elite)


# --- AP8、AP10 慶祝與個性 ------------------------------------------------------------

func test_level_completed_makes_goldie_and_bulldog_cheer() -> void:
	make_arena()
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	EventBus.level_completed.emit(&"1-1")
	assert_true(player.celebrating, "金毛歡呼")
	assert_true(dog.celebrating, "鬥牛犬歡呼")
	var swings := player.swing_count
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(18, 0))
	enemy.set_physics_process(false)
	await wait_physics(40)
	assert_eq(player.swing_count, swings, "過關後不再攻擊")
	var goldie_hopped := false
	var dog_hopped := false
	for i in 90:
		await get_tree().physics_frame
		goldie_hopped = goldie_hopped or player.sprite.position.y < -0.5
		dog_hopped = dog_hopped or dog.sprite.position.y < -0.5
	assert_true(goldie_hopped, "金毛原地跳起來")
	assert_true(dog_hopped, "鬥牛犬跳起來")


func test_bulldog_says_woof_when_guarding() -> void:
	make_arena()
	player.set_physics_process(false)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -40))
	enemy.set_physics_process(false)
	var guarding := await wait_until(func() -> bool: return dog.is_taunting(), 120)
	assert_true(guarding)
	assert_eq(dog.woofs, 1, "舉盾時冒「汪!」")
	var bubble: SpeechBubble = null
	for child in dog.get_children():
		if child is SpeechBubble:
			bubble = child
	assert_not_null(bubble)
	assert_eq(bubble.text, tr(&"COMPANION_BULLDOG_WOOF"))
	assert_ne(bubble.text, "COMPANION_BULLDOG_WOOF", "i18n/strings.csv 有這個鍵")
	assert_false(dog.woof(), "有冷卻,不會一直冒")


func _last_number() -> DamageNumber:
	var numbers := get_tree().get_nodes_in_group(DamageNumber.GROUP)
	return numbers[numbers.size() - 1] as DamageNumber if not numbers.is_empty() else null
