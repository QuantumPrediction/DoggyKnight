extends Node
## 整合試玩機器人(擁有者:整合工作階段)。不是自動化測試,而是 M2/M3 的工具。
##
## 用「全部正式零件」(A 線戰鬥、B 線流程、C 線介面、D 線營地)從標題玩到打敗黑騎士:
## 走向最近的敵人、停下自動攻擊、看到預警就閃開;升級時點第一張把戲卡;
## 忠誠度滿就按必殺技按鈕;營地裡玩一次卷軸小遊戲再繼續冒險。
## 每關印出用時、擊倒數、等級、把戲與剩餘活力,最後印出總結。
##
## 執行(headless,約 2 至 3 分鐘):
##   godot --headless --path . res://tests/integration/playthrough_bot.tscn
## 加截圖(需要畫面):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/integration/playthrough_bot.tscn -- --shots=/tmp/playthrough_shots
## 其他參數:--speed=4(倍速,預設 4)、--seed=7、--chapter=2(v2.6:玩第幾章,預設 1;會先把前面的章當作已通關)、
##   --hard(困難模式)、--reinforced(首兩關迎戰援軍)

const SAVE_PATH: String = "user://playthrough_bot_save.json"
const TIMEOUT_MS: int = 600000
const ATTACK_DISTANCE: float = 22.0
const DANGER_DISTANCE: float = 42.0
const BOSS_DANGER_DISTANCE: float = 110.0

var flow: FlowMain
var shots_dir: String = ""
var speed: float = 4.0
var rng_seed: int = 7
var chapter: int = 1
var hard: bool = false
var hero_class: StringName = &"knight"
var equipment_preset: String = "none"
var equipment_element: String = "default"
var movement_policy: String = "original"
var guard_policy: String = "off"
var route_choice: int = 0
var build_policy: String = "first"
var _moving_seconds: float = 0.0
var _standing_seconds: float = 0.0
var _empty_swings: int = 0
var _last_swing_count: int = 0
var report_path: String = ""
var max_downs: int = 0 # Existing interactive bot behavior remains unlimited by default.
var max_sim_seconds: float = 0.0
var _sim_seconds: float = 0.0
var _attempts: Array[Dictionary] = []
var _outcome: String = "wall_timeout"
var _starting_equipment: Dictionary = {}
var _enemy_serial: int = 0
var _player_serial: int = 0
var _minigame_serial: int = 0
var _escape_direction: Vector2 = Vector2.ZERO
var _escape_think_left: float = 0.0

var _downs: int = 0
var _ultimates: int = 0
var _level_lines: PackedStringArray = []
var _shot_flags: Dictionary = {}
var _level_clock: float = 0.0
var _dialogues: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg.begins_with("--seed="):
			rng_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--chapter="):
			chapter = clampi(int(arg.trim_prefix("--chapter=")), 1, GameState.CHAPTER_COUNT)
		elif arg == "--hard":
			hard = true
		elif arg.begins_with("--class="):
			hero_class = HeroClasses.valid_id(arg.trim_prefix("--class="))
		elif arg.begins_with("--gear="):
			equipment_preset = arg.trim_prefix("--gear=")
		elif arg.begins_with("--element="):
			equipment_element = arg.trim_prefix("--element=")
		elif arg.begins_with("--policy="):
			movement_policy = arg.trim_prefix("--policy=")
		elif arg.begins_with("--guard="):
			guard_policy = arg.trim_prefix("--guard=")
		elif arg.begins_with("--route="):
			route_choice = clampi(int(arg.trim_prefix("--route=")), 0, 1)
		elif arg == "--build=route":
			build_policy = "route"
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--max-downs="):
			max_downs = maxi(0, int(arg.trim_prefix("--max-downs=")))
		elif arg.begins_with("--max-sim-seconds="):
			max_sim_seconds = maxf(0.0, float(arg.trim_prefix("--max-sim-seconds=")))
	if not ["original", "cautious", "escape"].has(movement_policy) or not ["off", "reactive"].has(guard_policy) or not preload("res://tests/integration/equipment_profiles.gd").PRESETS.has(equipment_preset) or (equipment_element != "default" and not EquipmentInventory.ELEMENTS.has(equipment_element)):
		push_error("Unknown equipment preset: " + equipment_preset)
		get_tree().quit(2)
		return
	if not shots_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shots_dir)
	_run()


