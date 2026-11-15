extends "res://tests/line_a/combat_test_base.gd"
## A12:戰鬥場地的合約方法(DEV_PLAN 4.4、4.9)與 A8 鬥牛犬。


func test_arena_contains_player_camera_and_walls() -> void:
	make_arena()
	assert_true(player is CharacterBody2D)
	assert_true(player.is_in_group(&"player"))
	assert_eq(arena.get_player(), player)
	assert_eq(player.global_position, Layout.PLAYER_START)
	assert_eq(arena.camera.position, SafeArea.GAME_CENTER)
	var walls := arena.get_node("Walls") as StaticBody2D
	assert_eq(walls.collision_layer, Layers.ARENA)
	assert_eq(walls.get_child_count(), 4, "四邊都有牆")
	assert_true(player.has_method(&"take_damage") and player.has_method(&"heal"))


func test_spawn_enemy_loads_data_and_stays_inside() -> void:
	make_arena()
	var crow := arena.spawn_enemy(&"crow", Vector2(-50, -50)) as EnemyBase
	assert_not_null(crow)
	assert_eq(crow.data.id, &"crow")
	assert_true(Layout.ARENA_RECT.has_point(crow.global_position), "生成位置限制在場地內")
	assert_null(arena.spawn_enemy(&"no_such_enemy", Vector2(90, 120)), "找不到資料時傳回 null")


func test_spawn_points_are_inside_near_edges_and_away_from_player() -> void:
	make_arena()
	var points := arena.get_spawn_points()
	assert_true(points.size() >= 3)
	for point in points:
		assert_true(Layout.ARENA_RECT.has_point(point), "生成點在場地內:%s" % point)
		assert_true(point.distance_to(player.global_position) >= arena.spawn_min_player_distance, "離主角夠遠")
		var rect := Layout.ARENA_RECT
		var edge_distance := minf(minf(point.x - rect.position.x, rect.end.x - point.x),
				minf(point.y - rect.position.y, rect.end.y - point.y))
		assert_true(edge_distance <= arena.spawn_point_inset + 0.01, "靠近邊緣")
	player.global_position = Vector2(14, 84)
	points = arena.get_spawn_points()
	assert_true(points.size() >= 3, "主角在角落時仍有生成點")
	for point in points:
		assert_true(point.distance_to(player.global_position) > 40.0)


func test_clear_removes_enemies_orbs_and_fx_but_keeps_player_and_companion() -> void:
	make_arena()
	var died := watch_signal(EventBus.enemy_died)
	var companion := arena.spawn_companion(&"bulldog")
	for i in 3:
		arena.spawn_enemy(&"scarecrow", Vector2(40 + i * 40, 120))
	arena.spawn_exp_orb(Vector2(90, 150), 1)
	arena.clear()
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 0, "清場後立刻沒有敵人")
	assert_eq(get_tree().get_nodes_in_group(&"exp_orb").size(), 0)
	assert_eq(died.count, 0, "清場不算擊倒")
	await get_tree().process_frame
	assert_true(is_instance_valid(player) and player.is_inside_tree())
	assert_true(is_instance_valid(companion) and companion.is_inside_tree())
	assert_eq(arena.entities.get_child_count(), 2)


func test_spawn_companion_loads_data_once() -> void:
	make_arena()
	var dog := arena.spawn_companion(&"bulldog")
	assert_true(dog is BulldogCompanion)
	assert_true(dog.is_in_group(&"companion"))
	assert_eq(dog.get(&"companion_id"), &"bulldog")
	assert_eq(arena.spawn_companion(&"bulldog"), dog, "同一個同伴不會重複生成")
	var data := load("res://data/companions/bulldog.tres") as CompanionData
	assert_eq(data.display_name, "COMPANION_BULLDOG")
	assert_eq(data.role, &"guard")


func test_set_background_replaces_the_ground() -> void:
	make_arena()
	assert_eq(arena.background.get_child_count(), 1, "預設背景")
	arena.set_background(load("res://assets/backgrounds/bridge.tscn") as PackedScene)
	assert_eq(arena.background.get_child_count(), 1)
	# 背景由 C 線原地替換,不能依賴背景場景內部的屬性;只核對載入的是哪一個場景。
	assert_eq(arena.background.get_child(0).scene_file_path, "res://assets/backgrounds/bridge.tscn")
	arena.set_background(null)
	assert_eq(arena.background.get_child_count(), 0)


func test_walls_keep_the_player_inside() -> void:
	make_arena()
	player.set_move_override(Vector2(-1, -1))
	await wait_physics(270)
	assert_true(Layout.ARENA_RECT.has_point(player.global_position), "走不出場地")
	assert_true(player.global_position.x < 25.0 and player.global_position.y < 90.0, "可以走到角落")
	player.set_move_override(Vector2(1, 1))
	await wait_physics(240)
	assert_true(Layout.ARENA_RECT.has_point(player.global_position))


func test_bulldog_guards_taunts_and_gets_dazed_not_hurt() -> void:
	make_arena()
	player.set_physics_process(false)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -50))
	enemy.set_physics_process(false)
	var guarding := await wait_until(func() -> bool: return dog.is_taunting(), 120)
	assert_true(guarding, "走向敵人並舉盾")
	assert_eq(dog.sprite.animation, &"guard")
	enemy.set_physics_process(true)
	await wait_physics(20)
	assert_eq(enemy.target, dog, "舉盾時敵人改打鬥牛犬")
	enemy.set_physics_process(false)
	dog.take_damage(10)
	assert_eq(dog.damage_taken_total, 2, "舉盾減傷 80%")
	var bumped := await wait_until(func() -> bool: return dog.bumps > 0, 90)
	assert_true(bumped, "用盾撞敵人")
	assert_eq(enemy.hp, 75 - dog.bump_damage)
	for i in 20:
		dog.take_damage(10)
	assert_true(dog.is_dazed(), "受太多傷害會暈眩(不會倒下)")
	assert_false(dog.is_taunting())
	assert_true(dog.is_inside_tree())
	var recovered := await wait_until(func() -> bool: return not dog.is_dazed(), 200)
	assert_true(recovered, "3 秒後自己站起來")
