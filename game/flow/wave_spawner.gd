class_name WaveSpawner
extends Node
## 波次生成器(B2)。讀 LevelData,依序生成每一波,透過場地的 spawn_enemy() 放出敵人。
##
## 規則:
## - 每一波開始時發 EventBus.wave_started(index, total)。index 從 1 起算(第 1 波 = 1),
##   HUD 可以直接用 tr("UI_WAVE") % [index, total] 顯示「第 1/3 波」。wave_cleared 用同一個 index。
## - SpawnEntry.delay = 這一組在本波開始後幾秒出現;同一組的 count 隻之間相隔
##   DifficultyData.spawn_spacing 秒。出生點取自 arena.get_spawn_points(),輪流使用並打散,
##   避開離金毛太近的點,再加一點隨機偏移,讓敵人分散出現。
## - 這一波全部放完、而且群組 "enemy" 沒有任何節點(頭目召喚的小怪也算)時,
##   發 wave_cleared(index),等 inter_wave_delay 秒再開始下一波。
## - 最後一波清空後發本地訊號 all_waves_cleared(LevelSession 據此發 level_completed)。
## - 用 _physics_process 計時,遊戲暫停時自動停住。

signal all_waves_cleared()

enum Phase { IDLE, WAITING, IN_WAVE, DONE }

var level: LevelData
var arena: Node
var difficulty: DifficultyData
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _phase: Phase = Phase.IDLE
var _wave: int = 0                       # 目前的波次(1 起算;0 = 還沒開始)
var _timer: float = 0.0                  # WAITING:倒數;IN_WAVE:本波已過的秒數
var _pending: Array[Dictionary] = []     # 本波還沒放出的敵人 {"time": float, "enemy_id": StringName}
var _not_yet_in_tree: Array[Node] = []   # spawn_enemy 傳回、但還沒進場景樹的敵人(仍算在場上)
var _point_order: Array[int] = []
var _point_cursor: int = 0


func setup(level_data: LevelData, arena_node: Node, curve: DifficultyData, random: RandomNumberGenerator = null) -> void:
	level = level_data
	arena = arena_node
	difficulty = curve
	if random != null:
		rng = random


func start() -> void:
	_wave = 0
	_pending.clear()
	_not_yet_in_tree.clear()
	if level == null or level.waves.is_empty():
		_phase = Phase.DONE
		all_waves_cleared.emit.call_deferred()
		return
	_phase = Phase.WAITING
	_timer = difficulty.first_wave_delay


## 停止生成(例如金毛倒下)。已在場上的敵人不受影響。
func stop() -> void:
	_phase = Phase.IDLE
	_pending.clear()


func current_wave() -> int:
	return _wave


func total_waves() -> int:
	return level.waves.size() if level != null else 0


func is_done() -> bool:
	return _phase == Phase.DONE


func is_running() -> bool:
	return _phase == Phase.WAITING or _phase == Phase.IN_WAVE


## 場上還有多少敵人(群組 "enemy" 的節點,加上剛生成、還沒進場景樹的)。
func enemies_remaining() -> int:
	var count := get_tree().get_node_count_in_group(&"enemy")
	for node in _not_yet_in_tree:
		if is_instance_valid(node):
			count += 1
	return count


func _physics_process(delta: float) -> void:
	step(delta)


## 讓時間前進 delta 秒(_physics_process 每格呼叫;測試可以關掉物理處理後自己呼叫)。
func step(delta: float) -> void:
	match _phase:
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_start_wave(_wave + 1)
		Phase.IN_WAVE:
			_timer += delta
			_spawn_due()
			if _pending.is_empty() and enemies_remaining() == 0:
				_finish_wave()


func _start_wave(number: int) -> void:
	_wave = number
	_timer = 0.0
	_phase = Phase.IN_WAVE
	_pending.clear()
	var wave: WaveData = level.waves[number - 1]
	for entry in wave.spawns:
		if entry == null:
			continue
		for i in maxi(0, entry.count):
			_pending.append({"time": entry.delay + i * difficulty.spawn_spacing, "enemy_id": entry.enemy_id,
					"order": _pending.size()})
	# 依出現時間排序;時間相同時保持資料檔裡的次序。
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["time"] < b["time"] or (a["time"] == b["time"] and a["order"] < b["order"]))
	EventBus.wave_started.emit(number, total_waves())
	if level.is_boss:
		Sfx.play(&"boss_warning")
	_spawn_due()


func _spawn_due() -> void:
	while not _pending.is_empty() and _pending[0]["time"] <= _timer:
		var item: Dictionary = _pending.pop_front()
		_spawn(item["enemy_id"])


func _spawn(enemy_id: StringName) -> void:
	if arena == null or not arena.has_method(&"spawn_enemy"):
		push_warning("WaveSpawner: 場地沒有 spawn_enemy(),略過 %s" % enemy_id)
		return
	var node: Variant = arena.call(&"spawn_enemy", enemy_id, _pick_spawn_point())
	if node is Node and not (node as Node).is_inside_tree():
		var enemy := node as Node
		_not_yet_in_tree.append(enemy)
		enemy.tree_entered.connect(_on_enemy_entered_tree.bind(enemy), CONNECT_ONE_SHOT)
	elif node == null:
		push_warning("WaveSpawner: spawn_enemy(%s) 沒有傳回敵人" % enemy_id)


func _on_enemy_entered_tree(enemy: Node) -> void:
	_not_yet_in_tree.erase(enemy)


func _finish_wave() -> void:
	_not_yet_in_tree.clear()
	EventBus.wave_cleared.emit(_wave)
	if _wave >= total_waves():
		_phase = Phase.DONE
		all_waves_cleared.emit()
	else:
		_phase = Phase.WAITING
		_timer = difficulty.inter_wave_delay


func _pick_spawn_point() -> Vector2:
	var points: Array = []
	if arena.has_method(&"get_spawn_points"):
		points = arena.call(&"get_spawn_points")
	if points.is_empty():
		return _jitter(Vector2(Layout.ARENA_RECT.get_center().x, Layout.ARENA_RECT.position.y + 8.0))
	if _point_order.size() != points.size():
		_reshuffle(points.size())
	var player_pos: Variant = _player_position()
	var chosen: Vector2 = points[_point_order[0]]
	for attempt in points.size():
		if _point_cursor >= _point_order.size():
			_reshuffle(points.size())
		chosen = points[_point_order[_point_cursor]]
		_point_cursor += 1
		if player_pos == null or chosen.distance_to(player_pos) >= difficulty.min_spawn_distance:
			break
	return _jitter(chosen)


func _player_position() -> Variant:
	if not arena.has_method(&"get_player"):
		return null
	var player: Variant = arena.call(&"get_player")
	if player is Node2D and is_instance_valid(player):
		return (player as Node2D).global_position
	return null


func _reshuffle(count: int) -> void:
	_point_order.clear()
	for i in count:
		_point_order.append(i)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := _point_order[i]
		_point_order[i] = _point_order[j]
		_point_order[j] = tmp
	_point_cursor = 0


func _jitter(point: Vector2) -> Vector2:
	var j := difficulty.spawn_jitter
	return point + Vector2(rng.randf_range(-j, j), rng.randf_range(-j, j))
