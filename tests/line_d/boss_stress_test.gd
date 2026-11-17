extends Node2D
## v2.6 DV4:頭目戰的效能量測(DEV_PLAN 19)。模擬最重的頭目戰:摩根娜第三階段(66% 以下的鏡像分身 +
## 33% 以下的旋轉月光束)加上召喚的小怪與兩位同伴,量節點數與每格時間。
##
## 場上一直有(load = 1 時;--load=N 全部乘 N):
## - 頭目(摩根娜的圖,64 格):每 TELEPORT_EVERY 秒瞬間移動(目的地先亮月光圈 0.7 秒);
##   每 BOSS_FAN_EVERY 秒射出 BOSS_FAN 顆扇形月光球(moon_orb,帶光暈)。
## - 鏡像分身 CLONES 個(半透明紫色):每 CLONE_FAN_EVERY 秒射 CLONE_FAN 顆較弱的光球。
## - 狐火雨:每 FOX_RAIN_EVERY 秒 FOX_RAIN 個預警圈,0.6 秒後落下 fox_flame(有碰撞)。
## - 旋轉的月光束:每 BEAM_EVERY 秒先畫紅線預警 0.8 秒,再旋轉 BEAM_SEC 秒(有碰撞)。
## - 荊棘環(綠騎士的招式,混進來當最壞情況):每 THORN_EVERY 秒 THORNS 根放射。
## - 小怪(CharacterBody2D,彼此碰撞推開):狐火 FOXFIRES 隻追著金毛、影狼 WOLVES 隻在外圍繞圈、石像鬼 GARGOYLES 隻。
## - 金毛(繞圈走)、貝德維爾與蘭斯洛特跟在旁邊。
## - 特效:每秒 HITS_PER_SEC 次 hit_burst、SPARKLES_PER_SEC 次 sparkle(各有同時存在的上限)。
##
## A 線的新頭目與小怪(data/enemies/morgana.tres 等)還沒合併時全部用替身;有 A 線的場地
## (game/combat/arena.tscn)時,用正式的場地、主角與同伴(spawn_companion),背景用 tower_top。
##
## 每 2 秒印一行;跑滿 bench_seconds 後印出總結(節點數、每格 CPU 時間的平均與最慢 1%、FPS)。
## 雲端沒有 GPU:無畫面(headless)時量到的是 CPU 端(腳本、物理、粒子)的負擔;手機的數字要在實機量。
##
## 用法:
##   godot --path . res://tests/line_d/boss_stress_test.tscn
##   godot --headless --path . res://tests/line_d/boss_stress_test.tscn -- --bench-seconds=20 --quit-when-done
## 參數:--load=N(全部數量乘 N,看餘裕)、--no-clones、--no-beam、--no-glow、--no-minions、--uncapped-fps

const ARENA_PATH: String = "res://game/combat/arena.tscn"
const BACKGROUND_PATH: String = "res://assets/backgrounds/tower_top.tscn"
const BOSS_FRAMES_PATH: String = "res://assets/sprites/morgana/morgana_frames.tres"
const FOXFIRE_FRAMES_PATH: String = "res://assets/sprites/foxfire/foxfire_frames.tres"
const WOLF_FRAMES_PATH: String = "res://assets/sprites/shadow_wolf/shadow_wolf_frames.tres"
const GARGOYLE_FRAMES_PATH: String = "res://assets/sprites/gargoyle/gargoyle_frames.tres"
const GOLDIE_FRAMES_PATH: String = "res://assets/sprites/goldie/goldie_frames.tres"
const BULLDOG_FRAMES_PATH: String = "res://assets/sprites/bulldog/bulldog_frames.tres"
const LANCELOT_FRAMES_PATH: String = "res://assets/sprites/lancelot/lancelot_frames.tres"
const MOON_ORB_PATH: String = "res://assets/fx/moon_orb/moon_orb_frames.tres"
const FOX_FLAME_PATH: String = "res://assets/fx/fox_flame/fox_flame_frames.tres"
const THORN_PATH: String = "res://assets/fx/thorn/thorn_frames.tres"
const FX_DIR: String = "res://assets/fx/particles/"

