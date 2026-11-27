extends TestCase
## Integration checks for production scene bindings, animation timing and save isolation.

func after_each() -> void:
	for child in get_children():
		child.queue_free()
	SafeArea.simulate_notch = false
	await wait_frames(2)

func test_every_production_level_installs_painted_world() -> void:
	for chapter in range(1, 7):
		for number in range(1, 7):
			var level := load("res://data/levels/level_%d_%d.tres" % [chapter, number]) as LevelData
			var world := level.background.instantiate()
			add_child(world)
			await wait_frames(2)
			var skin := world.get_node_or_null("IllustratedWorld")
			assert_not_null(skin, "production background %d-%d" % [chapter, number])
			if skin != null:
				assert_not_null(skin.get("_texture"))
				assert_eq(skin.get("chapter"), chapter)
			world.queue_free()
			await wait_frames(1)

func test_all_production_cast_has_art_and_original_animation_events() -> void:
	for code: String in DirAccess.get_directories_at("res://assets/sprites"):
		var path := "res://assets/sprites/%s/%s_frames.tres" % [code, code]
		if not ResourceLoader.exists(path):
			continue
		var frames := load(path) as SpriteFrames
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.animation = frames.get_animation_names()[0]
		add_child(sprite)
		await wait_frames(2)
		assert_not_null(sprite.get_node_or_null("IllustratedActor"), code)
		assert_eq(sprite.sprite_frames, frames, "keep the gameplay animation resource")
		assert_not_null(StoryArt.actor(code), code)
		sprite.queue_free()
		await wait_frames(1)

func test_attack_finishes_and_flip_remains_attached_to_sprite() -> void:
	var frames := load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.play(&"attack")
	var completed := [0]
	sprite.animation_finished.connect(func() -> void: completed[0] += 1)
	add_child(sprite)
	await wait_frames(2)
	var skin := sprite.get_node("IllustratedActor") as Node2D
	sprite.flip_h = true
	await wait_frames(2)
	assert_eq(skin.scale.x, -1.0)
	sprite.flip_h = false
	await wait_frames(2)
	assert_eq(skin.scale.x, 1.0)
	await get_tree().create_timer(0.5).timeout
	assert_eq(completed[0], 1, "a non-looping attack still completes once")
	assert_eq(sprite.sprite_frames, frames)

func test_every_story_page_and_trick_icon_is_replaced() -> void:
	for file: String in DirAccess.get_files_at("res://assets/story"):
		if file.ends_with(".png"):
			assert_not_null(StoryArt.story(file.get_basename()), file)
	for file: String in DirAccess.get_files_at("res://data/tricks"):
		if file.ends_with(".tres"):
			var id := StringName(file.get_basename())
			if AttackTechniques.IDS.has(id):
				var icon := TrickDeck.load_trick(id).icon
				assert_not_null(icon, file)
				assert_eq(icon.resource_path, "res://assets/illustrated/techniques/%s.webp" % id)
				assert_eq(icon.get_size(), Vector2(128, 128))
			else:
				assert_true(StoryArt.TRICKS.has(file.get_basename()), file)

func test_gallery_does_not_unlock_chapters_or_change_progress() -> void:
	var before := [GameState.chapter, GameState.level_index, GameState.chapters_cleared,
		GameState.snacks, GameState.story_seen.duplicate(true), GameState.best_stars.duplicate(true)]
	var gallery := CanvasLayer.new()
	gallery.set_script(load("res://ui/illustrated/art_gallery.gd"))
	add_child(gallery)
	for chapter in range(1, 7):
		gallery.call("select_chapter", chapter)
		for level in 6:
			gallery.call("select_level", level)
	await wait_frames(2)
	assert_eq([GameState.chapter, GameState.level_index, GameState.chapters_cleared,
		GameState.snacks, GameState.story_seen, GameState.best_stars], before)
	SafeArea.simulate_notch = true
	gallery.call("_layout")
	var content := gallery.get("_root") as Control
	assert_true(SafeArea.get_safe_rect().encloses(Rect2(content.position, content.size * content.scale)), "gallery respects the notch")
