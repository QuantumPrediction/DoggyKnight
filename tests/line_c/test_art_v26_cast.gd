extends TestCase
## v2.6 C 角色(DEV_PLAN 第 19 節 CC1 至 CC4):新角色圖、頭像、投射物、粒子與黑騎士上移。
## (路徑、動畫名稱與格子大小的合約由 tests/core/test_v26_contract.gd 檢查。)

## 代號:格子大小。
const SIZES: Dictionary = {
	"gargoyle": 32, "spellbook": 24, "foxfire": 16, "shadow_wolf": 32,
	"green_knight": 64, "morgana": 64, "lancelot": 32, "lady_lake": 32,
}
## 走在地上的角色:這些動畫每一格的最低一列(腳底的描邊)都一樣。
const GROUNDED: Dictionary = {
	"lancelot": [&"idle", &"run", &"attack", &"hurt", &"dash"],
	"shadow_wolf": [&"idle", &"run", &"attack", &"hurt"],
	"lady_lake": [&"idle", &"run", &"cast"],
	"green_knight": [&"idle", &"run", &"attack", &"hurt", &"whip", &"summon", &"hat_off", &"idle_bare", &"run_bare",
			&"attack_bare", &"hurt_bare", &"whip_bare", &"summon_bare"],
	"morgana": [&"idle", &"hurt"],
}
const PORTRAITS: Dictionary = {
	"lancelot": ["normal", "happy", "serious", "surprised"],
	"gargoyle": ["normal"],
	"green_knight": ["normal"],
	"lady_lake": ["normal", "smile", "worried"],
	"morgana_true": ["normal", "angry", "sad", "smile"],
}
const PROJECTILES: Array[String] = ["magic_orb", "thorn", "fox_flame", "moon_orb"]
const PARTICLES: Array[String] = ["stone_chips", "shadow_leaves"]


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


func test_every_animation_uses_the_same_cell() -> void:
	for code: String in SIZES:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				assert_eq(frames.get_frame_texture(anim, i).get_size(), Vector2(SIZES[code], SIZES[code]),
						"%s.%s 第 %d 格" % [code, anim, i])


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
	for tex in ["stone_chip", "leaf"]:
		paths.append("res://assets/fx/particles/tex/%s.png" % tex)
	for path in paths:
		var bad := _off_palette(path, pal)
		assert_true(bad.is_empty(), "%s 用了調色盤以外的顏色:%s" % [path, bad.slice(0, 5)])


func test_feet_line_up_in_every_frame() -> void:
	for code: String in GROUNDED:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [code, code]) as SpriteFrames
		var expected := _lowest_row(frames.get_frame_texture(&"idle", 0))
		for anim: StringName in GROUNDED[code]:
			for i in frames.get_frame_count(anim):
				assert_eq(_lowest_row(frames.get_frame_texture(anim, i)), expected, "%s.%s 第 %d 格的腳底" % [code, anim, i])


func test_bosses_are_recognisable() -> void:
	# 綠騎士的葉子帽上有紫色荊棘;摩根娜有紫斗篷與金色新月
	var gk := (load("res://assets/sprites/green_knight/green_knight_frames.tres") as SpriteFrames).get_frame_texture(&"idle", 0).get_image()
	assert_true(_has(gk, PaletteColors.VIOLET) and _has(gk, PaletteColors.LEAF_L), "綠騎士:葉子帽與紫色荊棘")
	var mo := (load("res://assets/sprites/morgana/morgana_frames.tres") as SpriteFrames).get_frame_texture(&"idle", 0).get_image()
	assert_true(_has(mo, PaletteColors.DUSK) and _has(mo, PaletteColors.YELLOW), "摩根娜:紫斗篷與新月法杖")
	# 石像鬼變成石頭時眼睛不再發紫光
	var stone := (load("res://assets/sprites/gargoyle/gargoyle_frames.tres") as SpriteFrames).get_frame_texture(&"stone", 0).get_image()
	assert_false(_has(stone, PaletteColors.VIOLET), "石像:眼睛不發光")
	var awake := (load("res://assets/sprites/gargoyle/gargoyle_frames.tres") as SpriteFrames).get_frame_texture(&"idle", 0).get_image()
	assert_true(_has(awake, PaletteColors.VIOLET), "石像鬼:紫色眼睛")