const TELEPORT_EVERY: float = 3.0
const TELEPORT_WARN: float = 0.7
const BOSS_FAN: int = 5
const BOSS_FAN_EVERY: float = 1.0
const CLONES: int = 2
const CLONE_FAN: int = 3
const CLONE_FAN_EVERY: float = 1.5
const ORB_SPEED: float = 70.0
const FOX_RAIN: int = 8
const FOX_RAIN_EVERY: float = 2.5
const FOX_RAIN_WARN: float = 0.6
const FOX_FLAME_SEC: float = 0.5
const BEAM_EVERY: float = 5.0
const BEAM_WARN: float = 0.8
const BEAM_SEC: float = 2.0
const BEAM_SPIN: float = 1.4
const THORNS: int = 10
const THORN_EVERY: float = 3.0
const THORN_SPEED: float = 80.0
const FOXFIRES: int = 6
const WOLVES: int = 4
const GARGOYLES: int = 2
const HITS_PER_SEC: float = 8.0
const SPARKLES_PER_SEC: float = 3.0
const FX_CAPS: Dictionary = {&"hit_burst": 8, &"sparkle": 6, &"star_burst": 2}

@export var bench_seconds: float = 10.0
@export var load_mult: int = 1
@export var with_clones: bool = true
@export var with_beam: bool = true
@export var with_glow: bool = true
@export var with_minions: bool = true

var using_real_arena: bool = false
var _arena: Node
var _player: Node2D
var _companions: Array[Node2D] = []
var _boss: AnimatedSprite2D
var _clones: Array[AnimatedSprite2D] = []
var _shots: Node2D
var _warnings: Node2D
var _fx_layer: Node2D
var _beam: Area2D
var _beam_line: Line2D
var _beam_state: int = 0   # 0 = 沒有、1 = 預警、2 = 旋轉中
var _beam_time: float = 0.0
var _label: Label
var _frames: Dictionary = {}
var _fx_scenes: Dictionary = {}
var _glow_texture: Texture2D
var _timers: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _report_timer: float = 0.0
var _done: bool = false
var _quit_when_done: bool = false
var _teleport_to: Vector2 = Vector2.ZERO
var _teleport_warn_left: float = 0.0
var _hit_accum: float = 0.0
var _sparkle_accum: float = 0.0

# 量測
var _cpu_ms: PackedFloat32Array = []
var _frame_ms: PackedFloat32Array = []
var _fps: PackedFloat32Array = []
var peak_nodes: int = 0
var peak_shots: int = 0
var peak_minions: int = 0
var shots_spawned: int = 0
var shot_hits: int = 0


func _ready() -> void:
	_rng.seed = 66
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-seconds="):
			bench_seconds = float(arg.trim_prefix("--bench-seconds="))
		elif arg.begins_with("--load="):
			load_mult = maxi(1, int(arg.trim_prefix("--load=")))
		elif arg == "--quit-when-done":
			_quit_when_done = true
		elif arg == "--no-clones":
			with_clones = false
		elif arg == "--no-beam":
			with_beam = false
		elif arg == "--no-glow":
			with_glow = false
		elif arg == "--no-minions":
			with_minions = false
		elif arg == "--uncapped-fps":
			Engine.max_fps = 0
	for key: String in ["boss", "foxfire", "wolf", "gargoyle", "goldie", "bulldog", "lancelot", "moon_orb", "fox_flame", "thorn"]:
		var path: String = {"boss": BOSS_FRAMES_PATH, "foxfire": FOXFIRE_FRAMES_PATH, "wolf": WOLF_FRAMES_PATH,
			"gargoyle": GARGOYLE_FRAMES_PATH, "goldie": GOLDIE_FRAMES_PATH, "bulldog": BULLDOG_FRAMES_PATH,
			"lancelot": LANCELOT_FRAMES_PATH, "moon_orb": MOON_ORB_PATH, "fox_flame": FOX_FLAME_PATH, "thorn": THORN_PATH}[key]
		_frames[key] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	for fx_name: StringName in FX_CAPS:
		var fx_path := FX_DIR + String(fx_name) + ".tscn"
		if ResourceLoader.exists(fx_path):
			_fx_scenes[fx_name] = load(fx_path)
	_glow_texture = _make_glow_texture()
	_build_world()
	_build_boss()
	if with_minions:
		_build_minions()
	_build_readout()
	for key: String in ["teleport", "fan", "clone_fan", "rain", "beam", "thorn"]:
		_timers[key] = 0.3
	print("[boss-stress] real_arena=%s load=%d clones=%s beam=%s glow=%s minions=%d renderer=%s display=%s max_fps=%d" % [
		using_real_arena, load_mult, with_clones, with_beam, with_glow, minion_count(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), DisplayServer.get_name(), Engine.max_fps])


