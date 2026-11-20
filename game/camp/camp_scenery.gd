class_name CampScenery
extends Control
## 營地的景物(DEV_PLAN 15 DP1)。全部用程式畫像素圖,不需要外部素材;CampConfig 有正式圖時改用正式圖。
##
## 一個營地有三個 CampScenery,依 part 分工(由下往上疊):
## - SKY:夜空漸層、閃爍的星星、月亮、偶爾的流星、遠山與卡美洛城堡的剪影、松樹。
## - GROUND:草地、營火旁的空地、圓桌、木頭椅、卸下的盔甲與劍、營火(木柴、石頭、跳動的火焰)。
## - GLOW:營火的光暈(加亮混合,會閃爍),照在金毛、鬥牛犬與地面上。
## 位置(horizon_y、fire_spot 等)由 Camp._layout() 設定。
##
## v2.6 DV2:場景依章變化(chapter):
## - 1 草地夜空:遠山、卡美洛城堡剪影、松樹、草地與小花。
## - 2 城牆下的營火:石砌城牆(雉堞、塔樓、亮著的窗、飄動的圓桌旗、牆上的火把、殘留的紫色荊棘)、石板地。
## - 3 湖邊洞口與月光:滿月、湖面的月光倒影與水波、湖霧、遠方小島上的摩根娜之塔、
##   左邊的岩石洞口(會閃的水晶)、湖邊的蘆葦與鵝卵石。
## 顏色:CampConfig 的 sky_*、ground_* 由 Camp 依 chapter_palettes 換好;這裡另外讀 chapter_palettes 的
## wall_color、rock_color、water_color、crystal_color 等(沒有寫時用下面的預設值)。
##
## v2.7 DW2:第四至六章的景物在 camp_chapter_scenes.gd(CampChapterScenes),這裡依章呼叫:
## - 4 海灘營火與星空、5 雪山小屋與溫泉蒸氣、6 秋天山丘上的野外圓桌(暮色)。

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
## 場景的上緣(標題與活力條下面);城牆與洞口不會高過這裡太多。
var top_y: float = 70.0
## v2.6:第幾章的場景(1 至 GameState.CHAPTER_COUNT)。
var chapter: int = 1
## v2.7:第五章第二次營地,桌上有摩根娜的水晶球(crystal_spot 是它的中心)。
var crystal_ball: bool = false
var crystal_spot: Vector2 = Vector2.ZERO

## 流星:{"pos": Vector2, "vel": Vector2, "age": float, "life": float}
var meteors: Array[Dictionary] = []
var _next_meteor: float = 2.0
var _rng := RandomNumberGenerator.new()


func _init(p_part: Part = Part.SKY, p_config: CampConfig = null, p_chapter: int = 1) -> void:
	part = p_part
	config = p_config
	chapter = clampi(p_chapter, 1, GameState.CHAPTER_COUNT)
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
	if _draw_illustrated():
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
		if chapter == 6:
			# 黃昏:只有天頂的幾顆星星,越靠近地平線越淡
			color.a *= clampf(1.0 - star.y / maxf(horizon * 0.55, 1.0), 0.0, 1.0)
			if color.a <= 0.02:
				continue
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
	# 月亮(新月;第三章是又大又圓的滿月;第六章是黃昏,沒有月亮,改畫夕陽)與月暈
	var moon := moon_spot
	if chapter == 6:
		pass
	elif chapter == 3:
		draw_circle(moon, 20.0, Color(0.8, 0.95, 1, 0.05))
		draw_circle(moon, 15.0, Color(0.8, 0.95, 1, 0.08))
		draw_circle(moon, 11.0, Color("f4fbff"))
		draw_circle(moon + Vector2(-3, -2), 3.0, Color("dce9f2"))
		draw_circle(moon + Vector2(4, 3), 2.0, Color("dce9f2"))
		draw_circle(moon + Vector2(2, -5), 1.5, Color("e6f0f7"))
	else:
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
	match chapter:
		2:
			_draw_castle_wall()
			return
		3:
			_draw_lake_and_cave()
			return
		4:
			CampChapterScenes.sky_beach(self)
			return
		5:
			CampChapterScenes.sky_snow(self)
			return
		6:
			CampChapterScenes.sky_autumn(self)
			return
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
	match chapter:
		2:
			_draw_cobbles()
		3:
			_draw_shore()
		4:
			CampChapterScenes.ground_beach(self)
		5:
			CampChapterScenes.ground_snow(self)
		6:
			CampChapterScenes.ground_autumn(self)
	# 草(隨風輕輕搖;第二章是石板地,只有幾撮;第三章是湖邊,少一點;第四章沙灘幾撮海邊草;
	# 第五章雪地沒有草;第六章秋天的金色草地)
	var tufts: int = [34, 34, 8, 18, 6, 0, 30][clampi(chapter, 0, 6)]
	for i in tufts:
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
	CampChapterScenes.table_extras(self)
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
		var layer_scale := 1.0 - layer * 0.28
		var flick := 1.0 + 0.18 * sin(time * (9.0 + layer * 3.0)) + 0.1 * sin(time * 23.0 + layer)
		var h := 24.0 * layer_scale * flick
		var w := 11.0 * layer_scale
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


