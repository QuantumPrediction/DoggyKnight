extends Node2D
## 效能壓力測試(DEV_PLAN 2、11 D9、15 DP4):場上一直保持 40 個會動的敵人,加上激烈戰鬥時的粒子特效,
## 畫面左上角顯示 FPS。
##
## - 有 A 線的 res://game/combat/arena.tscn 與 res://data/enemies/scarecrow.tres 時,
##   用正式的場地、主角與稻草人兵(arena.spawn_enemy);敵人被打倒後立刻補回 40 隻。
## - 沒有的話,用 tests/line_d/stress_enemy.gd 的替身敵人(CharacterBody2D + 稻草人兵動畫),
##   追著一個繞圈走的替身主角,彼此碰撞推開。
##
## 特效(DP4,預設開啟):模擬比真實戰鬥更激烈的情況——
## 每秒 hit_burst 命中 FX_HITS_PER_SEC 次、打倒 FX_KILLS_PER_SEC 隻(straw_bits / feathers)、
## 金毛跑步的 footstep_dust、拾取的 sparkle,以及定時的 shockwave、level_up_pillar、ultimate_burst、confetti。
## 每種特效「同時存在」的數量有上限(FX_CAPS,建議值,給 A、B、C 線參考);超過上限的就略過不放。
##
## 每 2 秒在標準輸出印一行數字;跑滿 bench_seconds 後印出總結(含特效統計)。
## 注意:雲端環境沒有 GPU。無畫面(headless)時量到的是 CPU 端(腳本、物理、粒子模擬)的負擔;
## Xvfb + llvmpipe 是軟體算繪,不能代表手機。手機上的數字要在實機上量(用「Android Sandbox」匯出設定裝到手機)。
##
## 用法:
##   godot --path . res://tests/line_d/stress_test.tscn
##   godot --headless --path . res://tests/line_d/stress_test.tscn -- --bench-seconds=20 --quit-when-done
## 參數:--no-fx(不放特效,對照用)、--no-caps(特效不設上限,看最壞情況)、--uncapped-fps(不鎖 60,看餘裕)

const ARENA_PATH: String = "res://game/combat/arena.tscn"
const ENEMY_DATA_PATH: String = "res://data/enemies/scarecrow.tres"
const BACKGROUND_PATH: String = "res://assets/backgrounds/meadow.tscn"
const STAND_IN_ENEMY: Script = preload("res://tests/line_d/stress_enemy.gd")
const FX_DIR: String = "res://assets/fx/particles/"

## 建議的同時存在上限(每種特效)。數量以 C 線現在的粒子數計算;C 線加大粒子數時,上限要相應調低。
const FX_CAPS: Dictionary = {
	&"hit_burst": 8, &"straw_bits": 6, &"feathers": 6, &"footstep_dust": 4, &"sparkle": 6,
	&"heart": 4, &"star_burst": 3, &"shockwave": 2, &"level_up_pillar": 1, &"ultimate_burst": 1, &"confetti": 1,
}
## 每秒觸發的次數(比真實戰鬥更激烈)。
const FX_HITS_PER_SEC: float = 10.0
const FX_KILLS_PER_SEC: float = 4.0
const FX_DUST_EVERY: float = 0.12
const FX_SPARKLES_PER_SEC: float = 3.0
## 定時的大特效:[名稱, 每幾秒一次]
const FX_TIMED: Array = [[&"shockwave", 4.0], [&"level_up_pillar", 6.0], [&"ultimate_burst", 8.0], [&"confetti", 10.0], [&"star_burst", 3.0], [&"heart", 2.5]]

@export var enemy_count: int = 40
@export var bench_seconds: float = 10.0
@export var with_fx: bool = true
@export var with_caps: bool = true

