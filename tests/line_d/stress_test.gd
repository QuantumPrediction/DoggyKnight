extends Node2D
## 效能壓力測試(DEV_PLAN 2、11 D9):場上 40 個會動的敵人,畫面左上角顯示 FPS。
##
## - 有 A 線的 res://game/combat/arena.tscn 與 res://data/enemies/scarecrow.tres 時,
##   用正式的場地與稻草人兵(arena.spawn_enemy)。
## - 沒有的話,用 tests/line_d/stress_enemy.gd 的替身敵人(CharacterBody2D + 稻草人兵動畫),
##   追著一個繞圈走的替身主角,彼此碰撞推開。
##
## 每 2 秒在標準輸出印一行數字;跑滿 bench_seconds 後印出總結。
## 注意:雲端環境的 Xvfb + llvmpipe 是「軟體算繪」,數字只能看出 CPU 端(腳本、物理)的負擔,
## 不能代表手機。手機上的數字要在實機上量(用「Android Sandbox」匯出設定裝到手機)。
##
## 用法:
##   godot --path . res://tests/line_d/stress_test.tscn
##   godot --path . res://tests/line_d/stress_test.tscn -- --bench-seconds=20 --quit-when-done

const ARENA_PATH: String = "res://game/combat/arena.tscn"
const ENEMY_DATA_PATH: String = "res://data/enemies/scarecrow.tres"
const BACKGROUND_PATH: String = "res://assets/backgrounds/meadow.tscn"
const STAND_IN_ENEMY: Script = preload("res://tests/line_d/stress_enemy.gd")

@export var enemy_count: int = 40
@export var bench_seconds: float = 10.0

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


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-seconds="):
			bench_seconds = float(arg.trim_prefix("--bench-seconds="))
		elif arg == "--quit-when-done":
			_quit_when_done = true
	_build_world()
	_build_readout()
	print("[stress] enemies=%d real_arena=%s renderer=%s display=%s video_adapter=%s" % [
		get_tree().get_nodes_in_group(&"enemy").size(), using_real_arena,
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name()])


func _process(delta: float) -> void:
	_elapsed += delta
	if _player != null and not using_real_arena:
		var t := _elapsed * 0.6
		_player.position = Layout.ARENA_RECT.get_center() + Vector2(cos(t) * 60.0, sin(t * 1.3) * 80.0)
	var fps := Engine.get_frames_per_second()
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if _elapsed > 1.0 and not _done:
		_fps_samples.append(fps)
		_frame_ms.append(delta * 1000.0)
		_process_ms.append(process_ms)
		_physics_ms.append(physics_ms)
	var count := get_tree().get_nodes_in_group(&"enemy").size()
	_label.text = "FPS %d  enemies %d\nprocess %.2f ms  physics %.2f ms\n%s" % [
		fps, count, process_ms, physics_ms, "real arena" if using_real_arena else "stand-in enemies"]
	_report_timer += delta
	if _report_timer >= 2.0:
		_report_timer = 0.0
		print("[stress] t=%.0fs fps=%d enemies=%d process=%.2fms physics=%.2fms" % [_elapsed, fps, count, process_ms, physics_ms])
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
	print("[stress] SUMMARY enemies=%d seconds=%.0f avg_fps=%.1f min_fps=%.0f avg_frame=%.2fms p99_frame=%.2fms avg_process=%.2fms avg_physics=%.2fms" % [
		count, bench_seconds, _avg(_fps_samples), fps_sorted[0], _avg(_frame_ms),
		ms_sorted[mini(ms_sorted.size() - 1, int(ms_sorted.size() * 0.99))], _avg(_process_ms), _avg(_physics_ms)])


static func _avg(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(1.0, values.size())


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
				_arena.call(&"spawn_enemy", &"scarecrow", _random_point(i))
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
		var enemy := CharacterBody2D.new()
		enemy.set_script(STAND_IN_ENEMY)
		enemy.set(&"target", _player)
		enemy.position = _random_point(i)
		add_child(enemy)


func _random_point(i: int) -> Vector2:
	var r := Layout.ARENA_RECT.grow(-10)
	var cols := 8
	@warning_ignore("integer_division")
	var row := i / cols
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
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 2)
	var safe := SafeArea.get_safe_rect()
	_label.position = safe.position + Vector2(4, 4)
	layer.add_child(_label)
