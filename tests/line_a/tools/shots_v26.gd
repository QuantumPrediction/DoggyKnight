extends "res://tests/line_a/tools/shots_v23.gd"
## A 線 v2.6 的截圖工具(不是測試):第二、三章的新敵人、頭目與蘭斯洛特的格子圖。
##
## 執行(需要畫面;雲端環境用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_a/tools/shots_v26.tscn -- --out=/tmp/line_a_shots
## 產生:v26_enemies.png(石像鬼預警與石頭、魔法書扇形、狐火預警圈、影狼紅線與落葉)、
##       v26_green_knight.png(藤鞭、荊棘環、帽子掉下、跪下)、
##       v26_morgana.png(月光圈、狐火雨、分身、月光束、坐下)、v26_lancelot.png(兩位同伴、突刺)。


func _run() -> void:
	await _frames_wait(10)
	await _enemies()
	await _green_knight()
	await _morgana()
	await _lancelot()
	print("SHOTS DONE -> ", out_dir)
	get_tree().quit(0)


func _enemies() -> void:
	var kept: Array[Image] = []
	await _new_arena()
	_crop = Rect2i(20, 110, 140, 150)
	var g := arena.spawn_enemy(&"gargoyle", player.global_position + Vector2(-20, -80)) as GargoyleEnemy
	await _frames_wait(2)
	g.target = player
	g.flight._stone_left = 99.0
	g.flight.start_tell()
	await _frames_wait(20)
	await _snap()
	g.flight.cancel()
	g.flight.start_stone()
	await _frames_wait(10)
	g.take_damage(5)
	await _frames_wait(2)
	await _snap()
	kept.append_array(_frames)
	await _new_arena()
	_crop = Rect2i(20, 110, 140, 150)
	var book := arena.spawn_enemy(&"spellbook", player.global_position + Vector2(0, -90)) as SpellbookEnemy
	await _frames_wait(2)
	book.target = player
	book._start_cast()
	await _frames_wait(30)
	await _snap()
	await _until(func() -> bool: return book.phase != SpellbookEnemy.Phase.CAST, 60)
	await _frames_wait(20)
	await _snap()
	kept.append_array(_frames)
	await _new_arena()
	_crop = Rect2i(20, 110, 140, 150)
	for i in 4:
		arena.spawn_enemy(&"foxfire", player.global_position + Vector2(-30 + i * 20, -40))
	await _until(func() -> bool:
		for e in arena.get_enemies():
			if (e as FoxfireEnemy).phase == FoxfireEnemy.Phase.WARN:
				return true
		return false, 120)
	await _frames_wait(15)
	await _snap()
	kept.append_array(_frames)
	await _new_arena()
	_crop = Rect2i(20, 110, 140, 150)
	var w := arena.spawn_enemy(&"shadow_wolf", player.global_position + Vector2(-60, -30)) as ShadowWolfEnemy
	arena.spawn_enemy(&"shadow_wolf", player.global_position + Vector2(60, -40))
	await _frames_wait(2)
	w.target = player
	w._start_tell()
	await _frames_wait(25)
	await _snap()
	w.take_damage(999)
	await _frames_wait(8)
	await _snap()
	await _frames_wait(18)
	await _snap()
	kept.append_array(_frames)
	_frames = kept
	_save_sheet("v26_enemies")


func _green_knight() -> void:
	await _new_arena()
	_crop = Rect2i(0, 70, 180, 230)
	var gk := arena.spawn_enemy(&"green_knight", player.global_position + Vector2(0, -90)) as GreenKnightBoss
	await _frames_wait(2)
	gk.target = player
	gk.set_physics_process(false)
	gk._start_whip(1)
	gk.set_physics_process(true)
	await _frames_wait(30)
	await _snap()
	await _until(func() -> bool: return gk.phase != GreenKnightBoss.Phase.WHIP_TELL, 60)
	await _frames_wait(4)
	await _snap()
	gk.set_physics_process(false)
	gk._cancel_attack()
	gk._start_thorns()
	gk.set_physics_process(true)
	await _frames_wait(30)
	await _snap()
	await _until(func() -> bool: return gk.phase != GreenKnightBoss.Phase.THORN_TELL, 60)
	await _frames_wait(12)
	await _snap()
	gk.take_damage(gk.max_hp / 2)
	await _frames_wait(30)
	await _snap()
	gk.take_damage(99999)
	await _until(func() -> bool: return not gk.is_in_group(&"enemy"), 120)
	await _frames_wait(10)
	await _snap()
	_save_sheet("v26_green_knight")


func _morgana() -> void:
	await _new_arena()
	_crop = Rect2i(0, 70, 180, 230)
	var m := arena.spawn_enemy(&"morgana", player.global_position + Vector2(0, -100)) as MorganaBoss
	await _frames_wait(2)
	m.target = player
	m.set_physics_process(false)
	m._start_teleport()
	m.set_physics_process(true)
	await _frames_wait(25)
	await _snap()
	await _until(func() -> bool: return m.phase != MorganaBoss.Phase.TELEPORT_TELL, 60)
	m.set_physics_process(false)
	m._cancel_attack()
	m._start_rain()
	m.set_physics_process(true)
	await _frames_wait(30)
	await _snap()
	await _frames_wait(30)
	await _snap()
	m.take_damage(m.max_hp - roundi(m.max_hp * 0.66) + 1)
	await _until(func() -> bool: return m.alive_summons() == 2, 150)
	await _frames_wait(5)
	await _snap()
	m.beam_sweep_deg = 120.0
	m.take_damage(m.hp - roundi(m.max_hp * 0.33) + 1)
	await _until(func() -> bool: return m.phase == MorganaBoss.Phase.BEAM_TELL, 120)
	await _frames_wait(20)
	await _snap()
	await _until(func() -> bool: return m.is_beaming(), 90)
	await _frames_wait(30)
	await _snap()
	m.take_damage(99999)
	await _until(func() -> bool: return not m.is_in_group(&"enemy"), 150)
	await _frames_wait(10)
	await _snap()
	_save_sheet("v26_morgana")


func _lancelot() -> void:
	await _new_arena()
	_crop = Rect2i(30, 140, 120, 120)
	arena.spawn_companion(&"bulldog")
	var lance := arena.spawn_companion(&"lancelot") as LancelotCompanion
	await _frames_wait(30)
	await _snap()
	var dummy := arena.spawn_enemy(&"scarecrow_elite", player.global_position + Vector2(10, -50)) as EnemyBase
	dummy.set_physics_process(false)
	lance._dash_timer = lance.dash_interval
	await _until(func() -> bool: return lance.is_dashing(), 30)
	await _frames_wait(3)
	await _snap()
	await _until(func() -> bool: return lance.dash_hits > 0, 60)
	await _snap()
	_save_sheet("v26_lancelot")
