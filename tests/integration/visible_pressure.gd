extends RefCounted
## Shared read-only geometry for diagnostics. No RNG or changes to actors/marks.

static func warnings(tree: SceneTree) -> Array[AttackTelegraph]:
	var result: Array[AttackTelegraph] = []
	for node in tree.get_nodes_in_group(&"combat_fx"):
		var mark := node as AttackTelegraph
		if mark != null and is_instance_valid(mark) and mark.is_visible_in_tree():
			result.append(mark)
	return result


static func covers(mark: AttackTelegraph, at: Vector2, padding: float) -> bool:
	if mark.shape == AttackTelegraph.Shape.SECTOR:
		return mark.intersects_sector_body(at, padding)
	var point := mark.to_local(at)
	var scale_floor := maxf(0.001, minf(mark.global_scale.abs().x, mark.global_scale.abs().y))
	var pad := padding / scale_floor
	if mark.shape == AttackTelegraph.Shape.CIRCLE:
		return point.length() <= mark.radius + pad
	var along := point.dot(mark.direction)
	var side := point.dot(mark.direction.orthogonal())
	return along >= -pad and along <= mark.length + pad and absf(side) <= mark.width * 0.5 + pad


static func warning_cost(marks: Array[AttackTelegraph], at: Vector2, padding: float) -> float:
	var cost := 0.0
	for mark in marks:
		if covers(mark, at, padding):
			cost += 1.0 + 2.0 * mark.progress
	return cost


static func snapshot(mark: AttackTelegraph) -> Dictionary:
	return {"shape": AttackTelegraph.Shape.keys()[mark.shape],
		"position": [mark.global_position.x, mark.global_position.y],
		"direction": [mark.direction.x, mark.direction.y], "radius": mark.radius,
		"half_angle": mark.half_angle, "length": mark.length, "width": mark.width,
		"progress": mark.progress, "aim_tracking": mark.show_aim_lock and not mark.aim_locked,
		"aim_locked": mark.show_aim_lock and mark.aim_locked}
