extends RefCounted
## Fixed alternate policy, R01. Scores short steps from visible positions/warnings.
## It knows neither enemy cooldowns, spawn schedules nor future RNG outcomes.
## This is engineering coverage, not a reaction-time model of a human player.

const Visible = preload("res://tests/integration/visible_pressure.gd")
const STEP_DISTANCE: float = 18.0
const BODY_PADDING: float = 6.0
const DIRECTIONS: int = 16

static func choose(tree: SceneTree, at: Vector2, hero: StringName, attack_range: float,
		previous: Vector2) -> Vector2:
	var enemies: Array[Node2D] = []
	var nearest := INF
	for node in tree.get_nodes_in_group(&"enemy"):
		var enemy := node as EnemyBase
		if enemy != null and enemy.is_targetable():
			enemies.append(enemy)
			nearest = minf(nearest, at.distance_to(enemy.global_position))
	if enemies.is_empty():
		return Vector2.ZERO
	var marks := Visible.warnings(tree)
	var bounds := Layout.ARENA_RECT.grow(-14.0)
	var desired := minf(attack_range * 0.8, 70.0) if hero != &"knight" else attack_range + 2.0
	var best := Vector2.ZERO
	var best_score := -INF
	# Zero is considered first: ties favour stopping and using the real autoattack.
	for index in DIRECTIONS + 1:
		var direction := Vector2.ZERO if index == 0 else Vector2.from_angle(TAU * float(index - 1) / DIRECTIONS)
		var probe := at + direction * STEP_DISTANCE
		if not bounds.has_point(probe):
			continue
		var midpoint := at.lerp(probe, 0.5)
		var risk := Visible.warning_cost(marks, probe, BODY_PADDING)
		# Do not choose a safe endpoint by walking through an already visible hazard.
		risk += Visible.warning_cost(marks, midpoint, BODY_PADDING) * 0.5
		var separation := INF
		var crowd := 0.0
		for enemy in enemies:
			var distance := probe.distance_to(enemy.global_position)
			separation = minf(separation, distance)
			crowd += maxf(0.0, 30.0 - distance) / 30.0
		var score := -risk * 140.0 - crowd * 24.0 - absf(separation - desired) * 0.6
		# Space near an edge is usable, but prefer preserving a future escape route.
		var edge := minf(minf(probe.x - bounds.position.x, bounds.end.x - probe.x),
			minf(probe.y - bounds.position.y, bounds.end.y - probe.y))
		score += minf(edge, 24.0) * 0.35
		if direction == Vector2.ZERO and nearest <= attack_range + 4.0:
			score += 16.0
		elif direction != Vector2.ZERO:
			score += direction.dot(previous) * 3.0
		if score > best_score:
			best_score = score
			best = direction
	return best