# --- 第二章:城牆下的營火 ---

## 城牆的上緣(畫面邏輯像素)。
func wall_top() -> float:
	return roundf(horizon_y - clampf((horizon_y - top_y) * 0.62, 34.0, 64.0))


## 牆上兩支火把的位置(火焰的底部)。光暈(GLOW)也用。
func torch_spots() -> Array[Vector2]:
	var screen := SafeArea.get_screen_size()
	var y := roundf(lerpf(wall_top(), horizon_y, 0.42))
	return [Vector2(roundf(screen.x * 0.16), y), Vector2(roundf(screen.x * 0.5) + 4.0, y)]


func _draw_castle_wall() -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := horizon_y
	var top := wall_top()
	var stone: Color = _pc("wall_color", Color("6a5f74"))
	var dark := stone.darkened(0.3)
	var light := stone.lightened(0.18)
	# 牆後遠處的城堡屋頂與塔尖(更暗,襯出城牆)
	var far := config.sky_bottom_color.darkened(0.35)
	for spire: Vector3 in [Vector3(0.3, 16, 7), Vector3(0.62, 24, 9), Vector3(0.9, 12, 6)]:
		var x := roundf(screen.x * spire.x)
		draw_rect(Rect2(x - spire.z * 0.5, top - spire.y, spire.z, spire.y), far)
		draw_colored_polygon(PackedVector2Array([Vector2(x - spire.z * 0.5 - 1, top - spire.y), Vector2(x, top - spire.y - 9),
			Vector2(x + spire.z * 0.5 + 1, top - spire.y)]), far)
		var lit := 0.5 + 0.5 * sin(time * 0.8 + spire.x * 9.0)
		draw_rect(Rect2(x - 1, top - spire.y + 4, 2, 3), Color(1, 0.8, 0.4, 0.4 + 0.5 * lit))
	# 牆身與雉堞
	draw_rect(Rect2(0, top, screen.x, horizon - top), stone)
	var merlon := 8.0
	var gap := 6.0
	var x0 := -fmod(screen.x * 0.5, merlon + gap)
	var mx := x0
	while mx < screen.x:
		draw_rect(Rect2(mx, top - 6, merlon, 6), stone)
		draw_rect(Rect2(mx, top - 6, merlon, 1), light)
		draw_rect(Rect2(mx + merlon - 1, top - 6, 1, 6), dark)
		mx += merlon + gap
	draw_rect(Rect2(0, top, screen.x, 1), light)
	# 石塊(每行 6 像素,上下錯開半塊)
	var row := 0
	var y := top + 3.0
	while y < horizon - 1.0:
		draw_rect(Rect2(0, y, screen.x, 1), dark)
		var offset := 6.0 if row % 2 == 0 else 0.0
		var bx := offset
		while bx < screen.x:
			draw_rect(Rect2(bx, y + 1, 1, 5), dark)
			# 每塊石頭左上角一點點亮面
			if int(bx + y) % 3 == 0:
				draw_rect(Rect2(bx + 1, y + 1, 3, 1), light)
			bx += 12.0
		y += 6.0
		row += 1
	# 牆腳的陰影
	draw_rect(Rect2(0, horizon - 3, screen.x, 3), Color(0, 0, 0, 0.25))
	# 右邊的塔樓:比牆高,有亮著的窗與旗子
	var tower_x := roundf(screen.x * 0.8)
	var tower_w := 26.0
	var tower_top := top - 22.0
	draw_rect(Rect2(tower_x - tower_w * 0.5, tower_top, tower_w, horizon - tower_top), stone.darkened(0.08))
	draw_rect(Rect2(tower_x - tower_w * 0.5, tower_top, 1, horizon - tower_top), light)
	draw_rect(Rect2(tower_x + tower_w * 0.5 - 2, tower_top, 2, horizon - tower_top), dark)
	for i in 3:
		var cx := tower_x - tower_w * 0.5 + i * 10.0
		draw_rect(Rect2(cx, tower_top - 5, 6, 5), stone.darkened(0.08))
		draw_rect(Rect2(cx, tower_top - 5, 6, 1), light)
	var window := Rect2(tower_x - 3, tower_top + 8, 6, 8)
	var lamp := 0.75 + 0.25 * sin(time * 3.1) * sin(time * 1.7)
	draw_rect(window.grow(1), dark)
	draw_rect(window, Color(1, 0.78, 0.38, lamp))
	draw_rect(Rect2(window.position + Vector2(0, -1), Vector2(6, 1)), dark)
	draw_rect(Rect2(window.position.x + 2, window.position.y, 1, 8), dark)
	# 塔頂的圓桌旗(藍底金圈,飄動)
	var pole := Vector2(tower_x, tower_top - 18)
	draw_rect(Rect2(pole, Vector2(1, 13)), Color("3a2a2a"))
	var flag_blue: Color = _pc("banner_color", Color("3d5aa8"))
	for k in 7:
		var wave := roundf(sin(time * 5.0 - k * 0.8) * 1.0)
		draw_rect(Rect2(pole + Vector2(1 + k, wave), Vector2(1, 5)), flag_blue if k < 6 else flag_blue.darkened(0.2))
	draw_rect(Rect2(pole + Vector2(3, 2 + roundf(sin(time * 5.0 - 2.4))), Vector2(2, 1)), Color("ffe066"))
	# 牆上掛的長旗(兩面,下襬隨風擺)
	for b: float in [0.33, 0.66]:
		var bx2 := roundf(screen.x * b)
		var banner_top := top + 4.0
		var length := clampf((horizon - top) * 0.45, 14.0, 24.0)
		draw_rect(Rect2(bx2 - 6, banner_top - 1, 12, 2), Color("8a6a3a"))
		for k in 10:
			var sway := roundf(sin(time * 2.2 + b * 7.0) * (k / 10.0) * 1.5)
			draw_rect(Rect2(bx2 - 5 + sway, banner_top + 1 + k * length / 10.0, 10, ceilf(length / 10.0) + 1), flag_blue)
		var tip := banner_top + 1 + length + roundf(sin(time * 2.2 + b * 7.0) * 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(bx2 - 5, tip), Vector2(bx2, tip + 4), Vector2(bx2 + 5, tip)]), flag_blue)
		# 圓桌紋章:金色的圓
		var c := Vector2(bx2 + roundf(sin(time * 2.2 + b * 7.0) * 0.7), banner_top + length * 0.5)
		draw_arc(c, 3.0, 0, TAU, 12, Color("ffe066"), 1.0)
	# 殘留的紫色荊棘(午睡咒):從左下爬上牆,尖刺一閃一閃
	var thorn: Color = _pc("thorn_color", Color("7a3a9a"))
	var vine_x := roundf(screen.x * 0.04)
	for k in 14:
		var vy := horizon - 2.0 - k * 3.0
		if vy < top + 2.0:
			break
		var vx := vine_x + roundf(sin(k * 0.9) * 4.0) + k * 1.0
		draw_rect(Rect2(vx, vy, 2, 3), thorn)
		if k % 3 == 1:
			draw_rect(Rect2(vx + 2, vy, 2, 1), thorn.lightened(0.2))
		if k % 4 == 2:
			draw_rect(Rect2(vx - 2, vy + 1, 2, 1), thorn.lightened(0.2))
	# 火把(支架與火焰)
	for t: Vector2 in torch_spots():
		draw_rect(Rect2(t + Vector2(-1, 0), Vector2(3, 6)), Color("3a2a2a"))
		draw_rect(Rect2(t + Vector2(-3, 5), Vector2(7, 1)), Color("3a2a2a"))
		var h := 5.0 + roundf(1.5 * sin(time * 11.0 + t.x))
		draw_colored_polygon(PackedVector2Array([t + Vector2(-3, 0), t + Vector2(roundf(sin(time * 6.0 + t.x)), -h), t + Vector2(4, 0)]),
			config.fire_colors[1] if config.fire_colors.size() > 1 else Color("ff9a2e"))
		draw_rect(Rect2(t + Vector2(0, -2), Vector2(1, 2)), Color("ffe36a"))


