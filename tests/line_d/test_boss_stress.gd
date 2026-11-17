extends TestCase
## v2.6 DV4:頭目戰的效能量測場景可以跑(頭目 + 分身 + 小怪 + 投射物 + 月光束),並量到節點數與每格時間。
## 真正的數字由 headless 執行量度(見 docs/status/LINE_D.md)。

const SCENE := "res://tests/line_d/boss_stress_test.tscn"

var _stress: Node


func after_each() -> void:
	if _stress != null and is_instance_valid(_stress):
		_stress.queue_free()
	_stress = null
	await wait_frames(2)
	GameState.reset_run()


func test_boss_fight_load_is_on_the_field() -> void:
	_stress = (load(SCENE) as PackedScene).instantiate()
	add_child(_stress)
	await wait_frames(3)
	assert_eq(_stress.call(&"clone_count"), 2, "兩個鏡像分身")
	assert_eq(_stress.call(&"minion_count"), 12, "狐火 6 + 影狼 4 + 石像鬼 2")
	var boss := _stress.find_child("Boss", true, false) as AnimatedSprite2D
	assert_not_null(boss, "頭目")
	assert_not_null(boss.sprite_frames, "用摩根娜的圖(C 線的,或佔位圖)")
	# 推進招式:扇形光球、狐火雨、荊棘環、月光束
	for i in 70:
		_stress.call(&"run_patterns", 0.1)
	assert_true(int(_stress.call(&"shots_alive")) >= 20, "場上有很多投射物(%d)" % _stress.call(&"shots_alive"))
	assert_true(int(_stress.get(&"shots_spawned")) >= 40)
	assert_ne(_stress.call(&"beam_state"), -1)
	var warnings := _stress.find_child("Warnings", true, false)
	assert_not_null(warnings)


func test_beam_warns_before_it_spins() -> void:
	_stress = (load(SCENE) as PackedScene).instantiate()
	add_child(_stress)
	await wait_frames(1)
	var states: Array[int] = []
	for i in 120:
		_stress.call(&"run_patterns", 0.05)
		var s := int(_stress.call(&"beam_state"))
		if states.is_empty() or states[-1] != s:
			states.append(s)
	assert_true(states.size() >= 3, "月光束:沒有 → 預警 → 旋轉(%s)" % [states])
	assert_eq(states[1], 1, "先預警")
	assert_eq(states[2], 2, "再旋轉")


func test_measures_nodes_and_frame_time() -> void:
	_stress = (load(SCENE) as PackedScene).instantiate()
	add_child(_stress)
	for i in 90:
		await wait_frames(1)
	var r: Dictionary = _stress.call(&"report")
	for key: String in ["peak_nodes", "peak_shots", "avg_cpu_ms", "p99_cpu_ms", "avg_frame_ms", "avg_fps", "samples"]:
		assert_true(r.has(key), key)
	assert_true(int(r["peak_nodes"]) > 150, "節點數(%d)" % r["peak_nodes"])
	assert_true(int(r["samples"]) > 0, "有每格時間的樣本")
	assert_true(float(r["avg_cpu_ms"]) >= 0.0)


func test_load_multiplier_scales_everything() -> void:
	_stress = (load(SCENE) as PackedScene).instantiate()
	_stress.set(&"load_mult", 2)
	add_child(_stress)
	await wait_frames(2)
	assert_eq(_stress.call(&"clone_count"), 4)
	assert_eq(_stress.call(&"minion_count"), 24)
