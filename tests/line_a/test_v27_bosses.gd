extends "res://tests/line_a/fast_combat_test_base.gd"
## v2.7 頭目與新同伴(DEV_PLAN 第 20 節 AW2、AW4、AW6、AW7、AW9):章魚王、紅龍與白龍(雙頭目、合計血條、
## 坐下生悶氣與暴怒)、莫德雷德第一戰(半血逃走 = 過關)、莫德雷德(劍鞘護盾只有同伴打得破、舊頭目的幻影)、
## 崔斯坦(音符)、高文(鐵鎚震暈)、四位同伴同時在場不重疊。每個頭目至少有一個「看到預警就躲得開」的測試。
## 為了測試總時間,這裡的測試都快轉(fast_combat_test_base.gd)。


# --- AW2 章魚王 ---------------------------------------------------------------------------

func _tentacle_down() -> bool:
	var slam := first_in(arena.get_ground_layer(), TentacleSlam) as TentacleSlam
	return slam != null and slam.is_tip_down()


func test_kraken_tentacle_red_line_from_the_edge_is_dodgeable() -> void:
	make_fast_arena()
	var appeared := watch_signal(EventBus.boss_appeared)
	var damaged := watch_signal(EventBus.player_damaged)
	var kraken := spawn(&"kraken", Vector2(90, 116)) as KrakenBoss
	assert_eq(appeared.last_args(), [&"kraken"], "出場發 boss_appeared")
	kraken.target = player
	kraken._start_tentacles()
	var slam := first_in(arena.get_ground_layer(), TentacleSlam) as TentacleSlam
	assert_not_null(slam, "觸手從邊緣伸進來")
	var r := Layout.ARENA_RECT
	var on_edge := absf(slam.global_position.x - r.position.x) < 1.0 or absf(slam.global_position.x - r.end.x) < 1.0 \
			or absf(slam.global_position.y - r.end.y) < 1.0
	assert_true(on_edge, "起點在場地邊緣")
	assert_true(EnemyProjectile.segment_distance(slam.global_position, slam.global_position + slam.direction * slam.length,
			player.global_position) < 1.0, "紅線經過金毛現在的位置")
	assert_true(slam.length >= 140.0, "長長的紅線")
	assert_true(slam.tell_time >= 0.85, "預警夠長(%.2f 秒)" % slam.tell_time)
	await wait_until(_tentacle_down, 40)
	assert_eq(damaged.count, 1, "站著不動被觸手拍到")
	await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), TentacleSlam) == 0, 40)
	reset_player_hit()
	kraken.phase = KrakenBoss.Phase.IDLE
	kraken._start_tentacles()
	slam = first_in(arena.get_ground_layer(), TentacleSlam) as TentacleSlam
	await wait_physics(2)
	player.global_position += slam.direction.orthogonal() * 30.0
	await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), TentacleSlam) == 0, 60)
	assert_eq(damaged.count, 1, "看到紅線就走開,拍不到")