## 第二章的地面:城牆前的石板地。
func _draw_cobbles() -> void:
	# 越遠(越靠近城牆)石板越扁,有透視感;顏色很淡,不搶角色的眼。石板之間有空隙,偶爾冒一撮草。
	var screen := SafeArea.get_screen_size()
	var light := config.ground_light_color
	var y := horizon_y + 3.0
	var r := 0
	# 只鋪到營火下面一點(再往下是選單,地面保持素色)
	var bottom := minf(screen.y, fire_spot.y + 44.0)
	while y < bottom:
		var depth := clampf((y - horizon_y) / 60.0, 0.0, 1.0)
		var fade := 1.0 - clampf((y - fire_spot.y) / 44.0, 0.0, 1.0)
		var h := roundf(lerpf(2.0, 5.0, depth))
		var x := -float((r * 7) % 11)
		var k := 0
		while x < screen.x:
			var w := roundf(lerpf(6.0, 11.0, depth)) + float((r * 5 + k * 3) % 4)
			var skip := (r * 7 + k * 5) % 6 == 0
			var near_fire := absf(x + w * 0.5 - fire_spot.x) < 52.0 and absf(y - fire_spot.y - 10.0) < 13.0
			if not skip and not near_fire:
				draw_rect(Rect2(x + 1, y, w - 2, h), Color(light, 0.14 * fade))
				draw_rect(Rect2(x + 1, y, w - 2, 1), Color(light.lightened(0.25), 0.2 * fade))
			x += w
			k += 1
		y += h + 2.0
		r += 1


