extends TestCase
## DS4:壓力測試場景可以跑(40 隻敵人 + 投射物 + 光暈 + 對白插畫),數字由 headless 執行量度(見 docs/status/LINE_D.md)。

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


func test_glow_texture_fallback_is_a_radial_gradient() -> void:
	var script := load("res://tests/line_d/stress_test.gd") as GDScript
	var tex := script.call(&"_make_glow_texture") as Texture2D
	assert_not_null(tex)
	assert_eq(tex.get_size(), Vector2(32, 32))
