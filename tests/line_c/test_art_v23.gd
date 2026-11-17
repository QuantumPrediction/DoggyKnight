extends TestCase
## v2.3 美術(DEV_PLAN 第 16 節 CS2 至 CS5、CS9):頭像、繪本插畫、新角色與投射物、光暈、前景、投影。
## (路徑、動畫名稱與大小範圍的合約由 tests/core/test_story_contract.gd 檢查;這裡檢查 C 線自己的規格。)

const SPRITES: Dictionary = {   # 代號:[格子, {動畫: 是否循環}]
	"scarecrow_archer": [32, {&"idle": true, &"run": true, &"attack": false, &"hurt": false, &"aim": true}],
	"armored_husk": [32, {&"idle": true, &"run": true, &"attack": false, &"hurt": false, &"dash": true, &"down": false}],
	"scarecrow_captain": [48, {&"idle": true, &"run": true, &"attack": false, &"hurt": false, &"throw": false,
			&"rally": true, &"down": false}],
	"merlin": [32, {&"idle": true, &"run": true, &"cast": false}],
}
const PROJECTILES: Dictionary = {"arrow": 16, "sword_wave": 24, "pitchfork": 16}
const BACKGROUNDS: Array[String] = ["sword_stone", "wheat_field", "meadow", "farm_fence", "crow_forest", "bridge"]
const LIGHTS: Array[String] = ["torch", "campfire", "lantern", "magic", "eye_violet", "visor_blue", "sword", "sun",
		"ultimate"]
## 背景圖左上角的世界座標(tools/pixel/art_world.py 的 ORIGIN)。
const BG_ORIGIN: Vector2 = Vector2(-62, -88)


func _image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _palette() -> Dictionary:
	var img := _image("res://assets/palette.png")
	var colors := {}
	for x in range(0, img.get_width(), 8):
		colors[img.get_pixel(x, 0).to_html(false)] = true
	return colors


func test_new_sprites_have_exact_cells_and_loop_flags() -> void:
	for code: String in SPRITES:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		var cell: int = SPRITES[code][0]
		var loops: Dictionary = SPRITES[code][1]
		for anim: StringName in loops:
			assert_true(frames.has_animation(anim), "%s.%s" % [code, anim])
			if not frames.has_animation(anim):
				continue
			assert_eq(frames.get_frame_texture(anim, 0).get_size(), Vector2(cell, cell), "%s.%s 的格子" % [code, anim])
			assert_eq(frames.get_animation_loop(anim), loops[anim], "%s.%s 循環與佔位版相同" % [code, anim])
	for fx_name: String in PROJECTILES:
		var frames := load("res://assets/fx/%s/%s_frames.tres" % [fx_name, fx_name]) as SpriteFrames
		var size: int = PROJECTILES[fx_name]
		assert_eq(frames.get_frame_texture(&"default", 0).get_size(), Vector2(size, size), fx_name)
		assert_true(frames.get_animation_loop(&"default"), "%s 循環" % fx_name)


func test_portraits_and_pages_are_opaque_palette_art() -> void:
	var pal := _palette()
	var paths: Array[String] = []
	for dir in DirAccess.get_directories_at("res://assets/portraits"):
		for f in DirAccess.get_files_at("res://assets/portraits/" + dir):
			if f.ends_with(".png"):
				paths.append("res://assets/portraits/%s/%s" % [dir, f])
	for f in DirAccess.get_files_at("res://assets/story"):
		if f.ends_with(".png"):
			paths.append("res://assets/story/" + f)
	assert_true(paths.size() >= 24, "16 張頭像 + 8 張插畫(實際 %d)" % paths.size())
	for path in paths:
		var img := _image(path)
		assert_eq(img.detect_alpha(), Image.ALPHA_NONE, "%s 不透明" % path)
		var bad := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y).to_html(false)
				if not pal.has(c):
					bad[c] = true
		assert_true(bad.is_empty(), "%s 只用調色盤:%s" % [path, bad.keys().slice(0, 4)])