var using_real_arena: bool = false
var _arena: Node
var _player: Node2D
var _label: Label
var _elapsed: float = 0.0
var _report_timer: float = 0.0
var _fps_samples: PackedFloat32Array = []
var _frame_ms: PackedFloat32Array = []
var _process_ms: PackedFloat32Array = []
var _physics_ms: PackedFloat32Array = []
var _done: bool = false
var _quit_when_done: bool = false
var _rng := RandomNumberGenerator.new()

var _fx_layer: Node2D
var _fx_scenes: Dictionary = {}
var _fx_spawned: Dictionary = {}
var _fx_skipped: Dictionary = {}
var _fx_peak_alive: int = 0
var _fx_peak_particles: int = 0
var _fx_timers: Dictionary = {}
var _hit_accum: float = 0.0
var _kill_accum: float = 0.0
var _sparkle_accum: float = 0.0
var _dust_timer: float = 0.0
var _respawned: int = 0
var _spawn_index: int = 0


func _ready() -> void:
	_rng.seed = 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-seconds="):
			bench_seconds = float(arg.trim_prefix("--bench-seconds="))
		elif arg == "--quit-when-done":
			_quit_when_done = true
		elif arg == "--no-fx":
			with_fx = false
		elif arg == "--no-caps":
			with_caps = false
		elif arg == "--uncapped-fps":
			Engine.max_fps = 0
	_build_world()
	_load_fx()
	_build_readout()
	if using_real_arena:
		EventBus.enemy_died.connect(_on_enemy_died)
	print("[stress] enemies=%d real_arena=%s fx=%s caps=%s renderer=%s display=%s video_adapter=%s max_fps=%d" % [
		get_tree().get_nodes_in_group(&"enemy").size(), using_real_arena, with_fx, with_caps,
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name(), Engine.max_fps])


func _process(delta: float) -> void:
	_elapsed += delta
	if _player != null and not using_real_arena:
		var t := _elapsed * 0.6
		_player.position = Layout.ARENA_RECT.get_center() + Vector2(cos(t) * 60.0, sin(t * 1.3) * 80.0)
	_keep_enemy_count()
	if with_fx:
		_run_fx(delta)
	var fps := Engine.get_frames_per_second()
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if _elapsed > 1.0 and not _done:
		_fps_samples.append(fps)
		_frame_ms.append(delta * 1000.0)
		_process_ms.append(process_ms)
		_physics_ms.append(physics_ms)
	var count := get_tree().get_nodes_in_group(&"enemy").size()
	var alive := _fx_layer.get_child_count() if _fx_layer != null else 0
	_label.text = "FPS %d  enemies %d  fx %d\nprocess %.2f ms  physics %.2f ms\n%s" % [
		fps, count, alive, process_ms, physics_ms, "real arena" if using_real_arena else "stand-in enemies"]
	_report_timer += delta
	if _report_timer >= 2.0:
		_report_timer = 0.0
		print("[stress] t=%.0fs fps=%d enemies=%d fx_alive=%d particles=%d process=%.2fms physics=%.2fms" % [
			_elapsed, fps, count, alive, _particles_alive(), process_ms, physics_ms])
	if not _done and _elapsed >= bench_seconds + 1.0:
		_done = true
		_print_summary(count)
		if _quit_when_done:
			get_tree().quit()


