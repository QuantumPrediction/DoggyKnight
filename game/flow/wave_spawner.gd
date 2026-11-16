class_name WaveSpawner
extends Node
## 波次生成器(B2、BP7)。讀 LevelData,依序生成每一波,透過場地的 spawn_enemy() 放出敵人。
##
## 規則:
## - 每一波開始時發 EventBus.wave_started(index, total)。index 從 1 起算(第 1 波 = 1),
##   HUD 可以直接用 tr("UI_WAVE") % [index, total] 顯示「第 1/3 波」。wave_cleared 用同一個 index。
## - SpawnEntry.delay = 這一組在本波開始後幾秒出現。
## - SpawnEntry.pattern(出場隊形,DEV_PLAN 4.10):
##     edges     場邊(預設):出生點取自 arena.get_spawn_points(),輪流使用並打散,避開離金毛
##               min_spawn_distance 以內的點,再加一點隨機偏移;每隻相隔 spawn_spacing 秒。
##     surround  圍著金毛一圈(surround_radius),整組同時出現;先在地上顯示 surround_telegraph 秒的
##               預警記號(SpawnMarker),敵人就在記號的位置冒出來。貼牆時壓扁的點改用別的角度,
##               保證離金毛至少 surround_min_distance。
##     line_top  上方一排,由左到右每隻相隔 line_spacing 秒;金毛在上方時改在下方排一排。
##     corners   四個角落輪流,每一輪相隔 spawn_spacing 秒;跳過離金毛太近的角落。
##   所有位置都在 Layout.ARENA_RECT 之內(離邊緣 pattern_inset)。場地的 spawn_enemy() 還會
##   自己避開已在場上的敵人,所以同一點連續出來的敵人不會疊在一起。
## - 這一波全部放完、而且群組 "enemy" 沒有任何節點(頭目召喚的小怪也算)時,
##   發 wave_cleared(index),等 inter_wave_delay 秒再開始下一波。
## - 最後一波清空後發本地訊號 all_waves_cleared(LevelSession 據此發 level_completed)。
## - 用 _physics_process 計時,遊戲暫停時自動停住。

signal all_waves_cleared()
## 第 index 波開始(與 EventBus.wave_started 同時發出;LevelSession 用來知道開場結束)。
signal wave_began(index: int)

enum Phase { IDLE, WAITING, IN_WAVE, DONE }

const EDGES: StringName = &"edges"
const SURROUND: StringName = &"surround"
const LINE_TOP: StringName = &"line_top"
const CORNERS: StringName = &"corners"
const PATTERNS: Array[StringName] = [EDGES, SURROUND, LINE_TOP, CORNERS]
const ARENA_FALLBACK_POINT: Vector2 = Vector2(90, 84)

var level: LevelData
var arena: Node
var difficulty: DifficultyData
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _phase: Phase = Phase.IDLE
var _wave: int = 0                       # 目前的波次(1 起算;0 = 還沒開始)
var _timer: float = 0.0                  # WAITING:倒數;IN_WAVE:本波已過的秒數
## 本波還沒放出的敵人,依 time 排序:
## {"time": float, "enemy_id": StringName, "order": int, "group": int, "slot": int}
var _pending: Array[Dictionary] = []
## 本波每一組(一個 SpawnEntry)的隊形資料:
## {"pattern": StringName, "count": int, "telegraph_at": float(-1 = 不預警),
##  "positions": Array[Vector2](空 = 還沒決定), "markers": Array[Node]}
var _groups: Array[Dictionary] = []
var _not_yet_in_tree: Array[Node] = []   # spawn_enemy 傳回、但還沒進場景樹的敵人(仍算在場上)
var _point_order: Array[int] = []
var _point_cursor: int = 0
var _corner_turn: int = 0


func setup(level_data: LevelData, arena_node: Node, curve: DifficultyData, random: RandomNumberGenerator = null) -> void:
	level = level_data
	arena = arena_node
	difficulty = curve
	if random != null:
		rng = random


## 開始第一波的倒數。initial_delay < 0 時用 difficulty.first_wave_delay(LevelSession 傳入開場秒數)。
func start(initial_delay: float = -1.0) -> void:
	_wave = 0
	_clear_wave_state()
	_not_yet_in_tree.clear()
	if level == null or level.waves.is_empty():
		_phase = Phase.DONE
		all_waves_cleared.emit.call_deferred()
		return
	_phase = Phase.WAITING
	_timer = difficulty.first_wave_delay if initial_delay < 0.0 else initial_delay


## 停止生成(例如金毛倒下)。已在場上的敵人不受影響;還沒冒出來的預警記號會移除。
func stop() -> void:
	_phase = Phase.IDLE
	_clear_wave_state()


func current_wave() -> int:
	return _wave


func total_waves() -> int:
	return level.waves.size() if level != null else 0


