extends Node2D
## 黑騎士被打敗後的盔甲(A11):碎片四散彈跳,頭盔滾出來,停下時翻過來,
## 看得到裡面是空的,紫色魔法煙飄走。碎片與頭盔用程式畫(C 線之後可換成圖);
## 留在地上的胸甲用 black_knight_frames 的 "down" 動畫。
## 在群組 combat_fx,場地 clear() 時移除。

const STEEL := Color("4a4f5c")
const STEEL_LIGHT := Color("8a91a3")
const STEEL_DARK := Color("23262e")
const SWORD := Color("cfd4de")
const PLUME := Color("b8323a")
const EMPTY := Color("0d0812")
const WISP := Color(0.78, 0.52, 1.0, 0.9)
const GRAVITY := 260.0
const HELMET_RADIUS := 6.0

var flip: bool = false
var sprite_frames: SpriteFrames

var helmet_settled: bool = false
var _pieces: Array[Dictionary] = []
var _helmet: Dictionary = {}
var _age: float = 0.0
var _wisps: int = 0
var _next_wisp: float = 0.0


func _ready() -> void:
	add_to_group(&"combat_fx")
	if sprite_frames != null and sprite_frames.has_animation(&"down"):
		var body := AnimatedSprite2D.new()
		body.sprite_frames = sprite_frames
		body.flip_h = flip
		body.modulate = Color(0.85, 0.85, 0.9)
		add_child(body)
		body.play(&"down")
	var specs: Array = [
		[Vector2(8, 5), STEEL], [Vector2(8, 5), STEEL],          # 肩甲
		[Vector2(5, 5), STEEL_LIGHT], [Vector2(5, 5), STEEL_LIGHT], # 護手
		[Vector2(4, 7), STEEL], [Vector2(4, 7), STEEL],          # 護脛
		[Vector2(2, 15), SWORD],                                  # 劍
	]
	for i in specs.size():
		var angle := TAU * float(i) / float(specs.size()) + randf_range(-0.3, 0.3)
		_pieces.append({
			"pos": Vector2.ZERO, "vel": Vector2.from_angle(angle) * randf_range(30.0, 55.0),
			"height": 10.0, "vz": randf_range(45.0, 75.0), "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "size": specs[i][0], "color": specs[i][1],
		})
	var roll_dir := Vector2(-1.0 if flip else 1.0, 0.35).normalized()
	_helmet = {"pos": Vector2(0, -2), "vel": roll_dir * 48.0, "height": 16.0, "vz": 35.0, "rot": 0.0, "tip": 0.0}


func _process(delta: float) -> void:
	_age += delta
	for piece in _pieces:
		_simulate(piece, delta, true)
		if piece["height"] <= 0.0:
			piece["spin"] = float(piece["spin"]) * exp(-6.0 * delta)
		piece["rot"] = float(piece["rot"]) + float(piece["spin"]) * delta
	_simulate(_helmet, delta, false)
	var speed := (_helmet["vel"] as Vector2).length()
	if _helmet["height"] <= 0.0:
		# 滾動:轉的角度 = 走的距離 / 半徑。
		_helmet["rot"] = float(_helmet["rot"]) + speed * delta / HELMET_RADIUS * signf((_helmet["vel"] as Vector2).x + 0.001)
		_helmet["vel"] = (_helmet["vel"] as Vector2).move_toward(Vector2.ZERO, 22.0 * delta)
		if speed < 3.0 and _age > 0.6:
			_helmet["vel"] = Vector2.ZERO
			_helmet["tip"] = minf(1.0, float(_helmet["tip"]) + delta / 0.25)
			helmet_settled = float(_helmet["tip"]) >= 1.0
	if helmet_settled and _wisps < 4 and _age >= _next_wisp:
		_wisps += 1
		_next_wisp = _age + 0.22
		var fx := CombatFx.spawn(self, &"dust", global_position + (_helmet["pos"] as Vector2) + Vector2(randf_range(-2, 2), -5),
				0.0, Vector2.ONE, WISP, false, 1.0)
		if fx != null:
			fx.drift = Vector2(randf_range(-4.0, 4.0), -16.0)
			fx.fade_out = true
	queue_redraw()
	if _age > 4.0:
		set_process(false)


## ground_friction:落地後滑動很快停下(碎片);頭盔自己處理滾動。
func _simulate(item: Dictionary, delta: float, ground_friction: bool) -> void:
	var height: float = item["height"]
	var vz: float = item["vz"]
	if height > 0.0 or vz > 0.0:
		vz -= GRAVITY * delta
		height += vz * delta
		if height <= 0.0:
			height = 0.0
			if absf(vz) > 25.0:
				vz = -vz * 0.35
				item["vel"] = (item["vel"] as Vector2) * 0.6
			else:
				vz = 0.0
		item["height"] = height
		item["vz"] = vz
	elif ground_friction:
		item["vel"] = (item["vel"] as Vector2).move_toward(Vector2.ZERO, 120.0 * delta)
	var pos: Vector2 = item["pos"] + (item["vel"] as Vector2) * delta
	var world := CombatMath.clamp_to_arena(global_position + pos, 3.0)
	item["pos"] = world - global_position


func _draw() -> void:
	for piece in _pieces:
		var size: Vector2 = piece["size"]
		var at: Vector2 = (piece["pos"] as Vector2) + Vector2(0, -float(piece["height"]))
		_draw_shadow(piece["pos"], size.x * 0.5)
		draw_set_transform(at, piece["rot"])
		draw_rect(Rect2(-size * 0.5, size), piece["color"])
		draw_rect(Rect2(-size * 0.5, Vector2(size.x, 1)), STEEL_LIGHT)
		draw_rect(Rect2(-size * 0.5, size), STEEL_DARK, false, 1.0)
		draw_set_transform(Vector2.ZERO)
	_draw_helmet()


func _draw_helmet() -> void:
	var base: Vector2 = _helmet["pos"]
	var at := base + Vector2(0, -float(_helmet["height"]) - HELMET_RADIUS * 0.5)
	_draw_shadow(base, HELMET_RADIUS)
	var tip: float = _helmet["tip"]
	if tip < 0.5:
		# 側面:圓頂、面罩縫、紅色羽飾,邊滾邊轉。
		draw_set_transform(at, _helmet["rot"])
		draw_circle(Vector2.ZERO, HELMET_RADIUS, STEEL)
		draw_arc(Vector2.ZERO, HELMET_RADIUS, 0.0, TAU, 16, STEEL_DARK, 1.0)
		draw_rect(Rect2(-4, -1, 8, 2), STEEL_DARK)
		draw_rect(Rect2(-1, -HELMET_RADIUS - 3, 2, 4), PLUME)
		draw_set_transform(Vector2.ZERO)
	else:
		# 翻過來:開口朝上,裡面黑漆漆、空空的。
		draw_set_transform(at, 0.0, Vector2(1.0, 0.8))
		draw_circle(Vector2.ZERO, HELMET_RADIUS, STEEL)
		draw_arc(Vector2.ZERO, HELMET_RADIUS, 0.0, TAU, 16, STEEL_LIGHT, 1.0)
		draw_circle(Vector2.ZERO, HELMET_RADIUS - 2.0, EMPTY)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(at + Vector2(HELMET_RADIUS - 1, -1), Vector2(4, 2)), PLUME)


func _draw_shadow(at: Vector2, radius: float) -> void:
	draw_set_transform(at + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