func test_kraken_ink_bubbles_and_double_tentacles_at_half() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var kraken := spawn(&"kraken", Vector2(90, 116)) as KrakenBoss
	kraken.target = player
	kraken.set_physics_process(false)
	kraken._start_ink()
	assert_eq(count_in(arena.get_ground_layer(), LobbedShot), kraken.ink_count, "墨汁的落點先出現影子")
	var points := kraken.pick_ink_points(4)
	for i in points.size():
		for j in range(i + 1, points.size()):
			assert_true(points[i].distance_to(points[j]) >= kraken.ink_spacing - 0.01, "落點彼此分開")
	player.global_position += Vector2(70, 0)
	var landed := await wait_until(func() -> bool: return count_in(arena.get_ground_layer(), InkPuddle) >= 1, 60)
	assert_true(landed, "墨汁落地留下一片暗區")
	assert_eq(damaged.count, 0, "走開就淋不到")
	assert_true(kraken.bubble_gap_at(60.0) >= 6.0, "扇形泡泡之間有空隙(%.1f)" % kraken.bubble_gap_at(60.0))
	kraken._start_bubbles()
	kraken._release_bubbles()
	assert_eq(projectiles().size(), kraken.bubble_count)
	assert_eq((projectiles()[0] as EnemyProjectile).data.id, &"bubble")
	kraken.set_physics_process(true)
	kraken.take_damage(kraken.max_hp / 2)
	assert_eq(phases.last_args(), [2], "半血進入第二階段")
	assert_eq(kraken.phase, KrakenBoss.Phase.ROAR, "停下大叫")
	assert_true(kraken.is_invulnerable())
	var struck := kraken.tentacles_struck
	var twice := await wait_until(func() -> bool: return kraken.tentacles_struck >= struck + 2, 90)
	assert_true(twice, "之後觸手連續兩次(每一次都有預警)")
	kraken._start_summon()
	kraken._summon()
	assert_eq(kraken.alive_summons(), 2, "叫出 2 隻水母")
	kraken.take_damage(999999)
	var gone := await wait_until(func() -> bool: return not kraken.is_in_group(&"enemy"), 60)
	assert_true(gone)
	assert_eq(kraken.alive_summons(), 0, "水母一起散掉")
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 1, "趴在地上嘟嘴(不是受傷)")


# --- AW4 紅龍與白龍 -----------------------------------------------------------------------

func test_twin_dragons_one_clear_boss_bar_take_turns_sulk_then_rage() -> void:
	make_fast_arena()
	var appeared := watch_signal(EventBus.boss_appeared)
	var bar := watch_signal(EventBus.boss_hp_changed)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var red := spawn(&"red_dragon", Vector2(40, 120)) as DragonBoss
	var white := spawn(&"white_dragon", Vector2(140, 120)) as DragonBoss
	assert_eq(red.partner, white, "兩條龍互相配對")
	assert_eq(appeared.last_args(), [&"twin_dragons"], "血條顯示「紅龍與白龍」")
	assert_ne(tr("ENEMY_TWIN_DRAGONS"), "ENEMY_TWIN_DRAGONS")
	assert_eq(bar.last_args(), [red.hp + white.hp, red.max_hp + white.max_hp], "血條是兩條龍的生命合計")
	red.take_damage(50)
	assert_eq(bar.last_args(), [red.hp + white.hp, red.max_hp + white.max_hp], "打一條,合計的血條跟著少")
	# 輪流:一條正在預警時,另一條先等。
	red.target = player
	white.target = player
	red._start_breath_tell()
	white._next_move()
	assert_eq(white.phase, DragonBoss.Phase.IDLE, "搭檔在預警時先等,不會兩條同時預警")
	red._cancel_attack()
	# 紅龍坐下生悶氣,白龍大吼後暴怒。
	red.take_damage(999999)
	assert_true(red.sulked)
	assert_eq(red.sprite.animation, &"sulk", "播 sulk 坐下(不是受傷)")
	assert_true(white.enraged, "另一條暴怒")
	assert_eq(white.phase, DragonBoss.Phase.ROAR, "先大吼")
	assert_eq(white.sprite.animation, &"roar")
	assert_true(white.is_invulnerable(), "大吼時無敵(短暫停頓)")
	assert_eq(phases.last_args(), [2])
	assert_eq(bar.last_args(), [white.hp, red.max_hp + white.max_hp], "坐下的那條算 0,血條不會跳")
	assert_true(white._speed_mult() > 1.0 and white._tell_time(1.0) < 1.0, "暴怒:更快、預警較短")
	assert_true(white._tell_time(white.breath_telegraph) >= 0.75, "仍有完整預警")
	assert_true(white.current_ring_count() > white.ring_count, "冰刺更多")
	var sat := await wait_until(func() -> bool: return not red.is_in_group(&"enemy"), 40)
	assert_true(sat, "坐下的那條離開 enemy 群組")
	assert_true(white.is_in_group(&"enemy"), "另一條還在:還沒過關")
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 1, "紅龍坐在地上生悶氣")
	await wait_until(func() -> bool: return not white.is_invulnerable(), 40)
	white.take_damage(999999)
	var both := await wait_until(func() -> bool: return get_tree().get_nodes_in_group(&"enemy").is_empty(), 40)
	assert_true(both, "兩條都坐下才過關")
	assert_eq(bar.last_args()[0], 0, "血條歸零")
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 2)