# --- 第三章:湖邊洞口與月光 ---

## 湖面的上緣(遠岸)。
func lake_top() -> float:
	return roundf(horizon_y - clampf((horizon_y - top_y) * 0.5, 24.0, 44.0))


func _draw_lake_and_cave() -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := horizon_y
	var lake := lake_top()
	var water: Color = _pc("water_color", Color("1d3a5c"))
	var far := config.sky_bottom_color.darkened(0.35)
	# 遠岸的森林(小小的圓頂樹影)
	var shore := PackedVector2Array([Vector2(0, lake + 1)])
	for i in 25:
		var x := screen.x * i / 24.0
		shore.append(Vector2(roundf(x), lake - 4.0 - roundf(absf(sin(i * 1.7)) * 5.0 + (i % 3))))
	shore.append(Vector2(screen.x, lake + 1))
	draw_colored_polygon(shore, far)
	# 湖中小島上的摩根娜之塔(窗口的紫光慢慢明暗)
	var tower_x := roundf(screen.x * 0.6)
	var island := far.darkened(0.2)
	_draw_ellipse(Vector2(tower_x, lake + 1), Vector2(14, 3), island)
	draw_rect(Rect2(tower_x - 3, lake - 34, 6, 34), island)
	draw_rect(Rect2(tower_x - 5, lake - 36, 10, 3), island)
	draw_colored_polygon(PackedVector2Array([Vector2(tower_x - 5, lake - 36), Vector2(tower_x, lake - 50), Vector2(tower_x + 5, lake - 36)]), island)
	var glow := 0.5 + 0.5 * sin(time * 1.3)
	draw_rect(Rect2(tower_x - 1, lake - 30, 2, 3), Color(0.75, 0.45, 1.0, 0.5 + 0.5 * glow))
	draw_circle(Vector2(tower_x, lake - 29), 4.0, Color(0.75, 0.45, 1.0, 0.12 * glow))
	# 湖面:遠深近淺的色帶
	var bands := 5
	for i in bands:
		var y0 := lake + roundf((horizon - lake) * i / bands)
		var y1 := lake + roundf((horizon - lake) * (i + 1) / bands)
		draw_rect(Rect2(0, y0, screen.x, y1 - y0 + 1), water.lerp(water.lightened(0.18), float(i) / bands))
	# 水波(短短的亮線,左右慢慢移動)
	for i in 16:
		var wy := lake + 2.0 + fmod(i * 7.0, maxf(horizon - lake - 3.0, 1.0))
		var wx := fmod(i * 37.0 + time * (3.0 + (i % 3)), screen.x + 12.0) - 6.0
		var a := 0.25 + 0.2 * sin(time * 2.0 + i)
		draw_rect(Rect2(roundf(wx), roundf(wy), 4 + (i % 3) * 2, 1), Color(0.75, 0.9, 1.0, a))
	# 湖霧:半透明的帶子慢慢飄
	for i in 3:
		var mist_x := fmod(i * 70.0 + time * (4.0 + i * 1.5), screen.x + 80.0) - 40.0
		var mist_y := lake + 2.0 + i * 4.0
		_draw_ellipse(Vector2(roundf(mist_x), mist_y), Vector2(34, 3), Color(0.85, 0.92, 1.0, 0.1))
	# 左邊的岩石洞口
	_draw_cave(screen, horizon)
	# 湖邊的蘆葦(右邊)
	for i in 5:
		var rx := roundf(screen.x * (0.86 + i * 0.03))
		var h := 10.0 + float(i % 3) * 4.0
		var sway := 1.0 if sin(time * 1.4 + i) > 0.2 else 0.0
		draw_rect(Rect2(rx, horizon - h, 1, h), Color("2f4a3a"))
		draw_rect(Rect2(rx + sway, horizon - h - 4, 2, 4), Color("6a4a2a"))


