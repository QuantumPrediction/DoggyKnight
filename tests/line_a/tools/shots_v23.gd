extends Node
## A 線 v2.3 的截圖工具(不是測試):把新敵人與新招式的關鍵時刻拍成「格子圖」(frame sheet),
## 方便檢查預警是否清楚、投射物看不看得見、倒下演出好不好看。
##
## 執行(需要畫面;雲端環境用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_a/tools/shots_v23.tscn -- --out=/tmp/line_a_shots
## 產生:archer_aim_shot.png、archer_blocked.png、husk_dash.png、husk_death.png、captain_sweep.png、
##       captain_rally.png、captain_throw.png、captain_defeat.png、knight_wave.png、knight_husks.png、
##       overview_*.png(整個畫面)。

const ARENA_SCENE: PackedScene = preload("res://game/combat/arena.tscn")
const SCALE := 3
const GAP := 2

var out_dir: String = "/tmp/line_a_shots"
var arena: CombatArena
var player: GoldiePlayer
var _frames: Array[Image] = []
var _crop: Rect2i = Rect2i(0, 60, 180, 240)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	await _frames_wait(10)
	await _archer_aim_shot()
	await _archer_blocked()
	await _husk_dash()
	await _husk_death()
	await _captain_sweep()
	await _captain_rally()
	await _captain_throw()
	await _captain_defeat()
	await _knight_wave()
	await _knight_husks()
	print("SHOTS DONE -> ", out_dir)
	get_tree().quit(0)


# --- 場景 -----------------------------------------------------------------------

func _new_arena() -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
		await _frames_wait(2)
	GameState.reset_run()
	arena = ARENA_SCENE.instantiate() as CombatArena
	arena.spawn_telegraph_time = 0.0
	add_child(arena)
	player = arena.get_player() as GoldiePlayer
	player.set_physics_process(false)
	_frames.clear()
	await _frames_wait(3)


func _archer_aim_shot() -> void:
	await _new_arena()
	_crop = Rect2i(30, 110, 120, 150)
	var archer := arena.spawn_enemy(&"scarecrow_archer", player.global_position + Vector2(-20, -85)) as ArcherEnemy
	archer._cooldown_left = 0.3
	await _until(func() -> bool: return archer.phase == ArcherEnemy.Phase.AIM, 120)
	await _snap()
	await _frames_wait(14)
	await _snap()
	await _until(func() -> bool: return archer.phase == ArcherEnemy.Phase.RELEASE, 60)
	await _snap()
	await _frames_wait(12)
	await _snap()
	await _frames_wait(14)
	await _snap()
	await _until(func() -> bool: return arena.get_projectiles().is_empty() or player.invuln_left > 0.0, 60)
	await _snap()
	_save_sheet("archer_aim_shot")
	await _overview("overview_archer")


func _archer_blocked() -> void:
	await _new_arena()
	_crop = Rect2i(20, 100, 140, 160)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	dog.global_position = player.global_position + Vector2(0, -26)
	var archer := arena.spawn_enemy(&"scarecrow_archer", player.global_position + Vector2(0, -95)) as ArcherEnemy
	var dummy := arena.spawn_enemy(&"scarecrow", dog.global_position + Vector2(14, -10)) as EnemyBase
	dummy.set_physics_process(false)
	archer.target = player
	await _until(func() -> bool: return dog.is_taunting(), 120)
	dog.set_physics_process(false)
	archer.set_physics_process(false)
	archer.target = player
	archer._start_aim()
	archer.set_physics_process(true)
	archer.retarget_interval = 99.0
	await _snap()
	await _until(func() -> bool: return archer.phase == ArcherEnemy.Phase.RELEASE, 60)
	await _frames_wait(8)
	await _snap()
	await _until(func() -> bool: return dog.blocks > 0, 90)
	await _snap()
	await _frames_wait(6)
	await _snap()
	await _frames_wait(10)
	await _snap()
	_save_sheet("archer_blocked")


func _husk_dash() -> void:
	await _new_arena()
	_crop = Rect2i(40, 140, 100, 120)
	var husk := arena.spawn_enemy(&"armored_husk", player.global_position + Vector2(-8, -48)) as HuskEnemy
	husk._cooldown_left = 0.2
	await _until(func() -> bool: return husk.phase == HuskEnemy.Phase.TELEGRAPH, 60)
	await _snap()
	await _frames_wait(18)
	await _snap()
	await _until(func() -> bool: return husk.phase == HuskEnemy.Phase.BASH, 60)
	await _frames_wait(4)
	await _snap()
	await _until(func() -> bool: return husk.phase == HuskEnemy.Phase.RECOVER, 60)
	await _snap()
	await _frames_wait(20)
	await _snap()
	_save_sheet("husk_dash")


func _husk_death() -> void:
	await _new_arena()
	_crop = Rect2i(45, 110, 90, 100)
	var husk := arena.spawn_enemy(&"armored_husk", Vector2(90, 170)) as HuskEnemy
	husk.set_physics_process(false)
	await _snap()
	husk.take_damage(999)
	for wait: int in [2, 8, 10, 14, 20, 30]:
		await _frames_wait(wait)
		await _snap()
	_save_sheet("husk_death")


