class_name CampScenery
extends Control
## 營地的景物(DEV_PLAN 15 DP1)。全部用程式畫像素圖,不需要外部素材;CampConfig 有正式圖時改用正式圖。
##
## 一個營地有三個 CampScenery,依 part 分工(由下往上疊):
## - SKY:夜空漸層、閃爍的星星、月亮、偶爾的流星、遠山與卡美洛城堡的剪影、松樹。
## - GROUND:草地、營火旁的空地、圓桌、木頭椅、卸下的盔甲與劍、營火(木柴、石頭、跳動的火焰)。
## - GLOW:營火的光暈(加亮混合,會閃爍),照在金毛、鬥牛犬與地面上。
## 位置(horizon_y、fire_spot 等)由 Camp._layout() 設定。

enum Part { SKY, GROUND, GLOW }

var part: Part = Part.SKY
var config: CampConfig
var time: float = 0.0
## 營火閃爍的強度(約 0.85 至 1.15),由 Camp 每格計算,三個部分共用。
var flicker: float = 1.0

var horizon_y: float = 200.0
var fire_spot: Vector2 = Vector2.ZERO
var table_spot: Vector2 = Vector2.ZERO
var log_spot: Vector2 = Vector2.ZERO
var moon_spot: Vector2 = Vector2.ZERO

## 流星:{"pos": Vector2, "vel": Vector2, "age": float, "life": float}
var meteors: Array[Dictionary] = []
var _next_meteor: float = 2.0
var _rng := RandomNumberGenerator.new()


func _init(p_part: Part = Part.SKY, p_config: CampConfig = null) -> void:
	part = p_part
	config = p_config
	name = String(Part.keys()[p_part]).capitalize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	if p_part == Part.GLOW:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _ready() -> void:
	if config != null:
		_next_meteor = _rng.randf_range(config.shooting_star_every_min * 0.4, config.shooting_star_every_min)


func advance(delta: float) -> void:
	time += delta
	if part == Part.SKY:
		_update_meteors(delta)
	queue_redraw()


func _draw() -> void:
	if config == null:
		return
	match part:
		Part.SKY:
			_draw_sky()
		Part.GROUND:
			_draw_ground()
		Part.GLOW:
			_draw_glow()


# --- 流星 ---

func _update_meteors(delta: float) -> void:
	_next_meteor -= delta
	if _next_meteor <= 0.0:
		_next_meteor = _rng.randf_range(config.shooting_star_every_min, maxf(config.shooting_star_every_min, config.shooting_star_every_max))
		spawn_meteor()
	for m: Dictionary in meteors:
		m["age"] = float(m["age"]) + delta
		m["pos"] = (m["pos"] as Vector2) + (m["vel"] as Vector2) * delta
	meteors = meteors.filter(func(m: Dictionary) -> bool: return float(m["age"]) < float(m["life"]))


## 立刻放一顆流星(測試與截圖也用)。
func spawn_meteor() -> void:
	var screen := SafeArea.get_screen_size()
	var start := Vector2(_rng.randf_range(screen.x * 0.35, screen.x + 10.0), _rng.randf_range(4.0, maxf(10.0, horizon_y * 0.45)))
	var speed := _rng.randf_range(120.0, 170.0)
	var dir := Vector2(-1.0, _rng.randf_range(0.35, 0.6)).normalized()
	meteors.append({"pos": start, "vel": dir * speed, "age": 0.0, "life": _rng.randf_range(0.45, 0.7)})


# --- 夜空 ---