func _draw_cave(screen: Vector2, horizon: float) -> void:
	var rock: Color = _pc("rock_color", Color("39405e"))
	var w := screen.x
	var top := minf(top_y - 6.0, horizon - 70.0)
	var outer := PackedVector2Array([
		Vector2(0, horizon + 4), Vector2(0, top), Vector2(w * 0.1, top + 4), Vector2(w * 0.22, top + 12),
		Vector2(w * 0.3, top + 26), Vector2(w * 0.34, horizon - 22), Vector2(w * 0.38, horizon - 8), Vector2(w * 0.4, horizon + 4),
	])
	draw_colored_polygon(outer, rock)
	# 被月光照到的岩石邊緣(右邊,月亮在右上)
	for i in range(2, outer.size() - 1):
		var a := outer[i]
		var b := outer[i + 1]
		var steps := int(a.distance_to(b) / 2.0)
		for k in steps:
			var pt := a.lerp(b, float(k) / maxf(steps, 1)).round()
			draw_rect(Rect2(pt + Vector2(-2, 0), Vector2(2, 1)), rock.lightened(0.28))
	# 岩石的裂紋
	for crack: Vector4 in [Vector4(0.06, 0.25, 6, 4), Vector4(0.18, 0.12, 5, 3), Vector4(0.27, 0.45, 4, 5)]:
		var c := Vector2(roundf(w * crack.x), roundf(lerpf(top, horizon, crack.y)))
		draw_rect(Rect2(c, Vector2(crack.z, 1)), rock.darkened(0.25))
		draw_rect(Rect2(c + Vector2(crack.z - 1, 1), Vector2(1, crack.w)), rock.darkened(0.25))
	# 洞口(更深的黑)
	var mouth := PackedVector2Array([
		Vector2(w * 0.04, horizon + 2), Vector2(w * 0.06, horizon - 24), Vector2(w * 0.12, horizon - 38),
		Vector2(w * 0.2, horizon - 36), Vector2(w * 0.26, horizon - 20), Vector2(w * 0.29, horizon + 2),
	])
	draw_colored_polygon(mouth, Color("0d0f1e"))
	# 洞口的水晶(一閃一閃)
	var crystal: Color = _pc("crystal_color", Color("7fe6ff"))
	var crystals: Array[Vector3] = [Vector3(0.07, -20, 5), Vector3(0.25, -16, 6), Vector3(0.13, -36, 4), Vector3(0.31, -6, 4), Vector3(0.03, -8, 3)]
	for i in crystals.size():
		var cr := crystals[i]
		var base := Vector2(roundf(w * cr.x), horizon + cr.y)
		var shine := 0.55 + 0.45 * sin(time * (1.6 + i * 0.37) + i * 2.0)
		var col := crystal if i % 2 == 0 else Color("c99bff")
		draw_colored_polygon(PackedVector2Array([base + Vector2(-2, 0), base + Vector2(0, -cr.z), base + Vector2(2, 0), base + Vector2(0, 2)]),
			Color(col, 0.6 + 0.4 * shine))
		draw_rect(Rect2(base + Vector2(0, -cr.z + 1), Vector2(1, 2)), Color(1, 1, 1, shine))


