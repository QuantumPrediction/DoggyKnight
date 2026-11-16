extends TestCase
## C 線美術(C1 至 C7、C9、C13):格數、格子大小、調色盤、背景範圍、App 圖示規格。
## (路徑與動畫名稱的合約由 tests/core/test_art_contract.gd 檢查。)

const FRAME_COUNTS: Dictionary = {   # DEV_PLAN C2、CP1(v2.2 加格數);v2.3 金毛站立 6 格(披風、耳朵)
	"goldie": {&"idle": 6, &"run": 6, &"attack": 4, &"hurt": 2, &"sleep": 2, &"victory": 4},
	"bulldog": {&"idle": 4, &"run": 6, &"attack": 4, &"hurt": 2, &"guard": 2, &"victory": 4},
	"scarecrow": {&"idle": 4, &"run": 6, &"attack": 4, &"hurt": 2},
	"crow": {&"idle": 4, &"run": 6, &"attack": 4, &"hurt": 2},
	"black_knight": {&"idle": 4, &"run": 6, &"attack": 4, &"hurt": 2, &"charge": 3, &"slam": 4, &"down": 2},
}
const SIZES: Dictionary = {
	"goldie": 24, "bulldog": 24, "scarecrow": 24, "crow": 16, "black_knight": 48,
}
const PIXEL_ART: Array[String] = [
	"res://assets/sprites/goldie/goldie.png", "res://assets/sprites/bulldog/bulldog.png",
	"res://assets/sprites/scarecrow/scarecrow.png", "res://assets/sprites/crow/crow.png",
	"res://assets/sprites/black_knight/black_knight.png", "res://assets/tiles/chapter1_tiles.png",
	"res://assets/backgrounds/meadow.png", "res://assets/backgrounds/sword_stone.png",
	"res://assets/backgrounds/bridge.png", "res://assets/backgrounds/wheat_field.png",
	"res://assets/backgrounds/farm_fence.png", "res://assets/backgrounds/crow_forest.png",
	"res://assets/icons/tricks/sit.png",
	"res://assets/icons/tricks/spin.png", "res://assets/ui/button_normal.png",
	"res://assets/ui/title_bg.png", "res://assets/app_icon/icon_master_32.png",
]


func _image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return img


func _palette() -> Dictionary:
	var img := _image("res://assets/palette.png")
	var colors := {}
	for x in range(0, img.get_width(), 8):
		colors[img.get_pixel(x, 0).to_html(false)] = true
	return colors


func test_palette_has_40_colours() -> void:
	# v1 的 32 色 + v2.2 的 8 個氣氛色(黃昏、夜晚、農場);見 tools/pixel/palette.py
	assert_eq(_palette().size(), 40)
	assert_eq(PaletteColors.DIRT, Color("c9a06e"))


func test_pixel_art_uses_only_the_palette() -> void:
	var pal := _palette()
	for path in PIXEL_ART:
		var img := _image(path)
		assert_not_null(img, path)
		if img == null:
			continue
		var bad := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and not pal.has(c.to_html(false)):
					bad[c.to_html(false)] = true
		assert_true(bad.is_empty(), "%s 用了調色盤以外的顏色:%s" % [path, bad.keys().slice(0, 5)])


func test_frame_counts_and_sizes() -> void:
	for code: String in SIZES:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		for anim in frames.get_animation_names():
			var size := frames.get_frame_texture(anim, 0).get_size()
			assert_eq(size, Vector2(SIZES[code], SIZES[code]), "%s.%s 的格子大小" % [code, anim])
	for code: String in FRAME_COUNTS:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		for anim: StringName in FRAME_COUNTS[code]:
			assert_eq(frames.get_frame_count(anim), FRAME_COUNTS[code][anim], "%s.%s 的格數" % [code, anim])
	var bulldog := load("res://assets/sprites/bulldog/bulldog_frames.tres") as SpriteFrames
	assert_true(bulldog.has_animation(&"guard"), "鬥牛犬有 guard(舉盾)")


func test_looping_rules() -> void:
	var goldie := load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	assert_true(goldie.get_animation_loop(&"idle"))
	assert_true(goldie.get_animation_loop(&"run"))
	assert_false(goldie.get_animation_loop(&"attack"), "攻擊只播一次,A 線可以等 animation_finished")
	assert_false(goldie.get_animation_loop(&"hurt"))
	var knight := load("res://assets/sprites/black_knight/black_knight_frames.tres") as SpriteFrames
	assert_false(knight.get_animation_loop(&"down"))
	assert_false(knight.get_animation_loop(&"slam"))
	assert_true(goldie.get_animation_loop(&"victory"), "過關歡呼循環播放")


