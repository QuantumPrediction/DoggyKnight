extends TestCase
## 整合測試(擁有者:整合工作階段):用全部正式零件跑 1-1 → 1-2 → 營地 → 1-3 開頭。
## 敵人由測試直接擊倒(不是試玩手感),目的是確認四條線的接縫:
## 場地、波次、經驗與升級、把戲選擇介面、結算畫面、營地、同伴加入、存檔。

const SAVE_PATH: String = "user://test_real_flow_save.json"
const SPEED: float = 8.0
const STEP_LIMIT_FRAMES: int = 20000

var flow: FlowMain
var started_levels: Array[StringName] = []


func before_each() -> void:
	SaveStore.new(SAVE_PATH).delete()
	GameState.reset_run()
	started_levels.clear()
	EventBus.level_started.connect(_on_level_started)
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.use_stand_ins = false
	flow.rng_seed = 11
	add_child(flow)
	await wait_frames(5)


func after_each() -> void:
	Engine.time_scale = 1.0
	EventBus.level_started.disconnect(_on_level_started)
	get_tree().paused = false
	if is_instance_valid(flow):
		flow.queue_free()
	await wait_frames(3)
	SaveStore.new(SAVE_PATH).delete()
	GameState.reset_run()
	GameState.snacks = 0
	GameState.sound_on = true


func _on_level_started(level_id: StringName) -> void:
	started_levels.append(level_id)


func test_real_parts_are_used() -> void:
	assert_eq(flow.state, FlowMain.State.TITLE)
	assert_true(flow.get_screen().scene_file_path.begins_with("res://ui/screens/title"), "C 線的標題畫面")
	flow.get_screen().emit_signal(&"new_game_pressed")
	await wait_frames(10)
	assert_eq(flow.state, FlowMain.State.LEVEL)
	assert_true(flow.get_arena() is CombatArena, "A 線的戰鬥場地")
	assert_true(flow.get_hud().scene_file_path == "res://ui/hud/hud.tscn", "C 線的 HUD")
	assert_true(flow.get_arena().call(&"get_player") is GoldiePlayer, "A 線的金毛")


func test_two_levels_camp_and_companion() -> void:
	flow.get_screen().emit_signal(&"new_game_pressed")
	Engine.time_scale = SPEED
	assert_true(await _clear_level(), "1-1 過關")
	assert_eq(flow.state, FlowMain.State.RESULTS)
	assert_true(flow.get_last_result()["victory"])
	assert_false(flow.get_last_result()["next_is_camp"], "1-1 之後不進營地")
	flow.get_screen().emit_signal(&"continue_pressed")
	await wait_frames(5)
	assert_true(await _clear_level(), "1-2 過關")
	assert_true(flow.get_last_result()["next_is_camp"], "1-2 之後進營地")
	assert_true(GameState.hero_level >= 2, "打兩關至少升一級")
	flow.get_screen().emit_signal(&"continue_pressed")
	await wait_frames(10)
	assert_eq(flow.state, FlowMain.State.CAMP)
	var camp := flow.get_camp()
	assert_true(camp != null and camp.scene_file_path == "res://game/camp/camp.tscn", "D 線的營地")
	camp.call(&"leave_camp")
	await wait_frames(10)
	assert_eq(flow.state, FlowMain.State.LEVEL)
	assert_eq(started_levels, [&"1-1", &"1-2", &"1-3"] as Array[StringName])
	assert_eq(get_tree().get_nodes_in_group(&"companion").size(), 1, "鬥牛犬在 1-3 加入")
	var save := SaveStore.new(SAVE_PATH)
	assert_true(FileAccess.file_exists(SAVE_PATH), "已存檔")
	assert_eq(int(save.read().get("level_index", -1)), 2, "存檔記錄到達第 3 關")


## 把目前這一關打完:選把戲、擊倒所有可擊倒的敵人,直到結算畫面出現。
func _clear_level() -> bool:
	for i in STEP_LIMIT_FRAMES:
		await get_tree().process_frame
		if flow.state == FlowMain.State.RESULTS:
			return true
		if flow.state != FlowMain.State.LEVEL:
			continue
		if flow.is_choice_open():
			var choice := flow.get_trick_choice()
			if choice.visible:
				choice.call(&"choose", 0)
			continue
		for node in get_tree().get_nodes_in_group(&"enemy"):
			if node.has_method(&"is_targetable") and node.call(&"is_targetable"):
				node.call(&"take_damage", 9999)
	return false
