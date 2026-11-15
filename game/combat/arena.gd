class_name CombatArena
extends Node2D
## 戰鬥場地(A12)。合約見 DEV_PLAN 4.4、4.9。
##
## 場景內容:背景(預設 meadow,可用 set_background 換)、戰鬥區四邊的牆(Layout.ARENA_RECT,
## 主角與敵人都穿不過)、置中的 Camera2D(SafeArea.GAME_CENTER)、主角(Layout.PLAYER_START)。
## 場地要放在世界原點(DEV_PLAN 4.8 的座標約定),B 線實例化後直接加進樹即可。
##
## 圖層(由下而上):Background(-100)→ GroundFx(-10,塵土、震波、盔甲碎片)→ Pickups(-5,經驗珠)
## → Entities(y 排序:主角、同伴、敵人)→ Fx(10,刀光、火花、必殺技)。

const ENEMY_DATA_PATH := "res://data/enemies/%s.tres"
const COMPANION_DATA_PATH := "res://data/companions/%s.tres"
const EXP_ORB_SCENE: PackedScene = preload("res://game/combat/exp_orb.tscn")
const ARENA_GROUP: StringName = &"arena"
const ENEMY_GROUP: StringName = &"enemy"
const COMPANION_GROUP: StringName = &"companion"
const GOLDEN_ANGLE := 2.39996

@export var spawn_telegraph_time: float = -1.0    ## 出場預警秒數;< 0 表示用各敵人自己的 spawn_time
@export var spawn_point_inset: float = 14.0       ## 生成點離場地邊緣的距離
@export var spawn_min_player_distance: float = 72.0
@export var min_spawn_points: int = 3
@export var spawn_spacing: float = 14.0           ## 同一點連續生成時,新敵人與已在場敵人至少相隔多遠
@export var wall_thickness: float = 32.0
@export var companion_offset: Vector2 = Vector2(-18, 8)

var background: Node2D
var ground_layer: Node2D
var pickups: Node2D
var entities: Node2D
var fx_layer: Node2D
var camera: Camera2D
var player: Node2D

var _spawn_counter: int = 0
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _shake_strength: float = 0.0


func _ready() -> void:
	add_to_group(ARENA_GROUP)
	background = $Background as Node2D
	ground_layer = $GroundFx as Node2D
	pickups = $Pickups as Node2D
	entities = $Entities as Node2D
	fx_layer = $Fx as Node2D
	camera = $Camera2D as Camera2D
	player = get_node_or_null(^"Entities/Player") as Node2D
	_build_walls()
	camera.position = SafeArea.GAME_CENTER
	camera.make_current()
	if player != null:
		player.position = Layout.PLAYER_START


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_strength = 0.0
		return
	var s := _shake_strength * _shake_left / maxf(_shake_total, 0.001)
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round()


# --- 合約方法(DEV_PLAN 4.4) -------------------------------------------------------

## 讀取 data/enemies/<enemy_id>.tres 生成敵人。敵人立刻在群組 "enemy" 之內,
## 但先播短暫的塵土出場預警才開始行動。位置會被限制在戰鬥區內;同一點生成多隻時,
## 會在附近找空位(不疊在一起)。找不到資料時傳回 null。
func spawn_enemy(enemy_id: StringName, at: Vector2) -> Node:
	var path := ENEMY_DATA_PATH % enemy_id
	if not ResourceLoader.exists(path):
		push_warning("CombatArena: 找不到敵人資料 %s" % path)
		return null
	var data := load(path) as EnemyData
	if data == null or data.scene == null:
		push_warning("CombatArena: 敵人資料不完整 %s" % path)
		return null
	var enemy := data.scene.instantiate() as Node2D
	if enemy == null:
		return null
	if enemy.has_method(&"setup"):
		enemy.call(&"setup", data)
	if &"arena" in enemy:
		enemy.set(&"arena", self)
	var r: Variant = enemy.get(&"body_radius")
	enemy.position = _free_spot(at, float(r) if r != null else 6.0)
	entities.add_child(enemy)
	if not enemy.is_in_group(ENEMY_GROUP):
		enemy.add_to_group(ENEMY_GROUP)
	if enemy.has_method(&"begin_spawn"):
		enemy.call(&"begin_spawn", spawn_telegraph_time)
	return enemy


## 生成點:戰鬥區內、靠近四邊、離主角夠遠。至少傳回 min_spawn_points 個(主角在角落時取最遠的幾個)。
func get_spawn_points() -> Array[Vector2]:
	var r := Layout.ARENA_RECT.grow(-spawn_point_inset)
	var candidates: Array[Vector2] = []
	for i in 5:
		candidates.append(Vector2(lerpf(r.position.x, r.end.x, float(i) / 4.0), r.position.y))
	for i in 3:
		candidates.append(Vector2(lerpf(r.position.x, r.end.x, float(i) / 2.0), r.end.y))
	for i in range(1, 4):
		var y := lerpf(r.position.y, r.end.y, float(i) / 4.0)
		candidates.append(Vector2(r.position.x, y))
		candidates.append(Vector2(r.end.x, y))
	var player_pos := player.global_position if player != null else Layout.PLAYER_START
	var far: Array[Vector2] = []
	for point in candidates:
		if point.distance_to(player_pos) >= spawn_min_player_distance:
			far.append(point)
	if far.size() >= min_spawn_points:
		return far
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(player_pos) > b.distance_squared_to(player_pos))
	return candidates.slice(0, min_spawn_points)


