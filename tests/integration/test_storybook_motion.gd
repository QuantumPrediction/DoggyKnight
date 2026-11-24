extends TestCase
## The drawables are the ones attached by the normal arena and equipment UI.
const ARENA := preload("res://game/combat/arena.tscn")
const WORKSHOP := preload("res://ui/equipment/equipment_screen.gd")
const ROLES := [&"knight", &"mage", &"archer"]
var arena: Node
var prior_class: StringName

func before_each() -> void:
	prior_class = GameState.hero_class

func after_each() -> void:
	if is_instance_valid(arena):
		arena.free()
	arena = null
	GameState.hero_class = prior_class
	GameState.reset_run()

func start_role(role: StringName) -> GoldiePlayer:
	GameState.hero_class = role
	GameState.reset_run()
	arena = ARENA.instantiate()
	add_child(arena)
	return arena.call("get_player") as GoldiePlayer

func selected(sprite: AnimatedSprite2D) -> AtlasTexture:
	var skin := sprite.get_node("IllustratedActor")
	skin.call("_update")
	return skin.get("_tex") as AtlasTexture

func check_poses(role: StringName) -> void:
	var player := start_role(role)
	await wait_frames(2)
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var total := sprite.sprite_frames.get_frame_count(&"run")
	sprite.play(&"run")
	var regions: Dictionary = {}
	for phase in 8:
		var progress := float(phase * total) / 8.0
		sprite.set_frame_and_progress(floori(progress), fmod(progress, 1.0))
		var painted := selected(sprite)
		assert_eq(painted.atlas.resource_path, "res://assets/illustrated/motion/stride_%s.png" % role)
		assert_eq(painted.region, Rect2(256 * (phase % 4), 192 * (phase / 4), 256, 192))
		regions[painted.region] = true
	assert_eq(regions.size(), 8, "both footfalls have four individually drawn positions")
	sprite.set_frame_and_progress(0, 0.0)
	assert_eq(selected(sprite), StoryArt.hero_stride(role, 0), "cycle returns to its first footfall")
	player.set_physics_process(false)
	sprite.set_frame_and_progress(0, 0.9)
	sprite.pause()
	var held_pose := selected(sprite)
	await wait_frames(2)
	assert_eq(selected(sprite), held_pose, "held playback repeats the same painting")
	sprite.play(&"attack")
	sprite.set_frame_and_progress(0, 0.0)
	sprite.pause()
	assert_eq(selected(sprite), StoryArt.motion_pose(role, 5), "hold until the real release")
	sprite.play(&"attack")
	assert_eq(selected(sprite), StoryArt.motion_pose(role, 6), "first drawing on release")
	for frame_index in [2, 3]:
		sprite.set_frame_and_progress(frame_index, 0.0)
		assert_eq(selected(sprite), StoryArt.motion_pose(role, frame_index + 5), "follow-through and recovery")

func test_knight_running_and_strike() -> void:
	await check_poses(&"knight")

func test_mage_running_and_cast() -> void:
	await check_poses(&"mage")

func test_archer_running_and_release() -> void:
	await check_poses(&"archer")


func test_stride_drawings_keep_both_contacts_and_two_airborne_poses_inside_each_tile() -> void:
	for role: StringName in ROLES:
		var sheet := StoryArt.texture("motion/stride_" + String(role)).get_image()
		assert_eq(sheet.get_size(), Vector2i(1024, 384))
		var silhouettes: Dictionary = {}
		for i in 8:
			var tile := sheet.get_region(Rect2i((i % 4) * 256, (i / 4) * 192, 256, 192))
			var bounds := tile.get_used_rect()
			assert_true(bounds.position.x >= 5 and bounds.position.y >= 5)
			assert_true(bounds.end.x <= 251 and bounds.end.y <= 187)
			assert_true(bounds.size.y >= 120, "full-size running character")
			if i % 4 == 3:
				assert_true(bounds.end.y >= 157 and bounds.end.y <= 172, "airborne sole")
			else:
				assert_true(bounds.end.y >= 175 and bounds.end.y <= 181, "registered ground contact")
			silhouettes[bounds] = true
		assert_eq(silhouettes.size(), 8, "each painting has its own silhouette bounds")

func test_each_hero_has_distinct_blink_cheer_and_sleep_drawings() -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	var drawings: Dictionary = {}
	for role: StringName in ROLES:
		for anim: StringName in [&"idle", &"victory", &"sleep"]:
			sprite.play(anim)
			sprite.set_frame_and_progress(3 if anim == &"idle" else 0, 0.0)
			var tex := StoryArt.hero_motion(role, sprite, sprite.sprite_frames.get_frame_count(anim)) as AtlasTexture
			assert_eq(tex.atlas.resource_path, "res://assets/illustrated/motion/reactions.png")
			drawings[tex.region] = true
	assert_eq(drawings.size(), 9)
	sprite.free()