func _process(delta: float) -> void:
	_elapsed += delta
	_move_player(delta)
	run_patterns(delta)
	_run_fx(delta)
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var shots := shots_alive()
	peak_nodes = maxi(peak_nodes, nodes)
	peak_shots = maxi(peak_shots, shots)
	peak_minions = maxi(peak_minions, minion_count())
	if _elapsed > 1.0 and not _done:
		_cpu_ms.append(process_ms + physics_ms)
		_frame_ms.append(delta * 1000.0)
		_fps.append(Engine.get_frames_per_second())
	if _label != null:
		_label.text = "FPS %d  nodes %d\nshots %d  minions %d\ncpu %.2f ms" % [Engine.get_frames_per_second(), nodes, shots,
			minion_count(), process_ms + physics_ms]
	_report_timer += delta
	if _report_timer >= 2.0:
		_report_timer = 0.0
		print("[boss-stress] t=%.0fs fps=%d nodes=%d shots=%d minions=%d process=%.2fms physics=%.2fms" % [
			_elapsed, Engine.get_frames_per_second(), nodes, shots, minion_count(), process_ms, physics_ms])
	if not _done and _elapsed >= bench_seconds + 1.0:
		_done = true
		var r := report()
		print("[boss-stress] SUMMARY load=%d seconds=%.0f peak_nodes=%d peak_shots=%d peak_minions=%d avg_cpu=%.2fms p99_cpu=%.2fms avg_frame=%.2fms p99_frame=%.2fms avg_fps=%.1f min_fps=%.0f shots_spawned=%d hits=%d" % [
			load_mult, bench_seconds, r["peak_nodes"], r["peak_shots"], r["peak_minions"], r["avg_cpu_ms"], r["p99_cpu_ms"],
			r["avg_frame_ms"], r["p99_frame_ms"], r["avg_fps"], r["min_fps"], shots_spawned, shot_hits])
		if _quit_when_done:
			get_tree().quit()


## 量測的結果(測試與總結用)。
func report() -> Dictionary:
	var cpu := _cpu_ms.duplicate()
	cpu.sort()
	var frames := _frame_ms.duplicate()
	frames.sort()
	var fps := _fps.duplicate()
	fps.sort()
	return {
		"peak_nodes": peak_nodes, "peak_shots": peak_shots, "peak_minions": peak_minions,
		"avg_cpu_ms": _avg(_cpu_ms), "p99_cpu_ms": _p99(cpu), "avg_frame_ms": _avg(_frame_ms), "p99_frame_ms": _p99(frames),
		"avg_fps": _avg(_fps), "min_fps": fps[0] if not fps.is_empty() else 0.0, "samples": _cpu_ms.size(),
	}


func shots_alive() -> int:
	return _shots.get_child_count() if _shots != null else 0


func minion_count() -> int:
	return get_tree().get_nodes_in_group(&"boss_stress_minion").size() if is_inside_tree() else 0


func clone_count() -> int:
	return _clones.size()


func beam_state() -> int:
	return _beam_state


