extends TestCase

const ARENA := preload("res://game/combat/arena.tscn")
var arena: Node
var player: GoldiePlayer
var previous_role: StringName

func before_each() -> void:
	previous_role = GameState.hero_class
	GameState.hero_class = &"knight"
	GameState.reset_run()
	arena = ARENA.instantiate()
	add_child(arena)
	player = arena.call("get_player") as GoldiePlayer
	player.global_position = Vector2(90, 160)

func after_each() -> void:
	arena.free()
	GameState.hero_class = previous_role
	GameState.reset_run()

func ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame

func test_reversal_paints_the_travelled_direction_through_braking() -> void:
	player.set_move_override(Vector2.RIGHT)
	await ticks(12)
	player.set_move_override(Vector2.LEFT)
	var still_right := false
	var turned_left := false
	for tick in 12:
		var start := player.global_position
		await ticks(1)
		var dx := player.global_position.x - start.x
		if absf(dx) > 0.0001:
			assert_eq(signf(player.stride_direction.x), signf(dx))
			still_right = still_right or dx > 0.0
			turned_left = turned_left or dx < 0.0
	assert_true(still_right and turned_left)

func test_held_boundary_plants_and_freezes_the_stride() -> void:
	player.global_position = Vector2(90, 24)
	player.set_move_override(Vector2.UP)
	await ticks(45)
	var position_at_wall := player.global_position
	var phase := player.stride_cycle
	await ticks(20)
	assert_eq(player.global_position, position_at_wall)
	assert_eq(player.stride_cycle, phase)
	assert_false(player.stride_moving)
	var skin := player.sprite.get_node("IllustratedActor")
	skin.call("_update")
	var rest := skin.get("_tex") as AtlasTexture
	assert_eq(rest.atlas.resource_path, "res://assets/illustrated/motion/settle_knight.png")
	assert_eq(rest.region, Rect2(256, 192, 256, 192))

func test_equal_ground_distances_advance_equal_cycles_at_different_speeds() -> void:
	var phases: Array[float] = []
	for step_size: float in [0.5, 1.0]:
		player._clear_stride()
		for tick in roundi(12.0 / step_size):
			player._update_stride(Vector2.RIGHT * step_size, 1.0 / 60.0, true, false)
		phases.append(player.stride_cycle)
	assert_true(phases[0] > 0.0)
	assert_almost_eq(phases[0], phases[1])

func test_ultimate_takes_over_immediately_after_northward_travel() -> void:
	player.set_move_override(Vector2.UP)
	await ticks(12)
	assert_eq(player.stride_direction, Vector2.UP)
	player.loyalty = player.tuning.loyalty_max
	assert_true(player.use_ultimate())
	assert_eq(player.stride_direction, Vector2.ZERO)
	assert_false(player.stride_moving)