func _print_summary(count: int) -> void:
	if _fps_samples.is_empty():
		return
	var fps_sorted := _fps_samples.duplicate()
	fps_sorted.sort()
	var ms_sorted := _frame_ms.duplicate()
	ms_sorted.sort()
	var cpu := PackedFloat32Array()
	for i in _process_ms.size():
		cpu.append(_process_ms[i] + _physics_ms[i])
	cpu.sort()
	print("[stress] SUMMARY enemies=%d seconds=%.0f fx=%s caps=%s avg_fps=%.1f min_fps=%.0f avg_frame=%.2fms p99_frame=%.2fms avg_process=%.2fms avg_physics=%.2fms p99_cpu=%.2fms respawned=%d" % [
		count, bench_seconds, with_fx, with_caps, _avg(_fps_samples), fps_sorted[0], _avg(_frame_ms),
		ms_sorted[mini(ms_sorted.size() - 1, int(ms_sorted.size() * 0.99))], _avg(_process_ms), _avg(_physics_ms),
		cpu[mini(cpu.size() - 1, int(cpu.size() * 0.99))], _respawned])
	if with_fx:
		var parts := PackedStringArray()
		for fx_name: StringName in FX_CAPS:
			parts.append("%s=%d/%d" % [fx_name, int(_fx_spawned.get(fx_name, 0)), int(_fx_skipped.get(fx_name, 0))])
		print("[stress] FX spawned/skipped: %s" % ", ".join(parts))
		print("[stress] FX peak_alive=%d peak_particles=%d" % [_fx_peak_alive, _fx_peak_particles])


static func _avg(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(1.0, values.size())


# --- 敵人 ---

func _keep_enemy_count() -> void:
	var count := get_tree().get_nodes_in_group(&"enemy").size()
	while count < enemy_count:
		_spawn_enemy(_random_point(_spawn_index))
		_spawn_index += 1
		_respawned += 1
		count += 1


func _spawn_enemy(at: Vector2) -> void:
	if using_real_arena:
		_arena.call(&"spawn_enemy", &"scarecrow" if _rng.randf() < 0.7 else &"crow", at)
		return
	var enemy := CharacterBody2D.new()
	enemy.set_script(STAND_IN_ENEMY)
	enemy.set(&"target", _player)
	enemy.position = at
	add_child(enemy)


func _on_enemy_died(enemy_id: StringName, at: Vector2, _exp_value: int) -> void:
	if not with_fx:
		return
	spawn_fx(&"hit_burst", at)
	spawn_fx(&"feathers" if enemy_id == &"crow" else &"straw_bits", at)


# --- 特效 ---

func _load_fx() -> void:
	_fx_layer = Node2D.new()
	_fx_layer.name = "Fx"
	_fx_layer.z_index = 5
	add_child(_fx_layer)
	for fx_name: StringName in FX_CAPS:
		var path := FX_DIR + String(fx_name) + ".tscn"
		if ResourceLoader.exists(path):
			_fx_scenes[fx_name] = load(path)
	for entry: Array in FX_TIMED:
		_fx_timers[entry[0]] = float(entry[1]) * 0.5


## 放一個特效;同種特效已達上限時略過(傳回 false)。
func spawn_fx(fx_name: StringName, at: Vector2) -> bool:
	var scene: PackedScene = _fx_scenes.get(fx_name)
	if scene == null:
		return false
	var group := StringName("stress_fx_%s" % fx_name)
	if with_caps and get_tree().get_node_count_in_group(group) >= int(FX_CAPS.get(fx_name, 99)):
		_fx_skipped[fx_name] = int(_fx_skipped.get(fx_name, 0)) + 1
		return false
	var fx := scene.instantiate()
	fx.add_to_group(group)
	if fx is Node2D:
		(fx as Node2D).position = at
	_fx_layer.add_child(fx)
	_fx_spawned[fx_name] = int(_fx_spawned.get(fx_name, 0)) + 1
	return true


func _run_fx(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	_hit_accum += delta * FX_HITS_PER_SEC
	while _hit_accum >= 1.0:
		_hit_accum -= 1.0
		if not enemies.is_empty():
			spawn_fx(&"hit_burst", (enemies[_rng.randi() % enemies.size()] as Node2D).global_position)
	if not using_real_arena:
		# 替身敵人不會真的死:每秒打倒幾隻(噴稻草或羽毛),然後補回來。
		_kill_accum += delta * FX_KILLS_PER_SEC
		while _kill_accum >= 1.0 and not enemies.is_empty():
			_kill_accum -= 1.0
			var victim := enemies[_rng.randi() % enemies.size()] as Node2D
			var at := victim.global_position
			victim.remove_from_group(&"enemy")
			victim.queue_free()
			enemies.erase(victim)
			spawn_fx(&"hit_burst", at)
			spawn_fx(&"feathers" if _rng.randf() < 0.3 else &"straw_bits", at)
	var hero := _hero_position()
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = FX_DUST_EVERY
		spawn_fx(&"footstep_dust", hero + Vector2(0, 8))
	_sparkle_accum += delta * FX_SPARKLES_PER_SEC
	while _sparkle_accum >= 1.0:
		_sparkle_accum -= 1.0
		spawn_fx(&"sparkle", hero + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 4)))
	for fx_name: StringName in _fx_timers:
		_fx_timers[fx_name] = float(_fx_timers[fx_name]) - delta
		if float(_fx_timers[fx_name]) <= 0.0:
			for entry: Array in FX_TIMED:
				if entry[0] == fx_name:
					_fx_timers[fx_name] = float(entry[1])
			spawn_fx(fx_name, hero)
	var alive := _fx_layer.get_child_count()
	_fx_peak_alive = maxi(_fx_peak_alive, alive)
	_fx_peak_particles = maxi(_fx_peak_particles, _particles_alive())