func test_attack_animations_stay_short() -> void:
	# A 線在動畫開始的一刻就判定命中;揮劍動畫要短,第一格(預備)更要短。
	var goldie := load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	var total := 0.0
	for i in goldie.get_frame_count(&"attack"):
		total += goldie.get_frame_duration(&"attack", i) / goldie.get_animation_speed(&"attack")
	assert_true(total <= 0.32, "金毛揮劍動畫 %.2f 秒(不超過 0.32)" % total)
	assert_true(goldie.get_frame_duration(&"attack", 0) / goldie.get_animation_speed(&"attack") <= 0.05,
			"預備格很短,揮劍的感覺不會延遲")


const ALL_BACKGROUNDS: Array[String] = ["sword_stone", "wheat_field", "meadow", "farm_fence", "crow_forest", "bridge"]


func test_backgrounds_cover_the_extended_screen() -> void:
	var need := Rect2(-10, -60, 200, 440)
	for bg in ALL_BACKGROUNDS:
		var node := (load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate() as Node2D
		var image := node.get_node_or_null("Image") as Sprite2D
		assert_not_null(image, "%s 有 Image(烘焙好的背景圖)" % bg)
		if image != null:
			var covered := Rect2(image.position, image.texture.get_size())
			assert_true(covered.encloses(need), "%s 覆蓋 %s(實際 %s)" % [bg, need, covered])
			assert_true(covered.encloses(Layout.ARENA_RECT))
		node.free()


func test_background_ambience_is_light_and_readable() -> void:
	for bg in ALL_BACKGROUNDS:
		var node := (load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate() as Node2D
		var particles := 0
		var mood: CanvasModulate = null
		for c in node.find_children("*", "", true, false):
			if c is CPUParticles2D:
				particles += (c as CPUParticles2D).amount
			elif c is GPUParticles2D:
				assert_true(false, "%s:背景只用 CPUParticles2D" % bg)
			elif c is CanvasModulate:
				mood = c as CanvasModulate
		assert_true(particles <= 100, "%s 的環境粒子不超過 100 個(實際 %d)" % [bg, particles])
		if mood != null:
			var lum := mood.color.r * 0.3 + mood.color.g * 0.59 + mood.color.b * 0.11
			assert_true(lum >= 0.85, "%s 的氣氛色不可太暗(亮度 %.2f),角色與預警要看得清楚" % [bg, lum])
		node.free()


func test_trick_icons_are_16px() -> void:
	for trick in ["sit", "wag", "fetch", "shake", "spin", "bark"]:
		var tex := load("res://assets/icons/tricks/%s.png" % trick) as Texture2D
		assert_eq(tex.get_size(), Vector2(16, 16), trick)


func test_app_icons() -> void:
	var icon := _image("res://assets/app_icon/icon.png")
	assert_true(icon.get_width() >= 256 and icon.get_width() == icon.get_height(), "icon.png 至少 256×256")
	assert_false(icon.detect_alpha() != Image.ALPHA_NONE, "icon.png 不透明")
	var specs := {
		"icon_1024.png": [Vector2i(1024, 1024), true],
		"play_icon_512.png": [Vector2i(512, 512), true],
		"android_foreground.png": [Vector2i(432, 432), false],
		"android_background.png": [Vector2i(432, 432), true],
		"android_monochrome.png": [Vector2i(432, 432), false],
		"feature_graphic_1024x500.png": [Vector2i(1024, 500), true],
	}
	for file: String in specs:
		var img := _image("res://assets/app_icon/" + file)
		assert_not_null(img, file)
		if img == null:
			continue
		assert_eq(img.get_size(), specs[file][0], file)
		if specs[file][1]:
			assert_eq(img.detect_alpha(), Image.ALPHA_NONE, "%s 不可透明" % file)
	assert_true(ResourceLoader.exists("res://assets/app_icon/splash.png"), "啟動畫面")
	# Android 自適應圖示:主體在中央 66% 的圓內
	var fg := _image("res://assets/app_icon/android_foreground.png")
	var r := 432.0 * 0.66 * 0.5
	var outside := 0
	for y in range(0, 432, 2):
		for x in range(0, 432, 2):
			if fg.get_pixel(x, y).a > 0.0 and Vector2(x + 0.5, y + 0.5).distance_to(Vector2(216, 216)) > r:
				outside += 1
	assert_eq(outside, 0, "前景超出安全圓的像素")
