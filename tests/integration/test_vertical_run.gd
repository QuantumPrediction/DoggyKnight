extends TestCase

const ARENA := preload("res://game/combat/arena.tscn")
var arena: Node
var role_before: StringName

func before_each() -> void:
	role_before = GameState.hero_class

func after_each() -> void:
	if is_instance_valid(arena):
		arena.free()
	GameState.hero_class = role_before
	GameState.reset_run()

func start_role(role: StringName) -> GoldiePlayer:
	GameState.hero_class = role
	GameState.reset_run()
	arena = ARENA.instantiate()
	add_child(arena)
	await wait_frames(2)
	return arena.call("get_player") as GoldiePlayer

func paint(player: GoldiePlayer, direction: Vector2, phase: float) -> AtlasTexture:
	var sprite := player.sprite
	player.facing = direction.normalized()
	sprite.play(&"run")
	var clock := phase * sprite.sprite_frames.get_frame_count(&"run")
	sprite.set_frame_and_progress(floori(clock), fmod(clock, 1.0))
	var skin := sprite.get_node("IllustratedActor")
	skin.call("_update")
	return skin.get("_tex") as AtlasTexture

func check_role(role: StringName) -> void:
	var player := await start_role(role)
	var skin := player.sprite.get_node("IllustratedActor") as Node2D
	var vertical_path := "res://assets/illustrated/motion/vertical_%s.png" % role
	var side_path := "res://assets/illustrated/motion/stride_%s.png" % role
	for row in 2:
		var direction := Vector2.DOWN if row == 0 else Vector2.UP
		for phase in 4:
			var cycle := float(phase) / 4.0
			var drawing := paint(player, direction, cycle)
			assert_not_null(drawing)
			if drawing == null:
				return
			assert_eq(drawing.atlas.resource_path, vertical_path)
			assert_eq(drawing.region, Rect2(256 * phase, 192 * row, 256, 192))
			for noise: float in [-0.08, 0.08]:
				player.sprite.flip_h = noise < 0.0
				assert_eq(paint(player, Vector2(noise, direction.y), cycle), drawing)
				assert_true(skin.transform.x.x > 0.0, "small changes in X cannot swap the painted weapon hand")
	for direction: Vector2 in [Vector2(1, 1), Vector2(-1, -1), Vector2.RIGHT]:
		assert_eq(paint(player, direction, 0.64).atlas.resource_path, side_path)
		assert_eq(StoryArt.stride_phase(player.sprite, player.sprite.sprite_frames.get_frame_count(&"run"), 8), 5)

func test_knight_front_rear_and_diagonal() -> void:
	await check_role(&"knight")

func test_mage_front_rear_and_diagonal() -> void:
	await check_role(&"mage")

func test_archer_front_rear_and_diagonal() -> void:
	await check_role(&"archer")

func test_turn_margin_and_animation_transition() -> void:
	var player := await start_role(&"knight")
	var side := paint(player, Vector2.RIGHT, 0.0)
	var down := paint(player, Vector2.DOWN, 0.0)
	assert_ne(side, down)
	for tilt: float in [1.55, 1.605, 1.24, 1.59]:
		assert_eq(paint(player, Vector2(1, tilt), 0.0), down, "retain view within the turn margin")
	assert_eq(paint(player, Vector2(1, 1.18), 0.0), side)
	assert_eq(paint(player, Vector2(1, 1.50), 0.0), side)
	assert_eq(paint(player, Vector2(1, 1.70), 0.0), down)
	player.sprite.play(&"idle")
	var skin := player.sprite.get_node("IllustratedActor")
	skin.call("_update")
	assert_eq(skin.get("_tex"), StoryArt.motion_pose(&"knight", 0))
	assert_eq(paint(player, Vector2(1, 1.50), 0.0), side, "a new run starts from the current input")

func test_normal_input_moves_the_actor_in_the_painted_direction() -> void:
	var player := await start_role(&"archer")
	var skin := player.sprite.get_node("IllustratedActor")
	player.global_position = Vector2(90, 180)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var start := player.global_position
		player.set_move_override(direction)
		for tick in 30:
			await get_tree().physics_frame
		assert_true((player.global_position - start).dot(direction) > 5.0)
		assert_eq(player.sprite.animation, &"run")
		skin.call("_update")
		var tex := skin.get("_tex") as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/illustrated/motion/vertical_archer.png")
		assert_eq(tex.region.position.y, 192.0 if direction.y < 0.0 else 0.0)

func test_all_painted_feet_and_weapons_fit_the_registered_gutters() -> void:
	var signatures := {}
	for role: String in ["knight", "mage", "archer"]:
		var sheet := load("res://assets/illustrated/motion/vertical_%s.png" % role) as Texture2D
		assert_not_null(sheet)
		if sheet == null:
			return
		var image := sheet.get_image()
		assert_eq(image.get_size(), Vector2i(1024, 384))
		for index in 8:
			var tile := image.get_region(Rect2i(256 * (index % 4), 192 * (index / 4), 256, 192))
			signatures[hash(tile.get_data())] = true
			var top_left := Vector2i(256, 192)
			var bottom_right := Vector2i(-1, -1)
			for y in 192:
				for x in 256:
					if tile.get_pixel(x, y).a >= 32.0 / 255.0:
						top_left = top_left.min(Vector2i(x, y))
						bottom_right = bottom_right.max(Vector2i(x, y))
			assert_true(top_left.x >= 5 and top_left.y >= 5)
			assert_true(bottom_right.x <= 250)
			assert_true(absi(bottom_right.y - 176) <= 2, "foot contact shares the existing ground line")
			assert_true(bottom_right.y - top_left.y > 130, "the figure has a full painted body")
	assert_eq(signatures.size(), 24)
