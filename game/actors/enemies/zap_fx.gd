class_name ZapFx
extends Node2D
## v2.7 電電水母放電的樣子(程式畫的):從中心往外的幾條鋸齒狀小閃電,很快閃兩下就消失。
## 只是畫面;打中的判定在 JellyfishEnemy(和預警圈同一個範圍)。放在特效層,在群組 combat_fx。

const BOLT := Color(1.0, 0.95, 0.5)
const GLOW := Color(0.6, 0.9, 1.0)

var radius: float = 22.0
var lifetime: float = 0.28
var bolts: int = 7

var _age: float = 0.0
var _seed: int = 0


static func zap(host: Node, at: Vector2, p_radius: float) -> ZapFx:
	if host == null or not host.is_inside_tree():
		return null
	var fx := ZapFx.new()
	fx.radius = p_radius
	CombatFx.layer_for(host).add_child(fx)
	fx.global_position = at
	return fx


func _ready() -> void:
	add_to_group(&"combat_fx")
	_seed = randi()


func _process(delta: float) -> void:
	_age += delta * CombatFx.time_scale
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var blink := int(_age / 0.07) % 2 == 0
	var a := 1.0 if blink else 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(_age / 0.07)
	draw_circle(Vector2.ZERO, radius * 0.35, Color(GLOW, 0.35 * a))
	for i in bolts:
		var dir := Vector2.from_angle(TAU * float(i) / float(bolts) + rng.randf_range(-0.25, 0.25))
		var normal := dir.orthogonal()
		var prev := Vector2.ZERO
		for k in range(1, 5):
			var t := float(k) / 4.0
			var p := dir * radius * t + normal * rng.randf_range(-3.0, 3.0) * (1.0 - t * 0.5)
			draw_line(prev, p, Color(GLOW, 0.6 * a), 3.0)
			draw_line(prev, p, Color(BOLT, a), 1.0)
			prev = p