func _run() -> void:
	seed(rng_seed)
	Loot.seed_rng(rng_seed + 200)
	# node_added fires before _ready: actor initial decisions must use the test seed too.
	get_tree().node_added.connect(_seed_added_node)
	SaveStore.new(SAVE_PATH).delete()
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.use_stand_ins = false
	flow.rng_seed = rng_seed
	add_child(flow)
	EventBus.player_downed.connect(func() -> void: _downs += 1)
	EventBus.ultimate_used.connect(func() -> void: _ultimates += 1)
	EventBus.level_started.connect(func(_id: StringName) -> void:
		_level_clock = 0.0
		_moving_seconds = 0.0
		_standing_seconds = 0.0
		_empty_swings = 0
		_last_swing_count = 0
		_escape_direction = Vector2.ZERO
		_escape_think_left = 0.0)
	await _frames(10)
	await _shot("00_title")
	# 標題畫面在 new_game_pressed 之前設定章與難度(DEV_PLAN 4.11、4.13);機器人直接設定。
	GameState.chapters_cleared = maxi(GameState.chapters_cleared, chapter - 1)
	GameState.chapter_cleared = GameState.chapter_cleared or chapter > 1 or hard
	GameState.chapter = chapter
	GameState.hero_class = hero_class
	GameState.meta_upgrades = {}
	GameState.equipment = preload("res://tests/integration/equipment_profiles.gd").make(String(hero_class), equipment_preset)
	if equipment_element != "default":
		for id: String in GameState.equipment.owned:
			if EquipmentInventory.item(id).slot in ["weapon", "armor"]:
				EquipmentInventory.transact(GameState.equipment, "attune", id, String(hero_class), equipment_element)
	_starting_equipment = EquipmentInventory.loadout(GameState.equipment, String(hero_class))
	GameState.difficulty = &"hard" if hard else &"normal"
	if not hard and OS.get_cmdline_user_args().has("--reinforced"):
		GameState.difficulty = &"reinforced"
	print("== 第 %d 章%s / %s ==" % [chapter, "(困難)" if hard else "", hero_class])
	flow.get_screen().emit_signal(&"new_game_pressed")
	Engine.time_scale = speed
	var started := Time.get_ticks_msec()
	var finished := false
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame
		_sim_seconds += get_process_delta_time()
		if max_sim_seconds > 0.0 and _sim_seconds >= max_sim_seconds:
			_outcome = "simulation_limit"
			break
		if _skip_dialogues():
			continue
		match flow.state:
			FlowMain.State.LEVEL:
				_level_clock += get_process_delta_time()
				await _play_level()
			FlowMain.State.RESULTS:
				await _on_results()
			FlowMain.State.FAILURE:
				var r := flow.get_last_result()
				_record_attempt(r)
				_level_lines.append("%s  失敗 %5.1f 秒  擊倒 %2d" % [r["level_id"], r["time_sec"], r["kills"]])
				await _shot("fail_%s" % r["level_id"])
				if max_downs > 0 and _downs >= max_downs:
					_outcome = "down_limit"
					break
				flow.get_screen().emit_signal(&"retry_pressed")
				await _frames(5)
			FlowMain.State.CAMP:
				await _play_camp()
			FlowMain.State.TITLE:
				# Returning to title alone must never count as a successful chapter.
				finished = not _attempts.is_empty() and bool(_attempts[-1].get("is_final", false)) and bool(_attempts[-1].get("victory", false))
				_outcome = "complete" if finished else "unexpected_title"
				break
	Engine.time_scale = 1.0
	print("\n== 試玩結果 ==")
	for line in _level_lines:
		print(line)
	print("倒下 %d 次;必殺技 %d 次;略過對白 %d 段;最後活力 %d" % [_downs, _ultimates, _dialogues, GameState.vigor])
	print("PLAYTHROUGH %s" % ("COMPLETE" if finished else "TIMEOUT"))
	var report_ok := _write_report(finished)
	SaveStore.new(SAVE_PATH).delete()
	get_tree().quit(2 if not report_ok else (0 if finished else 1))