## 無盡試煉只出一條龍:一條自己坐下就算打倒(不用等搭檔)。
func test_a_lone_dragon_sulking_counts_as_defeated() -> void:
	make_fast_arena()
	var bar := watch_signal(EventBus.boss_hp_changed)
	var white := spawn(&"white_dragon", Vector2(90, 120)) as DragonBoss
	assert_false(white.has_partner())
	assert_eq(bar.last_args(), [white.hp, white.max_hp], "血條只有自己的生命")
	white.take_damage(999999)
	var gone := await wait_until(func() -> bool: return get_tree().get_nodes_in_group(&"enemy").is_empty(), 40)
	assert_true(gone, "坐下 = 打倒,場上清空")
	assert_eq(bar.last_args()[0], 0)
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 1, "坐在地上生悶氣")


func test_dragon_breath_cone_is_dodgeable_and_ice_ring_has_gaps() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var red := spawn(&"red_dragon", player.global_position + Vector2(-20, -50)) as DragonBoss
	assert_eq(red.boss_bar_id(), &"red_dragon", "只有一條龍時顯示自己的名字")
	red.target = player
	red._start_breath_tell()
	assert_eq(red._marks.size(), 1)
	assert_eq((red._marks[0] as AttackTelegraph).shape, AttackTelegraph.Shape.SECTOR, "扇形紅色預警")
	assert_true(red._tell_time(red.breath_telegraph) >= 0.8, "預警夠長")
	await wait_until(func() -> bool: return red.phase == DragonBoss.Phase.RECOVER, 40)
	assert_eq(damaged.count, 1, "站在扇形裡被火燒到")
	assert_eq(count_in(arena.get_fx_layer(), BreathCone), 1, "噴火")
	reset_player_hit()
	red.phase = DragonBoss.Phase.IDLE
	red._start_breath_tell()
	await wait_physics(2)
	player.global_position += Vector2(60, 20)
	await wait_until(func() -> bool: return red.phase == DragonBoss.Phase.RECOVER, 40)
	assert_eq(damaged.count, 1, "看到扇形就走開")
	red.set_physics_process(false)
	red._start_volley()
	assert_eq(count_in(arena.get_ground_layer(), LobbedShot), red.volley_count, "火球的落點先出現影子")
	var white := spawn(&"white_dragon", Vector2(150, 110)) as DragonBoss
	white.target = player
	white.set_physics_process(false)
	assert_true(white.ring_gap_at(50.0) >= 6.0, "冰刺之間有空隙(%.1f)" % white.ring_gap_at(50.0))
	white._start_ring()
	assert_eq(white._marks.size(), white.ring_count, "放射的預警線")
	white._release_ring()
	var shards := 0
	for p in projectiles():
		if (p as EnemyProjectile).data.id == &"ice_shard":
			shards += 1
	assert_eq(shards, white.ring_count)


# --- AW6 莫德雷德 ---------------------------------------------------------------------------

