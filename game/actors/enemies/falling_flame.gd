class_name FallingFlame
extends Node2D
## v2.6 摩根娜的狐火雨:地上先亮紅色預警圈(一開始全部畫出來,依次填滿),
## 填滿時一團狐火(assets/fx/fox_flame)從上面落下,落地爆開,圈內的角色受傷(角色中心在圈內才算)。
## 放在地面層(圈在角色之下);落下的火在最上面(z_index 10)。在群組 combat_fx(場地 clear() 時移除)。

const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const FLAME := Color(0.55, 0.85, 1.0)

enum State { WAIT, TELL, FALL, DONE }

var damage: int = 10
var radius: float = 12.0
var delay: float = 0.0                  ## 預警圈出現後,過多久才開始填滿
var tell_time: float = 0.9              ## 填滿要多久
var fall_time: float = 0.2
var fall_height: float = 70.0
var hit_margin: float = 2.0
var state: State = State.WAIT
var hits: int = 0

var _left: float = 0.0
var _telegraph: AttackTelegraph
var _flame: AnimatedSprite2D


## 在 at 放一個狐火落點。p_damage 已經乘好難度。
static func drop(host: Node, at: Vector2, p_damage: int, p_radius: float, p_tell: float, p_delay: float) -> FallingFlame:
	if host == null or not host.is_inside_tree():
		return null
	var f := FallingFlame.new()
	f.damage = p_damage
	f.radius = p_radius
	f.tell_time = maxf(0.05, p_tell)
	f.delay = maxf(0.0, p_delay)
	CombatFx.layer_for(host, true).add_child(f)
	f.global_position = at
	return f


func _ready() -> void:
	add_to_group(&"combat_fx")
	_telegraph = AttackTelegraph.make_circle(radius)
	add_child(_telegraph)
	_left = delay
	state = State.WAIT if delay > 0.0 else State.TELL
	if state == State.TELL:
		_left = tell_time


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_left -= delta
	match state:
		State.WAIT:
			if _left <= 0.0:
				state = State.TELL
				_left = tell_time
		State.TELL:
			if _telegraph != null:
				_telegraph.progress = 1.0 - _left / tell_time
			if _left <= 0.0:
				_start_fall()
		State.FALL:
			if _flame != null:
				var t := 1.0 - clampf(_left / fall_time, 0.0, 1.0)
				_flame.position = Vector2(0, -fall_height * (1.0 - t * t))
			if _left <= 0.0:
				_land()
		State.DONE:
			if _left <= 0.0:
				queue_free()


func _start_fall() -> void:
	state = State.FALL
	_left = fall_time
	var frames := CombatFx.frames(&"fox_flame", self)
	if frames != null and frames.has_animation(&"default"):
		_flame = AnimatedSprite2D.new()
		_flame.sprite_frames = frames
		_flame.rotation = PI * 0.5
		_flame.z_as_relative = false
		_flame.z_index = 10
		_flame.position = Vector2(0, -fall_height)
		add_child(_flame)
		_flame.play(&"default")


func _land() -> void:
	state = State.DONE
	_left = 0.3
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	if _flame != null:
		_flame.queue_free()
		_flame = null
	for group: StringName in [PLAYER_GROUP, COMPANION_GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var victim := node as Node2D
			if victim == null or not victim.has_method(&"take_damage"):
				continue
			if victim.has_method(&"is_downed") and bool(victim.call(&"is_downed")):
				continue
			if global_position.distance_to(victim.global_position) <= radius + hit_margin:
				victim.call(&"take_damage", damage)
				hits += 1
	CombatFx.ring(self, global_position, 2.0, radius + 3.0, 0.25, Color(FLAME, 0.9), 2.0)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 0.9, Color(0.8, 0.9, 1.0), true)
	CombatFx.sfx(&"foxfire_burst", &"hit", -8.0)


func is_pending() -> bool:
	return state == State.WAIT or state == State.TELL or state == State.FALL


## 頭目倒下時:還沒落下的狐火熄掉(不再傷人)。
func fizzle() -> void:
	if not is_pending():
		return
	state = State.DONE
	_left = 0.0
	queue_free()
