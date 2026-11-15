extends "res://tests/line_b/flow_test_base.gd"
## B2 波次生成器:波次順序、延遲與間隔、清空才進下一波、頭目召喚也算、出生點分散。

const FakeArena := preload("res://tests/line_b/fake_arena.gd")

var arena: Node2D
var spawner: WaveSpawner


# 注意:測試執行器在 after_each 之後才停止 watch_signal,所以被觀察訊號的物件
# (spawner)要到下一個測試的 before_each 才釋放;最後一個隨測試檔一起釋放。
func before_each() -> void:
	if spawner != null:
		spawner.queue_free()
	spawner = null
	if arena != null:
		remove_child(arena)       # 立即離開場景樹,舊敵人不再算在 "enemy" 群組
		arena.queue_free()
	arena = FakeArena.new()
	add_child(arena)


func _entry(id: StringName, count: int, delay: float = 0.0) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = id
	e.count = count
	e.delay = delay
	return e


func _wave(entries: Array) -> WaveData:
	var w := WaveData.new()
	for e: SpawnEntry in entries:
		w.spawns.append(e)
	return w


func _level(waves: Array, boss: bool = false) -> LevelData:
	var l := LevelData.new()
	l.id = &"test"
	l.is_boss = boss
	for w: WaveData in waves:
		l.waves.append(w)
	return l


func _difficulty() -> DifficultyData:
	var d := DifficultyData.new()
	d.first_wave_delay = 1.0
	d.inter_wave_delay = 2.0
	d.spawn_spacing = 0.5
	d.spawn_jitter = 0.0
	d.min_spawn_distance = 0.0
	return d


func _make(level: LevelData, d: DifficultyData = null) -> WaveSpawner:
	spawner = WaveSpawner.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	spawner.setup(level, arena, d if d != null else _difficulty(), rng)
	add_child(spawner)
	spawner.set_physics_process(false)    # 測試自己用 step() 控制時間
	return spawner


func test_waves_run_in_order_and_wait_until_field_is_empty() -> void:
	var level := _level([
		_wave([_entry(&"scarecrow", 2), _entry(&"crow", 1)]),
		_wave([_entry(&"black_knight", 1)]),
	])
	var s := _make(level)
	var started := watch_signal(EventBus.wave_started)
	var cleared := watch_signal(EventBus.wave_cleared)
	var done := watch_signal(s.all_waves_cleared)
	s.start()
	s.step(0.5)
	assert_eq(started.count, 0, "first_wave_delay 之前不開始")
	s.step(0.5)
	assert_eq(started.count, 1)
	assert_eq(started.last_args(), [1, 2], "wave_started 的 index 從 1 起算")
	s.step(1.0)
	assert_eq(arena.spawned_ids(), [&"scarecrow", &"crow", &"scarecrow"] as Array[StringName],
			"依出現時間排序:scarecrow@0、crow@0、scarecrow@0.5")
	for i in 10:
		s.step(1.0)
	assert_eq(cleared.count, 0, "敵人還在就不算清空")
	assert_eq(started.count, 1, "敵人還在就不進下一波")
	arena.kill_all()
	s.step(0.1)
	assert_eq(cleared.count, 1)
	assert_eq(cleared.last_args(), [1])
	s.step(1.0)
	assert_eq(started.count, 1, "inter_wave_delay 之前不開始第 2 波")
	s.step(1.0)
	assert_eq(started.count, 2)
	assert_eq(started.last_args(), [2, 2])
	assert_eq(arena.spawned_ids().back(), &"black_knight")
	assert_eq(done.count, 0)
	arena.kill_all()
	s.step(0.1)
	assert_eq(cleared.count, 2)
	assert_eq(done.count, 1, "最後一波清空 → all_waves_cleared")
	assert_true(s.is_done())