func _draw_sky() -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := horizon_y
	if config.background_texture != null:
		var tex_size := config.background_texture.get_size()
		var game := SafeArea.get_game_rect()
		draw_rect(Rect2(Vector2.ZERO, screen), config.sky_top_color)
		draw_texture(config.background_texture, (game.get_center() - tex_size * 0.5).round())
		return
	var bands := 12
	for i in bands:
		var c := config.sky_top_color.lerp(config.sky_bottom_color, float(i) / (bands - 1))
		draw_rect(Rect2(0, floorf(horizon * i / bands), screen.x, ceilf(horizon / bands) + 1.0), c)
	# 星星(位置固定,亮度各自閃爍)
	for i in config.star_count:
		var star := Vector2(fmod(i * 47.0 + 13.0 + (i % 3) * 5.0, screen.x), fmod(i * 29.0 + 7.0 + (i % 5) * 11.0, maxf(horizon - 14.0, 20.0)))
		var twinkle := 0.5 + 0.5 * sin(time * (1.1 + (i % 4) * 0.45) + i * 1.3)
		var color := Color(1, 1, 0.85, 0.25 + 0.65 * twinkle)
		if i % 9 == 0:
			# 大星星:十字形
			draw_rect(Rect2(star.round(), Vector2.ONE), Color(1, 1, 0.95, 0.9))
			var arm := Color(color, color.a * 0.6)
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2((star + d).round(), Vector2.ONE), arm)
		else:
			draw_rect(Rect2(star.round(), Vector2.ONE), color)
	# 慢慢飄過的雲(半透明,蓋住後面的星星一點點)
	for i in 3:
		var speed := 2.0 + i * 1.3
		var cloud_x := fmod(i * 83.0 + time * speed, screen.x + 70.0) - 35.0
		var cloud_y := roundf(horizon * (0.22 + i * 0.2))
		var cloud_color := Color(config.sky_bottom_color.lightened(0.12), 0.35)
		for puff: Vector3 in [Vector3(0, 0, 9), Vector3(10, -3, 7), Vector3(-10, 1, 6), Vector3(18, 1, 5)]:
			_draw_ellipse(Vector2(roundf(cloud_x) + puff.x, cloud_y + puff.y), Vector2(puff.z * 1.4, puff.z * 0.55), cloud_color)
	# 月亮(新月)與月暈
	var moon := moon_spot
	draw_circle(moon, 14.0, Color(1, 0.95, 0.75, 0.05))
	draw_circle(moon, 11.0, Color(1, 0.95, 0.75, 0.07))
	draw_circle(moon, 9.0, Color("fff3c4"))
	draw_circle(moon + Vector2(4, -2), 8.0, config.sky_top_color.lerp(config.sky_bottom_color, 0.15))
	# 流星
	for m: Dictionary in meteors:
		var t := float(m["age"]) / float(m["life"])
		var alpha := sin(t * PI)
		var head := m["pos"] as Vector2
		var back := -(m["vel"] as Vector2).normalized()
		for k in 14:
			var a := alpha * (1.0 - k / 14.0)
			draw_rect(Rect2((head + back * k).round(), Vector2.ONE), Color(1, 0.97, 0.85, a))
		draw_rect(Rect2(head.round() - Vector2.ONE * 0.5, Vector2(2, 2)), Color(1, 1, 1, alpha))
	# 遠山
	var far := config.sky_bottom_color.darkened(0.25)
	var hills := PackedVector2Array([Vector2(0, horizon), Vector2(0, horizon - 16), Vector2(screen.x * 0.18, horizon - 28),
		Vector2(screen.x * 0.4, horizon - 18), Vector2(screen.x * 0.62, horizon - 34), Vector2(screen.x * 0.85, horizon - 20),
		Vector2(screen.x, horizon - 26), Vector2(screen.x, horizon)])
	draw_colored_polygon(hills, far)
	_draw_castle(Vector2(roundf(screen.x * 0.62), horizon - 33.0), far.darkened(0.25))
	# 近處的山丘與松樹剪影
	var near := config.sky_bottom_color.darkened(0.5)
	var hills2 := PackedVector2Array([Vector2(0, horizon), Vector2(0, horizon - 8), Vector2(screen.x * 0.3, horizon - 12),
		Vector2(screen.x * 0.55, horizon - 6), Vector2(screen.x * 0.8, horizon - 13), Vector2(screen.x, horizon - 7), Vector2(screen.x, horizon)])
	draw_colored_polygon(hills2, near)
	for i in 7:
		var x := fmod(i * 61.0 + 9.0, screen.x + 20.0) - 10.0
		if absf(x - screen.x * 0.62) < 26.0:
			continue
		_draw_pine(Vector2(roundf(x), horizon - 6.0), 10.0 + float(i % 3) * 4.0, near.darkened(0.15))


