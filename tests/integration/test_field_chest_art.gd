extends TestCase

const SHEET := "res://assets/illustrated/motion/field_chests.png"
const CELL := 128

func test_three_tiers_follow_the_actor_animation() -> void:
	var arena: CombatArena = preload("res://game/combat/arena.tscn").instantiate()
	add_child(arena)
	var rewards := watch_signal(EventBus.chest_collected)
	for tier in 3:
		var chest := arena.spawn_chest(Vector2(60, 125), tier)
		await wait_frames(2)
		var sprite := chest.get_node("Sprite") as AnimatedSprite2D
		var skin := sprite.get_node("IllustratedActor")
		var original := sprite.sprite_frames
		for frame in 2:
			sprite.set_frame_and_progress(frame, 0.0)
			check_drawing(skin, tier, 0)
		chest.open()
		for frame in 3:
			sprite.set_frame_and_progress(frame, 0.0)
			check_drawing(skin, tier, frame + 1)
		chest.open()
		assert_eq(rewards.count, tier + 1)
		assert_eq(rewards.last_args(), [tier])
		assert_eq(sprite.sprite_frames, original)
		chest.free()
	arena.free()

func check_drawing(skin: Node, tier: int, column: int) -> void:
	skin.call("_update")
	var drawing := skin.get("_tex") as AtlasTexture
	assert_not_null(drawing)
	if drawing != null:
		assert_eq(drawing.atlas.resource_path, SHEET)
		assert_eq(drawing.region, Rect2(column * CELL, tier * CELL, CELL, CELL))
		assert_eq(skin.get("_rect"), Rect2(-12, -20, 24, 24))

func test_registered_feet_and_increasing_lid_heights() -> void:
	var sheet := (load(SHEET) as Texture2D).get_image()
	assert_eq(sheet.get_size(), Vector2i(CELL * 4, CELL * 3))
	var silhouettes := {}
	for row in 3:
		var previous_top := CELL
		for column in 4:
			var tile := sheet.get_region(Rect2i(column * CELL, row * CELL, CELL, CELL))
			var low := Vector2i(CELL, CELL)
			var high := Vector2i(-1, -1)
			for y in CELL:
				for x in CELL:
					if tile.get_pixel(x, y).a >= 32.0 / 255.0:
						low = low.min(Vector2i(x, y))
						high = high.max(Vector2i(x, y))
			assert_true(low.x >= 4 and low.y >= 4 and high.x < CELL - 4)
			assert_true(high.y in [108, 109], "a fixed foot line across all frames")
			assert_true(low.y < previous_top, "each lid rotates higher")
			previous_top = low.y
			silhouettes[Rect2i(low, high - low + Vector2i.ONE)] = true
	assert_eq(silhouettes.size(), 12)
