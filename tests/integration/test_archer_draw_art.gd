extends "res://tests/line_a/combat_test_base.gd"

const ATLAS := "res://assets/illustrated/motion/archer_draw.png"
var archer: ArcherEnemy
var skin: Node2D

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(146, 170)
	archer = spawn(&"scarecrow_archer", Vector2(70, 170)) as ArcherEnemy
	archer.set_physics_process(false)
	archer.target = player
	await wait_frames(2)
	skin = archer.sprite.get_node("IllustratedActor") as Node2D

func costume() -> AtlasTexture:
	skin.call(&"_update")
	return skin.get("_tex") as AtlasTexture

func check_pose(row: int, col: int, mirror: bool = false) -> void:
	var tex := costume()
	assert_eq(tex.atlas.resource_path, ATLAS)
	assert_eq(tex.region, Rect2(col * 192, row * 192, 192, 192))
	assert_eq(skin.scale.x, -1.0 if mirror else 1.0)

func test_tracking_direction_and_handedness() -> void:
	assert_ne(costume().atlas.resource_path, ATLAS)
	archer._start_aim()
	for aim: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2(-1,1), Vector2(-0.12,1), Vector2(0.12,1), Vector2.UP]:
		player.global_position = archer.global_position + aim.normalized() * 65.0
		archer._ai(0.001)
		var row := (1 if aim.y > 0 else 2) if absf(aim.y) > absf(aim.x) else 0
		check_pose(row, 0, row == 0 and aim.x < 0)
	assert_eq(archer.aims_started, 1)
	assert_eq(archer.shots_fired, 0)

func test_actual_lock_release_and_empty_bow_through_recovery() -> void:
	archer._start_aim()
	var warning := archer._telegraph
	var threshold := archer._aim_total * archer.aim_track_ratio
	archer._ai(threshold - 0.001)
	check_pose(0, 0)
	archer._ai(0.002)
	assert_true(warning.aim_locked)
	check_pose(0, 1)
	player.global_position = archer.global_position + Vector2(0, 65)
	archer._ai(0.07)
	check_pose(0, 1)
	var frozen_direction := warning.direction
	archer._ai(archer._phase_left + 0.001)
	check_pose(0, 2)
	var arrow := get_tree().get_first_node_in_group(EnemyProjectile.GROUP) as EnemyProjectile
	assert_eq(arrow.direction, frozen_direction)
	assert_eq(arrow.origin, archer.global_position)
	archer._release()
	assert_eq(archer.shots_fired, 1)
	archer.sprite.set_frame_and_progress(1, 0.0)
	check_pose(0, 3)
	archer._ai(archer.release_time)
	assert_ne(costume().atlas.resource_path, ATLAS)
	archer._start_aim()
	check_pose(1, 0)
	assert_eq(archer.shots_fired, 1)

func test_hurt_hidden_cancelled_and_dead_keep_original_drawing() -> void:
	archer._start_aim()
	archer._telegraph.hide()
	assert_ne(costume().atlas.resource_path, ATLAS)
	archer._telegraph.show()
	archer.sprite.play(&"hurt")
	assert_ne(costume().atlas.resource_path, ATLAS)
	archer.sprite.play(&"aim")
	archer.stun(1.0)
	archer._release()
	assert_ne(costume().atlas.resource_path, ATLAS)
	assert_eq(EnemyProjectile.flying_count(self), 0)
	assert_eq(archer.shots_fired, 0)
	archer.die()
	assert_eq(archer.illustrated_draw_beat(), -1)

func test_pause_preserves_lock_and_other_enemy_keeps_its_swing() -> void:
	archer._start_aim()
	archer._ai(archer._aim_total * 0.6)
	var left := archer._phase_left
	var mark := archer._telegraph
	var was_paused := get_tree().paused
	archer.set_physics_process(true)
	get_tree().paused = true
	await wait_frames(4)
	check_pose(0, 1)
	get_tree().paused = was_paused
	assert_eq(archer._phase_left, left)
	assert_eq(archer._telegraph, mark)
	await wait_physics(3)
	assert_true(archer._phase_left < left)
	check_pose(0, 1)
	archer.set_physics_process(false)
	var melee := spawn(&"scarecrow", Vector2(90, 130)) as ScarecrowEnemy
	melee.set_physics_process(false)
	await wait_frames(2)
	melee._start_telegraph(Vector2.RIGHT, false)
	var other_skin := melee.sprite.get_node("IllustratedActor")
	other_skin.call(&"_update")
	assert_eq((other_skin.get("_tex") as AtlasTexture).atlas.resource_path,
		"res://assets/illustrated/motion/scarecrow_swing.png")
