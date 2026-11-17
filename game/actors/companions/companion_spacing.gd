class_name CompanionSpacing
extends RefCounted
## v2.6(AV8):兩位同伴(貝德維爾的鬥牛犬、蘭斯洛特)同時在場時互不重疊。
## push() 傳回把 who 推離其他同伴與金毛的方向(長度 0 至 1.5);同伴把它乘上速度加進自己的移動。

const COMPANION_GROUP: StringName = &"companion"
const PLAYER_GROUP: StringName = &"player"


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
