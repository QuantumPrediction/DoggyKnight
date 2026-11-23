extends TestCase

const SHEET := "res://assets/illustrated/motion/scarecrow_swing.png"
var arena: CombatArena

func before_each() -> void:
	arena = preload("res://game/combat/arena.tscn").instantiate()
	arena.spawn_telegraph_time = 0.0
	add_child(arena)
	arena.get_player().set_physics_process(false)

func after_each() -> void:
	arena.free()

func spawn_still(id: StringName = &"scarecrow") -> ScarecrowEnemy:
	var enemy := arena.spawn_enemy(id, Vector2(75, 165)) as ScarecrowEnemy
	enemy.set_physics_process(false)
	return enemy

func selected(enemy: EnemyBase) -> AtlasTexture:
	var skin := enemy.sprite.get_node("IllustratedActor")
	skin.call("_update")
	return skin.get("_tex") as AtlasTexture

func check_pose(enemy: ScarecrowEnemy, row: int, column: int) -> void:
	var drawing := selected(enemy)
	assert_eq(drawing.atlas.resource_path, SHEET)
	assert_eq(drawing.region, Rect2(column * 192, row * 192, 192, 192))

func test_locked_direction_and_existing_release_clock() -> void:
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(-1, 1).normalized()]:
		var enemy := spawn_still()
		await wait_frames(2)
		enemy._start_telegraph(dir, false)
		var row := 0 if absf(dir.x) >= absf(dir.y) else (1 if dir.y > 0.0 else 2)
		var energy := GameState.vigor
		var mark := enemy._telegraph
		check_pose(enemy, row, 0)
		assert_eq((enemy.sprite.get_node("IllustratedActor") as Node2D).scale.x, -1.0 if dir.x < 0 else 1.0)
		mark.progress = AttackTelegraph.FLASH_FROM - 0.001
		check_pose(enemy, row, 0)
		mark.progress = AttackTelegraph.FLASH_FROM
		check_pose(enemy, row, 1)
		assert_eq(enemy.attacks_started, 1)
		assert_eq(enemy._telegraph, mark)
		assert_eq(GameState.vigor, energy)
		enemy._swing()
		check_pose(enemy, row, 2)
		enemy.sprite.set_frame_and_progress(1, 0.0)
		check_pose(enemy, row, 3)
		enemy._ai(1.0)
		assert_ne(selected(enemy).atlas.resource_path, SHEET)
		enemy.free()

func test_hidden_warning_hurt_and_cancel_return_to_regular_costume() -> void:
	var enemy := spawn_still()
	await wait_frames(2)
	assert_ne(selected(enemy).atlas.resource_path, SHEET)
	enemy._start_telegraph(Vector2.RIGHT, false)
	enemy._telegraph.hide()
	assert_ne(selected(enemy).atlas.resource_path, SHEET)
	enemy._telegraph.show()
	enemy.sprite.play(&"hurt")
	assert_ne(selected(enemy).atlas.resource_path, SHEET)
	enemy.sprite.play(&"idle")
	check_pose(enemy, 0, 0)
	enemy.stun(0.5)
	assert_ne(selected(enemy).atlas.resource_path, SHEET)
	assert_eq(enemy.phase, ScarecrowEnemy.Phase.RECOVER)
	assert_true(enemy._telegraph == null)

func test_elite_and_archer_keep_their_costumes() -> void:
	var elite := spawn_still(&"scarecrow_elite")
	var archer := arena.spawn_enemy(&"scarecrow_archer", Vector2(45, 105)) as EnemyBase
	archer.set_physics_process(false)
	await wait_frames(2)
	elite._start_telegraph(Vector2.RIGHT, false)
	assert_eq(selected(elite).atlas.resource_path, "res://assets/illustrated/foes_meadow.png")
	assert_eq(selected(archer).atlas.resource_path, "res://assets/illustrated/extra_cast.png")