func _seed_added_node(node: Node) -> void:
	if node is EnemyBase:
		_enemy_serial += 1
		(node as EnemyBase).rng_seed_override = rng_seed + 10000 + _enemy_serial * 97
	elif node is GoldiePlayer:
		_player_serial += 1
		(node as GoldiePlayer).rng.seed = rng_seed + 100 + _player_serial
	elif node is MinigameBase:
		_minigame_serial += 1
		var minigame := node as MinigameBase
		minigame.config = minigame.config.duplicate() as MinigameConfig if minigame.config != null else MinigameConfig.new()
		minigame.config.rng_seed = rng_seed + 300 + _minigame_serial

func _record_attempt(result: Dictionary) -> void:
	var row := result.duplicate(true)
	row["remaining_vigor"] = GameState.vigor
	row["max_vigor"] = GameState.player_stats.max_vigor
	row["build_tricks"] = GameState.active_tricks.duplicate()
	row["moving_seconds"] = _moving_seconds
	row["standing_seconds"] = _standing_seconds
	row["melee_empty_swings"] = _empty_swings
	row["guard_commands"] = 0
	row["guard_protected_hits"] = 0
	row["guard_prevented_damage"] = 0
	for node in get_tree().get_nodes_in_group(&"companion"):
		if node.has_method(&"is_protecting"):
			row["guard_commands"] += int(node.get("rally_commands"))
			row["guard_protected_hits"] += int(node.get("rally_protected_hits"))
			row["guard_prevented_damage"] += int(node.get("rally_prevented_damage"))
	_attempts.append(row)

func _write_report(finished: bool) -> bool:
	if report_path.is_empty():
		return true
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write bot report: " + report_path)
		return false
	file.store_string(JSON.stringify({"schema": 3, "engine": Engine.get_version_info().string,
		"movement_policy": movement_policy, "guard_policy": guard_policy,
		"route_choice": route_choice, "build_policy": build_policy, "route": String(GameState.run_route),
		"hero": String(hero_class), "chapter": chapter, "seed": rng_seed, "hard": hard,
		"equipment_preset": equipment_preset, "equipment_element": equipment_element, "starting_equipment": _starting_equipment,
		"training": {}, "speed": speed, "max_downs": max_downs, "max_sim_seconds": max_sim_seconds,
		"finished": finished, "outcome": _outcome, "downs": _downs, "ultimates": _ultimates,
		"simulation_seconds": _sim_seconds, "attempts": _attempts,
		"seed_scope": "Global, flow, enemy spawn order, player crit, loot, equipment drops and minigames; cosmetic camp dialogue RNG is not seeded.",
		"limits": "Staged gear, class-specific bot; first offered trick unless build_policy=route (eligible evolution, then route preference, then first). Automatic dialogue skip and camp bot. Engineering evidence, not human balance or retention."}, "\t") + "\n")
	file.close()
	return true


func _play_level() -> void:
	if flow.is_pause_open():
		return
	if flow.is_choice_open():
		await _shot_once("trick_choice", "02_trick_choice")
		var choice := flow.get_trick_choice()
		if choice != null and choice.visible:
			choice.call(&"choose", _build_choice_index())
		return
	var level_id := String(flow.get_session().level.id) if flow.get_session() != null else ""
	if _level_clock > 6.0:
		await _shot_once("level_" + level_id, "01_level_%s" % level_id)
	if _level_clock > 22.0:   # 關卡標題卡早已消失,拍戰鬥正激烈的一刻
		await _shot_once("level_mid_" + level_id, "01_level_%s_mid" % level_id)
	if _level_clock > 40.0:   # 頭目戰比較長:再拍一張,頭目與預警都在畫面上
		await _shot_once("level_late_" + level_id, "01_level_%s_late" % level_id)
	_press_ultimate_if_ready()
	_steer()

func _build_choice_index() -> int:
	if flow.is_event_open():
		return route_choice if BuildRoutes.is_route_event(flow.level_events.get_open_id()) else 0
	if build_policy != "route":
		return 0
	var route := BuildRoutes.get_route(GameState.run_route)
	var offer := flow.progression.get_current_offer()
	if route == null:
		return 0
	for i in offer.size():
		if offer[i].is_evolution:
			return i
	for id in route.preferred:
		for i in offer.size():
			if offer[i].id == id:
				return i
	return 0