static func _avg(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(1.0, values.size())


static func _p99(sorted: PackedFloat32Array) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]


# --- 場地 ---

func _build_world() -> void:
	var camera := Camera2D.new()
	camera.position = SafeArea.GAME_CENTER
	add_child(camera)
	camera.make_current()
	var bg_scene: PackedScene = load(BACKGROUND_PATH) if ResourceLoader.exists(BACKGROUND_PATH) else null
	if ResourceLoader.exists(ARENA_PATH):
		_arena = (load(ARENA_PATH) as PackedScene).instantiate()
		add_child(_arena)
		if _arena.has_method(&"get_player") and _arena.has_method(&"spawn_companion"):
			using_real_arena = true
			if bg_scene != null and _arena.has_method(&"set_background"):
				_arena.call(&"set_background", bg_scene)
			_player = _arena.call(&"get_player") as Node2D
			for id: StringName in [&"bulldog", &"lancelot"]:
				var companion: Node2D = null
				if ResourceLoader.exists("res://data/companions/%s.tres" % id):
					companion = _arena.call(&"spawn_companion", id) as Node2D
				if companion == null:
					companion = _stand_in_sprite(String(id), Layout.PLAYER_START)
				_companions.append(companion)
		else:
			_arena.queue_free()
			_arena = null
	if not using_real_arena:
		if bg_scene != null:
			var bg := bg_scene.instantiate()
			bg.z_index = -10
			add_child(bg)
		_add_walls()
		_player = _stand_in_sprite("goldie", Layout.PLAYER_START)
		for id: String in ["bulldog", "lancelot"]:
			_companions.append(_stand_in_sprite(id, Layout.PLAYER_START))
	_warnings = Node2D.new()
	_warnings.name = "Warnings"
	_warnings.z_index = 2
	add_child(_warnings)
	_shots = Node2D.new()
	_shots.name = "Shots"
	_shots.z_index = 4
	add_child(_shots)
	_fx_layer = Node2D.new()
	_fx_layer.name = "Fx"
	_fx_layer.z_index = 5
	add_child(_fx_layer)


func _stand_in_sprite(frames_key: String, at: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "StandIn_" + frames_key
	sprite.sprite_frames = _frames.get(frames_key)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"run"):
		sprite.play(&"run")
	sprite.position = at
	add_child(sprite)
	return sprite


func _add_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = Layers.ARENA
	walls.collision_mask = 0
	var r := Layout.ARENA_RECT
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var shape := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = corners[i]
		seg.b = corners[(i + 1) % 4]
		shape.shape = seg
		walls.add_child(shape)
	add_child(walls)


func _move_player(_delta: float) -> void:
	if _player == null:
		return
	var t := _elapsed * 0.7
	_player.global_position = Layout.ARENA_RECT.get_center() + Vector2(cos(t) * 55.0, 40.0 + sin(t * 1.3) * 50.0)
	for i in _companions.size():
		var c := _companions[i]
		if c != null and is_instance_valid(c):
			c.global_position = _player.global_position + Vector2(-22.0 if i == 0 else 22.0, 8.0)


# --- 頭目與分身 ---

