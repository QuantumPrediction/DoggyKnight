extends TestCase

const PROFILES := preload("res://tests/integration/equipment_profiles.gd")
const PLAYER := preload("res://game/actors/player/player.tscn")

func profile_at(role: String, preset: String, level: int) -> Dictionary:
	var profile: Dictionary = PROFILES.make(role, preset)
	for id in profile.owned:
		profile.owned[id] = level
	return profile

func test_equipment_slots_and_levels_select_the_painted_grades() -> void:
	var look := WornGear.new()
	for role: String in EquipmentInventory.HEROES:
		for point in [["common5",1,1], ["common5",2,1], ["common5",3,2], ["common5",5,3],
				["epic9",1,3], ["epic9",5,3], ["epic9",6,4], ["epic9",8,4], ["epic9",9,5]]:
			var profile := profile_at(role, point[0], point[1])
			var original := profile.duplicate(true)
			look.configure(StringName(role), profile)
			assert_eq(look.weapon_grade, point[2])
			assert_eq(look.armor_grade, point[2])
			assert_eq(profile, original)

func test_armor_family_and_weapon_level_are_independent() -> void:
	var profile := PROFILES.make("mage", "epic9") as Dictionary
	profile.owned["mistcloak"] = 6
	profile.loadouts.mage.armor = "mistcloak"
	profile.owned.moonstaff = 1
	var look := WornGear.new()
	look.configure(&"mage", profile)
	assert_eq(look.armor_row, 1, "the mage can really wear the ranger mantle")
	assert_eq(look.armor_grade, 4)
	assert_eq(look.weapon_grade, 3)
	profile.loadouts.mage.erase("weapon")
	look.configure(&"mage", profile)
	assert_eq(look.weapon_grade, 0, "spares in inventory do not paint an extra weapon")
	assert_eq(look.armor_grade, 4)
	look.configure(&"knight", profile)
	assert_eq(look.armor_grade, 0)
	assert_eq(look.weapon_grade, 0)

func test_treasures_legacy_and_empty_slots_leave_the_hero_drawing_alone() -> void:
	var look := WornGear.new()
	var profile := PROFILES.make("archer", "epic9") as Dictionary
	profile.loadouts.archer.erase("armor")
	profile.loadouts.archer.erase("weapon")
	for inventory in [profile, {}, {"owned": {"future_item": 9}, "loadouts": {"archer": {"weapon": "future_item"}}}]:
		look.configure(&"archer", inventory)
		assert_eq(look.armor_grade, 0)
		assert_eq(look.weapon_grade, 0)

func test_all_84_drawings_register_both_sockets_on_the_original_silhouette() -> void:
	var sheets := {}
	for role: StringName in HeroClasses.IDS:
		var frames: Array[Texture2D] = []
		for phase in 8:
			frames.append(StoryArt.hero_stride(role, phase))
			frames.append(StoryArt.cell("motion/vertical_" + String(role), phase % 4, phase / 4, 4, 2))
		for phase in 4:
			frames.append(StoryArt.cell("motion/settle_" + String(role), phase % 2, phase / 2, 2, 2))
		for phase in [0, 5, 6, 7, 8]:
			frames.append(StoryArt.motion_pose(role, phase))
		for phase in 3:
			frames.append(StoryArt.cell("motion/reactions", phase, HeroClasses.IDS.find(role), 3, 3))
		assert_eq(frames.size(), 28)
		for texture in frames:
			var key := WornGear.SOCKETS.locate(String(role), texture)
			assert_true(key.size() in [5, 7], String(role))
			if key.size() not in [5, 7]:
				continue
			var frame := texture as AtlasTexture
			var path := frame.atlas.resource_path
			if not sheets.has(path):
				sheets[path] = frame.atlas.get_image()
			var source: Image = sheets[path]
			var offsets := [0, 2, 5] if key.size() == 7 else [0, 2]
			for offset in offsets:
				var point := Vector2i(frame.region.position) + Vector2i(key[offset], key[offset + 1])
				var on_paint := false
				for near in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					on_paint = on_paint or source.get_pixelv(point + near).a > 0.46
				assert_true(on_paint, "%s (%d, %d) socket %d" % [path, key[offset], key[offset + 1], offset])

