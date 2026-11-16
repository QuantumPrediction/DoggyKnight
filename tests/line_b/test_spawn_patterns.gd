extends "res://tests/line_b/flow_test_base.gd"
## BP7 出場隊形(SpawnEntry.pattern):surround 有預警而且公平、line_top 一排、corners 角落、
## 全部在戰鬥區之內;以及六關的波次設計(特色、高潮、喘息)。

const FakeArena := preload("res://tests/line_b/fake_arena.gd")
const LEVEL_FILES: Array[String] = [
	"res://data/levels/level_1_1.tres", "res://data/levels/level_1_2.tres", "res://data/levels/level_1_3.tres",
	"res://data/levels/level_1_4.tres", "res://data/levels/level_1_5.tres", "res://data/levels/level_1_6.tres",
]

var arena: Node2D
var spawner: WaveSpawner


func before_each() -> void:
	if spawner != null:
		spawner.queue_free()
	spawner = null
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = FakeArena.new()
	add_child(arena)


func _difficulty() -> DifficultyData:
	var d := (load(DIFFICULTY) as DifficultyData).duplicate() as DifficultyData
	d.first_wave_delay = 0.0
	d.spawn_jitter = 0.0
	return d


func _make(entries: Array, d: DifficultyData = null) -> WaveSpawner:
	var level := LevelData.new()
	level.id = &"pattern_test"
	var wave := WaveData.new()
	for e: SpawnEntry in entries:
		wave.spawns.append(e)
	level.waves.append(wave)
	spawner = WaveSpawner.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	spawner.setup(level, arena, d if d != null else _difficulty(), rng)
	add_child(spawner)
	spawner.set_physics_process(false)
	return spawner


func _entry(id: StringName, count: int, pattern: StringName, delay: float = 0.0) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = id
	e.count = count
	e.pattern = pattern
	e.delay = delay
	return e


func _inside(p: Vector2) -> bool:
	return Layout.ARENA_RECT.has_point(p)


func test_surround_is_telegraphed_then_spawns_on_the_markers() -> void:
	var d := _difficulty()
	var s := _make([_entry(&"scarecrow", 6, &"surround")], d)
	var cleared := watch_signal(EventBus.wave_cleared)
	s.start(0.0)
	s.step(0.0)
	assert_eq(arena.spawned.size(), 0, "先預警,敵人還沒出來")
	var markers := s.active_markers()
	assert_eq(markers.size(), 6, "每隻敵人一個預警記號")
	var marked: Array[Vector2] = []
	for marker: Node in markers:
		assert_true(marker is SpawnMarker)
		assert_true(arena.is_ancestor_of(marker), "記號在場地裡")
		marked.append((marker as Node2D).position)
	s.step(d.surround_telegraph * 0.5)
	assert_eq(arena.spawned.size(), 0)
	assert_eq(cleared.count, 0, "預警中的敵人也算這一波,不會提早清空")
	s.step(d.surround_telegraph * 0.5 + 0.01)
	assert_eq(arena.spawned.size(), 6, "預警結束,整組同時出現")
	for item in arena.spawned:
		assert_true(marked.has(item["at"]), "敵人在記號的位置出現 %s" % item["at"])
	assert_eq(s.active_markers().size(), 0, "出現後記號移除")
	await wait_frames(1)


func test_surround_rings_the_player_at_a_fair_distance() -> void:
	var d := _difficulty()
	var s := _make([], d)
	var rect := Layout.ARENA_RECT.grow(-d.pattern_inset)
	for center: Vector2 in [Layout.PLAYER_START, rect.position + Vector2(4, 4), Vector2(rect.end.x - 2, rect.get_center().y),
			rect.end - Vector2(1, 1), Layout.ARENA_RECT.get_center()]:
		var points := s.surround_positions(8, center)
		assert_eq(points.size(), 8)
		for p in points:
			assert_true(p.x >= rect.position.x and p.x <= rect.end.x and p.y >= rect.position.y and p.y <= rect.end.y,
					"在隊形範圍之內 %s" % p)
			assert_true(_inside(p), "在戰鬥區之內 %s" % p)
			assert_true(p.distance_to(center) >= d.surround_min_distance - 0.6,
					"離金毛夠遠 %s → %s(%.1f)" % [center, p, p.distance_to(center)])
	var open := s.surround_positions(6, Layout.ARENA_RECT.get_center())
	var angles: Array[float] = []
	for p in open:
		angles.append((p - Layout.ARENA_RECT.get_center()).angle())
	angles.sort()
	for i in angles.size() - 1:
		assert_almost_eq(angles[i + 1] - angles[i], TAU / 6.0, 0.15, "空曠處平均圍一圈")


