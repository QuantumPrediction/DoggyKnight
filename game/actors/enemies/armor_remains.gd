extends Node2D
## 黑騎士被打敗後的盔甲(A11):碎片四散彈跳,頭盔滾出來,停下時翻過來,
## 看得到裡面是空的,紫色魔法煙飄走。慢動作時(CombatFx.time_scale)跟著變慢。
## 碎片與頭盔用程式畫(C 線之後可換成圖);
## 留在地上的胸甲用 black_knight_frames 的 "down" 動畫。
## 在群組 combat_fx,場地 clear() 時移除。
##
## v2.3(AS2):空盔甲兵也用這個(configure_small()):碎片較小、較少,頭盔的羽飾是藍色,
## 一縷藍色火光(MagicWisp)從盔甲裡飛走;幾秒後盔甲淡出(一關會打倒很多隻,不留滿地)。

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
var piece_scale: float = 1.0                      ## 碎片大小倍數
var piece_count: int = 7                          ## 用 SPECS 的前幾個
var helmet_radius: float = HELMET_RADIUS
var plume_color: Color = PLUME
var wisp_color: Color = WISP                      ## 頭盔翻過來後飄走的魔法煙
var fade_after: float = -1.0                      ## 幾秒後淡出並移除;< 0 = 一直留著
var fade_time: float = 0.6
var spread: float = 1.0                           ## 碎片飛散的速度倍數

var helmet_settled: bool = false
var _pieces: Array[Dictionary] = []
var _helmet: Dictionary = {}
var _age: float = 0.0
var _wisps: int = 0
var _next_wisp: float = 0.0


## 空盔甲兵的小盔甲:碎片小一點、少一點,藍色羽飾與藍色火光,幾秒後淡出。
func configure_small() -> void:
	piece_scale = 0.65
	piece_count = 5
	helmet_radius = 4.0
	plume_color = Color("3d5fb0")
	wisp_color = Color(0.45, 0.75, 1.0, 0.9)
	fade_after = 2.4
	spread = 0.75


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
		[Vector2(2, 15), SWORD],                                  # 劍
		[Vector2(5, 5), STEEL_LIGHT], [Vector2(5, 5), STEEL_LIGHT], # 護手
		[Vector2(4, 7), STEEL], [Vector2(4, 7), STEEL],          # 護脛
	]
	var count := clampi(piece_count, 1, specs.size())
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var size: Vector2 = specs[i][0]
		_pieces.append({
			"pos": Vector2.ZERO, "vel": Vector2.from_angle(angle) * randf_range(30.0, 55.0) * spread,
			"height": 10.0 * piece_scale, "vz": randf_range(45.0, 75.0) * spread, "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "size": (size * piece_scale).round().max(Vector2.ONE),
			"color": specs[i][1],
		})
	var roll_dir := Vector2(-1.0 if flip else 1.0, 0.35).normalized()
	_helmet = {"pos": Vector2(0, -2), "vel": roll_dir * 48.0 * spread, "height": 16.0 * piece_scale, "vz": 35.0,
			"rot": 0.0, "tip": 0.0}


func _process(delta: float) -> void:
	# 打倒頭目時的慢動作:盔甲碎片以慢動作飛散,再漸漸回到正常速度。
	delta *= CombatFx.time_scale
	_age += delta
	if fade_after >= 0.0 and _age > fade_after:
		modulate.a = clampf(1.0 - (_age - fade_after) / maxf(fade_time, 0.001), 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()
			return
	for piece in _pieces:
		_simulate(piece, delta, true)
		if piece["height"] <= 0.0:
			piece["spin"] = float(piece["spin"]) * exp(-6.0 * delta)
		piece["rot"] = float(piece["rot"]) + float(piece["spin"]) * delta
	_simulate(_helmet, delta, false)
	var speed := (_helmet["vel"] as Vector2).length()
	if _helmet["height"] <= 0.0:
		# 滾動:轉的角度 = 走的距離 / 半徑。
		_helmet["rot"] = float(_helmet["rot"]) + speed * delta / helmet_radius * signf((_helmet["vel"] as Vector2).x + 0.001)
		_helmet["vel"] = (_helmet["vel"] as Vector2).move_toward(Vector2.ZERO, 22.0 * delta)
		if speed < 3.0 and _age > 0.6:
			_helmet["vel"] = Vector2.ZERO
			_helmet["tip"] = minf(1.0, float(_helmet["tip"]) + delta / 0.25)
			helmet_settled = float(_helmet["tip"]) >= 1.0
	if helmet_settled and _wisps < 4 and _age >= _next_wisp:
		_wisps += 1
		_next_wisp = _age + 0.22
		var fx := CombatFx.spawn(self, &"dust", global_position + (_helmet["pos"] as Vector2) + Vector2(randf_range(-2, 2), -5),
				0.0, Vector2.ONE * piece_scale, wisp_color, false, 1.0)
		if fx != null:
			fx.drift = Vector2(randf_range(-4.0, 4.0), -16.0)
			fx.fade_out = true
	queue_redraw()
	if _age > 4.0 and fade_after < 0.0:
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
	var hr := helmet_radius
	var at := base + Vector2(0, -float(_helmet["height"]) - hr * 0.5)
	_draw_shadow(base, hr)
	var tip: float = _helmet["tip"]
	if tip < 0.5:
		# 側面:圓頂、面罩縫、紅色羽飾,邊滾邊轉。
		draw_set_transform(at, _helmet["rot"])
		draw_circle(Vector2.ZERO, hr, STEEL)
		draw_arc(Vector2.ZERO, hr, 0.0, TAU, 16, STEEL_DARK, 1.0)
		draw_rect(Rect2(-hr + 2.0, -1, hr * 2.0 - 4.0, 2), STEEL_DARK)
		draw_rect(Rect2(-1, -hr - 3, 2, 4), plume_color)
		draw_set_transform(Vector2.ZERO)
	else:
		# 翻過來:開口朝上,裡面黑漆漆、空空的。
		draw_set_transform(at, 0.0, Vector2(1.0, 0.8))
		draw_circle(Vector2.ZERO, hr, STEEL)
		draw_arc(Vector2.ZERO, hr, 0.0, TAU, 16, STEEL_LIGHT, 1.0)
		draw_circle(Vector2.ZERO, maxf(1.0, hr - 2.0), EMPTY)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(at + Vector2(hr - 1, -1), Vector2(4, 2)), plume_color)


func _draw_shadow(at: Vector2, radius: float) -> void:
	draw_set_transform(at + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
