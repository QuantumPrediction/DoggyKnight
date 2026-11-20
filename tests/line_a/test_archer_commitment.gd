extends "res://tests/line_a/combat_test_base.gd"

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.reset_run()
	GameState.difficulty = &"normal"
	GameState.chapter = 1
	GameState.level_index = 0
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(130, 180)

func aiming() -> ArcherEnemy:
	var archer := spawn(&"scarecrow_archer", Vector2(60, 180)) as ArcherEnemy
	archer.set_physics_process(false)
	archer.target = player
	archer._start_aim()
	return archer

func test_crowd_cannot_slide_a_committed_arrow_lane() -> void:
	var archer := aiming()
	var neighbour := spawn(&"scarecrow", Vector2(61, 180))
	neighbour.set_physics_process(false)
	archer._ai(archer._aim_total * 0.6)
	var origin := archer.global_position
	var direction := archer._aim_dir
	archer._move(0.1)
	assert_almost_eq(archer.global_position.distance_to(origin), 0.0, 0.001, "locked lane origin must not slide under crowd pressure")
	assert_eq(archer._aim_dir, direction)

func test_cancelled_aim_cannot_release_a_ghost_arrow() -> void:
	var archer := aiming()
	archer._cancel_attack()
	archer._release()
	assert_eq(EnemyProjectile.flying_count(self), 0)
	assert_eq(archer.shots_fired, 0)

func test_release_is_exactly_once_and_follows_last_warning() -> void:
	var archer := aiming()
	archer._ai(archer._aim_total * 0.6)
	var origin := archer.global_position
	var direction := archer._aim_dir
	player.global_position += Vector2(0, 45)
	archer._ai(archer._aim_total * 0.5)
	archer._release()
	assert_eq(archer.shots_fired, 1)
	assert_eq(EnemyProjectile.flying_count(self), 1)
	var shot := get_tree().get_first_node_in_group(EnemyProjectile.GROUP) as EnemyProjectile
	assert_eq(shot.origin, origin)
	assert_eq(shot.direction, direction)

func test_tracking_cue_changes_to_lock_and_then_stops_following() -> void:
	var archer := aiming()
	assert_true(archer._telegraph.show_aim_lock)
	assert_false(archer._telegraph.aim_locked)
	player.global_position += Vector2(0, 20)
	archer._ai(archer._aim_total * 0.2)
	assert_true(archer._aim_dir.y > 0.0)
	archer._ai(archer._aim_total * 0.4)
	assert_true(archer._telegraph.aim_locked)
	var direction := archer._aim_dir
	player.global_position += Vector2(0, 30)
	archer._ai(archer._aim_total * 0.1)
	assert_eq(archer._aim_dir, direction)
	archer.stun(0.5)
	assert_null(archer._telegraph)
