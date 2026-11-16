class_name StrawScatter
extends Node2D
## 稻草人隊長倒下時散成一堆稻草(AS3):一根根稻草四散、彈跳、落地,隊長帽(紫色帽帶)掉在地上翻一下;
## 幾秒後慢慢淡出(紫色羽毛 PurpleFeather 另外飄落,一直留到這一關結束)。
## 程式畫的(C 線之後可以換成圖)。在群組 combat_fx,放在地面層;慢動作時跟著變慢。

const STRAW := Color("e9c86c")
const STRAW_DARK := Color("b28a3c")
const HAT := Color("6a4a2f")
const HAT_DARK := Color("3f2a1a")
const HAT_BAND := Color("8f48cf")
const GRAVITY := 260.0

var count: int = 14
var fade_after: float = 3.2
var fade_time: float = 0.8
var flip: bool = false

var _sticks: Array[Dictionary] = []
var _hat: Dictionary = {}
var _age: float = 0.0


func _ready() -> void:
	add_to_group(&"combat_fx")
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.35, 0.35)
		_sticks.append({
			"pos": Vector2(randf_range(-4, 4), randf_range(-3, 3)),
			"vel": Vector2.from_angle(angle) * randf_range(22.0, 60.0),
			"height": randf_range(6.0, 16.0), "vz": randf_range(35.0, 85.0),
			"rot": randf() * TAU, "spin": randf_range(-14.0, 14.0), "len": randf_range(4.0, 7.0),
			"color": STRAW if i % 3 != 0 else STRAW_DARK,
		})
	var side := -1.0 if flip else 1.0
	_hat = {"pos": Vector2(0, -2), "vel": Vector2(side * 22.0, 6.0), "height": 18.0, "vz": 60.0,
			"rot": 0.0, "spin": side * 7.0}


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	for stick in _sticks:
		_simulate(stick, delta)
	_simulate(_hat, delta)
	if _age > fade_after:
		modulate.a = clampf(1.0 - (_age - fade_after) / maxf(fade_time, 0.001), 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()
			return
	queue_redraw()


func _simulate(item: Dictionary, delta: float) -> void:
	var height: float = item["height"]
	var vz: float = item["vz"]
	if height > 0.0 or vz > 0.0:
		vz -= GRAVITY * delta
		height += vz * delta
		item["rot"] = float(item["rot"]) + float(item["spin"]) * delta
		if height <= 0.0:
			height = 0.0
			if absf(vz) > 30.0:
				vz = -vz * 0.3
				item["vel"] = (item["vel"] as Vector2) * 0.5
				item["spin"] = float(item["spin"]) * 0.5
			else:
				vz = 0.0
		item["height"] = height
		item["vz"] = vz
	else:
		item["vel"] = (item["vel"] as Vector2).move_toward(Vector2.ZERO, 140.0 * delta)
	var pos: Vector2 = item["pos"] + (item["vel"] as Vector2) * delta
	item["pos"] = CombatMath.clamp_to_arena(global_position + pos, 3.0) - global_position


func _draw() -> void:
	for stick in _sticks:
		var base: Vector2 = stick["pos"]
		var at := base + Vector2(0, -float(stick["height"]))
		var half := Vector2.from_angle(stick["rot"]) * float(stick["len"]) * 0.5
		draw_line(base - half + Vector2(0, 1), base + half + Vector2(0, 1), Color(0, 0, 0, 0.18), 1.0)
		draw_line(at - half, at + half, stick["color"], 1.0)
	var hat_base: Vector2 = _hat["pos"]
	var hat_at := hat_base + Vector2(0, -float(_hat["height"]))
	draw_set_transform(hat_base + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.22))
	draw_set_transform(hat_at, _hat["rot"])
	draw_rect(Rect2(-6, 1, 12, 2), HAT_DARK)              # 帽沿
	draw_rect(Rect2(-4, -4, 8, 5), HAT)                   # 帽頂
	draw_rect(Rect2(-4, -1, 8, 1), HAT_BAND)              # 紫色帽帶(羽毛原本插在這裡)
	draw_rect(Rect2(-4, -4, 8, 1), HAT.lightened(0.25))
	draw_set_transform(Vector2.ZERO)