func test_run_snapshot_and_armory_projection_stay_separate() -> void:
	var old_role := GameState.hero_class
	var old_equipment := GameState.equipment
	var old_snapshot := GameState.run_equipment
	GameState.hero_class = &"knight"
	GameState.equipment = profile_at("knight", "epic9", 9)
	GameState.run_equipment = EquipmentInventory.loadout(profile_at("knight", "common5", 1), "knight")
	var player := PLAYER.instantiate() as GoldiePlayer
	add_child(player)
	player.set_physics_process(false)
	await wait_frames(2)
	var skin := player.sprite.get_node("IllustratedActor")
	var in_battle: WornGear = skin.get("_worn")
	assert_eq(in_battle.armor_grade, 1, "checkpoint still wears its source armor level")
	assert_eq(in_battle.weapon_grade, 1)
	var preview := WornGearPreview.new()
	preview.size = Vector2(53, 54)
	preview.set_appearance(&"knight", GameState.equipment)
	assert_eq(preview._appearance.armor_grade, 5)
	assert_eq(preview._appearance.weapon_grade, 5)
	assert_eq(preview._painting, StoryArt.motion_pose(&"knight", 0))
	assert_eq(preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	preview.free()
	player.free()
	GameState.hero_class = old_role
	GameState.equipment = old_equipment
	GameState.run_equipment = old_snapshot

func test_exp_awards_rank_on_the_live_actor_and_a_new_chapter_resets_only_the_rank() -> void:
	var previous := {}
	for key in ["hero_class", "equipment", "run_equipment", "hero_level", "player_stats", "vigor",
			"satisfaction", "active_tricks", "run_route", "guard_lesson_skipped", "level_index", "next_level_bonus"]:
		var current: Variant = GameState.get(key)
		previous[key] = current.duplicate(true) if current is Array or current is Dictionary else current
	GameState.hero_class = &"mage"
	GameState.equipment = PROFILES.make("mage", "epic9")
	GameState.reset_run()
	var inventory_before := GameState.equipment.duplicate(true)
	var progression := RunProgression.new()
	progression.setup(preload("res://game/progression/difficulty.tres"), 19)
	add_child(progression)
	progression.reset_run()
	progression.begin_level()
	var player := PLAYER.instantiate() as GoldiePlayer
	add_child(player)
	player.set_physics_process(false)
	await wait_frames(2)
	var worn: WornGear = player.sprite.get_node("IllustratedActor").get("_worn")
	for level in range(2, 9):
		EventBus.exp_collected.emit(progression.get_exp_needed())
		assert_eq(GameState.hero_level, level)
		assert_eq(worn.rank, int(level >= 4) + int(level >= 8))
		assert_eq(worn.weapon_grade, 5)
		assert_eq(worn.armor_grade, 5)
	var preview := WornGearPreview.new()
	preview.set_appearance(&"mage", GameState.equipment)
	assert_eq(preview._appearance.rank, 2)
	preview.free()
	player.free()
	progression.free()
	GameState.reset_run()
	var next := PLAYER.instantiate() as GoldiePlayer
	add_child(next)
	next.set_physics_process(false)
	await wait_frames(2)
	var new_worn: WornGear = next.sprite.get_node("IllustratedActor").get("_worn")
	assert_eq(new_worn.rank, 0)
	assert_eq(new_worn.weapon_grade, 5)
	assert_eq(new_worn.armor_grade, 5)
	assert_eq(GameState.equipment, inventory_before)
	next.free()
	for key in previous:
		GameState.set(key, previous[key])

func test_small_wearable_paint_uses_mipmaps_for_filigree_and_weapon_edges() -> void:
	for path: String in [WornGear.FITTINGS_PATH, WornGear.CAPES_PATH, WornGear.BLADE_PATH, WornGear.RANK_PATH]:
		var texture := load(path) as Texture2D
		assert_not_null(texture)
		assert_true(texture.get_image().has_mipmaps(), path)
	var preview := WornGearPreview.new()
	assert_eq(preview.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	preview.free()