func test_one_shot_animations_stay_short() -> void:
	# A 線等 animation_finished;一次性的動作不要比佔位版長太多
	for pair in [["gargoyle", &"attack"], ["spellbook", &"cast"], ["foxfire", &"burst"], ["shadow_wolf", &"down"],
			["green_knight", &"whip"], ["green_knight", &"hat_off"], ["morgana", &"teleport"], ["lancelot", &"attack"]]:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [pair[0], pair[0]]) as SpriteFrames
		assert_false(frames.get_animation_loop(pair[1]), "%s.%s 只播一次" % pair)
		var total := 0.0
		for i in frames.get_frame_count(pair[1]):
			total += frames.get_frame_duration(pair[1], i) / frames.get_animation_speed(pair[1])
		assert_true(total <= 1.2, "%s.%s 長 %.2f 秒" % [pair[0], pair[1], total])


func test_portraits_are_opaque_48px() -> void:
	for speaker: String in PORTRAITS:
		for expr: String in PORTRAITS[speaker]:
			var tex := load("res://assets/portraits/%s/%s.png" % [speaker, expr]) as Texture2D
			assert_eq(tex.get_size(), Vector2(48, 48))
			assert_eq(tex.get_image().get_pixel(0, 0).a, 1.0, "%s/%s 不透明" % [speaker, expr])


func test_projectiles_have_their_own_art() -> void:
	for fx in PROJECTILES:
		var path := "res://assets/fx/%s/%s_frames.tres" % [fx, fx]
		var frames := load(path) as SpriteFrames
		assert_true(frames.has_animation(&"default") and frames.get_animation_loop(&"default"), "%s 循環播放" % fx)
		var tex := frames.get_frame_texture(&"default", 0) as AtlasTexture
		assert_eq(tex.atlas.resource_path, "res://assets/fx/%s/%s.png" % [fx, fx], "%s 不再借用箭的圖" % fx)


func test_particle_scenes_follow_the_pattern() -> void:
	for p in PARTICLES:
		var node := (load("res://assets/fx/particles/%s.tscn" % p) as PackedScene).instantiate()
		assert_true(node is CPUParticles2D, "%s 是 CPUParticles2D" % p)
		var cpu := node as CPUParticles2D
		assert_true(cpu.one_shot and cpu.texture != null and cpu.get_script() != null, "%s 一次性、有圖、會自己刪除" % p)
		assert_true(cpu.amount <= 16, "%s 粒子不多" % p)
		node.free()


func test_black_knight_stands_8px_higher() -> void:
	var frames := load("res://assets/sprites/black_knight/black_knight_frames.tres") as SpriteFrames
	assert_eq(frames.get_meta(&"foot_lift", 0), 8, "影子可以讀到腳底上移了 8 像素")
	# 衝鋒時劍是橫的,最低的不透明像素就是腳底的描邊:在第 55 列(以前是 63)
	for i in frames.get_frame_count(&"charge"):
		assert_eq(_lowest_row(frames.get_frame_texture(&"charge", i)), 55, "charge 第 %d 格的腳底" % i)
	for i in frames.get_frame_count(&"run"):
		assert_true(_lowest_row(frames.get_frame_texture(&"run", i)) <= 56, "run 第 %d 格" % i)


func _has(img: Image, col: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and p.to_html(false) == col.to_html(false):
				return true
	return false


func test_green_knight_has_bare_phase_two() -> void:
	# 葉子帽掉了以後(第二階段)A 線改播 <動畫>_bare:格數、速度、循環與戴帽版一樣,頭上沒有帽子與紫荊棘
	var frames := load("res://assets/sprites/green_knight/green_knight_frames.tres") as SpriteFrames
	for anim: StringName in [&"idle", &"run", &"attack", &"hurt", &"whip", &"summon"]:
		var bare := StringName(String(anim) + "_bare")
		assert_true(frames.has_animation(bare), "綠騎士有 %s" % bare)
		if not frames.has_animation(bare):
			continue
		assert_eq(frames.get_frame_count(bare), frames.get_frame_count(anim), "%s 的格數" % bare)
		assert_eq(frames.get_animation_speed(bare), frames.get_animation_speed(anim), "%s 的速度" % bare)
		assert_eq(frames.get_animation_loop(bare), frames.get_animation_loop(anim), "%s 的循環" % bare)
		assert_false(_has(frames.get_frame_texture(bare, 0).get_image(), PaletteColors.VIOLET), "%s 沒有紫荊棘" % bare)
