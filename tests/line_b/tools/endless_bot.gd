extends Node
## B 線的量度工具(v2.4 BV6):用全部正式零件玩無盡試煉。不是自動化測試。
##
##   godot --headless --path . res://tests/line_b/tools/endless_bot.tscn -- --seed=7
## 參數:
##   --seed=N      亂數種子(預設 7)
##   --speed=N     倍速(預設 4)
##   --kill=N      不玩,直接擊倒敵人,檢查前 N 波(頭目波、事件、困難倍數)都能正常進行(預設 0 = 用機器人玩)
## 機器人的走法與 tests/integration/playthrough_bot.gd 相同(走向最近的敵人、停下攻擊、看到預警閃開);
## 升級、寶箱、事件都選第一項,忠誠度滿就放必殺技;倒下(不復活)就結束,印出每一波的用時與最後的紀錄。

const SAVE_PATH: String = "user://endless_bot_save.json"
const TIMEOUT_MS: int = 900000
const ATTACK_DISTANCE: float = 22.0
const DANGER_DISTANCE: float = 42.0
const BOSS_DANGER_DISTANCE: float = 110.0

var flow: FlowMain
var speed: float = 4.0
var rng_seed: int = 7
var kill_waves: int = 0
var _lines: PackedStringArray = []
var _wave_clock: float = 0.0
var _events: int = 0
var _evolutions: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			rng_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg.begins_with("--kill="):
			kill_waves = int(arg.trim_prefix("--kill="))
	_run()


func _run() -> void:
	SaveStore.new(SAVE_PATH).delete()
	GameState.chapter_cleared = true
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.rng_seed = rng_seed
	add_child(flow)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.event_offered.connect(func(id: StringName, _o: Array) -> void:
		_events += 1
		_lines.append("  事件 %s" % id))
	EventBus.trick_evolved.connect(func(id: StringName) -> void:
		_evolutions += 1
		_lines.append("  進化 %s" % id))
	EventBus.boss_appeared.connect(func(id: StringName) -> void: _lines.append("  頭目 %s" % id))
	await _frames(5)
	GameState.mode = &"endless"
	flow.get_screen().emit_signal(&"endless_pressed")
	Engine.time_scale = speed
	var started := Time.get_ticks_msec()
	var finished := false
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame
		if flow.state == FlowMain.State.FAILURE:
			finished = true
			break
		if flow.state != FlowMain.State.LEVEL:
			continue
		_wave_clock += get_process_delta_time()
		if flow.is_choice_open():
			var choice := flow.get_trick_choice()
			if choice != null and choice.visible:
				choice.call(&"choose", 0)
			continue
		if kill_waves > 0:
			if flow.get_session().waves_cleared >= kill_waves:
				finished = true
				break
			for node in get_tree().get_nodes_in_group(&"enemy"):
				if node.has_method(&"is_targetable") and node.call(&"is_targetable"):
					node.call(&"take_damage", 9999)
			continue
		_press_ultimate_if_ready()
		_steer()
	Engine.time_scale = 1.0
	print("\n== 無盡試煉 ==")
	for line in _lines:
		print(line)
	var session := flow.get_session()
	var cleared := session.waves_cleared if session != null else 0
	print("清了 %d 波;最佳紀錄 %d;零食 %d;等級 %d;事件 %d;進化 %d;把戲 %s" % [cleared, GameState.endless_best,
			GameState.snacks, GameState.hero_level, _events, _evolutions, GameState.active_tricks])
	print("ENDLESS %s" % ("DONE" if finished else "TIMEOUT"))
	SaveStore.new(SAVE_PATH).delete()
	get_tree().quit(0 if finished else 1)


func _on_wave_cleared(index: int) -> void:
	_lines.append("第 %2d 波 %5.1f 秒  活力 %3d  等級 %2d" % [index, _wave_clock, GameState.vigor, GameState.hero_level])
	_wave_clock = 0.0


func _press_ultimate_if_ready() -> void:
	var hud := flow.get_hud()
	if hud == null:
		return
	var button: Variant = hud.get(&"ultimate_button")
	if button is BaseButton and (button as BaseButton).visible and not (button as BaseButton).disabled:
		(button as BaseButton).pressed.emit()


func _steer() -> void:
	var arena := flow.get_arena()
	var player := arena.call(&"get_player") as Node2D if arena != null else null
	if player == null or not player.has_method(&"set_move_override"):
		return
	var nearest: Node2D = null
	var nearest_distance := INF
	var danger := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		var telegraph: Variant = enemy.get(&"_telegraph")
		var is_boss := enemy is BossBase
		var reach := BOSS_DANGER_DISTANCE if is_boss else DANGER_DISTANCE
		if telegraph != null and is_instance_valid(telegraph) and distance < reach:
			var away := (player.global_position - enemy.global_position).normalized()
			danger += away * (reach - distance)
			if is_boss:
				danger += away.orthogonal() * reach
		var targetable: bool = enemy.call(&"is_targetable") if enemy.has_method(&"is_targetable") else true
		if targetable and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	var direction := Vector2.ZERO
	if danger != Vector2.ZERO:
		direction = danger.normalized()
		var ahead := player.global_position + direction * 14.0
		if not Layout.ARENA_RECT.grow(-14.0).has_point(ahead):
			direction = (direction + (Layout.ARENA_RECT.get_center() - player.global_position).normalized()).normalized()
	elif nearest != null and nearest_distance > ATTACK_DISTANCE:
		direction = (nearest.global_position - player.global_position).normalized()
	player.call(&"set_move_override", direction)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
