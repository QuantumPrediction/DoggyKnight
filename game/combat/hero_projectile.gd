class_name HeroProjectile
extends Node2D
## Swept collision prevents tunnelling at high speed. Damage is resolved at impact,
## not at launch. The arena owns the projectile, so scene changes clear it.
const MAX_PROJECTILES: int = 32
const MAX_SPLASH_TARGETS: int = 6
var shooter: WeakRef
var loadout: HeroClassData
var direction: Vector2
var remaining: float
var multiplier: float = 1.0
var ultimate: bool = false
var damage: int = 0
var hits: int = 0
var hit_ids: Array[int] = []
var _tex: Texture2D
var _flight_frames: Array[Texture2D] = []
var _paint_distance: float = 0.0

static func launch(host: GoldiePlayer, dir: Vector2, mult: float = 1.0, is_ultimate: bool = false) -> HeroProjectile:
	var existing := host.get_tree().get_nodes_in_group(&"hero_projectile")
	if existing.size() >= MAX_PROJECTILES:
		existing[0].queue_free()
	var p := HeroProjectile.new()
	p.shooter = weakref(host)
	p.loadout = host.loadout.duplicate() as HeroClassData
	p.loadout.splash_radius += float(host.equipment_combat.effects.get("splash", 0.0))
	p.loadout.max_hits += roundi(float(host.equipment_combat.effects.get("pierce", 0.0)))
	p.direction = dir.normalized()
	p.remaining = GameState.player_stats.attack_range
	p.multiplier = mult
	p.ultimate = is_ultimate
	CombatFx.layer_for(host).add_child(p)
	p.global_position = host.global_position
	return p

func _ready() -> void:
	add_to_group(&"hero_projectile")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if loadout.id == &"mage":
		for frame in 4:
			_flight_frames.append(StoryArt.action_effect(1, frame))
		_tex = _flight_frames[0]
	else:
		_tex = StoryArt.object_icon("hero_arrow")
	rotation = direction.angle()
	z_index = 2

func _physics_process(delta: float) -> void:
	var host := shooter.get_ref() as GoldiePlayer
	if host == null or not host.is_inside_tree() or host.is_downed() or host.celebrating:
		queue_free()
		return
	var distance := minf(remaining, loadout.projectile_speed * delta * CombatFx.time_scale)
	var from := global_position
	var to := from + direction * distance
	# Resolve in spatial order; scene insertion order must not decide penetration.
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if host._is_valid_target(node) and not hit_ids.has(node.get_instance_id()):
			var enemy := node as Node2D
			if EnemyProjectile.segment_distance(from, to, enemy.global_position) <= GoldiePlayer._radius_of(enemy) + loadout.projectile_radius:
				candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return (a.global_position - from).dot(direction) < (b.global_position - from).dot(direction))
	for enemy in candidates:
		if not host._is_valid_target(enemy):
			continue
		if hits == 0:
			damage = host.projectile_impact_damage(multiplier, ultimate)
		var at := enemy.global_position
		var basic_contact := hits == 0 and not ultimate
		var primary_id := enemy.get_instance_id()
		_hit(host, enemy, damage if hits == 0 else maxi(1, roundi(damage * loadout.secondary_mult)))
		if loadout.splash_radius > 0.0:
			CombatFx.ring(host, at, 3.0, loadout.splash_radius, 0.24, loadout.accent, 1.5)
			for other in get_tree().get_nodes_in_group(&"enemy"):
				if hit_ids.size() >= MAX_SPLASH_TARGETS:
					break
				if host._is_valid_target(other) and not hit_ids.has(other.get_instance_id()) and at.distance_to(other.global_position) <= loadout.splash_radius + GoldiePlayer._radius_of(other):
					_hit(host, other, maxi(1, roundi(damage * loadout.secondary_mult)))
		if basic_contact:
			host.abilities.primary_impact(host, at, primary_id, direction)
		if loadout.splash_radius > 0.0 or hits >= loadout.max_hits:
			queue_free()
			return
	global_position = to
	remaining -= distance
	if not _flight_frames.is_empty():
		_paint_distance += distance
		var drawing := _flight_frames[floori(_paint_distance / 4.0) % _flight_frames.size()]
		if _tex != drawing:
			_tex = drawing
			queue_redraw()
	if remaining <= 0.0 or not Layout.ARENA_RECT.grow(12).has_point(global_position):
		queue_free()

func _hit(host: GoldiePlayer, enemy: Node2D, amount: int) -> void:
	hit_ids.append(enemy.get_instance_id())
	hits += 1
	host._strike(enemy, amount, host.tuning.knockback_speed * 0.35)
	host.last_swing_hits += 1
	host.last_swing_damage = amount
	if not ultimate:
		host.add_loyalty(host.tuning.loyalty_per_hit)
	Sfx.play(&"magic" if loadout.id == &"mage" else &"hit", -9.0)

func _draw() -> void:
	if _tex == null:
		return
	# Register the spell core and the arrow tip at the position used by swept collision.
	var dim := Vector2(14, 14) if loadout.id == &"mage" else Vector2(16, 16)
	var pivot := Vector2(0.74, 0.5) if loadout.id == &"mage" else Vector2(0.96, 0.5)
	draw_texture_rect(_tex, Rect2(-dim * pivot, dim), false)