func _build_boss() -> void:
	_boss = _stand_in_sprite("boss", Vector2(Layout.ARENA_RECT.get_center().x, Layout.ARENA_RECT.position.y + 50.0))
	_boss.name = "Boss"
	_boss.z_index = 3
	if _boss.sprite_frames != null and _boss.sprite_frames.has_animation(&"idle"):
		_boss.play(&"idle")
	_add_glow(_boss, 3.0, Color(0.7, 0.4, 1.0, 0.35))
	if with_clones:
		for i in CLONES * load_mult:
			var clone := _stand_in_sprite("boss", _boss.position + Vector2(-50.0 + 100.0 * (i % 2), 30.0 + 10.0 * (i / 2)))
			clone.name = "Clone%d" % i
			clone.modulate = Color(0.75, 0.5, 1.0, 0.6)
			clone.z_index = 3
			# 分身一下就打散:有被打的範圍
			var hurt := Area2D.new()
			hurt.collision_layer = Layers.ENEMY
			hurt.collision_mask = 0
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 10.0
			shape.shape = circle
			hurt.add_child(shape)
			clone.add_child(hurt)
			_clones.append(clone)
	_beam = Area2D.new()
	_beam.name = "MoonBeam"
	_beam.collision_layer = Layers.ENEMY_ATTACK
	_beam.collision_mask = Layers.PLAYER | Layers.COMPANION
	var beam_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 6)
	beam_shape.shape = rect
	beam_shape.position = Vector2(75, 0)
	_beam.add_child(beam_shape)
	_beam_line = Line2D.new()
	_beam_line.points = PackedVector2Array([Vector2.ZERO, Vector2(150, 0)])
	_beam.add_child(_beam_line)
	_beam.visible = false
	_beam.monitoring = false
	_beam.z_index = 4
	add_child(_beam)


## 推進頭目的招式(_process 每格呼叫;測試可以直接呼叫)。
func run_patterns(delta: float) -> void:
	for key: String in _timers:
		_timers[key] = float(_timers[key]) - delta
	# 瞬間移動:目的地先亮月光圈
	if _teleport_warn_left > 0.0:
		_teleport_warn_left -= delta
		if _teleport_warn_left <= 0.0:
			_boss.position = _teleport_to
			_spawn_fx(&"star_burst", _boss.position)
	elif float(_timers["teleport"]) <= 0.0:
		_timers["teleport"] = TELEPORT_EVERY
		var r := Layout.ARENA_RECT.grow(-24)
		_teleport_to = Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.position.y + r.size.y * 0.5))
		_teleport_warn_left = TELEPORT_WARN
		_add_warning(_teleport_to, 12.0, TELEPORT_WARN, Color(0.75, 0.9, 1.0, 0.6))
	if float(_timers["fan"]) <= 0.0:
		_timers["fan"] = BOSS_FAN_EVERY
		for k in load_mult:
			_fire_fan(_boss.position, BOSS_FAN, 0.9, "moon_orb", ORB_SPEED, 1.0)
	if with_clones and float(_timers["clone_fan"]) <= 0.0:
		_timers["clone_fan"] = CLONE_FAN_EVERY
		for i in _clones.size():
			var clone := _clones[i]
			clone.position = _boss.position + Vector2(cos(_elapsed + i * PI) * 50.0, 24.0 + sin(_elapsed * 1.3 + i) * 10.0)
			_fire_fan(clone.position, CLONE_FAN, 0.7, "moon_orb", ORB_SPEED * 0.8, 0.7)
	if float(_timers["rain"]) <= 0.0:
		_timers["rain"] = FOX_RAIN_EVERY
		for i in FOX_RAIN * load_mult:
			var r := Layout.ARENA_RECT.grow(-12)
			var at := Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y + 40.0, r.end.y))
			_add_warning(at, 9.0, FOX_RAIN_WARN, Color(1.0, 0.3, 0.2, 0.55))
			_fire_shot("fox_flame", at, Vector2.ZERO, FOX_FLAME_SEC, FOX_RAIN_WARN, 6.0)
	if float(_timers["thorn"]) <= 0.0:
		_timers["thorn"] = THORN_EVERY
		for i in THORNS * load_mult:
			var dir := Vector2.RIGHT.rotated(TAU * i / (THORNS * load_mult))
			_fire_shot("thorn", _boss.position, dir * THORN_SPEED, 2.2, 0.0, 3.0)
	if with_beam:
		_run_beam(delta)


func _fire_fan(from: Vector2, count: int, spread: float, frames_key: String, speed: float, glow: float) -> void:
	var aim := (_player.global_position - from).normalized() if _player != null else Vector2.DOWN
	for i in count:
		var a := -spread * 0.5 + spread * i / maxf(count - 1, 1)
		var shot := _fire_shot(frames_key, from, aim.rotated(a) * speed, 3.0, 0.0, 4.0)
		if with_glow and glow > 0.0:
			_add_glow(shot, glow, Color(0.6, 0.85, 1.0, 0.4))


