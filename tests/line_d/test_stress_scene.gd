extends TestCase
## DS4:壓力測試場景可以跑(40 隻敵人 + 投射物 + 光暈 + 對白插畫),數字由 headless 執行量度(見 docs/status/LINE_D.md)。
## DV3:寶箱、零食、進化特效也在場上。

const STRESS_SCENE := "res://tests/line_d/stress_test.tscn"

var _stress: Node


func after_each() -> void:
	if _stress != null and is_instance_valid(_stress):
		_stress.queue_free()
	_stress = null
	await wait_frames(2)
	GameState.reset_run()


func test_stress_scene_keeps_projectiles_and_glow_alive() -> void:
	_stress = (load(STRESS_SCENE) as PackedScene).instantiate()
	_stress.set(&"with_dialogue", true)
	add_child(_stress)
	await wait_frames(6)
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 40, "40 隻敵人")
	assert_eq(_stress.call(&"_projectiles_alive"), 16, "16 支投射物同時存在")
	assert_true(int(_stress.call(&"_glows_alive")) >= 16, "光暈:跟著敵人的 12 個 + 火把 4 個")
	assert_ne(String(_stress.get(&"_glow_source")), "", "有光暈圖(C 線的,或程式產生的替身)")
	var dialogue := _stress.get(&"_dialogue") as Node
	assert_not_null(dialogue, "--dialogue:對白框")
	assert_true(dialogue.call(&"is_active"), "對白框正在顯示插畫")


func test_stress_scene_keeps_chests_snacks_and_evolution_alive() -> void:
	_stress = (load(STRESS_SCENE) as PackedScene).instantiate()
	add_child(_stress)
	await wait_frames(4)
	var chests: Array = _stress.get(&"_chests")
	assert_eq(chests.size(), 3, "3 個寶箱")
	assert_not_null((chests[0] as AnimatedSprite2D).sprite_frames, "用 C 線的寶箱圖")
	assert_eq(get_tree().get_nodes_in_group(&"stress_snack").size(), 12, "12 個零食")
	assert_eq((_stress.get(&"_orbiters") as Array).size(), 6, "6 個繞身的劍氣(進化)")
	assert_eq(_stress.call(&"_loot_alive"), 21, "寶箱 3 + 零食 12 + 劍氣 6")
	# 推進時間:寶箱會打開、零食會被吃掉再補回
	for i in 40:
		_stress.call(&"_run_loot", 0.1)
	assert_true(int(_stress.get(&"_chests_opened")) >= 2, "寶箱輪流打開")
	assert_true(int(_stress.get(&"_snacks_eaten")) > 0, "零食被吸向金毛、吃掉")
	assert_true(int(_stress.get(&"_evolve_bursts")) >= 1, "進化演出")


func test_glow_texture_fallback_is_a_radial_gradient() -> void:
	var script := load("res://tests/line_d/stress_test.gd") as GDScript
	var tex := script.call(&"_make_glow_texture") as Texture2D
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(32, 32))
