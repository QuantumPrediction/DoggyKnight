extends Node2D
## 敵人的替身(只給 B 線的替身場地用)。正式版由 data/enemies/<id>.tres 的 scene 指定(A 線)。
##
## - 群組 "enemy";提供 setup(data: EnemyData)、take_damage(amount)。
## - 朝金毛走過去,碰到就造成接觸傷害;敵人之間互相推開,不會疊成一點。
## - 被點一下(場地處理)或被金毛打到生命歸零就倒下:立即離開 "enemy" 群組,
##   發 enemy_died,然後(替身直接代替經驗珠被拾取)發 exp_collected,縮小消失。
## - 黑騎士替身:每隔幾秒召喚兩隻稻草人兵(也算在 "enemy" 群組內),生命過半發 boss_phase_changed(2)。
##
## 數值:data/enemies/<id>.tres 存在就用它,否則用下面的替身數值(取自 DEV_PLAN 第 8 節)。

const STAND_IN_STATS: Dictionary = {
	&"scarecrow": {"max_hp": 25, "move_speed": 28.0, "contact_damage": 8, "exp_value": 1, "radius": 8.0},
	&"crow": {"max_hp": 12, "move_speed": 48.0, "contact_damage": 6, "exp_value": 1, "radius": 6.0},
	&"scarecrow_elite": {"max_hp": 75, "move_speed": 26.0, "contact_damage": 10, "exp_value": 3, "radius": 9.0,
			"frames": &"scarecrow", "tint": Color(1.0, 0.65, 0.65)},
	&"black_knight": {"max_hp": 450, "move_speed": 32.0, "contact_damage": 18, "exp_value": 20, "radius": 18.0,
			"summon_every": 10.0},
}
const SEPARATION: float = 30.0
const BOSS_SUMMON: StringName = &"scarecrow"

var enemy_id: StringName = &"scarecrow"
var max_hp: int = 25
var hp: int = 25
var move_speed: float = 28.0
var contact_damage: int = 8
var exp_value: int = 1
var radius: float = 8.0
var dead: bool = false
var arena: Node

var _sprite: AnimatedSprite2D
var _summon_every: float = 0.0
var _summon_timer: float = 0.0
var _phase: int = 1
var _flash: float = 0.0
var _base_tint: Color = Color.WHITE


## 替身場地呼叫:先用替身數值,再用 A 線的 EnemyData(若存在)覆蓋。
func configure(id: StringName, arena_node: Node) -> void:
	enemy_id = id
	arena = arena_node
	var stats: Dictionary = STAND_IN_STATS.get(id, STAND_IN_STATS[&"scarecrow"])
	max_hp = stats["max_hp"]
	move_speed = stats["move_speed"]
	contact_damage = stats["contact_damage"]
	exp_value = stats["exp_value"]
	radius = stats["radius"]
	_summon_every = stats.get("summon_every", 0.0)
	_summon_timer = _summon_every
	var data_path := "res://data/enemies/%s.tres" % id
	if ResourceLoader.exists(data_path):
		var data := load(data_path) as EnemyData
		if data != null:
			setup(data)
	hp = max_hp
	_build_sprite(stats.get("frames", id), stats.get("tint", Color.WHITE))


## 合約方法(DEV_PLAN 4.4)。
func setup(data: EnemyData) -> void:
	enemy_id = data.id if data.id != &"" else enemy_id
	max_hp = data.max_hp
	hp = max_hp
	move_speed = data.move_speed
	contact_damage = data.contact_damage
	exp_value = data.exp_value


func _ready() -> void:
	add_to_group(&"enemy")


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.1
	Sfx.play(&"hit")
	if _summon_every > 0.0 and _phase == 1 and hp * 2 <= max_hp and hp > 0:
		_phase = 2
		_summon_every *= 0.7
		EventBus.boss_phase_changed.emit(2)
	queue_redraw()
	if hp <= 0:
		die()


## 倒下(被點一下也會直接呼叫這個)。
func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group(&"enemy")
	EventBus.enemy_died.emit(enemy_id, global_position, exp_value)
	# 替身沒有經驗珠:當作立即被拾取。
	EventBus.exp_collected.emit(exp_value)
	Sfx.play(&"enemy_down")
	var tween := create_tween()
	tween.tween_property(self, ^"scale", Vector2(1.4, 0.2), 0.2)
	tween.parallel().tween_property(self, ^"modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var player := _player()
	if player != null and not bool(player.get(&"downed")):
		var to_player := player.global_position - global_position
		var push := _separation()
		var step := to_player.normalized() * move_speed + push
		global_position += step * delta
		if to_player.x != 0.0 and _sprite != null:
			_sprite.flip_h = to_player.x < 0.0
		if to_player.length() <= radius + 7.0 and player.has_method(&"take_damage"):
			player.call(&"take_damage", contact_damage)
	var bounds := Layout.ARENA_RECT.grow(-radius * 0.5)
	global_position = global_position.clamp(bounds.position, bounds.end)
	if _summon_every > 0.0:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = _summon_every
			_summon()
	if _flash > 0.0:
		_flash -= delta
		if _sprite != null:
			_sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else _base_tint
	if hp < max_hp:
		queue_redraw()


func _draw() -> void:
	if hp < max_hp and not dead:
		var w := maxf(12.0, radius * 2.0)
		var top := Vector2(-w * 0.5, -radius - 6.0)
		draw_rect(Rect2(top, Vector2(w, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * clampf(float(hp) / max_hp, 0.0, 1.0), 2)), Color("ffd166"))



func _build_sprite(frames_id: StringName, tint: Color) -> void:
	_base_tint = tint
	_sprite = AnimatedSprite2D.new()
	var path := "res://assets/sprites/%s/%s_frames.tres" % [frames_id, frames_id]
	if ResourceLoader.exists(path):
		_sprite.sprite_frames = load(path) as SpriteFrames
		if _sprite.sprite_frames.has_animation(&"run"):
			_sprite.play(&"run")
	_sprite.modulate = tint
	add_child(_sprite)


func _player() -> Node2D:
	if arena != null and arena.has_method(&"get_player"):
		return arena.call(&"get_player") as Node2D
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == self or not node is Node2D:
			continue
		var other := node as Node2D
		var offset := global_position - other.global_position
		var min_distance := radius + float(other.get(&"radius") if other.get(&"radius") != null else 8.0)
		var distance := offset.length()
		if distance < min_distance:
			push += (offset.normalized() if distance > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)) \
					* SEPARATION * (1.0 - distance / min_distance)
	return push


func _summon() -> void:
	if arena == null or not arena.has_method(&"spawn_enemy"):
		return
	for side: float in [-1.0, 1.0]:
		arena.call(&"spawn_enemy", BOSS_SUMMON, global_position + Vector2(side * 24.0, 8.0))