func test_portrait_designs_differ_per_expression() -> void:
	# 每個表情都要真的不同(不是同一張圖複製)
	for speaker in ["goldie", "bulldog", "merlin"]:
		var seen := {}
		for f in DirAccess.get_files_at("res://assets/portraits/" + speaker):
			if not f.ends_with(".png"):
				continue
			var data := _image("res://assets/portraits/%s/%s" % [speaker, f]).get_data()
			var key := Marshalls.raw_to_base64(data).sha256_text()
			assert_false(seen.has(key), "%s/%s 和 %s 一樣" % [speaker, f, seen.get(key, "")])
			seen[key] = f


func test_light_sprites_are_additive_and_cheap() -> void:
	for name in LIGHTS:
		var node := (load("res://assets/fx/lights/%s.tscn" % name) as PackedScene).instantiate()
		assert_true(node is Sprite2D, "%s 是 Sprite2D(不用 Light2D)" % name)
		var mat := (node as Sprite2D).material as CanvasItemMaterial
		assert_true(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "%s 加亮混合" % name)
		node.free()
	for fx_name in ["sparkle", "ultimate_burst", "level_up_pillar", "star_burst"]:
		var p := (load("res://assets/fx/particles/%s.tscn" % fx_name) as PackedScene).instantiate() as CPUParticles2D
		var mat := p.material as CanvasItemMaterial
		assert_true(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "%s 會發光" % fx_name)
		p.free()


func test_backgrounds_have_shadows_lights_and_a_safe_foreground() -> void:
	for bg in BACKGROUNDS:
		var node := (load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate() as Node2D
		var shadows := node.get_node_or_null(^"Shadows")
		assert_true(shadows != null and shadows.get_script() != null, "%s 有角色投影" % bg)
		var fg := node.get_node_or_null(^"Foreground") as Node2D
		assert_not_null(fg, "%s 有前景層" % bg)
		if fg != null:
			assert_true(fg.z_index >= 50 and not fg.z_as_relative, "%s 前景在最上面" % bg)
		for c in node.find_children("*", "Light2D", true, false):
			assert_true(false, "%s 不用 Light2D(%s)" % [bg, c.name])
		node.free()
		# 前景圖:戰鬥區(與上方敵人出場的空間)一個不透明像素都沒有
		var img := _image("res://assets/backgrounds/%s_fg.png" % bg)
		var arena := Rect2(Layout.ARENA_RECT.position - Vector2(2, 36), Layout.ARENA_RECT.size + Vector2(4, 44))
		var covered := 0
		for y in range(int(arena.position.y), int(arena.end.y)):
			for x in range(int(arena.position.x), int(arena.end.x)):
				var p := Vector2(x, y) - BG_ORIGIN
				if img.get_pixel(int(p.x), int(p.y)).a > 0.0:
					covered += 1
		assert_eq(covered, 0, "%s 的前景不蓋住戰鬥區" % bg)


func test_shadow_layer_follows_actor_groups() -> void:
	var bg := (load("res://assets/backgrounds/meadow.tscn") as PackedScene).instantiate() as Node2D
	add_child(bg)
	var actor := Node2D.new()
	actor.add_to_group(&"enemy")
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = load("res://assets/sprites/armored_husk/armored_husk_frames.tres")
	actor.add_child(spr)
	add_child(actor)
	await wait_frames(2)
	var cache: Dictionary = bg.get_node(^"Shadows").get("_frame_size")
	assert_true(cache.has(spr.sprite_frames.get_instance_id()), "敵人的影子依格子大小畫出")
	actor.queue_free()
	bg.queue_free()


func test_story_glows_on_the_armour() -> void:
	var knight := (load("res://assets/sprites/black_knight/black_knight_frames.tres") as SpriteFrames).get_frame_texture(&"idle", 0).get_image()
	var husk := (load("res://assets/sprites/armored_husk/armored_husk_frames.tres") as SpriteFrames).get_frame_texture(&"idle", 0).get_image()
	assert_true(_has_colour(knight, PaletteColors.LILAC), "黑騎士面罩發紫光")
	assert_false(_has_colour(knight, PaletteColors.ORANGE), "不再是橘色眼睛")
	assert_true(_has_colour(husk, PaletteColors.SKY_L), "空盔甲兵面罩發藍光")


func _has_colour(img: Image, col: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and p.to_html(false) == col.to_html(false):
				return true
	return false
