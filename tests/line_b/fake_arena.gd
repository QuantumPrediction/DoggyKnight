extends Node2D
## 給波次生成器單元測試用的極簡假場地:實作同一組方法,記錄每次 spawn_enemy 的呼叫。
## 敵人只是一個在 "enemy" 群組裡的 Node2D;用 kill()/kill_all() 讓它們倒下。

var spawn_points: Array[Vector2] = [Vector2(20, 80), Vector2(160, 80), Vector2(20, 280), Vector2(160, 280)]
var spawned: Array[Dictionary] = []      # {"id": StringName, "at": Vector2, "node": Node2D}
var player: Node2D
## true:spawn_enemy 傳回的敵人下一格才加進場景樹(模擬 call_deferred 的場地)。
var defer_add: bool = false


func _ready() -> void:
	player = Node2D.new()
	player.name = "Player"
	player.position = Layout.PLAYER_START
	player.add_to_group(&"player")
	add_child(player)


func spawn_enemy(enemy_id: StringName, at: Vector2) -> Node:
	var enemy := Node2D.new()
	enemy.name = "%s_%d" % [enemy_id, spawned.size()]
	enemy.position = at
	enemy.add_to_group(&"enemy")
	enemy.set_meta(&"enemy_id", enemy_id)
	if defer_add:
		add_child.call_deferred(enemy)
	else:
		add_child(enemy)
	spawned.append({"id": enemy_id, "at": at, "node": enemy})
	return enemy


func get_spawn_points() -> Array[Vector2]:
	return spawn_points.duplicate()


func clear() -> void:
	kill_all()


func spawn_companion(_companion_id: StringName) -> Node:
	return null


func set_background(_scene: PackedScene) -> void:
	pass


func get_player() -> Node2D:
	return player


func spawned_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in spawned:
		ids.append(item["id"])
	return ids


func alive() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for item in spawned:
		var node: Node2D = item["node"]
		if is_instance_valid(node) and node.is_in_group(&"enemy"):
			result.append(node)
	return result


func kill(node: Node2D) -> void:
	node.remove_from_group(&"enemy")
	node.queue_free()


func kill_all() -> void:
	for node in alive():
		kill(node)