func _particles_alive() -> int:
	if _fx_layer == null:
		return 0
	var total := 0
	for fx in _fx_layer.get_children():
		var p := fx as CPUParticles2D
		if p != null:
			total += p.amount
	return total


func _hero_position() -> Vector2:
	if using_real_arena and _arena.has_method(&"get_player"):
		var p := _arena.call(&"get_player") as Node2D
		if p != null:
			return p.global_position
	if _player != null:
		return _player.global_position
	return Layout.PLAYER_START


# --- 場地 ---

func _build_world() -> void:
	var camera := Camera2D.new()
	camera.position = SafeArea.GAME_CENTER
	add_child(camera)
	camera.make_current()

	if ResourceLoader.exists(ARENA_PATH) and ResourceLoader.exists(ENEMY_DATA_PATH):
		var arena_scene := load(ARENA_PATH) as PackedScene
		_arena = arena_scene.instantiate()
		add_child(_arena)
		if _arena.has_method(&"spawn_enemy"):
			using_real_arena = true
			for i in enemy_count:
				_spawn_enemy(_random_point(i))
			_spawn_index = enemy_count
			return
		_arena.queue_free()
		_arena = null

	if ResourceLoader.exists(BACKGROUND_PATH):
		var bg := (load(BACKGROUND_PATH) as PackedScene).instantiate()
		bg.z_index = -10
		add_child(bg)
	_add_walls()
	_player = Node2D.new()
	_player.name = "StandInPlayer"
	_player.position = Layout.PLAYER_START
	_player.draw.connect(func() -> void: _player.draw_circle(Vector2.ZERO, 6.0, Color("ffd34d")))
	add_child(_player)
	for i in enemy_count:
		_spawn_enemy(_random_point(i))
	_spawn_index = enemy_count


func _random_point(i: int) -> Vector2:
	var r := Layout.ARENA_RECT.grow(-10)
	var cols := 8
	@warning_ignore("integer_division")
	var row := (i / cols) % 6
	return r.position + Vector2((i % cols + 0.5) * r.size.x / cols, (row + 0.5) * r.size.y / 6.0)


func _add_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = Layers.ARENA
	walls.collision_mask = 0
	var r := Layout.ARENA_RECT
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var shape := SegmentShape2D.new()
		shape.a = corners[i]
		shape.b = corners[(i + 1) % 4]
		var col := CollisionShape2D.new()
		col.shape = shape
		walls.add_child(col)
	add_child(walls)


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 12)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 2)
	var safe := SafeArea.get_safe_rect()
	_label.position = safe.position + Vector2(4, 4)
	layer.add_child(_label)
