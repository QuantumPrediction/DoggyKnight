class_name AllyProjectile
extends Node2D
## v2.7 同伴的投射物(崔斯坦的音符)。數值在 ProjectileData(data/companions/music_note.tres):
## fx(圖)、damage、speed、max_range、hit_radius、spin_speed。
##
## - 朝目標飛,途中稍微轉向追著目標(homing 弧度/秒);碰到任何一隻可以打的敵人就打中消失,
##   用 hit(…, DamageNumber.Style.ALLY)(淡藍色的同伴傷害數字;莫德雷德的劍鞘護盾只被同伴的攻擊削弱)。
## - 飛滿射程或碰到場地邊緣就淡出。不會打到金毛與同伴。
## - 在群組 ally_projectile;放在場地的特效層,場地 clear() 時一起移除。慢動作時跟著變慢。

const GROUP: StringName = &"ally_projectile"
const ENEMY_GROUP: StringName = &"enemy"

var data: ProjectileData
var shooter: Node2D
var target: Node2D
var direction: Vector2 = Vector2.RIGHT
var damage: int = 4
var knockback: float = 20.0
var homing: float = 4.0
var traveled: float = 0.0
var hits: int = 0
var fading: bool = false

var _sprite: AnimatedSprite2D
var _fade_left: float = 0.2
var _age: float = 0.0


static func shoot(host: Node, p_data: ProjectileData, from: Vector2, p_target: Node2D, p_damage: int,
		p_knockback: float, p_homing: float, p_shooter: Node2D = null) -> AllyProjectile:
	if host == null or not host.is_inside_tree() or p_data == null:
		return null
	var p := AllyProjectile.new()
	p.data = p_data
	p.target = p_target
	p.damage = maxi(1, p_damage)
	p.knockback = p_knockback
	p.homing = p_homing
	p.shooter = p_shooter
	if p_target != null and is_instance_valid(p_target):
		var to := p_target.global_position - from
		p.direction = to.normalized() if to.length() > 0.5 else Vector2.RIGHT
	CombatFx.layer_for(host).add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 1
	var frames := CombatFx.frames(data.fx) if data != null else null
	if frames != null and frames.has_animation(&"default"):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2.ONE * data.visual_scale
		add_child(_sprite)
		_sprite.play(&"default")


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if fading:
		_fade_left -= delta
		modulate.a = clampf(_fade_left / 0.2, 0.0, 1.0)
		if _fade_left <= 0.0:
			queue_free()
		return
	if _sprite != null:
		_sprite.speed_scale = CombatFx.time_scale
		if data.spin_speed != 0.0:
			_sprite.rotation = sin(_age * data.spin_speed) * 0.35
	if _is_valid(target):
		var to := (target as Node2D).global_position - global_position
		if to.length() > 0.5:
			var want := to.normalized()
			var angle := direction.angle_to(want)
			direction = direction.rotated(clampf(angle, -homing * delta, homing * delta))
	var step := data.speed * delta
	var from := global_position
	global_position += direction * step
	traveled += step
	if _check_hit(from, global_position):
		return
	if traveled >= data.max_range or not Layout.ARENA_RECT.has_point(global_position):
		fading = true
	queue_redraw()


func _check_hit(a: Vector2, b: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid(enemy):
			continue
		if EnemyProjectile.segment_distance(a, b, enemy.global_position) <= data.hit_radius + EnemyBase.radius_of(enemy):
			hits += 1
			if enemy.has_method(&"hit"):
				enemy.call(&"hit", damage, global_position - direction * 8.0, knockback, DamageNumber.Style.ALLY)
			else:
				enemy.call(&"take_damage", damage)
			CombatFx.spawn(self, &"hit_spark", global_position, randf() * TAU, Vector2.ONE * 0.7, data.trail_color)
			fading = true
			_fade_left = 0.08
			return true
	return false


func _is_valid(node: Variant) -> bool:
	if not is_instance_valid(node):
		return false
	var enemy := node as Node2D
	if enemy == null or not enemy.is_inside_tree() or not enemy.is_in_group(ENEMY_GROUP):
		return false
	return not enemy.has_method(&"is_targetable") or bool(enemy.call(&"is_targetable"))


func _draw() -> void:
	if fading:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 16.0)
	draw_circle(Vector2.ZERO, data.hit_radius + 2.0 + pulse, Color(data.trail_color, 0.35))
	if _sprite == null:
		draw_circle(Vector2.ZERO, maxf(1.5, data.hit_radius), Color(1, 1, 1, 0.9))
