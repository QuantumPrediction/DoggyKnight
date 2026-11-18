class_name TentacleSlam
extends Node2D
## v2.7 章魚王的觸手(程式畫的身體 + assets/fx/tentacle 的觸手尖):從場地邊緣伸進來拍下。
##
## 1. 預警:從邊緣畫一條長長的紅線(寬度 = 打中範圍),tell_time 秒填滿;觸手尖在邊緣探頭、搖一搖。
## 2. 拍下:觸手沿紅線拍在地上(slap_time 很快),拍下的一刻紅線範圍內(身體碰到線)的角色受傷,
##    鏡頭震一下、揚起水花;之後停 hold_time 秒(不再傷人),縮回去淡出。
## 放在地面層(紅線在角色之下);觸手的身體 z_index 1。在群組 combat_fx。慢動作時跟著變慢。

const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const SKIN := Color("e8665c")
const SKIN_DARK := Color("a8404a")
const SUCKER := Color("ffd2b8")

enum State { TELL, SLAP, HOLD, RETRACT, DONE }

var direction: Vector2 = Vector2.RIGHT
var length: float = 176.0
var width: float = 18.0
var tell_time: float = 1.0
var slap_time: float = 0.08
var hold_time: float = 0.4
var retract_time: float = 0.3
var damage: int = 14
var state: State = State.TELL
var hits: int = 0

var _left: float = 0.0
var _telegraph: AttackTelegraph
var _tip: AnimatedSprite2D
var _age: float = 0.0


## 從 edge_point(場地邊緣)沿 dir 伸進來,長 p_length。p_damage 已乘好難度。
static func strike(host: Node, edge_point: Vector2, dir: Vector2, p_length: float, p_width: float,
		p_tell: float, p_damage: int) -> TentacleSlam:
	if host == null or not host.is_inside_tree():
		return null
	var t := TentacleSlam.new()
	t.direction = dir.normalized()
	t.length = p_length
	t.width = p_width
	t.tell_time = maxf(0.05, p_tell)
	t.damage = maxi(1, p_damage)
	CombatFx.layer_for(host, true).add_child(t)
	t.global_position = edge_point
	return t


## 從場地哪一邊、哪裡伸進來,才會經過 target:side 0 左、1 右、2 下。傳回 [起點, 方向, 長度]。
static func lane_through(target: Vector2, side: int) -> Array:
	var r := Layout.ARENA_RECT
	match side:
		0:
			return [Vector2(r.position.x, target.y), Vector2.RIGHT, r.size.x]
		1:
			return [Vector2(r.end.x, target.y), Vector2.LEFT, r.size.x]
		_:
			return [Vector2(target.x, r.end.y), Vector2.UP, r.size.y * 0.8]


func _ready() -> void:
	add_to_group(&"combat_fx")
	_telegraph = AttackTelegraph.make_line(direction, length, width)
	add_child(_telegraph)
	_left = tell_time
	var frames := CombatFx.frames(&"tentacle")
	if frames != null and frames.has_animation(&"default"):
		_tip = AnimatedSprite2D.new()
		_tip.sprite_frames = frames
		_tip.rotation = direction.angle()
		_tip.z_index = 2
		add_child(_tip)
		_tip.play(&"default")
	_place_tip(4.0)


func is_pending() -> bool:
	return state == State.TELL


func is_tip_down() -> bool:
	return state == State.HOLD


## 頭目倒下或被打斷:還沒拍下就縮回去(不再傷人)。
func cancel() -> void:
	if state == State.TELL:
		_clear_telegraph()
		state = State.RETRACT
		_left = retract_time


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	_left -= delta
	match state:
		State.TELL:
			if _telegraph != null:
				_telegraph.progress = 1.0 - _left / tell_time
			_place_tip(4.0 + sin(_age * 14.0) * 2.0)
			if _left <= 0.0:
				state = State.SLAP
				_left = slap_time
				_clear_telegraph()
		State.SLAP:
			_place_tip(length * (1.0 - clampf(_left / slap_time, 0.0, 1.0)))
			if _left <= 0.0:
				_slap()
		State.HOLD:
			if _left <= 0.0:
				state = State.RETRACT
				_left = retract_time
		State.RETRACT:
			var k := clampf(_left / retract_time, 0.0, 1.0)
			_place_tip(length * k)
			modulate.a = k
			if _left <= 0.0:
				state = State.DONE
				queue_free()
	queue_redraw()


func _slap() -> void:
	state = State.HOLD
	_left = hold_time
	_place_tip(length)
	var a := global_position
	var b := global_position + direction * length
	for group: StringName in [PLAYER_GROUP, COMPANION_GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var victim := node as Node2D
			if victim == null or not victim.has_method(&"take_damage"):
				continue
			if victim.has_method(&"is_downed") and bool(victim.call(&"is_downed")):
				continue
			if EnemyProjectile.segment_distance(a, b, victim.global_position) <= width * 0.5 + EnemyBase.radius_of(victim):
				victim.call(&"take_damage", damage)
				hits += 1
	CombatFx.trauma(self, 0.3)
	CombatFx.haptic(CombatFx.feel().haptic_boss_slam)
	for i in 4:
		var at := a + direction * length * (0.2 + 0.25 * float(i))
		CombatFx.spawn(self, &"dust", at, 0.0, Vector2.ONE * 1.1, Color(0.75, 0.9, 1.0), true)
	CombatFx.sfx(&"tentacle_slap", &"hit")


func _place_tip(reach: float) -> void:
	if _tip != null:
		_tip.position = direction * reach


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


## 觸手的身體:粗粗的一條,越往前越細,下面一排吸盤。
func _draw() -> void:
	var reach := 0.0
	match state:
		State.TELL:
			reach = 4.0 + sin(_age * 14.0) * 2.0
		State.SLAP:
			reach = length * (1.0 - clampf(_left / slap_time, 0.0, 1.0))
		State.HOLD:
			reach = length
		State.RETRACT:
			reach = length * clampf(_left / retract_time, 0.0, 1.0)
	if reach <= 1.0:
		return
	var normal := direction.orthogonal()
	var steps := maxi(3, int(reach / 8.0))
	var wiggle := 0.0 if state == State.HOLD else 1.0
	var prev := Vector2.ZERO
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := direction * reach * t + normal * sin(t * 7.0 + _age * 10.0) * 2.0 * wiggle
		var w := width * (0.75 - 0.45 * t)
		draw_line(prev, p, Color(SKIN_DARK, 0.95), w + 2.0)
		draw_line(prev, p, SKIN, w)
		if i % 2 == 0:
			draw_circle(p + normal * w * 0.25, maxf(1.0, w * 0.16), SUCKER)
		prev = p
