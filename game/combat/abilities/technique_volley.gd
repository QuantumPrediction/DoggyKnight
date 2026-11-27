class_name TechniqueVolley
extends Node2D
## A volley belongs to the arena and can only originate from a landed basic attack.
## Positions are world-space snapshots. Stars and blades check moving bodies at impact.
const ARC := preload("res://assets/illustrated/techniques/arc_rune.webp")
const STAR := preload("res://assets/illustrated/techniques/starfall.webp")
const DISC := preload("res://assets/illustrated/techniques/gale_disc.webp")
const ARC_LIFE := 0.16
const DISC_SPEED := 170.0
const STAR_DELAY := 0.34
const STAR_FLASH := 0.12

var caster: WeakRef
var ranks: Vector3i
var heading: Vector2
var travel_left := 0.0
var blade_at := Vector2.ZERO
var blade_seen: Array[int] = []
var blade_hits := 0
var age := 0.0
var stars: Array[Dictionary] = []
var arcs: Array[Dictionary] = []


static func launch(hero: GoldiePlayer, contact: Vector2, primary_id: int, direction: Vector2,
		levels: Vector3i) -> TechniqueVolley:
	var volley := TechniqueVolley.new()
	volley.caster = weakref(hero)
	volley.ranks = levels.clampi(0, 3)
	volley.heading = direction.normalized()
	CombatFx.layer_for(hero).add_child(volley)
	volley.global_position = contact
	volley.blade_at = contact
	volley.blade_seen.append(primary_id)
	if levels.y > 0:
		volley._mark(contact, false)
	if levels.z > 0:
		volley.travel_left = 42.0 + 7.0 * (levels.z - 1)
	if levels.x > 0:
		volley._chain(hero, contact, [primary_id], 2 if levels.z > 0 else 1)
	return volley


func _ready() -> void:
	add_to_group(&"friendly_technique")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 2


func _mark(at: Vector2, echo: bool) -> void:
	stars.append({"at": at, "due": age + STAR_DELAY, "echo": echo, "struck": false})


func _physics_process(delta: float) -> void:
	var hero := caster.get_ref() as GoldiePlayer
	if hero == null or not hero.is_inside_tree() or hero.is_downed() or hero.celebrating:
		queue_free()
		return
	var step := delta * CombatFx.time_scale
	age += step
	if travel_left > 0.0:
		_fly(hero, minf(travel_left, DISC_SPEED * step))
	for i in range(stars.size() - 1, -1, -1):
		var mark := stars[i]
		if not mark.struck and age >= mark.due:
			mark.struck = true
			_land(hero, mark.at, mark.echo)
		if age >= float(mark.due) + STAR_FLASH:
			stars.remove_at(i)
	for i in range(arcs.size() - 1, -1, -1):
		if age >= arcs[i].until:
			arcs.remove_at(i)
	queue_redraw()
	if travel_left <= 0.0 and stars.is_empty() and arcs.is_empty():
		queue_free()


func _near(hero: GoldiePlayer, at: Vector2, radius: float, excluded: Array[int]) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if hero._is_valid_target(node) and not node.is_queued_for_deletion() and not excluded.has(node.get_instance_id()):
			var enemy := node as Node2D
			if at.distance_to(enemy.global_position) <= radius + GoldiePlayer._radius_of(enemy):
				targets.append(enemy)
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var da := at.distance_squared_to(a.global_position)
		var db := at.distance_squared_to(b.global_position)
		if not is_equal_approx(da, db):
			return da < db
		return a.global_position < b.global_position if a.global_position != b.global_position else a.get_instance_id() < b.get_instance_id())
	return targets


func _chain(hero: GoldiePlayer, origin: Vector2, excluded: Array[int], hops: int) -> void:
	for hop in hops:
		var candidates := _near(hero, origin, 36.0 + 4.0 * (ranks.x - 1), excluded)
		if candidates.is_empty():
			break
		var enemy := candidates[0]
		var at := enemy.global_position
		excluded.append(enemy.get_instance_id())
		arcs.append({"from": origin, "to": at, "until": age + ARC_LIFE})
		var mult := (0.42 + 0.13 * (ranks.x - 1)) * (1.0 if hop == 0 else 0.75)
		hero.ability_hit(enemy, hero.ability_base_damage(mult), 0.0)
		origin = at


func _land(hero: GoldiePlayer, at: Vector2, echo: bool) -> void:
	var radius := (18.0 + 3.0 * (ranks.y - 1)) * (0.75 if echo else 1.0)
	var targets := _near(hero, at, radius, [])
	var ids: Array[int] = []
	var first_at := at
	for enemy in targets.slice(0, 2 if echo else 3):
		if not hero._is_valid_target(enemy) or enemy.is_queued_for_deletion():
			continue
		if ids.is_empty():
			first_at = enemy.global_position
		ids.append(enemy.get_instance_id())
		var mult := (0.65 + 0.16 * (ranks.y - 1)) * (0.55 if echo else 1.0)
		hero.ability_hit(enemy, hero.ability_base_damage(mult), 0.0)
	if not echo and ranks.x > 0 and not ids.is_empty():
		_chain(hero, first_at, ids, 1)


func _fly(hero: GoldiePlayer, distance: float) -> void:
	var next := blade_at + heading * distance
	var targets := _near(hero, (blade_at + next) * 0.5, distance * 0.5 + 3.0, blade_seen)
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var da := (a.global_position - blade_at).dot(heading)
		var db := (b.global_position - blade_at).dot(heading)
		if not is_equal_approx(da, db):
			return da < db
		return a.global_position < b.global_position if a.global_position != b.global_position else a.get_instance_id() < b.get_instance_id())
	for enemy in targets:
		var at := enemy.global_position
		if (at - global_position).dot(heading) <= 0.0:
			continue
		if EnemyProjectile.segment_distance(blade_at, next, at) > GoldiePlayer._radius_of(enemy) + 3.0:
			continue
		blade_seen.append(enemy.get_instance_id())
		blade_hits += 1
		hero.ability_hit(enemy, hero.ability_base_damage(0.46 + 0.13 * (ranks.z - 1)), 0.0)
		if blade_hits == 1 and ranks.y > 0:
			_mark(at, true)
		if blade_hits == 2:
			travel_left = 0.0
			return
	travel_left = maxf(0.0, travel_left - distance)
	blade_at = next


func _draw() -> void:
	for arc in arcs:
		var a := to_local(arc.from)
		var b := to_local(arc.to)
		var kink := a.lerp(b, 0.55) + (b - a).orthogonal().normalized() * 3.0
		var line := PackedVector2Array([a, kink, b])
		draw_polyline(line, Color("3079ae"), 2.5, true)
		draw_polyline(line, Color("c5f7ff"), 1.0, true)
		draw_texture_rect(ARC, Rect2(b - Vector2(5, 5), Vector2(10, 10)), false)
	for mark in stars:
		var at := to_local(mark.at)
		var left := clampf((float(mark.due) - age) / STAR_DELAY, 0.0, 1.0)
		var size_px := (10.0 if mark.echo else 15.0) * (1.0 if not mark.struck else 1.25)
		draw_set_transform(at + Vector2(-5.0, -16.0) * left)
		draw_texture_rect(STAR, Rect2(Vector2.ONE * -size_px / 2.0, Vector2.ONE * size_px), false)
		draw_set_transform(Vector2.ZERO)
	if travel_left > 0.0:
		draw_set_transform(to_local(blade_at), heading.angle() + age * 14.0)
		draw_texture_rect(DISC, Rect2(-7, -7, 14, 14), false)
		draw_set_transform(Vector2.ZERO)