func is_done() -> bool:
	return _phase == Phase.DONE


func is_running() -> bool:
	return _phase == Phase.WAITING or _phase == Phase.IN_WAVE


## 第一波開始之前(開場中)為 true。
func is_before_first_wave() -> bool:
	return _phase == Phase.WAITING and _wave == 0


## 場上還有多少敵人(群組 "enemy" 的節點,加上剛生成、還沒進場景樹的)。
func enemies_remaining() -> int:
	var count := get_tree().get_node_count_in_group(&"enemy")
	for node in _not_yet_in_tree:
		if is_instance_valid(node):
			count += 1
	return count


## 這一波還沒放出的敵人數目(包括正在預警的)。
func pending_count() -> int:
	return _pending.size()


## 目前地上的預警記號(測試與沙盒用)。
func active_markers() -> Array[Node]:
	var result: Array[Node] = []
	for group in _groups:
		for marker: Variant in group["markers"]:
			if marker is Node and is_instance_valid(marker):
				result.append(marker)
	return result


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
			_telegraph_due()
			_spawn_due()
			if _pending.is_empty() and enemies_remaining() == 0:
				_finish_wave()


func _start_wave(number: int) -> void:
	_wave = number
	_timer = 0.0
	_phase = Phase.IN_WAVE
	_clear_wave_state()
	var wave: WaveData = level.waves[number - 1]
	for entry in wave.spawns:
		if entry == null or entry.count <= 0:
			continue
		_schedule(entry)
	# 依出現時間排序;時間相同時保持資料檔裡的次序。
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["time"] < b["time"] or (a["time"] == b["time"] and a["order"] < b["order"]))
	EventBus.wave_started.emit(number, total_waves())
	wave_began.emit(number)
	if level.is_boss:
		Sfx.play(&"boss_warning")
	_telegraph_due()
	_spawn_due()


## 依隊形排定一組敵人的出現時間。
func _schedule(entry: SpawnEntry) -> void:
	var pattern := entry.pattern if PATTERNS.has(entry.pattern) else EDGES
	if pattern != entry.pattern:
		push_warning("WaveSpawner: 不認識的隊形 %s,改用 edges" % entry.pattern)
	var group_index := _groups.size()
	var telegraph_at := -1.0
	if pattern == SURROUND:
		telegraph_at = entry.delay
	_groups.append({"pattern": pattern, "count": entry.count, "telegraph_at": telegraph_at,
			"positions": [] as Array[Vector2], "markers": []})
	for i in entry.count:
		var time := entry.delay
		match pattern:
			SURROUND:
				time = entry.delay + difficulty.surround_telegraph
			LINE_TOP:
				time = entry.delay + i * difficulty.line_spacing
			CORNERS:
				@warning_ignore("integer_division")
				time = entry.delay + (i / 4) * difficulty.spawn_spacing
			_:
				time = entry.delay + i * difficulty.spawn_spacing
		_pending.append({"time": time, "enemy_id": entry.enemy_id, "order": _pending.size(),
				"group": group_index, "slot": i})


## 到了預警時間的 surround 組:決定圓圈上的位置,在地上放預警記號。
func _telegraph_due() -> void:
	for group in _groups:
		var at: float = group["telegraph_at"]
		if at < 0.0 or at > _timer or not (group["positions"] as Array).is_empty():
			continue
		var positions := surround_positions(group["count"], _player_position_or_start())
		group["positions"] = positions
		var markers: Array = []
		for p in positions:
			markers.append(_add_marker(p, difficulty.surround_telegraph))
		group["markers"] = markers
		Sfx.play(&"whoosh")


func _spawn_due() -> void:
	while not _pending.is_empty() and _pending[0]["time"] <= _timer:
		var item: Dictionary = _pending.pop_front()
		_spawn(item["enemy_id"], _position_for(item))
		_remove_marker(item)


func _position_for(item: Dictionary) -> Vector2:
	var group: Dictionary = _groups[item["group"]]
	var slot: int = item["slot"]
	match group["pattern"]:
		SURROUND:
			if (group["positions"] as Array).is_empty():
				group["positions"] = surround_positions(group["count"], _player_position_or_start())
			return group["positions"][slot]
		LINE_TOP:
			if (group["positions"] as Array).is_empty():
				group["positions"] = line_positions(group["count"], _player_position_or_start())
			return group["positions"][slot]
		CORNERS:
			return _corner_position()
		_:
			return _pick_spawn_point()


func _spawn(enemy_id: StringName, at: Vector2) -> void:
	if arena == null or not arena.has_method(&"spawn_enemy"):
		push_warning("WaveSpawner: 場地沒有 spawn_enemy(),略過 %s" % enemy_id)
		return
	var node: Variant = arena.call(&"spawn_enemy", enemy_id, at)
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
	_clear_wave_state()
	EventBus.wave_cleared.emit(_wave)
	if _wave >= total_waves():
		_phase = Phase.DONE
		all_waves_cleared.emit()
	else:
		_phase = Phase.WAITING
		_timer = difficulty.inter_wave_delay