func _fire_shot(frames_key: String, from: Vector2, velocity: Vector2, life: float, delay: float, radius: float) -> Area2D:
	var shot := BossShot.new()
	shot.setup(_frames.get(frames_key), from, velocity, life, delay, radius)
	shot.hit.connect(func() -> void: shot_hits += 1)
	_shots.add_child(shot)
	shots_spawned += 1
	return shot


func _run_beam(delta: float) -> void:
	match _beam_state:
		0:
			if float(_timers["beam"]) <= 0.0:
				_beam_state = 1
				_beam_time = BEAM_WARN
				_beam.position = _boss.position
				_beam.rotation = _rng.randf() * TAU
				_beam.visible = true
				_beam_line.width = 1.0
				_beam_line.default_color = Color(1, 0.25, 0.2, 0.7)
		1:
			_beam_time -= delta
			if _beam_time <= 0.0:
				_beam_state = 2
				_beam_time = BEAM_SEC
				_beam.monitoring = true
				_beam_line.width = 5.0
				_beam_line.default_color = Color(0.8, 0.92, 1.0, 0.85)
		2:
			_beam_time -= delta
			_beam.position = _boss.position
			_beam.rotation += BEAM_SPIN * delta
			if _beam_time <= 0.0:
				_beam_state = 0
				_timers["beam"] = BEAM_EVERY
				_beam.visible = false
				_beam.monitoring = false


func _add_warning(at: Vector2, radius: float, sec: float, color: Color) -> void:
	var w := WarningCircle.new()
	w.position = at
	w.radius = radius
	w.life = sec
	w.color = color
	_warnings.add_child(w)


# --- 小怪 ---

func _build_minions() -> void:
	var r := Layout.ARENA_RECT.grow(-14)
	var plan := [["foxfire", FOXFIRES, BossMinion.Mode.CHASE, 34.0, 4.0], ["wolf", WOLVES, BossMinion.Mode.ORBIT, 50.0, 7.0],
		["gargoyle", GARGOYLES, BossMinion.Mode.SWOOP, 42.0, 7.0]]
	var index := 0
	for entry: Array in plan:
		for i in int(entry[1]) * load_mult:
			var m := BossMinion.new()
			m.setup(_frames.get(entry[0]), entry[2], _player, float(entry[3]), float(entry[4]), index)
			m.position = r.position + Vector2(fmod(index * 37.0, r.size.x), fmod(index * 53.0, r.size.y * 0.6))
			add_child(m)
			index += 1


# --- 特效 ---

func _run_fx(delta: float) -> void:
	_hit_accum += delta * HITS_PER_SEC
	while _hit_accum >= 1.0:
		_hit_accum -= 1.0
		var minions := get_tree().get_nodes_in_group(&"boss_stress_minion")
		var at := _boss.position if minions.is_empty() else (minions[_rng.randi() % minions.size()] as Node2D).global_position
		_spawn_fx(&"hit_burst", at)
	_sparkle_accum += delta * SPARKLES_PER_SEC
	while _sparkle_accum >= 1.0:
		_sparkle_accum -= 1.0
		_spawn_fx(&"sparkle", _player.global_position if _player != null else _boss.position)


func _spawn_fx(fx_name: StringName, at: Vector2) -> void:
	var scene: PackedScene = _fx_scenes.get(fx_name)
	if scene == null:
		return
	var group := StringName("boss_fx_%s" % fx_name)
	if get_tree().get_node_count_in_group(group) >= int(FX_CAPS.get(fx_name, 4)) * load_mult:
		return
	var fx := scene.instantiate()
	fx.add_to_group(group)
	if fx is Node2D:
		(fx as Node2D).position = at
	_fx_layer.add_child(fx)