## 清場:移除敵人(立刻離開群組 "enemy",不發 enemy_died)、經驗珠與特效。主角與同伴保留。
func clear() -> void:
	for node in entities.get_children():
		if node == player or node.is_in_group(COMPANION_GROUP):
			continue
		if node.is_in_group(ENEMY_GROUP):
			node.remove_from_group(ENEMY_GROUP)
		node.queue_free()
	for layer: Node in [pickups, ground_layer, fx_layer]:
		for child in layer.get_children():
			if child.is_in_group(ExpOrb.GROUP):
				child.remove_from_group(ExpOrb.GROUP)
			child.queue_free()


## 讀取 data/companions/<companion_id>.tres 生成同伴,放在主角身旁。同一個同伴已在場上時傳回原本那隻。
func spawn_companion(companion_id: StringName) -> Node:
	for node in entities.get_children():
		if node.is_in_group(COMPANION_GROUP) and node.get(&"companion_id") == companion_id:
			return node
	var path := COMPANION_DATA_PATH % companion_id
	if not ResourceLoader.exists(path):
		push_warning("CombatArena: 找不到同伴資料 %s" % path)
		return null
	var data := load(path) as CompanionData
	if data == null or data.scene == null:
		push_warning("CombatArena: 同伴資料不完整 %s" % path)
		return null
	var companion := data.scene.instantiate() as Node2D
	if companion == null:
		return null
	if companion.has_method(&"setup"):
		companion.call(&"setup", data)
	var anchor := player.position if player != null else Layout.PLAYER_START
	companion.position = CombatMath.clamp_to_arena(anchor + companion_offset, 8.0)
	entities.add_child(companion)
	if not companion.is_in_group(COMPANION_GROUP):
		companion.add_to_group(COMPANION_GROUP)
	CombatFx.spawn(self, &"dust", companion.global_position, 0.0, Vector2.ONE * 1.4, Color.WHITE, true)
	return companion


## 換背景(assets/backgrounds/*.tscn)。傳入 null 只清掉現有背景。
func set_background(scene: PackedScene) -> void:
	for child in background.get_children():
		background.remove_child(child)
		child.queue_free()
	if scene != null:
		background.add_child(scene.instantiate())


func get_player() -> Node2D:
	return player


# --- 其他方法(A 線內部使用) ----------------------------------------------------------

func get_fx_layer() -> Node2D:
	return fx_layer


func get_ground_layer() -> Node2D:
	return ground_layer


func get_enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group(ENEMY_GROUP)


func spawn_exp_orb(at: Vector2, value: int) -> Node2D:
	var orb := EXP_ORB_SCENE.instantiate() as ExpOrb
	orb.value = value
	pickups.add_child(orb)
	orb.pop_from(at)
	return orb


## 鏡頭震動(邏輯像素,四捨五入到整數,保持像素清晰)。
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_left = maxf(_shake_left, duration)
	_shake_total = _shake_left


## 在 at 附近找一個沒有敵人的位置(黃金角螺旋向外找)。
func _free_spot(at: Vector2, radius: float) -> Vector2:
	var spacing := maxf(spawn_spacing, radius * 2.0 + 2.0)
	var others := get_tree().get_nodes_in_group(ENEMY_GROUP)
	_spawn_counter += 1
	var turn := float(_spawn_counter) * GOLDEN_ANGLE
	for k in 24:
		var offset := Vector2.ZERO if k == 0 else Vector2.from_angle(turn + float(k) * GOLDEN_ANGLE) * spacing * sqrt(float(k))
		var candidate := CombatMath.clamp_to_arena(at + offset, radius)
		var free := true
		for node in others:
			var other := node as Node2D
			if other != null and other.global_position.distance_to(candidate) < spacing:
				free = false
				break
		if free:
			return candidate
	return CombatMath.clamp_to_arena(at + Vector2.from_angle(turn) * spacing, radius)


func _build_walls() -> void:
	var walls := $Walls as StaticBody2D
	walls.collision_layer = Layers.ARENA
	walls.collision_mask = 0
	for child in walls.get_children():
		child.queue_free()
	var r := Layout.ARENA_RECT
	var t := wall_thickness
	var rects: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2.0 * t, t),
		Rect2(r.position.x - t, r.end.y, r.size.x + 2.0 * t, t),
		Rect2(r.position.x - t, r.position.y, t, r.size.y),
		Rect2(r.end.x, r.position.y, t, r.size.y),
	]
	for rect in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = rect.get_center()
		walls.add_child(collider)
