class_name CompanionSpacing
extends RefCounted
## v2.6(AV8):兩位同伴(貝德維爾的鬥牛犬、蘭斯洛特)同時在場時互不重疊。
## push() 傳回把 who 推離其他同伴與金毛的方向(長度 0 至 1.5);同伴把它乘上速度加進自己的移動。
##
## v2.7(AW7):最多 4 位同伴同時在場(鬥牛犬、蘭斯洛特、崔斯坦、高文),用隊形分開站,不重疊、不擋路:
## - 每位同伴的 formation_role():&"side"(蘭斯洛特、高文:站在金毛左右)、&"back"(崔斯坦:站在金毛
##   遠離敵人的那一邊,保持距離);沒有這個方法的(鬥牛犬)自由走動(去舉盾)。
## - side_of():站左右的同伴依生成次序輪流分左右;第一位站在自由走動的同伴(鬥牛犬)的另一邊。
## - back_spot():遠離最近敵人的方向。
## 同伴不和金毛碰撞(只撞場地的牆),所以不會擋住金毛的路;push() 讓大家的身體不疊在一起。

const COMPANION_GROUP: StringName = &"companion"
const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"
const SIDE: StringName = &"side"
const BACK: StringName = &"back"


## 離其他同伴(與金毛)太近時推開的方向。gap = 身體之間至少留多少像素。
static func push(who: Node2D, radius: float, gap: float = 4.0, include_player: bool = true) -> Vector2:
	if who == null or not who.is_inside_tree():
		return Vector2.ZERO
	var result := Vector2.ZERO
	var others: Array[Node] = who.get_tree().get_nodes_in_group(COMPANION_GROUP)
	if include_player:
		others.append_array(who.get_tree().get_nodes_in_group(PLAYER_GROUP))
	for node in others:
		var other := node as Node2D
		if other == null or other == who:
			continue
		var min_dist := radius + EnemyBase.radius_of(other) + gap
		var offset := who.global_position - other.global_position
		var dist := offset.length()
		if dist >= min_dist:
			continue
		if dist < 0.01:
			# 完全重疊:用兩者的 id 決定一個固定方向。
			offset = Vector2.RIGHT if who.get_instance_id() > other.get_instance_id() else Vector2.LEFT
			dist = 0.01
		else:
			offset /= dist
		result += offset * (1.0 - dist / min_dist) * 2.0
	return result.limit_length(1.5)


## 另一位同伴在金毛的哪一邊(-1 左、1 右、0 沒有別的同伴)。
static func other_side(who: Node2D, player: Node2D) -> float:
	if who == null or player == null or not who.is_inside_tree():
		return 0.0
	for node in who.get_tree().get_nodes_in_group(COMPANION_GROUP):
		var other := node as Node2D
		if other == null or other == who:
			continue
		var dx := other.global_position.x - player.global_position.x
		return -1.0 if dx < 0.0 else 1.0
	return 0.0


## 同伴在隊形裡的角色(&"side"、&"back";空白 = 自由走動)。
static func role_of(node: Node) -> StringName:
	if node != null and node.has_method(&"formation_role"):
		return StringName(node.call(&"formation_role"))
	return &""


## 站左右的同伴(formation_role = side)要站在金毛的哪一邊(-1 左、1 右)。
## 依生成次序輪流分左右;第一位站在自由走動的同伴(鬥牛犬)的另一邊,沒有的話站右邊。
static func side_of(who: Node2D, player: Node2D) -> float:
	if who == null or player == null or not who.is_inside_tree():
		return 1.0
	var users: Array[Node2D] = []
	var roamer: Node2D = null
	for node in who.get_tree().get_nodes_in_group(COMPANION_GROUP):
		var c := node as Node2D
		if c == null or c.is_queued_for_deletion():
			continue
		var role := role_of(c)
		if role == SIDE:
			users.append(c)
		elif role == &"" and roamer == null:
			roamer = c
	var base := 1.0
	if roamer != null:
		base = 1.0 if roamer.global_position.x - player.global_position.x < 0.0 else -1.0
	var index := maxi(0, users.find(who))
	return base if index % 2 == 0 else -base


## 站後面的同伴(formation_role = back)的位置:金毛遠離最近敵人那一邊 distance 像素(沒有敵人時在金毛下方)。
static func back_spot(who: Node2D, player: Node2D, distance: float) -> Vector2:
	if player == null:
		return who.global_position if who != null else Vector2.ZERO
	var away := Vector2.DOWN
	var best := INF
	if who != null and who.is_inside_tree():
		for node in who.get_tree().get_nodes_in_group(ENEMY_GROUP):
			var enemy := node as Node2D
			if enemy == null:
				continue
			var d := player.global_position.distance_squared_to(enemy.global_position)
			if d < best and d > 1.0:
				best = d
				away = (player.global_position - enemy.global_position).normalized()
	return player.global_position + away * distance