func _clear_wave_state() -> void:
	_pending.clear()
	for group in _groups:
		for marker: Variant in group["markers"]:
			_free_marker(marker)
	_groups.clear()


# --- 隊形的位置 ---------------------------------------------------------------------

## 隊形可用的範圍:戰鬥區向內縮 pattern_inset。
func pattern_rect() -> Rect2:
	return Layout.ARENA_RECT.grow(-difficulty.pattern_inset)


## surround:以 center 為圓心、surround_radius 為半徑平均分佈 count 個點(起始角度隨機)。
## 每個點都在 pattern_rect() 之內;貼牆被壓得太近(< surround_min_distance)的點,改用附近的角度,
## 都不行就用離 center 最遠的角落。
func surround_positions(count: int, center: Vector2) -> Array[Vector2]:
	var rect := pattern_rect()
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	var start := rng.randf() * TAU
	for i in count:
		var angle := start + TAU * float(i) / float(count)
		result.append(_ring_point(center, angle, rect))
	return result


func _ring_point(center: Vector2, angle: float, rect: Rect2) -> Vector2:
	var step := deg_to_rad(15.0)
	for k in 13:
		for sign_value: float in [1.0, -1.0]:
			if k == 0 and sign_value < 0.0:
				continue
			var a := angle + sign_value * step * float(k)
			var p := _clamp_to(center + Vector2.from_angle(a) * difficulty.surround_radius, rect)
			if p.distance_to(center) >= difficulty.surround_min_distance:
				return p
	return _farthest_corner(center, rect)


## line_top:沿上邊(金毛在上方 line_flip_ratio 之內時改沿下邊)平均排 count 個點,由左到右。
func line_positions(count: int, player_pos: Vector2) -> Array[Vector2]:
	var rect := pattern_rect()
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	var y := rect.position.y
	if player_pos.y < rect.position.y + rect.size.y * difficulty.line_flip_ratio:
		y = rect.end.y
	for i in count:
		var x := lerpf(rect.position.x, rect.end.x, (float(i) + 0.5) / float(count))
		result.append(Vector2(x, y).round())
	return result


## corners:四個角落輪流;離金毛 min_spawn_distance 以內的角落這次跳過。
func corner_points() -> Array[Vector2]:
	var rect := pattern_rect()
	return [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]


func _corner_position() -> Vector2:
	var corners := corner_points()
	var player_pos := _player_position_or_start()
	for attempt in corners.size():
		var corner := corners[_corner_turn % corners.size()]
		_corner_turn += 1
		if corner.distance_to(player_pos) >= difficulty.min_spawn_distance:
			return corner
	return _farthest_corner(player_pos, pattern_rect())


func _farthest_corner(from: Vector2, rect: Rect2) -> Vector2:
	var best := rect.position
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]:
		if corner.distance_squared_to(from) > best.distance_squared_to(from):
			best = corner
	return best


func _clamp_to(p: Vector2, rect: Rect2) -> Vector2:
	return Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y)).round()


# --- edges(場邊):沿用場地的出生點 ---------------------------------------------------

func _pick_spawn_point() -> Vector2:
	var points: Array = []
	if arena.has_method(&"get_spawn_points"):
		points = arena.call(&"get_spawn_points")
	if points.is_empty():
		return _jitter(ARENA_FALLBACK_POINT)
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
	if arena == null or not arena.has_method(&"get_player"):
		return null
	var player: Variant = arena.call(&"get_player")
	if player is Node2D and is_instance_valid(player):
		return (player as Node2D).global_position
	return null


func _player_position_or_start() -> Vector2:
	var pos: Variant = _player_position()
	return pos if pos is Vector2 else Layout.PLAYER_START


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


# --- 預警記號 ----------------------------------------------------------------------

func _add_marker(at: Vector2, seconds: float) -> Node:
	if arena == null or not is_instance_valid(arena):
		return null
	var marker := SpawnMarker.new()
	marker.name = "SpawnMarker"
	marker.setup(at, seconds)
	var parent: Node = arena
	if arena.has_method(&"get_ground_layer"):
		var ground: Variant = arena.call(&"get_ground_layer")
		if ground is Node and is_instance_valid(ground):
			parent = ground
	else:
		marker.z_index = -5
	parent.add_child(marker)
	return marker


func _remove_marker(item: Dictionary) -> void:
	var group: Dictionary = _groups[item["group"]]
	var markers: Array = group["markers"]
	var slot: int = item["slot"]
	if slot < markers.size():
		_free_marker(markers[slot])
		markers[slot] = null


func _free_marker(marker: Variant) -> void:
	if marker is Node and is_instance_valid(marker):
		var node := marker as Node
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
