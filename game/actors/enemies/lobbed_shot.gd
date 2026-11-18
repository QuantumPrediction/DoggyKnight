class_name LobbedShot
extends Node2D
## v2.7:沿拋物線飛的投射物(雪人的雪球、章魚王的墨汁、紅龍的火球)。
##
## - 落點在出手前就固定:地上先出現紅色預警圈與影子(放在地面層,在角色之下),
##   delay 秒(出手前的準備)後投射物從 from 沿拋物線飛過去(圖在最上層),飛行時間 = 距離 ÷ 速度
##   (至少 min_flight 秒);影子隨投射物落下而變大變深。看到影子就走開。
## - 落地:圈內(角色中心離圈邊 hit_margin 以內)的金毛與同伴受傷;依 splash 噴雪花、留下墨汁、冒火花。
## - 數值在 ProjectileData:fx(圖)、damage、speed(水平速度)、hit_radius(落點圈半徑)。
## - 出手的敵人被打斷(cancel())時,還沒出手的投射物連同預警一起消失。
## - 在群組 combat_fx(場地 clear() 時一起移除);慢動作時跟著變慢。

const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const SNOW_COLORS: Array[Color] = [Color("ffffff"), Color("dcefff"), Color("b8dcf5")]
const FIRE := Color(1.0, 0.55, 0.2)

enum State { WAIT, FLY, DONE }

var data: ProjectileData
var damage: int = 8
var radius: float = 10.0
var from_pos: Vector2 = Vector2.ZERO
var delay: float = 0.4                      ## 出手前(只有預警圈與影子)的秒數
var flight_time: float = 0.7
var arc_height: float = 40.0
var hit_margin: float = 2.0
var splash: StringName = &""                ## 落地效果:&"snow"、&"ink"、&"fire";空白 = 只有一圈
var puddle_time: float = 4.0                ## 墨汁留在地上的秒數
var state: State = State.WAIT
var hits: int = 0

var _left: float = 0.0
var _total: float = 1.0
var _telegraph: AttackTelegraph
var _ball: AnimatedSprite2D
var _age: float = 0.0


## 從 from 往 to 拋一顆。p_damage 已乘好難度;p_delay = 出手前的預警秒數;min_flight = 最短飛行秒數。
static func lob(host: Node, p_data: ProjectileData, from: Vector2, to: Vector2, p_damage: int,
		p_delay: float, min_flight: float = 0.55, speed_mult: float = 1.0, p_arc: float = 40.0) -> LobbedShot:
	if host == null or not host.is_inside_tree() or p_data == null:
		return null
	var shot := LobbedShot.new()
	shot.data = p_data
	shot.damage = maxi(1, p_damage)
	shot.radius = maxf(4.0, p_data.hit_radius)
	shot.from_pos = from
	shot.delay = maxf(0.0, p_delay)
	var speed := maxf(10.0, p_data.speed * maxf(0.05, speed_mult))
	shot.flight_time = maxf(min_flight, from.distance_to(to) / speed)
	shot.arc_height = p_arc
	CombatFx.layer_for(host, true).add_child(shot)
	shot.global_position = CombatMath.clamp_to_arena(to, 2.0)
	return shot


## 預警圈出現到落地一共幾秒(測試與 AI 用)。
func warning_time() -> float:
	return delay + flight_time


func is_pending() -> bool:
	return state != State.DONE


## 出手的敵人被打斷:還沒出手就整個消失(已經在飛的照樣落下)。
func cancel() -> void:
	if state == State.WAIT:
		state = State.DONE
		queue_free()


## 頭目倒下:不管飛到哪裡都消失(不再傷人)。
func fizzle() -> void:
	if state != State.DONE:
		state = State.DONE
		queue_free()


func _ready() -> void:
	add_to_group(&"combat_fx")
	_telegraph = AttackTelegraph.make_circle(radius)
	add_child(_telegraph)
	_total = maxf(0.05, delay + flight_time)
	_left = delay
	state = State.WAIT if delay > 0.0 else State.FLY
	if state == State.FLY:
		_launch()


func _physics_process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if _telegraph != null:
		_telegraph.progress = clampf(_age / _total, 0.0, 1.0)
	match state:
		State.WAIT:
			_left -= delta
			if _left <= 0.0:
				_launch()
		State.FLY:
			_left -= delta
			var t := 1.0 - clampf(_left / maxf(flight_time, 0.001), 0.0, 1.0)
			if _ball != null:
				var flat := (from_pos - global_position) * (1.0 - t)
				_ball.position = flat + Vector2(0, -arc_height * 4.0 * t * (1.0 - t))
				if data.spin_speed != 0.0:
					_ball.rotation += data.spin_speed * delta
				_ball.speed_scale = CombatFx.time_scale
			if _left <= 0.0:
				_land()
	queue_redraw()


func _launch() -> void:
	state = State.FLY
	_left = flight_time
	var frames := CombatFx.frames(data.fx)
	if frames != null and frames.has_animation(&"default"):
		_ball = AnimatedSprite2D.new()
		_ball.sprite_frames = frames
		_ball.scale = Vector2.ONE * data.visual_scale
		_ball.z_as_relative = false
		_ball.z_index = 10
		_ball.position = from_pos - global_position
		add_child(_ball)
		_ball.play(&"default")


func _land() -> void:
	state = State.DONE
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	if _ball != null:
		_ball.queue_free()
		_ball = null
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
	match splash:
		&"snow":
			BitsScatter.burst(self, global_position, BitsScatter.Kind.SNOW, SNOW_COLORS, 10)
			CombatFx.particles(self, &"snow_burst", global_position, true)
			CombatFx.ring(self, global_position, 2.0, radius + 3.0, 0.25, Color(1, 1, 1, 0.9), 2.0)
		&"ink":
			InkPuddle.spill(self, global_position, radius + 4.0, puddle_time)
			CombatFx.sfx(&"ink", &"hit", -8.0)
		&"fire":
			CombatFx.ring(self, global_position, 2.0, radius + 4.0, 0.3, Color(FIRE, 0.95), 2.0)
			CombatFx.ring(self, global_position, 1.0, radius, 0.35, Color(1.0, 0.85, 0.4, 0.5), 1.0, true, true)
			CombatFx.particles(self, &"sparkle", global_position, false)
		_:
			CombatFx.ring(self, global_position, 2.0, radius + 3.0, 0.25, Color(data.trail_color, 0.9), 2.0)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 0.9, Color.WHITE, true)
	queue_free()


## 影子:投射物越接近地面,影子越大越深(在預警圈之上、角色之下)。
func _draw() -> void:
	if state == State.DONE:
		return
	var t := clampf(_age / _total, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius * (0.35 + 0.55 * t), Color(0, 0, 0, 0.16 + 0.22 * t))
	draw_set_transform(Vector2.ZERO)