func test_mordred_duel_flees_at_half_and_the_field_clears() -> void:
	make_fast_arena()
	var appeared := watch_signal(EventBus.boss_appeared)
	var died := watch_signal(EventBus.enemy_died)
	var bar := watch_signal(EventBus.boss_hp_changed)
	var duel := spawn(&"mordred_duel", Vector2(90, 120)) as MordredBoss
	var knight := spawn(&"shadow_knight", Vector2(40, 160))
	assert_eq(appeared.last_args(), [&"mordred_duel"], "出場發 boss_appeared")
	assert_true(duel.duel)
	# 衝刺斬:紅線預警,走開就斬不到(中頭目也躲得開)。
	var damaged := watch_signal(EventBus.player_damaged)
	knight.set_physics_process(false)
	duel.target = player
	duel._start_dash_tell()
	assert_eq((duel._marks[0] as AttackTelegraph).shape, AttackTelegraph.Shape.LINE, "紅線預警")
	assert_true(duel._tell_time(duel.dash_telegraph) >= 0.75)
	await wait_physics(2)
	player.global_position += Vector2(40, 0)
	await wait_until(func() -> bool: return duel.phase == MordredBoss.Phase.DASH_RECOVER, 40)
	assert_eq(damaged.count, 0, "看到紅線就走開")
	# 一下打很多也不會被打倒:降到一半就逃走。
	duel.take_damage(999999)
	assert_true(duel.hp >= 1, "逃走前不會被打倒")
	assert_true(duel.is_fleeing(), "生命剩一半就逃走")
	assert_true(duel.is_invulnerable())
	assert_false(knight.is_in_group(&"enemy"), "手下跟著撤退")
	assert_false(died.calls.any(func(a: Array) -> bool: return a[0] == &"shadow_knight"), "撤退不算打倒")
	var gone := await wait_until(func() -> bool: return get_tree().get_nodes_in_group(&"enemy").is_empty(), 60)
	assert_true(gone, "逃走 = 場上清空(過關)")
	assert_true(duel.fled)
	assert_true(died.calls.any(func(a: Array) -> bool: return a[0] == &"mordred_duel"), "發 enemy_died(掉經驗與寶箱)")
	assert_eq(bar.last_args()[0], 0, "血條收起來")
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 0, "第一戰是逃走,不是跪下")


func test_mordred_dash_slash_and_shadow_slash_fan_have_room_to_dodge() -> void:
	make_fast_arena()
	var damaged := watch_signal(EventBus.player_damaged)
	var m := spawn(&"mordred", player.global_position + Vector2(0, -70)) as MordredBoss
	m.target = player
	m._start_dash_tell()
	assert_true(m._tell_time(m.dash_telegraph) >= 0.75, "預警夠長")
	await wait_until(func() -> bool: return m.phase == MordredBoss.Phase.DASH_RECOVER, 40)
	assert_eq(damaged.count, 1, "站著不動被衝刺斬打中")
	reset_player_hit()
	m.global_position = player.global_position + Vector2(0, -70)
	m.phase = MordredBoss.Phase.IDLE
	m._start_dash_tell()
	await wait_physics(2)
	player.global_position += Vector2(36, 0)
	await wait_until(func() -> bool: return m.phase == MordredBoss.Phase.DASH_RECOVER, 40)
	assert_eq(damaged.count, 1, "看到紅線就走開")
	m.boss_phase = 2
	assert_eq(m.current_slash_count(), m.slash_count_phase2, "第二階段劍氣三道")
	assert_true(m.slash_gap_at(m.keep_distance) >= 6.0, "劍氣之間有空隙(%.1f)" % m.slash_gap_at(m.keep_distance))
	m.set_physics_process(false)
	m._start_slash()
	assert_eq(m._marks.size(), 3)
	m._release_slash()
	assert_eq((projectiles()[0] as EnemyProjectile).data.id, &"shadow_slash")