func _press_ultimate_if_ready() -> void:
	var hud := flow.get_hud()
	if hud == null:
		return
	var button: BaseButton = hud.get(&"ultimate_button")
	if button != null and button.visible and not button.disabled:
		button.pressed.emit()


func _steer() -> void:
	var arena := flow.get_arena()
	var player := arena.call(&"get_player") as Node2D if arena != null else null
	if player == null or not player.has_method(&"set_move_override"):
		return
	var nearest: Node2D = null
	var nearest_distance := INF
	var danger := Vector2.ZERO
	var nearby_count := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance < 55.0:
			nearby_count += 1
		var telegraph: Variant = enemy.get(&"_telegraph")
		var is_boss := enemy is BlackKnightBoss
		var reach := BOSS_DANGER_DISTANCE if is_boss else DANGER_DISTANCE
		if movement_policy == "original" and telegraph != null and is_instance_valid(telegraph) and distance < reach:
			var away := (player.global_position - enemy.global_position).normalized()
			danger += away * (reach - distance)
			if is_boss:
				# 頭目的衝鋒是直線:往側面閃比往後退有效。
				danger += away.orthogonal() * reach
		var targetable: bool = enemy.call(&"is_targetable") if enemy.has_method(&"is_targetable") else true
		if targetable and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	danger += _telegraph_escape(player.global_position)
	if guard_policy == "reactive" and EventBus.has_signal(&"companion_guard_requested") and (nearby_count >= 2 or danger != Vector2.ZERO):
		# Uses the same public command as Q/touch. It does not edit stats or clocks.
		EventBus.emit_signal(&"companion_guard_requested")
	var direction := Vector2.ZERO
	if danger != Vector2.ZERO:
		direction = danger.normalized()
		var ahead := player.global_position + direction * 14.0
		if not Layout.ARENA_RECT.grow(-14.0).has_point(ahead):
			direction = (direction + (Layout.ARENA_RECT.get_center() - player.global_position).normalized()).normalized()
	elif nearest != null:
		var desired := ATTACK_DISTANCE if hero_class == &"knight" else GameState.player_stats.attack_range * 0.72
		if movement_policy == "cautious" and hero_class == &"knight":
			var body: Variant = nearest.get(&"body_radius")
			desired = GameState.player_stats.attack_range + (float(body) if body != null else 6.0) - 4.0
		if nearest_distance > desired:
			direction = (nearest.global_position - player.global_position).normalized()
		elif hero_class != &"knight" and nearest_distance < 32.0:
			# Kiting uses the same visible positions as a player. Never edit combat stats.
			var away := (player.global_position - nearest.global_position).normalized()
			if Layout.ARENA_RECT.grow(-14.0).has_point(player.global_position + away * 18.0):
				direction = away
	if movement_policy == "escape":
		_escape_think_left -= get_process_delta_time()
		if _escape_think_left <= 0.0:
			_escape_think_left = 0.12
			_escape_direction = preload("res://tests/integration/escape_policy.gd").choose(
				get_tree(), player.global_position, hero_class, GameState.player_stats.attack_range, _escape_direction)
		direction = _escape_direction
	player.call(&"set_move_override", direction)
	if direction == Vector2.ZERO:
		_standing_seconds += get_process_delta_time()
	else:
		_moving_seconds += get_process_delta_time()
	if hero_class == &"knight":
		var swings := int(player.get(&"swing_count"))
		if swings > _last_swing_count and int(player.get(&"last_swing_hits")) == 0:
			_empty_swings += swings - _last_swing_count
		_last_swing_count = swings


## v2.7:新頭目(章魚王、雙龍、莫德雷德等)把預警直接放在場上(AttackTelegraph,群組 combat_fx),
## 不在敵人的 _telegraph 欄位裡。像真人玩家一樣看地上的紅圈、扇形與紅線:站在裡面(或很接近)就往外閃。
const TELEGRAPH_MARGIN: float = 10.0