func _draw_castle(base: Vector2, color: Color) -> void:
	# 卡美洛城堡的剪影:城牆、三座塔、旗子、亮著的窗
	draw_rect(Rect2(base + Vector2(-16, -8), Vector2(32, 9)), color)
	for i in 5:
		draw_rect(Rect2(base + Vector2(-16 + i * 7, -10), Vector2(3, 2)), color)
	for tower: Vector3 in [Vector3(-16, 18, 6), Vector3(10, 18, 6), Vector3(-4, 26, 8)]:
		var top := base + Vector2(tower.x, -tower.y)
		draw_rect(Rect2(top, Vector2(tower.z, tower.y)), color)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-1, 0), top + Vector2(tower.z * 0.5, -6), top + Vector2(tower.z + 1, 0)]), color)
	# 旗子(飄動)
	var pole := base + Vector2(0, -32)
	draw_rect(Rect2(pole, Vector2(1, 5)), color)
	var wave := 1.0 if fmod(time * 3.0, 2.0) < 1.0 else 0.0
	draw_rect(Rect2(pole + Vector2(1, wave * 0.0), Vector2(4, 2)), Color("e8434f").darkened(0.35))
	draw_rect(Rect2(pole + Vector2(4, wave), Vector2(1, 2)), Color("e8434f").darkened(0.35))
	# 窗戶的燈光(慢慢閃)
	var windows := [Vector2(-13, -14), Vector2(13, -13), Vector2(-1, -20), Vector2(-8, -5), Vector2(6, -5)]
	for i in windows.size():
		var on := 0.55 + 0.45 * sin(time * 0.9 + i * 2.1)
		draw_rect(Rect2(base + (windows[i] as Vector2), Vector2(1, 2)), Color(1, 0.85, 0.4, on))


func _draw_pine(base: Vector2, height: float, color: Color) -> void:
	var w := height * 0.45
	for layer in 3:
		var y := base.y - height * (0.3 + layer * 0.3)
		var half := w * (1.0 - layer * 0.28)
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - half, y + height * 0.35), Vector2(base.x, y - height * 0.12),
			Vector2(base.x + half, y + height * 0.35)]), color)
	draw_rect(Rect2(base + Vector2(-1, -2), Vector2(2, 3)), color)


# --- 地面、圓桌、營火 ---

func _draw_ground() -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := horizon_y
	draw_rect(Rect2(0, horizon, screen.x, screen.y - horizon), config.ground_color)
	draw_rect(Rect2(0, horizon, screen.x, 1), config.ground_color.lightened(0.12))
	# 營火旁踩平的空地
	_draw_ellipse(fire_spot + Vector2(0, 10), Vector2(64, 16), config.ground_color.lerp(Color("5a4a32"), 0.45))
	_draw_ellipse(fire_spot + Vector2(0, 10), Vector2(46, 10), config.ground_color.lerp(Color("6a5638"), 0.5))
	# 草(隨風輕輕搖)
	for i in 34:
		var tuft := Vector2(fmod(i * 53.0 + 5.0, screen.x), horizon + 6.0 + fmod(i * 31.0, maxf(screen.y - horizon - 8.0, 8.0)))
		if absf(tuft.x - fire_spot.x) < 60.0 and absf(tuft.y - fire_spot.y - 10.0) < 14.0:
			continue
		var sway := 1.0 if sin(time * 1.6 + i * 0.7) > 0.3 else 0.0
		if i % 6 == 0:
			# 小花
			var petal := Color("fffaf0") if i % 12 == 0 else Color("ffe066")
			draw_rect(Rect2(tuft.round() + Vector2(1, 0), Vector2(1, 3)), config.ground_light_color)
			draw_rect(Rect2(tuft.round() + Vector2(sway, -2), Vector2(3, 1)), Color(petal, 0.85))
			draw_rect(Rect2(tuft.round() + Vector2(1 + sway, -3), Vector2(1, 3)), Color(petal, 0.85))
			draw_rect(Rect2(tuft.round() + Vector2(1 + sway, -2), Vector2(1, 1)), Color("ff8a3d"))
			continue
		draw_rect(Rect2(tuft.round(), Vector2(1, 2)), config.ground_light_color)
		draw_rect(Rect2(tuft.round() + Vector2(1 + sway, -1), Vector2(1, 2)), config.ground_light_color)
		draw_rect(Rect2(tuft.round() + Vector2(2, 0), Vector2(1, 2)), config.ground_light_color.darkened(0.15))
	if config.table_texture != null:
		var t_size := config.table_texture.get_size()
		draw_texture(config.table_texture, (table_spot - t_size * 0.5).round())
	else:
		_draw_table()
	_draw_armor()
	_draw_log()
	_draw_fire()