func test_line_top_is_a_row_and_flips_when_goldie_is_near_the_top() -> void:
	var d := _difficulty()
	var s := _make([], d)
	var rect := s.pattern_rect()
	var row := s.line_positions(5, Layout.PLAYER_START)
	assert_eq(row.size(), 5)
	for i in row.size():
		assert_eq(row[i].y, rect.position.y, "上方一排")
		assert_true(_inside(row[i]))
		if i > 0:
			assert_true(row[i].x > row[i - 1].x, "由左到右")
	var flipped := s.line_positions(5, Vector2(90, rect.position.y + 10))
	for p in flipped:
		assert_eq(p.y, rect.end.y, "金毛在上方:改在下方排一排")
	var timed := _make([_entry(&"scarecrow", 4, &"line_top")], d)
	timed.start(0.0)
	timed.step(0.0)
	assert_eq(arena.spawned.size(), 1, "逐隻出現")
	timed.step(d.line_spacing * 3.0 + 0.01)
	assert_eq(arena.spawned.size(), 4)
	var ys: Array = arena.spawned.map(func(item: Dictionary) -> float: return (item["at"] as Vector2).y)
	assert_eq(ys, [rect.position.y, rect.position.y, rect.position.y, rect.position.y])


func test_corners_skip_the_corner_next_to_goldie() -> void:
	var d := _difficulty()
	var s := _make([_entry(&"crow", 8, &"corners")], d)
	var corners := s.corner_points()
	arena.player.position = corners[3] + Vector2(-4, -4)          # 金毛站在右下角
	s.start(0.0)
	s.step(0.0)
	s.step(d.spawn_spacing + 0.01)
	assert_eq(arena.spawned.size(), 8)
	var used: Array[Vector2] = []
	for item in arena.spawned:
		var at: Vector2 = item["at"]
		assert_true(corners.has(at), "在角落出現 %s" % at)
		assert_true(at.distance_to(arena.player.position) >= d.min_spawn_distance, "不在金毛身邊")
		if not used.has(at):
			used.append(at)
	assert_eq(used.size(), 3, "其他三個角落輪流")


func test_unknown_pattern_falls_back_to_edges() -> void:
	var s := _make([_entry(&"scarecrow", 2, &"zigzag")])
	s.start(0.0)
	s.step(0.0)
	s.step(1.0)
	assert_eq(arena.spawned.size(), 2)
	for item in arena.spawned:
		assert_true(arena.spawn_points.has(item["at"]), "用場地的出生點")


func test_stop_removes_markers() -> void:
	var s := _make([_entry(&"scarecrow", 5, &"surround")])
	s.start(0.0)
	s.step(0.0)
	assert_eq(s.active_markers().size(), 5)
	s.stop()
	assert_eq(s.active_markers().size(), 0, "金毛倒下:預警記號消失")
	s.step(5.0)
	assert_eq(arena.spawned.size(), 0)


# --- 六關的波次設計 ---

func _levels() -> Array[LevelData]:
	var result: Array[LevelData] = []
	for path in LEVEL_FILES:
		result.append(load(path) as LevelData)
	return result


func _patterns(level: LevelData) -> Array[StringName]:
	var result: Array[StringName] = []
	for wave in level.waves:
		for entry in wave.spawns:
			if not result.has(entry.pattern):
				result.append(entry.pattern)
	return result


## 一波的「威脅」:敵人數目,但較強的敵人算多幾隻(v2.3:1-4 的高潮是稻草人隊長)。
const THREAT: Dictionary = {&"scarecrow": 1.0, &"crow": 1.0, &"scarecrow_archer": 1.5, &"scarecrow_elite": 3.0,
		&"armored_husk": 3.0, &"scarecrow_captain": 12.0, &"black_knight": 30.0}


func _threat(wave: WaveData) -> float:
	var total := 0.0
	for entry in wave.spawns:
		total += entry.count * float(THREAT.get(entry.enemy_id, 1.0))
	return total


func _count(wave: WaveData) -> int:
	var total := 0
	for entry in wave.spawns:
		total += entry.count
	return total


func test_every_pattern_in_data_is_known() -> void:
	for level in _levels():
		for pattern in _patterns(level):
			assert_true(WaveSpawner.PATTERNS.has(pattern), "%s 的隊形 %s" % [level.id, pattern])


func test_levels_have_identity_and_a_climax() -> void:
	var levels := _levels()
	assert_eq(_patterns(levels[0]).has(&"surround"), false, "1-1 溫和:不包圍")
	assert_true(_patterns(levels[3]).has(&"surround"), "1-4 被包圍")
	var surround_groups := 0
	for wave in levels[3].waves:
		for entry in wave.spawns:
			if entry.pattern == &"surround":
				surround_groups += 1
	assert_true(surround_groups >= 3, "1-4 的特色是包圍(%d 組)" % surround_groups)
	assert_true(_patterns(levels[1]).has(&"corners"), "1-2 烏鴉從角落飛進來")
	assert_eq(levels[5].waves[0].spawns[0].pattern, &"line_top", "黑騎士從橋頭(上方正中)出場")
	for i in 5:
		var level := levels[i]
		var threat: Array[float] = []
		for wave in level.waves:
			threat.append(_threat(wave))
		var last := threat.back() as float
		assert_eq(threat.max(), last, "%s 最後一波是高潮(威脅 %s)" % [level.id, threat])
		# 高潮之前有喘息:最後一波的第一組不是一開始就出來
		var first_delay := INF
		for entry in level.waves.back().spawns:
			first_delay = minf(first_delay, entry.delay)
		assert_true(first_delay >= 1.0, "%s 高潮前有喘息(%.1f 秒)" % [level.id, first_delay])