func _telegraph_escape(at: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"combat_fx"):
		var mark := node as AttackTelegraph
		if mark == null or not is_instance_valid(mark) or not mark.visible:
			continue
		var origin := mark.global_position
		var urgency := 1.0 + mark.progress * 2.0
		match mark.shape:
			AttackTelegraph.Shape.CIRCLE:
				var offset := at - origin
				var r := mark.radius * absf(mark.global_scale.x) + TELEGRAPH_MARGIN
				if offset.length() < r:
					push += (offset.normalized() if offset.length() > 0.5 else Vector2.RIGHT) * (r - offset.length() + 4.0) * urgency
			AttackTelegraph.Shape.LINE:
				var dir := mark.global_transform.basis_xform(mark.direction).normalized()
				var rel := at - origin
				var along := rel.dot(dir)
				var side := rel.dot(dir.orthogonal())
				var half := mark.width * 0.5 + TELEGRAPH_MARGIN
				if along > -TELEGRAPH_MARGIN and along < mark.length + TELEGRAPH_MARGIN and absf(side) < half:
					var away := dir.orthogonal() * (1.0 if side >= 0.0 else -1.0)
					push += away * (half - absf(side) + 4.0) * urgency * 2.0
			AttackTelegraph.Shape.SECTOR:
				var dir := mark.global_transform.basis_xform(mark.direction).normalized()
				var rel := at - origin
				var r := mark.radius + TELEGRAPH_MARGIN
				if rel.length() < r and absf(dir.angle_to(rel)) < mark.half_angle + 0.25:
					var side := 1.0 if dir.cross(rel) >= 0.0 else -1.0
					push += (dir.orthogonal() * side + rel.normalized()).normalized() * (r - rel.length() + 4.0) * urgency
	return push


func _on_results() -> void:
	_level_clock = 0.0   # 下一關在畫面露出前就進入 LEVEL;由結算時歸零,截圖才會在關卡進行中拍
	var r := flow.get_last_result()
	_record_attempt(r)
	_level_lines.append("%s  %5.1f 秒  擊倒 %2d  等級 %2d  把戲 %s  活力 %d" % [
			r["level_id"], r["time_sec"], r["kills"], r["hero_level"], r["tricks"], GameState.vigor])
	await _frames(20)
	await _shot("03_results_%s" % r["level_id"])
	flow.get_screen().emit_signal(&"continue_pressed")
	await _frames(5)


func _play_camp() -> void:
	var camp := flow.get_camp()
	if camp == null:
		return
	await _frames(20)
	for i in 600:   # 營地對白(D 線)播完才有選單
		if not _skip_dialogues():
			break
		await _frames(5)
	await _shot_once("camp_%d" % flow.get_level_index(), "04_camp_%d" % flow.get_level_index())
	camp.call(&"open_minigame")
	await _frames(5)
	var minigame := camp.call(&"get_minigame") as MinigameBase
	var shot_taken := false
	while minigame != null and is_instance_valid(minigame) and minigame.state != MinigameBase.State.CLOSED:
		await get_tree().process_frame
		if minigame.state == MinigameBase.State.PLAYING:
			# v2.7:每個小遊戲都有 bot_step()(D 線,MinigameBase),捲軸、叫醒騎士、接住跳跳魚都會自己玩
			minigame.bot_step(get_process_delta_time())
			if not shot_taken and minigame.play_elapsed > 4.0:
				shot_taken = true
				await _shot("05_minigame")
		elif minigame.state == MinigameBase.State.RESULTS and minigame.get_state_time() > 1.3:
			await _shot_once("minigame_results", "06_minigame_results")
			minigame.close()
	_level_lines.append("營地:小遊戲完成,活力 %d,下一關加成 %.0f%%" % [GameState.vigor, GameState.next_level_bonus * 100.0])
	await _frames(10)
	camp.call(&"leave_camp")
	await _frames(5)


## 有對白正在播放就略過(先截一張圖)。傳回 true 表示這一格處理了對白。
func _skip_dialogues() -> bool:
	for box in get_tree().get_nodes_in_group(&"dialogue_box"):
		if box.has_method(&"is_active") and box.call(&"is_active"):
			_dialogues += 1
			if _dialogues <= 3 or _dialogues % 5 == 0:
				_shot("07_dialogue_%02d" % _dialogues)
			box.call(&"skip")
			return true
	return false


func _shot_once(flag: String, file_name: String) -> void:
	if _shot_flags.has(flag):
		return
	_shot_flags[flag] = true
	await _shot(file_name)


func _shot(file_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	image.save_png(shots_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