func _captain_sweep() -> void:
	await _new_arena()
	_crop = Rect2i(30, 130, 120, 130)
	var captain := arena.spawn_enemy(&"scarecrow_captain", player.global_position + Vector2(-6, -34)) as CaptainBoss
	captain.target = player
	await _frames_wait(5)
	captain._start_sweep()
	await _snap()
	await _frames_wait(20)
	await _snap()
	await _until(func() -> bool: return captain.phase == CaptainBoss.Phase.SWEEP_RECOVER, 60)
	await _snap()
	await _frames_wait(8)
	await _snap()
	_save_sheet("captain_sweep")
	await _overview("overview_captain")


func _captain_rally() -> void:
	await _new_arena()
	_crop = Rect2i(20, 80, 140, 130)
	var captain := arena.spawn_enemy(&"scarecrow_captain", Vector2(90, 120)) as CaptainBoss
	captain.target = player
	captain.facing = Vector2.DOWN
	await _frames_wait(5)
	captain.set_physics_process(false)
	captain._start_rally()
	captain.set_physics_process(true)
	await _snap()
	await _frames_wait(30)
	await _snap()
	await _until(func() -> bool: return captain.phase == CaptainBoss.Phase.RALLY_RECOVER, 90)
	await _snap()
	await _frames_wait(20)
	await _snap()
	_save_sheet("captain_rally")


func _captain_throw() -> void:
	await _new_arena()
	_crop = Rect2i(10, 76, 160, 190)
	var captain := arena.spawn_enemy(&"scarecrow_captain", player.global_position + Vector2(-30, -110)) as CaptainBoss
	captain.target = player
	await _frames_wait(5)
	captain.set_physics_process(false)
	captain._start_throw()
	captain.set_physics_process(true)
	await _snap()
	await _frames_wait(25)
	await _snap()
	await _until(func() -> bool: return captain.phase == CaptainBoss.Phase.THROW_WAIT, 60)
	await _frames_wait(14)
	await _snap()
	await _frames_wait(30)
	await _snap()
	await _frames_wait(30)
	await _snap()
	await _until(func() -> bool: return captain.fork_in_hand, 200)
	await _snap()
	_save_sheet("captain_throw")


func _captain_defeat() -> void:
	await _new_arena()
	_crop = Rect2i(30, 70, 120, 140)
	var captain := arena.spawn_enemy(&"scarecrow_captain", Vector2(90, 140)) as CaptainBoss
	captain.target = player
	await _frames_wait(5)
	captain.take_damage(captain.max_hp / 2)
	await _frames_wait(12)
	await _snap()
	await _until(func() -> bool: return captain.phase != CaptainBoss.Phase.SHOUT, 90)
	captain._start_rally()
	captain._rally()
	await _frames_wait(30)
	captain.take_damage(9999)
	await _frames_wait(10)
	await _snap()
	await _until(func() -> bool: return not captain.is_in_group(&"enemy"), 120)
	await _frames_wait(3)
	await _snap()
	for wait: int in [25, 40, 60, 90]:
		await _frames_wait(wait)
		await _snap()
	_save_sheet("captain_defeat")


func _knight_wave() -> void:
	await _new_arena()
	_crop = Rect2i(0, 70, 180, 230)
	var boss := arena.spawn_enemy(&"black_knight", player.global_position + Vector2(-20, -110)) as BlackKnightBoss
	boss.target = player
	boss.take_damage(boss.max_hp / 2)
	await _until(func() -> bool: return boss.phase != BlackKnightBoss.Phase.ROAR, 90)
	boss.set_physics_process(false)
	boss._start_slam()
	boss._slam()
	boss.set_physics_process(true)
	await _frames_wait(3)
	await _snap()
	await _until(func() -> bool: return boss.phase == BlackKnightBoss.Phase.WAVE_TELL, 60)
	await _frames_wait(4)
	await _snap()
	await _frames_wait(20)
	await _snap()
	await _until(func() -> bool: return not arena.get_projectiles().is_empty(), 60)
	await _frames_wait(10)
	await _snap()
	await _frames_wait(25)
	await _snap()
	_save_sheet("knight_wave")
	await _overview("overview_knight_wave")


func _knight_husks() -> void:
	await _new_arena()
	_crop = Rect2i(10, 72, 160, 130)
	var boss := arena.spawn_enemy(&"black_knight", Vector2(90, 120)) as BlackKnightBoss
	boss.target = player
	boss.take_damage(boss.max_hp / 2)
	await _until(func() -> bool: return boss.phase != BlackKnightBoss.Phase.ROAR, 90)
	boss.set_physics_process(false)
	boss._start_summon()
	boss.set_physics_process(true)
	await _frames_wait(10)
	await _snap()
	await _until(func() -> bool: return boss.phase == BlackKnightBoss.Phase.SUMMON_RECOVER, 90)
	await _frames_wait(2)
	await _snap()
	await _frames_wait(30)
	await _snap()
	_save_sheet("knight_husks")


# --- 工具 -----------------------------------------------------------------------

func _snap() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var crop := _crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_frames.append(image.get_region(crop))


func _overview(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	image.save_png(out_dir.path_join(file_name + ".png"))


func _save_sheet(file_name: String) -> void:
	if _frames.is_empty():
		return
	var w := _frames[0].get_width()
	var h := _frames[0].get_height()
	var sheet := Image.create(_frames.size() * (w + GAP) - GAP, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in _frames.size():
		var frame := _frames[i]
		frame.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(i * (w + GAP), 0))
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", file_name, " (", _frames.size(), " frames)")
	_frames.clear()


func _frames_wait(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame
