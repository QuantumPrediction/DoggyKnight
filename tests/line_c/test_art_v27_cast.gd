extends TestCase
## v2.7 C 角色(DEV_PLAN 第 20 節 CC6 至 CC8):第四至六章的角色圖、頭像、投射物與粒子。
## (路徑、動畫名稱與格子範圍的合約由 tests/core/test_v27_contract.gd 檢查。)

## 代號:格子大小。
const SIZES: Dictionary = {
	"crab": 24, "jellyfish": 24, "kraken": 64, "snowman": 24, "salamander": 24, "red_dragon": 64,
	"white_dragon": 64, "shadow_knight": 32, "lantern_wisp": 16, "mordred": 48, "tristan": 32, "gawain": 40,
}
## 走在地上的角色:這些動畫每一格的最低一列(腳底的描邊)都一樣,而且就在影子那一列(格子高 - 2;
## 三個 64 格頭目和黑騎士一樣上移 8 像素)。水母與提燈鬼火會飄,不檢查。
const GROUNDED: Dictionary = {
	"crab": [&"idle", &"run", &"attack", &"hurt", &"guard"],
	"snowman": [&"idle", &"run", &"attack", &"hurt", &"throw"],
	"salamander": [&"idle", &"run", &"attack", &"hurt", &"dash"],
	"kraken": [&"idle", &"run", &"attack", &"hurt", &"slam", &"ink", &"summon", &"down"],
	"red_dragon": [&"idle", &"run", &"attack", &"hurt", &"breath", &"roar", &"sulk"],
	"white_dragon": [&"idle", &"run", &"attack", &"hurt", &"breath", &"roar", &"sulk"],
	"shadow_knight": [&"idle", &"run", &"attack", &"hurt", &"guard"],
	"mordred": [&"idle", &"run", &"attack", &"hurt", &"dash", &"slash", &"guard", &"summon", &"down"],
	"tristan": [&"idle", &"run", &"attack", &"hurt", &"play"],
	"gawain": [&"idle", &"run", &"attack", &"hurt", &"slam"],
}
const LIFTED: Array[String] = ["kraken", "red_dragon", "white_dragon"]
## 循環與否照佔位版(A 線依此等 animation_finished 或一直播)。
const LOOPS: Dictionary = {
	"crab": {&"guard": true}, "jellyfish": {&"zap": false},
	"kraken": {&"slam": false, &"ink": false, &"summon": false, &"down": false},
	"snowman": {&"throw": false}, "salamander": {&"dash": true},
	"red_dragon": {&"breath": false, &"roar": false, &"sulk": true},
	"white_dragon": {&"breath": false, &"roar": false, &"sulk": true},
	"shadow_knight": {&"guard": true, &"down": false}, "lantern_wisp": {&"heal": false},
	"mordred": {&"dash": true, &"slash": false, &"guard": true, &"summon": false, &"down": false},
	"tristan": {&"play": true}, "gawain": {&"slam": false},
}
const PORTRAITS: Dictionary = {
	"tristan": ["normal", "happy", "serious", "surprised"],
	"gawain": ["normal", "happy", "serious"],
	"kraken": ["normal"],
	"red_dragon": ["normal"],
	"white_dragon": ["normal"],
	"mordred": ["normal", "smirk", "angry", "sad"],
}
const PROJECTILES: Array[String] = ["bubble", "ink_blob", "music_note", "snowball", "fireball", "ice_shard",
		"shadow_slash", "tentacle"]
const PARTICLES: Array[String] = ["snow_burst", "bubble_pop"]


func _palette() -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette.png"))
	var colors := {}
	for x in range(0, img.get_width(), 8):
		colors[img.get_pixel(x, 0).to_html(false)] = true
	return colors


func _off_palette(path: String, pal: Dictionary) -> Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var bad := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and not pal.has(c.to_html(false)):
				bad[c.to_html(false)] = true
	return bad.keys()


## 一格圖的最低一列不透明像素(只算幾乎不透明的,光暈不算)。
func _lowest_row(tex: Texture2D) -> int:
	var img := tex.get_image()
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.9:
				return y
	return -1


func _frames(code: String) -> SpriteFrames:
	return load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames


func _has(img: Image, col: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and p.to_html(false) == col.to_html(false):
				return true
	return false


func test_every_animation_uses_the_same_cell() -> void:
	for code: String in SIZES:
		var frames := _frames(code)
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				assert_eq(frames.get_frame_texture(anim, i).get_size(), Vector2(SIZES[code], SIZES[code]),
						"%s.%s 第 %d 格" % [code, anim, i])
		var tex := frames.get_frame_texture(&"idle", 0) as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/sprites/%s/%s.png" % [code, code], "%s 用自己的圖" % code)


func test_new_art_uses_only_the_palette() -> void:
	var pal := _palette()
	var paths: Array[String] = []
	for code: String in SIZES:
		paths.append("res://assets/sprites/%s/%s.png" % [code, code])
	for speaker: String in PORTRAITS:
		for expr: String in PORTRAITS[speaker]:
			paths.append("res://assets/portraits/%s/%s.png" % [speaker, expr])
	for fx in PROJECTILES:
		paths.append("res://assets/fx/%s/%s.png" % [fx, fx])
	for tex in ["snow_chunk", "bubble_ring"]:
		paths.append("res://assets/fx/particles/tex/%s.png" % tex)
	for path in paths:
		var bad := _off_palette(path, pal)
		assert_true(bad.is_empty(), "%s 用了調色盤以外的顏色:%s" % [path, bad.slice(0, 5)])


func test_feet_line_up_on_the_shadow_row() -> void:
	for code: String in GROUNDED:
		var frames := _frames(code)
		# 64 格的頭目照黑騎士的做法:腳底描邊在第 55 列(以前的 63 往上 8)
		var expected: int = 55 if LIFTED.has(code) else SIZES[code] - 2
		for anim: StringName in GROUNDED[code]:
			for i in frames.get_frame_count(anim):
				assert_eq(_lowest_row(frames.get_frame_texture(anim, i)), expected, "%s.%s 第 %d 格的腳底" % [code, anim, i])


func test_big_bosses_stand_8px_higher() -> void:
	for code in LIFTED:
		assert_eq(_frames(code).get_meta(&"foot_lift", 0), 8, "%s 的影子可以讀到腳底上移了 8 像素" % code)


func test_loop_flags_and_one_shots_stay_short() -> void:
	for code: String in LOOPS:
		var frames := _frames(code)
		for anim: StringName in LOOPS[code]:
			assert_eq(frames.get_animation_loop(anim), LOOPS[code][anim], "%s.%s 的循環" % [code, anim])
		for anim in [&"attack", &"hurt"]:
			assert_false(frames.get_animation_loop(anim), "%s.%s 只播一次" % [code, anim])
		assert_true(frames.get_animation_loop(&"idle") and frames.get_animation_loop(&"run"), "%s 的 idle、run 循環" % code)
		for anim in frames.get_animation_names():
			if frames.get_animation_loop(anim):
				continue
			var total := 0.0
			for i in frames.get_frame_count(anim):
				total += frames.get_frame_duration(anim, i) / frames.get_animation_speed(anim)
			assert_true(total <= 1.2, "%s.%s 長 %.2f 秒" % [code, anim, total])


func test_characters_are_recognisable() -> void:
	var idle := func(code: String) -> Image: return _frames(code).get_frame_texture(&"idle", 0).get_image()
	# 章魚王:金色貝殼王冠與黑狼紋章(ink 加紫色描邊)
	var kraken: Image = idle.call("kraken")
	assert_true(_has(kraken, PaletteColors.YELLOW) and _has(kraken, PaletteColors.VIOLET), "章魚王:王冠與紋章")
	# 紋章在倒下(縮成一團)後碎掉
	assert_false(_has(_frames("kraken").get_frame_texture(&"down", 0).get_image(), PaletteColors.VIOLET), "倒下後沒有紋章")
	# 紅龍黃肚子、白龍冰藍色的角
	assert_true(_has(idle.call("red_dragon"), PaletteColors.GOLD_L), "紅龍:黃色肚子")
	assert_true(_has(idle.call("white_dragon"), PaletteColors.AZURE), "白龍:冰藍色的角與鬃毛")
	# 莫德雷德:發紫光的劍鞘、銀邊盔甲、黃褐色的杜賓毛
	var mordred: Image = idle.call("mordred")
	assert_true(_has(mordred, PaletteColors.LILAC) and _has(mordred, PaletteColors.STEEL_L)
			and _has(mordred, PaletteColors.GOLD_D), "莫德雷德:劍鞘、銀邊、杜賓的黃褐色")
	# 雪人的黑狼帽、火蜥蜴尾巴的火、崔斯坦的淺藍披風、高文的橘色斗篷
	assert_true(_has(idle.call("snowman"), PaletteColors.INK), "雪人:黑色毛線帽")
	assert_true(_has(idle.call("salamander"), PaletteColors.YELLOW), "火蜥蜴:尾巴上的小火")
	assert_true(_has(idle.call("tristan"), PaletteColors.AZURE), "崔斯坦:淺藍色披風")
	assert_true(_has(idle.call("gawain"), PaletteColors.ORANGE), "高文:橘色斗篷")
	# 水母是半透明的
	var jelly: Image = idle.call("jellyfish")
	var see_through := false
	for y in jelly.get_height():
		for x in jelly.get_width():
			var a := jelly.get_pixel(x, y).a
			if a > 0.6 and a < 0.95:
				see_through = true
	assert_true(see_through, "水母的身體半透明")


func test_portraits_are_opaque_48px_and_differ() -> void:
	for speaker: String in PORTRAITS:
		var seen := {}
		for expr: String in PORTRAITS[speaker]:
			var tex := load("res://assets/portraits/%s/%s.png" % [speaker, expr]) as Texture2D
			assert_eq(tex.get_size(), Vector2(48, 48))
			var img := tex.get_image()
			assert_eq(img.get_pixel(0, 0).a, 1.0, "%s/%s 不透明" % [speaker, expr])
			var key := Marshalls.raw_to_base64(img.get_data())
			assert_false(seen.has(key), "%s/%s 和其他表情不一樣" % [speaker, expr])
			seen[key] = true


func test_projectiles_have_their_own_art() -> void:
	for fx in PROJECTILES:
		var frames := load("res://assets/fx/%s/%s_frames.tres" % [fx, fx]) as SpriteFrames
		assert_true(frames.has_animation(&"default") and frames.get_animation_loop(&"default"), "%s 循環播放" % fx)
		assert_true(frames.get_frame_count(&"default") >= 2, "%s 有動畫" % fx)
		var tex := frames.get_frame_texture(&"default", 0) as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/fx/%s/%s.png" % [fx, fx], "%s 不再借用箭的圖" % fx)
	var tentacle := (load("res://assets/fx/tentacle/tentacle_frames.tres") as SpriteFrames).get_frame_texture(&"default", 0)
	var size := tentacle.get_size()
	assert_true(size.x >= 16 and size.x <= 24 and size.y >= 48 and size.y <= 64, "觸手是直立的長條(%s)" % size)


func test_particle_scenes_follow_the_pattern() -> void:
	for p in PARTICLES:
		var node := (load("res://assets/fx/particles/%s.tscn" % p) as PackedScene).instantiate()
		assert_true(node is CPUParticles2D, "%s 是 CPUParticles2D" % p)
		var cpu := node as CPUParticles2D
		assert_true(cpu.one_shot and cpu.texture != null and cpu.get_script() != null, "%s 一次性、有圖、會自己刪除" % p)
		assert_true(cpu.amount <= 16, "%s 粒子不多" % p)
		assert_true(cpu.texture.get_width() <= 6 and cpu.texture.get_height() <= 6, "%s 的粒子很小" % p)
		assert_true(cpu.lifetime <= 2.0, "%s 很快結束" % p)
		node.free()