func _add_glow(parent: Node2D, glow_scale: float, color: Color) -> void:
	if not with_glow or _glow_texture == null:
		return
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	glow.scale = Vector2.ONE * glow_scale * 0.5
	glow.modulate = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.show_behind_parent = true
	parent.add_child(glow)


static func _make_glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(4, 4)
	_label.add_theme_font_size_override(&"font_size", 12)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 2)
	layer.add_child(_label)


# --- 替身類別 ---

## 投射物替身:直線飛、可以先等一下(狐火雨的預警),碰到主角或同伴、或時間到就消失。不造成傷害。
class BossShot:
	extends Area2D
	signal hit()
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 3.0
	var delay: float = 0.0
	var _sprite: AnimatedSprite2D

	func setup(frames: SpriteFrames, from: Vector2, p_velocity: Vector2, p_life: float, p_delay: float, radius: float) -> void:
		position = from
		velocity = p_velocity
		life = p_life
		delay = p_delay
		rotation = velocity.angle() if velocity != Vector2.ZERO else 0.0
		collision_layer = Layers.ENEMY_ATTACK
		collision_mask = Layers.PLAYER | Layers.COMPANION
		monitorable = false
		monitoring = delay <= 0.0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		if frames != null and frames.has_animation(&"default"):
			_sprite.play(&"default")
		_sprite.visible = delay <= 0.0
		add_child(_sprite)
		body_entered.connect(func(_body: Node) -> void:
			hit.emit()
			queue_free())

	func _physics_process(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			if delay <= 0.0:
				monitoring = true
				_sprite.visible = true
			return
		position += velocity * dt
		life -= dt
		if life <= 0.0 or not Layout.ARENA_RECT.grow(20).has_point(position):
			queue_free()


## 預警圈(月光圈、狐火雨的落點):慢慢變亮,時間到就消失。
class WarningCircle:
	extends Node2D
	var radius: float = 10.0
	var life: float = 0.6
	var color: Color = Color.RED
	var _age: float = 0.0

	func _process(dt: float) -> void:
		_age += dt
		if _age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.35 * t))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 20, color, 1.0)
		draw_arc(Vector2.ZERO, radius * t, 0, TAU, 20, Color(color, 0.8), 1.0)


## 小怪替身:CharacterBody2D,彼此碰撞推開。CHASE 追金毛(狐火)、ORBIT 在外圍繞圈(影狼)、SWOOP 來回俯衝(石像鬼)。
class BossMinion:
	extends CharacterBody2D
	enum Mode { CHASE, ORBIT, SWOOP }
	var mode: Mode = Mode.CHASE
	var target: Node2D
	var speed: float = 30.0
	var phase: float = 0.0
	var _sprite: AnimatedSprite2D
	var _time: float = 0.0

	func setup(frames: SpriteFrames, p_mode: Mode, p_target: Node2D, p_speed: float, radius: float, index: int) -> void:
		mode = p_mode
		target = p_target
		speed = p_speed
		phase = index * 0.9
		add_to_group(&"boss_stress_minion")
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		collision_layer = Layers.ENEMY
		collision_mask = Layers.ARENA | Layers.ENEMY
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		if frames != null:
			var anim := &"run" if frames.has_animation(&"run") else &"idle"
			if frames.has_animation(anim):
				_sprite.play(anim)
		add_child(_sprite)

	func _physics_process(dt: float) -> void:
		_time += dt
		if target == null or not is_instance_valid(target):
			return
		var goal := target.global_position
		match mode:
			Mode.ORBIT:
				goal += Vector2.RIGHT.rotated(_time * 0.8 + phase) * 70.0
			Mode.SWOOP:
				goal += Vector2(sin(_time * 0.9 + phase) * 60.0, -50.0 + 50.0 * absf(sin(_time * 0.6 + phase)))
		var to_goal := goal - global_position
		velocity = to_goal.normalized() * speed if to_goal.length() > 6.0 else Vector2.ZERO
		move_and_slide()
		if velocity.x != 0.0:
			_sprite.flip_h = velocity.x < 0.0
