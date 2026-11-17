extends TestCase
## 背景音樂與粒子特效(CP3、CP6、CP10)。

const LOOPS: Array[StringName] = [&"title", &"field", &"boss", &"camp", &"story", &"field_2", &"boss_2", &"field_3", &"boss_3"]
const JINGLES: Array[StringName] = [&"victory", &"fail", &"chapter_clear"]
const PARTICLES: Array[String] = ["hit_burst", "straw_bits", "feathers", "confetti", "level_up_pillar", "shockwave",
		"sparkle", "ultimate_burst", "footstep_dust", "heart", "star_burst"]

var _music_before: bool


func before_each() -> void:
	_music_before = GameState.music_on


func after_each() -> void:
	GameState.music_on = _music_before
	Music.set_ducked(false)
	Music.stop(0.0)


func test_every_track_exists_loops_and_is_qoa() -> void:
	var total_bytes := 0
	for id in LOOPS + JINGLES:
		var path := "res://assets/music/%s.wav" % id
		assert_true(ResourceLoader.exists(path), path)
		var s := load(path) as AudioStreamWAV
		assert_not_null(s, path)
		if s == null:
			continue
		assert_true(Music.has_track(id))
		assert_eq(s.format, AudioStreamWAV.FORMAT_QOA, "%s 用 QOA 壓縮匯入" % id)
		total_bytes += s.data.size()
		if LOOPS.has(id):
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s 無縫循環" % id)
			assert_true(s.get_length() >= 20.0, "%s 夠長,不會很快重複(%.1f 秒)" % [id, s.get_length()])
		else:
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s 只播一次" % id)
			assert_true(s.get_length() <= 12.0, "%s 是短曲" % id)
	for id in Sfx.IDS:
		var sfx := load("res://assets/sfx/%s.wav" % id) as AudioStreamWAV
		if sfx != null:
			total_bytes += sfx.data.size()
	assert_true(total_bytes <= 8 * 1024 * 1024, "匯入後的音樂與音效合計 %.2f MB(不超過 8 MB)" % (total_bytes / 1048576.0))


func test_music_respects_switch_and_ducks() -> void:
	GameState.music_on = true
	Music.play(&"field", 0.0)
	assert_true(Music.is_playing())
	assert_eq(Music.playing_track(), &"field")
	Music.set_ducked(true)
	assert_true(Music.is_ducked())
	Music.set_ducked(false)
	GameState.music_on = false
	Music.refresh()
	assert_false(Music.is_playing(), "關掉音樂就停")
	Music.play(&"boss", 0.0)
	assert_false(Music.is_playing(), "關著時不播")
	GameState.music_on = true
	Music.refresh()
	assert_true(Music.is_playing(), "打開後接著播剛才要求的曲子")
	assert_eq(Music.playing_track(), &"boss")


func test_jingle_does_not_resume_after_toggle() -> void:
	GameState.music_on = true
	Music.play(&"victory")
	assert_eq(Music.playing_track(), &"victory")
	GameState.music_on = false
	Music.refresh()
	GameState.music_on = true
	Music.refresh()
	assert_false(Music.is_playing(), "短曲不會因為開關而重播")


func test_particles_are_small_crisp_and_one_shot() -> void:
	for n in PARTICLES:
		var p := (load("res://assets/fx/particles/%s.tscn" % n) as PackedScene).instantiate() as CPUParticles2D
		assert_not_null(p.texture, "%s 用像素圖(不是模糊圓點)" % n)
		if p.texture != null:
			assert_true(p.texture.get_width() <= 6 and p.texture.get_height() <= 6, "%s 的粒子很小" % n)
		assert_true(p.one_shot, "%s 只噴一次" % n)
		assert_true(p.amount <= 40, "%s 數量節制(%d)" % [n, p.amount])
		assert_true(p.lifetime <= 2.0, "%s 很快結束" % n)
		p.free()


func test_sprite_fx_centered_with_default_animation() -> void:
	var orb := load("res://assets/fx/exp_orb/exp_orb_frames.tres") as SpriteFrames
	assert_true(orb.get_frame_count(&"default") >= 4, "經驗珠閃爍")
	assert_true(orb.get_animation_loop(&"default"))
	var slash := load("res://assets/fx/slash/slash_frames.tres") as SpriteFrames
	assert_false(slash.get_animation_loop(&"default"), "刀光播一次")