func test_entry_delay_and_spacing() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	var s := _make(_level([_wave([_entry(&"scarecrow", 3, 0.0), _entry(&"crow", 1, 2.0)])]), d)
	s.start()
	s.step(0.0)
	assert_eq(arena.spawned.size(), 1, "t=0 只有第一隻")
	s.step(0.5)
	assert_eq(arena.spawned.size(), 2, "t=0.5 第二隻(spawn_spacing)")
	s.step(0.5)
	assert_eq(arena.spawned.size(), 3, "t=1.0 第三隻")
	s.step(0.9)
	assert_eq(arena.spawned.size(), 3, "t=1.9 烏鴉還沒出現")
	s.step(0.1)
	assert_eq(arena.spawned.size(), 4, "t=2.0 烏鴉依 delay 出現")
	arena.kill_all()
	s.step(0.1)
	assert_true(s.is_done())


func test_wave_not_cleared_before_all_scheduled_spawns() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	var s := _make(_level([_wave([_entry(&"scarecrow", 1, 0.0), _entry(&"scarecrow", 1, 5.0)])]), d)
	var cleared := watch_signal(EventBus.wave_cleared)
	s.start()
	s.step(0.0)
	arena.kill_all()
	s.step(1.0)
	assert_eq(cleared.count, 0, "還有排定的敵人沒出來,不算清空")
	s.step(4.0)
	assert_eq(arena.spawned.size(), 2)
	arena.kill_all()
	s.step(0.1)
	assert_eq(cleared.count, 1)


func test_boss_summons_count_as_enemies() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	var s := _make(_level([_wave([_entry(&"black_knight", 1)])], true), d)
	var done := watch_signal(s.all_waves_cleared)
	s.start()
	s.step(0.0)
	var boss: Node2D = arena.alive()[0]
	# 頭目召喚兩隻稻草人兵(經場地生成,在 "enemy" 群組內)
	arena.spawn_enemy(&"scarecrow", Vector2(60, 100))
	arena.spawn_enemy(&"scarecrow", Vector2(120, 100))
	arena.kill(boss)
	s.step(0.1)
	assert_eq(done.count, 0, "頭目倒下但召喚的小怪還在")
	arena.kill_all()
	s.step(0.1)
	assert_eq(done.count, 1)


func test_spawn_points_are_spread_out_and_avoid_the_player() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	d.spawn_spacing = 0.0
	d.min_spawn_distance = 40.0
	# 第 3 個出生點緊貼著金毛,不應被使用
	arena.spawn_points.assign([Vector2(20, 80), Vector2(160, 80), Layout.PLAYER_START + Vector2(4, 0), Vector2(90, 80)])
	var s := _make(_level([_wave([_entry(&"scarecrow", 6)])]), d)
	s.start()
	s.step(0.0)
	assert_eq(arena.spawned.size(), 6)
	var first_three: Array[Vector2] = []
	for i in 3:
		var at: Vector2 = arena.spawned[i]["at"]
		assert_false(first_three.has(at), "前三隻用不同的出生點")
		first_three.append(at)
	for item in arena.spawned:
		var at: Vector2 = item["at"]
		assert_true(at.distance_to(Layout.PLAYER_START) >= 40.0, "不在金毛身邊出生 %s" % at)


func test_stop_halts_spawning() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	var s := _make(_level([_wave([_entry(&"scarecrow", 4)])]), d)
	s.start()
	s.step(0.0)
	s.stop()
	s.step(5.0)
	assert_eq(arena.spawned.size(), 1, "停止後不再生成")
	assert_false(s.is_running())


func test_enemy_not_yet_in_tree_still_counts() -> void:
	var d := _difficulty()
	d.first_wave_delay = 0.0
	arena.defer_add = true
	var s := _make(_level([_wave([_entry(&"scarecrow", 1)])]), d)
	var cleared := watch_signal(EventBus.wave_cleared)
	s.start()
	s.step(0.0)
	assert_eq(s.enemies_remaining(), 1, "剛生成、還沒進場景樹的敵人也算在場上")
	s.step(0.1)
	assert_eq(cleared.count, 0)
	await wait_frames(1)
	assert_eq(s.enemies_remaining(), 1, "進了場景樹,在 enemy 群組內")
	arena.kill_all()
	s.step(0.1)
	assert_eq(cleared.count, 1)
