extends "res://tests/line_a/tools/shots_v23.gd"
## A 線 v2.4 的截圖工具(不是測試):進化把戲、寶箱、零食、復活的格子圖。
##
## 執行(需要畫面;雲端環境用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_a/tools/shots_v24.tscn -- --out=/tmp/line_a_shots
## 產生:v24_evolutions.png(旋風尾、獅王吼、擊掌掌印、流星撲擊)、v24_chest.png(掉落、發光、打開)、
##       v24_revive.png(睡著 → 醒來震開敵人)、v24_overview_chest.png。


func _run() -> void:
	await _frames_wait(10)
	await _evolutions()
	await _chest()
	await _revive()
	print("SHOTS DONE -> ", out_dir)
	get_tree().quit(0)


func _dummy(at: Vector2, id: StringName = &"scarecrow_elite") -> EnemyBase:
	var enemy := arena.spawn_enemy(id, at) as EnemyBase
	enemy.set_physics_process(false)
	return enemy


func _evolutions() -> void:
	var kept: Array[Image] = []
	# 旋風尾
	await _new_arena()
	_crop = Rect2i(40, 160, 100, 110)
	player.abilities.evolve(&"tornado_tail")
	player._sync_tornado_fx()
	player.set_physics_process(true)
	player.set_move_override(Vector2.ZERO)
	_dummy(player.global_position + Vector2(24, -8))
	await _frames_wait(20)
	await _snap()
	await _frames_wait(9)
	await _snap()
	kept.append_array(_frames)
	# 獅王吼
	await _new_arena()
	_crop = Rect2i(40, 160, 100, 110)
	player.abilities.evolve(&"lion_roar")
	player.set_physics_process(true)
	player.set_move_override(Vector2.ZERO)
	_dummy(player.global_position + Vector2(30, -20))
	player.abilities.lion_roar.timer = 99.0
	await _frames_wait(4)
	await _snap()
	await _frames_wait(8)
	await _snap()
	kept.append_array(_frames)
	# 擊掌連打的掌印
	await _new_arena()
	_crop = Rect2i(40, 160, 100, 110)
	_dummy(player.global_position + Vector2(40, -30))
	player.ability_projectile(&"paw", 15)
	await _frames_wait(6)
	await _snap()
	await _frames_wait(6)
	await _snap()
	kept.append_array(_frames)
	# 流星撲擊
	await _new_arena()
	_crop = Rect2i(40, 160, 100, 110)
	player.abilities.evolve(&"meteor_pounce")
	player.set_physics_process(true)
	player.set_move_override(Vector2.ZERO)
	_dummy(player.global_position + Vector2(0, -60))
	_dummy(player.global_position + Vector2(16, -62))
	await _until(func() -> bool: return player.is_pouncing(), 30)
	await _frames_wait(6)
	await _snap()
	await _until(func() -> bool: return not player.is_pouncing(), 30)
	await _frames_wait(2)
	await _snap()
	await _frames_wait(8)
	await _snap()
	kept.append_array(_frames)
	_frames = kept
	_save_sheet("v24_evolutions")


func _chest() -> void:
	await _new_arena()
	_crop = Rect2i(30, 110, 120, 140)
	_dummy(Vector2(20, 90), &"scarecrow")
	var elite := _dummy(player.global_position + Vector2(10, -70))
	elite.die()
	elite.set_physics_process(true)
	await _frames_wait(8)
	await _snap()
	await _frames_wait(30)
	await _snap()
	var chests := arena.get_chests()
	arena.spawn_chest(player.global_position + Vector2(-40, -30), 0)
	arena.spawn_chest(player.global_position + Vector2(40, -30), 2)
	await _frames_wait(40)
	await _snap()
	await _overview("v24_overview_chest")
	if not chests.is_empty():
		player.global_position = (chests[0] as Node2D).global_position + Vector2(6, 2)
	await _frames_wait(3)
	await _snap()
	await _frames_wait(10)
	await _snap()
	await _frames_wait(20)
	await _snap()
	_save_sheet("v24_chest")


func _revive() -> void:
	await _new_arena()
	_crop = Rect2i(40, 160, 100, 110)
	player.set_physics_process(true)
	player.set_move_override(Vector2.ZERO)
	for offset: Vector2 in [Vector2(-18, -6), Vector2(18, -4), Vector2(0, -20)]:
		arena.spawn_enemy(&"scarecrow", player.global_position + offset)
	await _frames_wait(5)
	player.invuln_left = 0.0
	GameState.vigor = 1
	player.take_damage(50)
	await _frames_wait(20)
	await _snap()
	player.revive()
	await _frames_wait(3)
	await _snap()
	await _frames_wait(12)
	await _snap()
	await _frames_wait(20)
	await _snap()
	_save_sheet("v24_revive")