func test_mordred_scabbard_shield_only_breaks_to_companions_then_he_is_stunned() -> void:
	make_fast_arena()
	var lance := arena.spawn_companion(&"lancelot") as LancelotCompanion
	lance.set_physics_process(false)
	var phases := watch_signal(EventBus.boss_phase_changed)
	var m := spawn(&"mordred", Vector2(90, 130)) as MordredBoss
	m.target = player
	m.take_damage(m.max_hp - roundi(m.max_hp * 0.66) + 1)
	assert_eq(phases.last_args(), [2], "66% 進入第二階段")
	assert_true(m.is_invulnerable(), "換階段時停下(無敵)")
	var up := await wait_until(func() -> bool: return m.shield_up, 60)
	assert_true(up, "張開劍鞘護盾")
	await wait_until(func() -> bool: return not m.is_invulnerable(), 30)
	var hp := m.hp
	m.hit(30, player.global_position, 60.0)
	m.take_damage(30)
	assert_eq(m.hp, hp, "金毛的攻擊打不動護盾")
	assert_true(m.blocked_hits >= 2, "「鏘!」")
	assert_true(m.shield_up)
	var before := m.shield_left
	m.hit(20, lance.global_position, 0.0, DamageNumber.Style.ALLY)
	assert_eq(m.shield_left, before - 20, "同伴的攻擊削弱護盾")
	assert_eq(m.hp, hp, "護盾還在時生命不變")
	m.hit(m.shield_left, lance.global_position, 0.0, DamageNumber.Style.ALLY)
	assert_false(m.shield_up, "破盾")
	assert_eq(m.shield_breaks, 1)
	assert_true(m.is_break_stunned(), "破盾後暈眩")
	assert_true(m.break_stun_time >= 2.0, "暈眩幾秒")
	m.hit(30, player.global_position, 60.0)
	assert_eq(m.hp, hp - 30, "暈眩時打得痛")
	# 場上沒有同伴時,護盾自己很快消失(不會打不完)。
	lance.get_parent().remove_child(lance)
	lance.queue_free()
	await wait_physics(1)
	m.shield_solo_time = 0.4
	m.raise_shield()
	var dropped := await wait_until(func() -> bool: return not m.shield_up, 30)
	assert_true(dropped, "沒有同伴:護盾 shield_solo_time 秒後消失")
	assert_false(m.is_break_stunned(), "自己消失的護盾不會暈眩")


func test_mordred_calls_old_boss_echoes_from_33_percent_and_kneels_when_defeated() -> void:
	make_fast_arena()
	var m := spawn(&"mordred", Vector2(90, 120)) as MordredBoss
	var phases := watch_signal(EventBus.boss_phase_changed)
	m.target = player
	m.take_damage(m.max_hp - roundi(m.max_hp * 0.33) + 1)
	assert_eq(phases.calls.map(func(a: Array) -> int: return a[0]), [2, 3], "一下打到 33% 也依次進入第二、三階段")
	assert_true(m._speed_mult() > m.phase2_speed_mult, "第三階段加快")
	var called := await wait_until(func() -> bool: return m.alive_summons() == 2, 90)
	assert_true(called, "召喚舊頭目的幻影")
	var kinds: Array = []
	for s in m._summons:
		if is_instance_valid(s):
			var echo := s as BossEcho
			kinds.append(echo.kind)
			assert_true(echo.tint.a < 0.8, "幻影半透明")
	assert_true(kinds.has(BossEcho.Kind.CHARGE) and kinds.has(BossEcho.Kind.WHIP), "黑騎士與綠騎士的簡化版")
	var echo := m._summons[0] as BossEcho
	echo.set_physics_process(false)
	echo.target = player
	echo._start_tell()
	assert_eq(echo._telegraph.shape, AttackTelegraph.Shape.LINE, "幻影也先畫紅線")
	assert_true(echo.tell(echo.tell_time) >= 0.75)
	m.set_physics_process(false)                # 先停住,不讓他再張開護盾
	if m.shield_up:
		m._drop_shield(false)
	m._go_idle()
	assert_false(m.is_invulnerable())
	m.take_damage(999999)
	m.set_physics_process(true)
	assert_eq(m.alive_summons(), 0, "幻影一起散掉")
	assert_eq(m.sprite.animation, &"down", "倒下播 down")
	var gone := await wait_until(func() -> bool: return not m.is_in_group(&"enemy"), 40)
	assert_true(gone)
	assert_eq(count_in(arena.get_ground_layer(), DefeatPose), 1, "單膝跪下(不是受傷)")


# --- AW7 崔斯坦、高文、四位同伴 --------------------------------------------------------------