func _draw_table() -> void:
	var c := table_spot
	# 圓桌:從正面看是一個扁扁的橢圓,加上桌腳
	_draw_ellipse(c + Vector2(0, 20), Vector2(50, 5), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(c + Vector2(-40, 6), Vector2(4, 16)), config.table_edge_color)
	draw_rect(Rect2(c + Vector2(36, 6), Vector2(4, 16)), config.table_edge_color)
	draw_rect(Rect2(c + Vector2(-2, 8), Vector2(4, 16)), config.table_edge_color)
	_draw_ellipse(c + Vector2(0, 4), Vector2(56, 14), config.table_edge_color)
	_draw_ellipse(c, Vector2(56, 14), config.table_color)
	_draw_ellipse(c + Vector2(0, -2), Vector2(44, 9), config.table_color.lightened(0.12))
	# 木紋
	for i in 3:
		draw_rect(Rect2(c + Vector2(-30 + i * 22, -1 + (i % 2) * 3), Vector2(12, 1)), config.table_color.darkened(0.12))
	# 桌上的王室卷軸(暗示小遊戲)、蠟燭與杯子
	draw_rect(Rect2(c + Vector2(-26, -5), Vector2(22, 6)), Color("f3e6c4"))
	draw_rect(Rect2(c + Vector2(-26, -5), Vector2(22, 1)), Color("fffaf0"))
	draw_rect(Rect2(c + Vector2(-28, -6), Vector2(3, 8)), Color("e0b040"))
	draw_rect(Rect2(c + Vector2(-5, -6), Vector2(3, 8)), Color("e0b040"))
	draw_rect(Rect2(c + Vector2(-18, -5), Vector2(2, 6)), Color("b8323a"))
	draw_rect(Rect2(c + Vector2(12, -10), Vector2(7, 9)), Color("c9c9d9"))
	draw_rect(Rect2(c + Vector2(12, -10), Vector2(7, 1)), Color("fffaf0"))
	draw_rect(Rect2(c + Vector2(19, -8), Vector2(2, 4)), Color("c9c9d9"))
	# 蠟燭(小小的火光在搖)
	var candle := c + Vector2(30, -6)
	draw_rect(Rect2(candle + Vector2(-1, -5), Vector2(3, 6)), Color("fff1c9"))
	var lean := 1.0 if sin(time * 7.0) > 0.4 else 0.0
	draw_rect(Rect2(candle + Vector2(lean, -8), Vector2(1, 2)), Color("ffe066"))
	draw_rect(Rect2(candle + Vector2(0, -7), Vector2(1, 2)), Color("ff8a3d"))


## 卸下的盔甲靠在桌腳,劍插在地上:金毛今晚是普通的狗。
func _draw_armor() -> void:
	var c := table_spot + Vector2(-64, 18)
	var ink := Color("2a1b2d")
	# 劍:插在地上,劍柄朝上
	var sword := c + Vector2(-8, 0)
	draw_rect(Rect2(sword + Vector2(-1, -22), Vector2(4, 20)), ink)
	draw_rect(Rect2(sword + Vector2(0, -21), Vector2(2, 19)), Color("d5dbe8"))
	draw_rect(Rect2(sword + Vector2(1, -21), Vector2(1, 19)), Color("95a1bd"))
	draw_rect(Rect2(sword + Vector2(-4, -24), Vector2(10, 3)), ink)
	draw_rect(Rect2(sword + Vector2(-3, -23), Vector2(8, 1)), Color("ffe066"))
	draw_rect(Rect2(sword + Vector2(0, -30), Vector2(2, 6)), Color("8a5232"))
	draw_rect(Rect2(sword + Vector2(-1, -32), Vector2(4, 3)), Color("ffe066"))
	# 劍刃上的光(隨營火閃)
	var glint := 0.4 + 0.5 * maxf(0.0, sin(time * 2.3))
	draw_rect(Rect2(sword + Vector2(0, -18), Vector2(1, 3)), Color(1, 1, 1, glint))
	# 胸甲(放在地上)
	var plate := c + Vector2(6, -4)
	_draw_ellipse(plate + Vector2(0, 5), Vector2(9, 2), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(plate + Vector2(-7, -6), Vector2(14, 11)), ink)
	draw_rect(Rect2(plate + Vector2(-6, -5), Vector2(12, 9)), Color("95a1bd"))
	draw_rect(Rect2(plate + Vector2(-6, -5), Vector2(5, 9)), Color("d5dbe8"))
	draw_rect(Rect2(plate + Vector2(-1, -3), Vector2(2, 2)), Color("ffe066"))
	draw_rect(Rect2(plate + Vector2(-6, 3), Vector2(12, 1)), Color("5d6888"))


