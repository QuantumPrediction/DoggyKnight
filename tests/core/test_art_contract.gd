extends TestCase
## 美術合約(DEV_PLAN 4.6):路徑、動畫名稱、格子大小。
## C 線原地替換正式美術後,這個測試必須仍然通過。

const BASE_ANIMS: Array[StringName] = [&"idle", &"run", &"attack", &"hurt"]

## 代號:[額外動畫, 最小格子, 最大格子](格子大小依 DEV_PLAN 2 與 C2 至 C5)
const CHARACTERS: Dictionary = {
	"goldie": [[&"sleep"], 24, 24],
	"bulldog": [[&"guard"], 24, 24],
	"scarecrow": [[], 16, 24],
	"crow": [[], 16, 24],
	"black_knight": [[&"charge", &"slam", &"down"], 48, 64],
}


func test_every_character_has_sheet_and_frames() -> void:
	for id: String in CHARACTERS:
		var png := "res://assets/sprites/%s/%s.png" % [id, id]
		var frames_path := "res://assets/sprites/%s/%s_frames.tres" % [id, id]
		assert_true(ResourceLoader.exists(png), png)
		var frames := load(frames_path) as SpriteFrames
		assert_not_null(frames, frames_path)


func test_required_animations_exist_and_have_frames() -> void:
	for id: String in CHARACTERS:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [id, id]) as SpriteFrames
		if frames == null:
			continue
		var required: Array = BASE_ANIMS.duplicate()
		required.append_array(CHARACTERS[id][0])
		for anim: StringName in required:
			assert_true(frames.has_animation(anim), "%s 缺少動畫 %s" % [id, anim])
			if frames.has_animation(anim):
				assert_true(frames.get_frame_count(anim) > 0, "%s.%s 沒有任何格" % [id, anim])


func test_frame_sizes_follow_the_grid() -> void:
	for id: String in CHARACTERS:
		var frames := load("res://assets/sprites/%s/%s_frames.tres" % [id, id]) as SpriteFrames
		if frames == null or not frames.has_animation(&"idle"):
			continue
		var size := frames.get_frame_texture(&"idle", 0).get_size()
		var min_size: int = CHARACTERS[id][1]
		var max_size: int = CHARACTERS[id][2]
		assert_true(size.x >= min_size and size.x <= max_size and size.y >= min_size and size.y <= max_size,
				"%s 的格子大小 %s 應在 %d 至 %d 之間" % [id, size, min_size, max_size])


const FX: Array[String] = ["slash", "hit_spark", "exp_orb", "ultimate_slash", "dizzy_stars", "dust"]
const BACKGROUNDS: Array[String] = ["meadow", "sword_stone", "bridge"]


func test_fx_frames_have_default_animation() -> void:
	for fx_name in FX:
		var path := "res://assets/fx/%s/%s_frames.tres" % [fx_name, fx_name]
		var frames := load(path) as SpriteFrames
		assert_not_null(frames, path)
		if frames != null:
			assert_true(frames.has_animation(&"default") and frames.get_frame_count(&"default") > 0, "%s 的 default 動畫" % fx_name)


func test_backgrounds_are_node2d_scenes() -> void:
	for bg in BACKGROUNDS:
		var path := "res://assets/backgrounds/%s.tscn" % bg
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene != null:
			var node := scene.instantiate()
			assert_true(node is Node2D, "%s 的根節點是 Node2D" % bg)
			node.free()


func test_sfx_api() -> void:
	assert_true(Sfx.has_method(&"play"), "Sfx.play(id)")
	Sfx.play(&"swing")       # 沒有音效檔時要安靜略過,不可出錯
	Sfx.play(&"not_a_sound")


func test_trick_icons_exist() -> void:
	for trick in ["sit", "wag", "fetch", "shake", "spin", "bark"]:
		var path := "res://assets/icons/tricks/%s.png" % trick
		assert_true(ResourceLoader.exists(path), path)


const PARTICLES: Array[String] = ["hit_burst", "straw_bits", "feathers", "confetti", "level_up_pillar", "shockwave",
		"sparkle", "ultimate_burst", "footstep_dust", "heart", "star_burst"]
const V22_BACKGROUNDS: Array[String] = ["wheat_field", "farm_fence", "crow_forest"]


func test_v22_particles_are_one_shot_cpu_particles() -> void:
	for fx_name in PARTICLES:
		var path := "res://assets/fx/particles/%s.tscn" % fx_name
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene != null:
			var node := scene.instantiate()
			assert_true(node is CPUParticles2D, "%s 的根節點是 CPUParticles2D" % fx_name)
			node.free()


func test_v22_backgrounds_exist() -> void:
	for bg in V22_BACKGROUNDS:
		var scene := load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene
		assert_not_null(scene, bg)


func test_particle_frees_itself_after_playing() -> void:
	var fx := (load("res://assets/fx/particles/hit_burst.tscn") as PackedScene).instantiate() as CPUParticles2D
	add_child(fx)
	assert_true(fx.emitting)
	var waited := 0
	while is_instance_valid(fx) and waited < 240:
		await get_tree().process_frame
		waited += 1
	assert_false(is_instance_valid(fx), "一次性特效播完自己刪除")


func test_music_and_transition_api() -> void:
	for method in [&"play", &"stop", &"set_ducked", &"refresh"]:
		assert_true(Music.has_method(method), "Music.%s" % method)
	Music.play(&"no_such_track")     # 沒有檔案時安靜略過
	Music.stop(0.0)
	var transition := (load("res://ui/transition/transition.tscn") as PackedScene).instantiate()
	assert_true(transition is CanvasLayer, "轉場的根節點是 CanvasLayer")
	add_child(transition)
	await transition.cover(0.01)
	assert_true(transition.is_covered())
	await transition.reveal(0.01)
	assert_false(transition.is_covered())
	transition.queue_free()