## 第三章的地面:湖邊的鵝卵石與濕沙。
func _draw_shore() -> void:
	var screen := SafeArea.get_screen_size()
	draw_rect(Rect2(0, horizon_y, screen.x, 3), Color(_pc("sand_color", Color("5a5a6a")), 0.6))
	for i in 22:
		var p := Vector2(fmod(i * 41.0 + 11.0, screen.x), horizon_y + 6.0 + fmod(i * 23.0, maxf(screen.y - horizon_y - 10.0, 8.0)))
		if absf(p.x - fire_spot.x) < 58.0 and absf(p.y - fire_spot.y - 10.0) < 14.0:
			continue
		var size := Vector2(3 + (i % 3), 2)
		draw_rect(Rect2(p.round(), size), Color("6f7690"))
		draw_rect(Rect2(p.round(), Vector2(size.x - 1, 1)), Color("9aa2bb"))


## 讀這一章的額外顏色(CampConfig.chapter_palettes[chapter][key]);沒有時用 fallback。
func _pc(key: String, fallback: Color) -> Color:
	var palette: Dictionary = config.chapter_palettes.get(chapter, {})
	var value: Variant = palette.get(key, fallback)
	return value if value is Color else fallback


## 給 CampChapterScenes 用(同 _pc)。
func palette_color(key: String, fallback: Color) -> Color:
	return _pc(key, fallback)


## 給 CampChapterScenes 用(同 _draw_ellipse:頂點取整數的橢圓)。
func draw_ellipse_px(center: Vector2, radii: Vector2, color: Color) -> void:
	_draw_ellipse(center, radii, color)


## 給 CampChapterScenes 用:畫松樹的剪影。
func draw_pine(base: Vector2, height: float, color: Color) -> void:
	_draw_pine(base, height, color)


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
	if chapter == 2:
		# 牆上火把的小光暈
		for t: Vector2 in torch_spots():
			for i in 3:
				draw_circle(t + Vector2(0, -3), roundf((14.0 - i * 4.0) * flicker), Color(1.0, 0.55, 0.2, 0.05 + i * 0.03))
	elif chapter >= 4:
		CampChapterScenes.glow(self)
	elif chapter == 3:
		# 湖面的月光倒影:月亮下方一段一段閃爍的亮線
		var lake := lake_top()
		var x := moon_spot.x
		var y := lake + 1.0
		var k := 0
		while y < horizon_y - 1.0:
			var half := 2.0 + k * 1.2 + roundf(sin(time * 3.0 + k * 1.3) * 1.5)
			var a := 0.18 + 0.12 * sin(time * 2.4 + k * 0.9)
			draw_rect(Rect2(roundf(x - half + sin(time * 1.1 + k) * 1.5), roundf(y), roundf(half * 2.0), 1), Color(0.75, 0.9, 1.0, a))
			y += 2.0
			k += 1


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append((center + Vector2(cos(a) * radii.x, sin(a) * radii.y)).round())
	draw_colored_polygon(pts, color)


func _draw_illustrated() -> bool:
	var tex := StoryArt.cell("camp_sheet", (chapter - 1) % 3, (chapter - 1) / 3, 3, 2)
	if tex == null:
		return false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if part == Part.SKY:
		var screen := SafeArea.get_screen_size()
		draw_texture_rect(tex, Rect2(Vector2.ZERO, screen), false)
		# Darken the header only; character space keeps its painted warmth.
		draw_rect(Rect2(0, 0, screen.x, 69), Color(0.03, 0.07, 0.08, 0.67))
	elif part == Part.GLOW:
		draw_circle(fire_spot, 15.0, Color(1.0, 0.55, 0.16, 0.04 * flicker), true, -1, true)
	return true