func _draw_log() -> void:
	var c := log_spot
	_draw_ellipse(c + Vector2(0, 5), Vector2(18, 3), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(c + Vector2(-16, -4), Vector2(32, 9)), Color("2a1b2d"))
	draw_rect(Rect2(c + Vector2(-15, -3), Vector2(30, 7)), Color("6b4428"))
	draw_rect(Rect2(c + Vector2(-15, -3), Vector2(30, 2)), Color("8a5a32"))
	_draw_ellipse(c + Vector2(15, 0.5), Vector2(3, 4), Color("c09060"))
	draw_rect(Rect2(c + Vector2(14, 0), Vector2(2, 1)), Color("8a5a32"))


func _draw_fire() -> void:
	var c := fire_spot
	if config.fire_frames != null:
		return
	# 石頭圍成一圈
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		var stone := c + Vector2(cos(a) * 17.0, 8.0 + sin(a) * 4.0)
		draw_rect(Rect2(stone.round() - Vector2(3, 2), Vector2(6, 4)), Color("2a1b2d"))
		draw_rect(Rect2(stone.round() - Vector2(2, 2), Vector2(4, 3)), Color("7a6f72"))
		draw_rect(Rect2(stone.round() - Vector2(2, 2), Vector2(4, 1)), Color("aaa09a"))
	# 木柴(交叉)
	draw_set_transform(c + Vector2(0, 7), 0.35)
	draw_rect(Rect2(-13, -2, 26, 5), Color("2a1b2d"))
	draw_rect(Rect2(-12, -1, 24, 3), Color("6b4428"))
	draw_set_transform(c + Vector2(0, 7), -0.35)
	draw_rect(Rect2(-13, -2, 26, 5), Color("2a1b2d"))
	draw_rect(Rect2(-12, -1, 24, 3), Color("8a5232"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# 炭火
	for i in 4:
		var ember := c + Vector2(-6 + i * 4, 6 + (i % 2))
		var hot := 0.6 + 0.4 * sin(time * 5.0 + i * 1.7)
		draw_rect(Rect2(ember.round(), Vector2(2, 1)), Color(1, 0.45 + 0.3 * hot, 0.2, 1))
	# 火焰:三層,高度隨時間跳動
	for layer in config.fire_colors.size():
		var scale := 1.0 - layer * 0.28
		var flick := 1.0 + 0.18 * sin(time * (9.0 + layer * 3.0)) + 0.1 * sin(time * 23.0 + layer)
		var h := 24.0 * scale * flick
		var w := 11.0 * scale
		var sway := sin(time * 4.0 + layer) * 2.0
		var pts := PackedVector2Array([
			c + Vector2(-w, 6), c + Vector2(-w * 0.7, -h * 0.35), c + Vector2(sway * 0.5 - w * 0.25, -h * 0.7),
			c + Vector2(sway, -h), c + Vector2(sway * 0.5 + w * 0.3, -h * 0.6), c + Vector2(w * 0.75, -h * 0.3), c + Vector2(w, 6),
		])
		draw_colored_polygon(pts, config.fire_colors[layer])
	# 火舌(左右兩小撮)
	for side in [-1.0, 1.0]:
		var hh := 10.0 + 4.0 * sin(time * 11.0 + side)
		var base := c + Vector2(side * 7.0, 4)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(side * 2.0, -hh), base + Vector2(3, 0)]), config.fire_colors[0])


# --- 光暈 ---

func _draw_glow() -> void:
	# 階梯狀的同心圓(像素風),半徑隨營火閃爍;用加亮混合,疊在角色與地面上。
	var c := (fire_spot + Vector2(0, -4)).round()
	var rings: Array[float] = [64.0, 46.0, 30.0, 18.0]
	var strength := config.glow_color.a * (0.7 + 0.3 * flicker)
	for i in rings.size():
		var r := roundf(rings[i] * flicker)
		draw_circle(c, r, Color(config.glow_color.r, config.glow_color.g, config.glow_color.b, strength * (0.6 + i * 0.25)))
	# 地面上的暖光(扁橢圓)
	_draw_ellipse(c + Vector2(0, 16), Vector2(54, 10) * flicker, Color(config.glow_color, strength))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append((center + Vector2(cos(a) * radii.x, sin(a) * radii.y)).round())
	draw_colored_polygon(pts, color)
