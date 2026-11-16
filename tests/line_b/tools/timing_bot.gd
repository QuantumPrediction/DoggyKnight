extends Node
## 關卡長度量測機器人(M3 調整難度用,不是自動化測試)。
## 用替身場地從新遊戲玩到打敗黑騎士:走向最近的敵人、停下自動攻擊、看到預警就閃開。
## 每關印出用時、擊倒數、等級與學會的把戲。機器人比真人有效率,真人通常會慢 20% 以上。
##
## 執行:godot --headless --path . res://tests/line_b/tools/timing_bot.tscn
## (4 倍速執行,約 1 至 2 分鐘。正式戰鬥合併後,結果會跟著 A 線的數值改變。)

const SAVE_PATH: String = "user://timing_bot_save.json"
const TIME_SCALE: float = 4.0
const TIMEOUT_MS: int = 300000

var flow: FlowMain


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _run() -> void:
	SaveStore.new(SAVE_PATH).delete()
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.use_stand_ins = true
	flow.rng_seed = 77
	add_child(flow)
	await _frames(3)
	Engine.time_scale = TIME_SCALE
	var downs := [0]
	EventBus.player_downed.connect(func() -> void: downs[0] += 1)
	flow.get_screen().emit_signal(&"new_game_pressed")
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame
		match flow.state:
			FlowMain.State.STORY:
				var box := flow.get_dialogue_box()      # 對白(v2.3):直接略過
				if box != null and box.call(&"is_active"):
					box.call(&"skip")
			FlowMain.State.LEVEL:
				if flow.is_choice_open():
					var offer := flow.progression.get_current_offer()
					if not offer.is_empty():
						EventBus.trick_chosen.emit(offer[0].id)
				else:
					_steer()
			FlowMain.State.RESULTS:
				var r := flow.get_last_result()
				print("%s  %5.1f 秒  擊倒 %2d  等級 %2d  把戲 %s  活力 %d" % [r["level_id"], r["time_sec"], r["kills"],
						r["hero_level"], r["tricks"], GameState.vigor])
				flow.get_screen().emit_signal(&"continue_pressed")
				await _frames(3)
			FlowMain.State.FAILURE:
				var r := flow.get_last_result()
				print("%s  失敗(%.1f 秒,擊倒 %d),重試" % [r["level_id"], r["time_sec"], r["kills"]])
				flow.get_screen().emit_signal(&"retry_pressed")
				await _frames(3)
			FlowMain.State.CAMP:
				print("營地")
				EventBus.camp_left.emit()
				await _frames(3)
			FlowMain.State.TITLE:
				if not flow.is_switching():
					break
	print("倒下 %d 次" % downs[0])
	Engine.time_scale = 1.0
	SaveStore.new(SAVE_PATH).delete()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _steer() -> void:
	var arena := flow.get_arena()
	var player: Node2D = arena.call(&"get_player") if arena != null else null
	if player == null:
		return
	var nearest: Node2D = null
	var nearest_distance := INF
	var danger := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		var distance := enemy.global_position.distance_to(player.global_position)
		if enemy.has_method(&"is_winding_up") and enemy.call(&"is_winding_up") and distance < 34.0:
			danger += (player.global_position - enemy.global_position).normalized()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	var direction := Vector2.ZERO
	if danger != Vector2.ZERO:
		direction = danger.normalized()
		if not Layout.ARENA_RECT.grow(-12.0).has_point(player.global_position + direction * 12.0):
			direction = (direction + (Layout.ARENA_RECT.get_center() - player.global_position).normalized()).normalized()
	elif nearest != null and nearest_distance > 26.0:
		direction = (nearest.global_position - player.global_position).normalized()
	player.set(&"direction", direction)