func test_bedivere_reads_four_existing_guard_states_without_changing_them() -> void:
	start_role(&"knight")
	var dog := arena.call("spawn_companion", &"bulldog") as BulldogCompanion
	await wait_frames(2)
	var sprite := dog.get_node("Sprite") as AnimatedSprite2D
	var before := {
		"cooldown": dog.rally_cooldown_left,
		"guard": dog.rally_left,
		"approach": dog.rally_approach_left,
		"blocks": dog.blocks,
		"bumps": dog.bumps,
	}
	dog.mode = BulldogCompanion.Mode.GUARD
	dog.set("_mode_time", 0.0)
	sprite.play(&"guard")
	assert_eq(selected(sprite), StoryArt.companion_guard_pose(0), "arrival raises the shield")
	dog.set("_mode_time", 0.18)
	assert_eq(selected(sprite), StoryArt.companion_guard_pose(1), "settled guard braces")
	dog.set("_block_flash_left", dog.block_flash_time)
	assert_eq(selected(sprite), StoryArt.companion_guard_pose(2), "real block flash selects impact")
	dog.set("_block_flash_left", 0.0)
	dog.set("_bump_anim_left", 0.2)
	sprite.play(&"attack")
	assert_eq(selected(sprite), StoryArt.companion_guard_pose(3), "existing shield bash selects counter pose")
	assert_eq({
		"cooldown": dog.rally_cooldown_left,
		"guard": dog.rally_left,
		"approach": dog.rally_approach_left,
		"blocks": dog.blocks,
		"bumps": dog.bumps,
	}, before, "reading the paintings cannot mutate combat state")
	for pose in 4:
		var tex := StoryArt.companion_guard_pose(pose) as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/illustrated/motion/companion_guard.png")
		assert_eq(tex.region, Rect2(543.0 * pose, 0.0, 543.0, 544.0))


func test_bedivere_guard_cells_are_distinct_unclipped_and_share_a_baseline() -> void:
	var texture := load("res://assets/illustrated/motion/companion_guard.png") as Texture2D
	var image := texture.get_image()
	assert_eq(image.get_size(), Vector2i(2172, 544))
	var bottoms: Array[int] = []
	var signatures: Dictionary = {}
	for pose in 4:
		var minimum := Vector2i(543, 544)
		var maximum := Vector2i(-1, -1)
		var opaque := 0
		for y in 544:
			for local_x in 543:
				if image.get_pixel(pose * 543 + local_x, y).a < 32.0 / 255.0:
					continue
				opaque += 1
				minimum.x = mini(minimum.x, local_x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, local_x)
				maximum.y = maxi(maximum.y, y)
		assert_true(opaque > 10000, "pose %d has a painted silhouette" % pose)
		assert_true(minimum.x >= 5, "pose %d keeps a left gutter" % pose)
		assert_true(maximum.x <= 537, "pose %d keeps a right gutter" % pose)
		assert_true(minimum.y >= 5, "pose %d keeps a top gutter" % pose)
		assert_true(maximum.y <= 538, "pose %d keeps a bottom gutter" % pose)
		bottoms.append(maximum.y)
		signatures[Rect2i(minimum, maximum - minimum + Vector2i.ONE)] = true
	assert_eq(signatures.size(), 4, "all four poses have different silhouettes")
	assert_true(bottoms.max() - bottoms.min() <= 2, "painted feet share a two-pixel baseline")

func test_magic_bolt_cycles_while_in_flight() -> void:
	var player := start_role(&"mage")
	await wait_frames(2)
	player.global_position = Vector2(40, 160)
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	shot.set_physics_process(false)
	var drawings: Dictionary = {}
	for tick in 16:
		var tex: AtlasTexture = shot.get("_tex")
		drawings[tex.region] = true
		assert_eq(tex.atlas.resource_path, "res://assets/illustrated/motion/effects.png")
		if not shot.is_queued_for_deletion():
			shot.call("_physics_process", 1.0 / 60.0)
	assert_eq(drawings.size(), 4)

func test_arrow_has_its_own_drawing() -> void:
	var player := start_role(&"archer")
	await wait_frames(2)
	var shot := HeroProjectile.launch(player, Vector2.RIGHT)
	assert_eq(shot.get("_tex"), StoryArt.object_icon("hero_arrow"))

func test_only_player_strikes_and_impacts_switch_effects() -> void:
	var host := start_role(&"knight")
	await wait_frames(2)
	for id: StringName in [&"slash", &"hit_spark"]:
		var friendly := CombatFx.spawn(host, id, host.global_position)
		var other := CombatFx.spawn(arena, id, host.global_position)
		assert_true(friendly.player_ink)
		assert_false(other.player_ink)
		var drawings: Dictionary = {}
		for phase in 4:
			var ink := StoryArt.action_effect(0 if id == &"slash" else 2, phase) as AtlasTexture
			drawings[ink.region] = true
		assert_eq(drawings.size(), 4)

func test_named_gear_and_pickups_use_separate_paintings() -> void:
	var shop := WORKSHOP.new()
	var slots: Dictionary = {}
	for id: String in ["training_sword", "apprentice_staff", "ash_bow", "pack_bell", "hearth_heart", "leaf_compass"]:
		var tex := shop.icon({"id": id, "icon": 0}) as AtlasTexture
		assert_eq(tex, StoryArt.object_icon(id))
		slots[tex.region] = true
	assert_eq(slots.size(), 6)
	for code: String in ["fx:exp_orb", "fx:snack"]:
		var tex := StoryArt.actor(code) as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/illustrated/motion/objects.png")
		slots[tex.region] = true
	assert_eq(slots.size(), 8)
	var fallback := shop.icon({"id": "other_equipment", "icon": 0}) as AtlasTexture
	assert_eq(fallback.atlas.resource_path, "res://assets/illustrated/equipment/equipment_cutout.png")
	shop.free()