func test_four_companions_stand_apart_without_overlapping() -> void:
	make_fast_arena()
	var ids: Array[StringName] = [&"bulldog", &"lancelot", &"tristan", &"gawain"]
	var dogs: Array[Node2D] = []
	for id in ids:
		var c := arena.spawn_companion(id) as Node2D
		assert_not_null(c, "生成 %s" % id)
		dogs.append(c)
	assert_eq(arena.get_companions().size(), 4, "最多 4 位同時在場")
	assert_eq(arena.spawn_companion(&"tristan"), dogs[2], "同一位同伴不會重複生成")
	for i in dogs.size():
		for j in range(i + 1, dogs.size()):
			assert_true(dogs[i].global_position.distance_to(dogs[j].global_position) > 4.0, "出現的位置不重疊")
	# 全部疊在一起也會自己分開。
	for c in dogs:
		c.global_position = player.global_position + Vector2(0, 2)
	await wait_physics(40)
	for i in dogs.size():
		for j in range(i + 1, dogs.size()):
			var gap := dogs[i].global_position.distance_to(dogs[j].global_position)
			var need := EnemyBase.radius_of(dogs[i]) + EnemyBase.radius_of(dogs[j])
			assert_true(gap >= need, "%s 和 %s 不重疊(相距 %.1f)" % [ids[i], ids[j], gap])
	var lance_side := signf(dogs[1].global_position.x - player.global_position.x)
	var gawain_side := signf(dogs[3].global_position.x - player.global_position.x)
	assert_true(lance_side != gawain_side, "蘭斯洛特和高文一左一右")


func test_tristan_plays_music_notes_at_the_nearest_enemy() -> void:
	make_fast_arena()
	var tristan := arena.spawn_companion(&"tristan") as TristanCompanion
	assert_not_null(tristan, "data/companions/tristan.tres")
	assert_eq(tristan.companion_id, &"tristan")
	assert_almost_eq(tristan.note_interval, 1.5, 0.3, "約每 1.5 秒射一次")
	var dummy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -60))
	dummy.set_physics_process(false)
	var hp := dummy.hp
	tristan._note_timer = tristan.note_interval
	var shot := await wait_until(func() -> bool: return tristan.notes > 0, 30)
	assert_true(shot, "朝最近的敵人射音符")
	assert_true(get_tree().get_nodes_in_group(AllyProjectile.GROUP).size() >= 1 or dummy.hp < hp, "音符飛出去")
	var hit := await wait_until(func() -> bool: return dummy.hp < hp, 30)
	assert_true(hit, "音符打中敵人")
	assert_true(tristan.global_position.distance_to(dummy.global_position) > 30.0, "保持距離")
	tristan.daze_time = 0.3
	tristan.take_damage(999)
	assert_true(tristan.is_dazed(), "不會倒下,只會暈一下")
	var awake := await wait_until(func() -> bool: return not tristan.is_dazed(), 30)
	assert_true(awake)


func test_gawain_hammer_slam_hits_an_area_and_briefly_stuns() -> void:
	make_fast_arena()
	var gawain := arena.spawn_companion(&"gawain") as GawainCompanion
	assert_not_null(gawain, "data/companions/gawain.tres")
	assert_almost_eq(gawain.slam_interval, 4.0, 0.5, "約每 4 秒砸一次")
	var a := spawn(&"scarecrow", player.global_position + Vector2(22, -30))
	var b := spawn(&"scarecrow", player.global_position + Vector2(34, -30))
	for e: EnemyBase in [a, b]:
		e.set_physics_process(false)
	var hp_a := a.hp
	var hp_b := b.hp
	gawain._slam_timer = gawain.slam_interval
	var slammed := await wait_until(func() -> bool: return gawain.slam_hits >= 2, 40)
	assert_true(slammed, "大鐵鎚落地打中範圍內的敵人")
	assert_true(a.hp < hp_a and b.hp < hp_b, "兩隻都受傷")
	assert_true(a.is_stunned() and b.is_stunned(), "短暫震暈")
	var back := await wait_until(func() -> bool: return gawain.mode == GawainCompanion.Mode.FOLLOW, 60)
	assert_true(back, "之後回到金毛身邊")
	gawain.daze_time = 0.3
	gawain.take_damage(999)
	assert_true(gawain.is_dazed(), "不會倒下")
