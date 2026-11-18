class_name BitsScatter
extends Node2D
## v2.6:程式畫的「散開的小碎片」,讓倒下的樣子可愛、不像受傷(C 線之後可以另外加粒子圖)。
## - LEAF:葉子(影狼散成落葉、綠騎士的葉子):往上飄一下,再左右擺著慢慢落下。
## - CHIP:石屑(石像鬼):彈開、落地、彈一下。
## - PAGE:書頁(魔法書):往上翻飛,慢慢飄落。
## - MIST:淡淡的霧團(幻影黑騎士、摩根娜的鏡像):往上飄、變大、淡出。
## - BUBBLE(v2.7):泡泡(螃蟹、水母、章魚王):左右搖著往上飄,一個一個「啵」地破掉。
## - SNOW(v2.7):雪球碎成的雪花(雪人):往外彈開,慢慢飄落。
## 幾秒後淡出、自己刪除。在群組 combat_fx(場地 clear() 時一起移除);慢動作時跟著變慢。

enum Kind { LEAF, CHIP, PAGE, MIST, BUBBLE, SNOW }

const GRAVITY := 220.0

var kind: Kind = Kind.LEAF
var count: int = 12
var colors: Array[Color] = [Color("5f8f3a"), Color("3f6b2a"), Color("8fbf4a")]
var spread: float = 50.0                        ## 散開的初速(像素/秒)
var lift: float = 60.0                          ## 往上的初速
var fade_after: float = 1.6
var fade_time: float = 0.6

var _bits: Array[Dictionary] = []
var _age: float = 0.0


## 在 host 所在的場地放一團碎片。ground = true 放在角色之下。
static func burst(host: Node, at: Vector2, p_kind: Kind, p_colors: Array[Color], p_count: int = 12,
		ground: bool = false) -> BitsScatter:
	if host == null or not host.is_inside_tree():
		return null
	var bits := BitsScatter.new()
	bits.kind = p_kind
	bits.colors = p_colors
	bits.count = p_count
	CombatFx.layer_for(host, ground).add_child(bits)
	bits.global_position = at
	return bits


func _ready() -> void:
	add_to_group(&"combat_fx")
	if colors.is_empty():
		colors = [Color.WHITE]
	for i in count:
		var angle := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.4, 0.4)
		_bits.append({
			"pos": Vector2(randf_range(-4, 4), randf_range(-4, 2)),
			"vel": Vector2.from_angle(angle) * randf_range(spread * 0.4, spread),
			"height": randf_range(2.0, 10.0),
			"vz": randf_range(lift * 0.5, lift),
			"rot": randf() * TAU,
			"spin": randf_range(-8.0, 8.0),
			"size": randf_range(3.0, 6.0) if kind == Kind.MIST else (randf_range(1.5, 3.5) if kind == Kind.BUBBLE else randf_range(1.5, 3.0)),
			"pop": randf_range(0.5, 1.0) * fade_after,
			"phase": randf() * TAU,
			"color": colors[i % colors.size()],
		})


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	for bit in _bits:
		_simulate(bit, delta)
	if _age > fade_after:
		modulate.a = clampf(1.0 - (_age - fade_after) / maxf(fade_time, 0.001), 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()
			return
	queue_redraw()


func _simulate(bit: Dictionary, delta: float) -> void:
	var vel: Vector2 = bit["vel"]
	var height: float = bit["height"]
	var vz: float = bit["vz"]
	match kind:
		Kind.CHIP:
			if height > 0.0 or vz > 0.0:
				vz -= GRAVITY * delta
				height += vz * delta
				if height <= 0.0:
					height = 0.0
					vz = -vz * 0.35 if absf(vz) > 25.0 else 0.0
					vel *= 0.5
			else:
				vel = vel.move_toward(Vector2.ZERO, 120.0 * delta)
		Kind.LEAF, Kind.PAGE:
			# 先往上,再像葉子一樣左右擺著慢慢落下。
			vz = maxf(vz - GRAVITY * 0.45 * delta, -16.0)
			height = maxf(0.0, height + vz * delta)
			vel = vel.move_toward(Vector2.ZERO, 60.0 * delta)
			bit["phase"] = float(bit["phase"]) + delta * 5.0
			if height > 0.0:
				vel.x += sin(float(bit["phase"])) * 30.0 * delta
		Kind.MIST:
			height += 14.0 * delta
			vel = vel.move_toward(Vector2.ZERO, 50.0 * delta)
			bit["size"] = float(bit["size"]) + 4.0 * delta
		Kind.BUBBLE:
			height += 22.0 * delta
			vel = vel.move_toward(Vector2.ZERO, 70.0 * delta)
			bit["phase"] = float(bit["phase"]) + delta * 6.0
			vel.x += sin(float(bit["phase"])) * 24.0 * delta
		Kind.SNOW:
			vz = maxf(vz - GRAVITY * 0.6 * delta, -10.0)
			height = maxf(0.0, height + vz * delta)
			vel = vel.move_toward(Vector2.ZERO, 80.0 * delta)
			bit["phase"] = float(bit["phase"]) + delta * 4.0
			if height > 0.0:
				vel.x += sin(float(bit["phase"])) * 12.0 * delta
	bit["pos"] = (bit["pos"] as Vector2) + vel * delta
	bit["vel"] = vel
	bit["height"] = height
	bit["vz"] = vz
	if height > 0.0:
		bit["rot"] = float(bit["rot"]) + float(bit["spin"]) * delta


func _draw() -> void:
	for bit in _bits:
		var pos: Vector2 = bit["pos"]
		var height: float = bit["height"]
		var color: Color = bit["color"]
		var size: float = bit["size"]
		var at := (pos + Vector2(0, -height)).round()
		match kind:
			Kind.MIST:
				draw_circle(at, size, Color(color, color.a * 0.45))
				draw_circle(at, size * 0.55, Color(color.lightened(0.3), color.a * 0.35))
			Kind.BUBBLE:
				if _age < float(bit["pop"]):
					draw_arc(at, size, 0.0, TAU, 10, Color(color, color.a * 0.9), 1.0)
					draw_rect(Rect2(at + Vector2(-size * 0.45, -size * 0.55), Vector2.ONE), Color(1, 1, 1, 0.9))
				elif _age < float(bit["pop"]) + 0.12:
					# 「啵」:破掉的一瞬間變成四個小點。
					for k in 4:
						draw_rect(Rect2((at + Vector2.from_angle(PI * 0.5 * float(k) + 0.6) * (size + 1.5)).round(), Vector2.ONE), color)
			Kind.SNOW:
				draw_circle(pos.round() + Vector2(0, 1), size * 0.5, Color(0, 0, 0, 0.12))
				draw_circle(at, size * 0.6, color)
			Kind.CHIP:
				draw_circle(pos.round() + Vector2(0, 1), size * 0.6, Color(0, 0, 0, 0.18))
				draw_rect(Rect2(at - Vector2.ONE * size * 0.5, Vector2.ONE * size).abs(), color)
			_:
				# 葉子與書頁:旋轉的小菱形(葉子)或小長方形(書頁)。
				var r: float = bit["rot"]
				var a := Vector2.from_angle(r) * size
				var b := Vector2.from_angle(r + PI * 0.5) * size * (0.45 if kind == Kind.LEAF else 0.8)
				var points := PackedVector2Array([at + a, at + b, at - a, at - b])
				draw_colored_polygon(points, color)
