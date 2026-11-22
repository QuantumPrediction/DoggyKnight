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
	for phase in 4:
		var progress := float(phase * total) / 4.0
		sprite.set_frame_and_progress(floori(progress), fmod(progress, 1.0))
		assert_eq(selected(sprite), StoryArt.motion_pose(role, phase + 1), "running phase %d" % phase)
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
