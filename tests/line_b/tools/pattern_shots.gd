extends Node
## B 線的截圖工具(不是自動化測試):用全部正式零件,拍下 B 線負責的幾個畫面,方便檢查:
##   b1_intro_<關>        關卡開場(level_started 之後約 0.5 秒,HUD 的標題卡)
##   b2_surround_warn     1-4 包圍網的預警記號
##   b3_surround_spawn    包圍網的稻草人兵冒出來之後
##   b4_line_top          1-1 第 2 波:一排稻草人兵從上方走來
##   b5_corners           1-2 第 2 波:烏鴉從角落飛進來
##   b6_results_<關>      結算畫面(星級)
##   b7_transition        轉場蓋住一半時
## 敵人由工具直接擊倒(快轉到想看的那一波)。
##
## 執行(需要畫面):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_b/tools/pattern_shots.tscn -- --shots=/tmp/line_b_shots

const SAVE_PATH: String = "user://pattern_shots_save.json"

var shots_dir: String = "user://pattern_shots"
var flow: FlowMain


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_run()


func _run() -> void:
	await _level_shots(0)
	await _level_shots(1)
	await _level_shots(3)
	SaveStore.new(SAVE_PATH).delete()
	print("PATTERN SHOTS DONE → %s" % shots_dir)
	get_tree().quit()


func _level_shots(index: int) -> void:
	SaveStore.new(SAVE_PATH).write_data({"level_index": index, "tutorial_done": true})
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.rng_seed = 5
	add_child(flow)
	await _frames(10)
	flow.get_screen().emit_signal(&"continue_pressed" if index > 0 else &"new_game_pressed")
	await _until(flow.is_level_running)
	var id := String(flow.get_session().level.id)
	await _seconds(0.5)
	await _shot("b1_intro_%s" % id)
	match index:
		0:
			await _until(func() -> bool: return flow.get_session().spawner.current_wave() == 1)
			await _clear_until_wave(2)
			await _seconds(2.4)
			await _shot("b4_line_top")
		1:
			await _clear_until_wave(2)
			await _seconds(4.6)
			await _shot("b5_corners")
		3:
			await _until(func() -> bool: return not flow.get_session().spawner.active_markers().is_empty())
			await _seconds(0.35)
			await _shot("b2_surround_warn")
			await _until(func() -> bool: return flow.get_session().spawner.active_markers().is_empty())
			await _seconds(0.6)
			await _shot("b3_surround_spawn")
	await _clear_until(func() -> bool: return flow.state == FlowMain.State.RESULTS)
	await _seconds(1.5)
	await _shot("b6_results_%s" % id)
	if index == 0:
		flow.get_screen().emit_signal(&"continue_pressed")
		await _frames(4)
		await _shot("b7_transition")
	flow.queue_free()
	await _frames(5)


func _clear_until_wave(wave: int) -> void:
	await _clear_until(func() -> bool:
		var session := flow.get_session()
		return session != null and session.spawner != null and session.spawner.current_wave() >= wave)


## 一直擊倒可擊倒的敵人、選第一張把戲卡,直到 condition 成立。
func _clear_until(condition: Callable) -> void:
	var limit := Time.get_ticks_msec() + 120000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
		if flow.is_choice_open():
			var choice := flow.get_trick_choice()
			if choice != null and choice.visible and choice.has_method(&"choose"):
				choice.call(&"choose", 0)
			continue
		for node in get_tree().get_nodes_in_group(&"enemy"):
			if node.has_method(&"is_targetable") and node.call(&"is_targetable"):
				node.call(&"take_damage", 9999)


func _until(condition: Callable) -> void:
	var limit := Time.get_ticks_msec() + 60000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await get_tree().process_frame


func _seconds(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	image.save_png(shots_dir.path_join(file_name + ".png"))
