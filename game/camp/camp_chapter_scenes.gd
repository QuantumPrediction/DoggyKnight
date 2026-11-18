class_name CampChapterScenes
extends RefCounted
## 第四至六章的營地景物(v2.7 DW2)。全部用程式畫像素圖;CampScenery 依章呼叫這裡的函式,畫在它自己身上。
##
## - 4 海灘營火與星空:銀河、海平線、月光照在海面、一波一波打上沙灘的浪、左邊懸崖上的燈塔(燈光會掃)、
##   右邊的椰子樹與崔斯坦漂來的小船、濕沙上的泡沫、貝殼、海星、金毛的腳印。
## - 5 雪山小屋與溫泉蒸氣:雪山(右邊遠方的山頂冒紅光:紅龍在睡覺)、積雪的松樹、左邊的小木屋
##   (窗裡有燈、煙囪冒煙、屋簷的冰柱)、右邊冒蒸氣的溫泉、雪地上閃閃的冰晶、飄雪。
## - 6 秋天山丘上的野外圓桌(黃昏):夕陽、遠方被佔領的卡美洛(黑狼旗)、兩邊的楓樹與掛著的燈籠、
##   金色草地上的落葉與南瓜、飄落的葉子、圓桌前面掛著圓桌旗布。
## 位置都用 CampScenery 的 horizon_y、top_y、table_spot、fire_spot、moon_spot(由 Camp._layout() 設定)。
## 顏色讀 chapter_palettes(CampScenery.palette_color),沒有寫時用這裡的預設值。

const WAVE_PERIOD_SEC: float = 3.4
const SNOWFLAKES: int = 28
const LEAVES: int = 10
## 第五章的遠山:(x 比例, 高度比例, 半寬);VOLCANO_INDEX 那座是火山。
const VOLCANO_PEAKS: Array[Vector3] = [Vector3(0.14, 0.62, 34), Vector3(0.5, 0.82, 40), Vector3(0.86, 0.66, 36)]
const VOLCANO_INDEX: int = 1


# --- 共用 ---

## 第四章:海平線(海面的上緣)。
static func sea_top(s: CampScenery) -> float:
	return roundf(s.horizon_y - clampf((s.horizon_y - s.top_y) * 0.42, 20.0, 38.0))


## 第四章:浪的週期(0 至 1)。0 至 0.75 浪頭往岸邊推,0.7 之後在沙灘上散開。
static func wave_phase(s: CampScenery) -> float:
	return fmod(s.time / WAVE_PERIOD_SEC, 1.0)


## 第五章:溫泉的中心與半徑。
static func spring_center(s: CampScenery) -> Vector2:
	var screen := SafeArea.get_screen_size()
	return Vector2(roundf(screen.x - 22.0), s.horizon_y + 9.0)


## 第五章:小木屋窗戶的中心。
static func hut_window(s: CampScenery) -> Vector2:
	return Vector2(8.0, s.horizon_y - 11.0)


## 第六章:兩邊楓樹的燈籠(燈的中心)。
static func lantern_spots(s: CampScenery) -> Array[Vector2]:
	var screen := SafeArea.get_screen_size()
	var y := roundf(lerpf(s.top_y, s.horizon_y, 0.55))
	return [Vector2(22.0, y), Vector2(roundf(screen.x - 22.0), y + 4.0)]


## 第六章:夕陽的中心(已經躲到遠山後面)。
static func sun_spot(s: CampScenery) -> Vector2:
	var screen := SafeArea.get_screen_size()
	return Vector2(roundf(screen.x * 0.3), s.horizon_y - 14.0)


# --- 第四章:海灘營火與星空 ---

static func sky_beach(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	var sea_y := sea_top(s)
	var water := s.palette_color("water_color", Color("1b3a63"))
	# 銀河:斜斜的一條淡淡的星帶
	for i in 4:
		var t := (i + 0.5) / 4.0
		s.draw_ellipse_px(Vector2(screen.x * (0.08 + t * 0.84), lerpf(sea_y * 0.15, sea_y * 0.75, t)), Vector2(24, 6), Color(0.75, 0.8, 1.0, 0.05))
	for i in 48:
		var t := float(i) / 48.0
		var p := Vector2(screen.x * (0.04 + t * 0.92) + sin(i * 4.1) * 5.0, lerpf(sea_y * 0.15, sea_y * 0.75, t) + sin(i * 2.7) * 7.0)
		var twinkle := 0.5 + 0.5 * sin(s.time * (0.8 + (i % 5) * 0.3) + i)
		s.draw_rect(Rect2(p.round(), Vector2.ONE), Color(0.88, 0.92, 1.0, 0.12 + 0.22 * twinkle))
	# 海面(遠深近淺)與海平線
	var bands := 6
	for i in bands:
		var y0 := sea_y + roundf((horizon - sea_y) * i / bands)
		var y1 := sea_y + roundf((horizon - sea_y) * (i + 1) / bands)
		s.draw_rect(Rect2(0, y0, screen.x, y1 - y0 + 1), water.lerp(water.lightened(0.22), float(i) / bands))
	s.draw_rect(Rect2(0, sea_y, screen.x, 1), water.lightened(0.35))
	# 海上的小浪頭(短短的白線,慢慢移動)
	for i in 18:
		var wy := sea_y + 3.0 + fmod(i * 5.0, maxf(horizon - sea_y - 8.0, 1.0))
		var wx := fmod(i * 29.0 + s.time * (4.0 + (i % 3) * 2.0), screen.x + 14.0) - 7.0
		var depth := (wy - sea_y) / maxf(horizon - sea_y, 1.0)
		var a := (0.18 + 0.2 * depth) * (0.6 + 0.4 * sin(s.time * 2.2 + i))
		s.draw_rect(Rect2(roundf(wx), roundf(wy), 3 + roundf(depth * 4.0), 1), Color(0.85, 0.95, 1.0, a))
	# 一波一波打上沙灘的浪:浪頭從外海推向岸邊(上了岸的泡沫在 ground_beach 畫)
	var phase := wave_phase(s)
	if phase < 0.75:
		var p := phase / 0.75
		var y := roundf(lerpf(sea_y + (horizon - sea_y) * 0.35, horizon - 1.0, p * p))
		for x in range(0, int(screen.x) + 2, 2):
			var bump := roundf(sin(x * 0.21 + s.time * 1.3) * 1.2)
			s.draw_rect(Rect2(x, y + bump, 2, 1), Color(0.92, 0.97, 1.0, 0.3 + 0.45 * p))
			if p > 0.6 and x % 6 == 0:
				s.draw_rect(Rect2(x, y + bump - 1, 1, 1), Color(1, 1, 1, 0.5 * p))
	_draw_lighthouse(s, sea_y, horizon)
	_draw_palm(s, Vector2(screen.x - 10.0, horizon + 1.0), clampf((horizon - s.top_y) * 0.8, 34.0, 50.0))


static func _draw_lighthouse(s: CampScenery, sea_y: float, horizon: float) -> void:
	# 左邊的懸崖與燈塔(燈每兩秒亮一下;光束在 glow 畫)
	var rock := s.palette_color("rock_color", Color("383450"))
	var cliff := PackedVector2Array([Vector2(0, horizon + 1), Vector2(0, sea_y - 12), Vector2(12, sea_y - 14), Vector2(22, sea_y - 8),
		Vector2(30, sea_y + 4), Vector2(38, horizon - 6), Vector2(46, horizon + 1)])
	s.draw_colored_polygon(cliff, rock)
	for i in range(1, cliff.size() - 2):
		var a := cliff[i]
		var b := cliff[i + 1]
		var steps := int(a.distance_to(b) / 2.0)
		for k in steps:
			var pt := a.lerp(b, float(k) / maxf(steps, 1)).round()
			s.draw_rect(Rect2(pt + Vector2(-1, 0), Vector2(2, 1)), rock.lightened(0.25))
	var lx := 10.0
	var base := sea_y - 13.0
	var top := base - 22.0
	var white := Color("dcd8d0")
	s.draw_rect(Rect2(lx - 4, top + 6, 9, base - top - 6), Color("2a2438"))
	s.draw_rect(Rect2(lx - 3, top + 7, 7, base - top - 7), white)
	for k in 2:
		s.draw_rect(Rect2(lx - 3, top + 11 + k * 7, 7, 3), Color("b8434a"))
	s.draw_rect(Rect2(lx - 3, top + 7, 2, base - top - 7), white.lightened(0.2))
	s.draw_rect(Rect2(lx - 4, top + 2, 9, 5), Color("2a2438"))
	var blink := clampf(sin(s.time * PI) * 1.4, 0.0, 1.0)
	s.draw_rect(Rect2(lx - 2, top + 3, 5, 3), Color(1, 0.85, 0.45).lerp(Color(1, 1, 0.8), blink))
	s.draw_colored_polygon(PackedVector2Array([Vector2(lx - 5, top + 2), Vector2(lx + 0.5, top - 3), Vector2(lx + 6, top + 2)]), Color("2a2438"))


static func _draw_palm(s: CampScenery, base: Vector2, height: float) -> void:
	# 椰子樹(彎彎的樹幹、隨風輕擺的葉子、兩顆椰子)
	var trunk := s.palette_color("trunk_color", Color("5a4038"))
	var leaf := s.palette_color("leaf_color", Color("2c5a4a"))
	var segments := 12
	for k in segments:
		var t := float(k) / (segments - 1)
		var p := base + Vector2(-sin(t * 1.4) * 10.0, -t * height)
		s.draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(3, ceilf(height / segments) + 1)), trunk if k % 2 == 0 else trunk.darkened(0.18))
	var crown := (base + Vector2(-sin(1.4) * 10.0, -height)).round()
	var sway := sin(s.time * 1.1) * 1.5
	for dir: Vector2 in [Vector2(-1, -0.3), Vector2(-0.85, 0.45), Vector2(0.75, 0.35), Vector2(1, -0.2), Vector2(-0.15, -1)]:
		for k in 10:
			var t := k / 9.0
			var p := crown + Vector2(dir.x * t * 17.0, dir.y * t * 11.0 + t * t * 9.0 + sway * t)
			s.draw_rect(Rect2(p.round(), Vector2(2, 2 if k < 7 else 1)), leaf if k % 3 != 2 else leaf.lightened(0.15))
	s.draw_circle(crown + Vector2(-2, 3), 2.0, Color("4a3426"))
	s.draw_circle(crown + Vector2(2, 3), 2.0, Color("3e2c20"))


static func ground_beach(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	var sand := s.config.ground_color
	# 濕沙(浪退去的地方)
	s.draw_rect(Rect2(0, horizon, screen.x, 5), sand.darkened(0.22))
	s.draw_rect(Rect2(0, horizon + 5, screen.x, 1), sand.darkened(0.1))
	# 浪打上沙灘:白色泡沫往上爬一點再退回去
	var phase := wave_phase(s)
	if phase >= 0.7:
		var p := (phase - 0.7) / 0.3
		var reach := roundf(1.0 + 5.0 * sin(p * PI * 0.5))
		var alpha := 0.8 * (1.0 - p)
		s.draw_rect(Rect2(0, horizon, screen.x, reach), Color(0.65, 0.82, 1.0, 0.22 * (1.0 - p)))
		for x in range(0, int(screen.x) + 2, 2):
			var y := horizon + reach + roundf(sin(x * 0.33 + s.time) * 1.0)
			s.draw_rect(Rect2(x, y, 2, 1), Color(0.95, 0.98, 1.0, alpha))
	# 沙的顆粒(淡淡的亮點)
	for i in 30:
		var p := Vector2(fmod(i * 47.0 + 9.0, screen.x), horizon + 8.0 + fmod(i * 19.0, maxf(screen.y - horizon - 10.0, 8.0)))
		s.draw_rect(Rect2(p.round(), Vector2.ONE), Color(s.config.ground_light_color, 0.5))
	# 貝殼與海星(避開營火旁的空地)
	var shells: Array[Vector3] = [Vector3(0.08, 14, 0), Vector3(0.3, 30, 1), Vector3(0.62, 12, 0), Vector3(0.9, 26, 2), Vector3(0.2, 46, 2), Vector3(0.78, 52, 1)]
	for sh in shells:
		var p := Vector2(roundf(screen.x * sh.x), horizon + sh.y)
		if absf(p.x - s.fire_spot.x) < 50.0 and absf(p.y - s.fire_spot.y - 10.0) < 14.0:
			continue
		match int(sh.z):
			0:
				s.draw_rect(Rect2(p, Vector2(3, 2)), Color("e8d8d0"))
				s.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 2)), Color("c8a8a8"))
			1:
				s.draw_rect(Rect2(p, Vector2(2, 2)), Color("f0b8c0"))
				s.draw_rect(Rect2(p + Vector2(0, 1), Vector2(3, 1)), Color("d898a8"))
			_:
				# 海星(五個角)
				var star := Color("e07a48")
				s.draw_rect(Rect2(p + Vector2(1, 1), Vector2(3, 3)), star)
				for d: Vector2 in [Vector2(2, -1), Vector2(-1, 1), Vector2(5, 1), Vector2(0, 4), Vector2(4, 4)]:
					s.draw_rect(Rect2(p + d, Vector2.ONE), star)
				s.draw_rect(Rect2(p + Vector2(2, 2), Vector2.ONE), Color("ffb080"))
	# 金毛從海邊走到營火的腳印
	var from := Vector2(screen.x * 0.66, horizon + 7.0)
	var to := s.fire_spot + Vector2(30, 12)
	for k in 6:
		var t := (k + 0.5) / 6.0
		var p := from.lerp(to, t) + Vector2(0, 2.0 if k % 2 == 0 else -1.0)
		s.draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(sand.darkened(0.3), 0.7))
		s.draw_rect(Rect2(p.round() + Vector2(0, -1), Vector2(1, 1)), Color(sand.darkened(0.3), 0.5))
	# 崔斯坦坐著漂來的小船(拉上沙灘,船上插著淺藍色的小旗)
	var b := Vector2(roundf(screen.x - 26.0), horizon + 9.0)
	s.draw_ellipse_px(b + Vector2(0, 4), Vector2(15, 2), Color(0, 0, 0, 0.22))
	s.draw_colored_polygon(PackedVector2Array([b + Vector2(-15, -3), b + Vector2(15, -4), b + Vector2(11, 3), b + Vector2(-11, 3)]), Color("5a3a24"))
	s.draw_colored_polygon(PackedVector2Array([b + Vector2(-13, -2), b + Vector2(13, -3), b + Vector2(10, 1), b + Vector2(-10, 1)]), Color("7a5232"))
	s.draw_rect(Rect2(b + Vector2(-14, -4), Vector2(28, 1)), Color("a87a4a"))
	s.draw_rect(Rect2(b + Vector2(3, -14), Vector2(1, 10)), Color("4a3020"))
	var wave := roundf(sin(s.time * 3.0))
	s.draw_colored_polygon(PackedVector2Array([b + Vector2(4, -14), b + Vector2(10, -12 + wave), b + Vector2(4, -10)]), Color("8ec8f0"))
	# 船槳
	s.draw_rect(Rect2(b + Vector2(-20, 0), Vector2(10, 1)), Color("8a6a42"))
	s.draw_rect(Rect2(b + Vector2(-22, -1), Vector2(3, 3)), Color("8a6a42"))


# --- 第五章:雪山小屋與溫泉蒸氣 ---

static func sky_snow(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	var room := horizon - s.top_y
	var far := s.config.sky_bottom_color.darkened(0.2)
	var cap := s.palette_color("snowcap_color", Color("dde6f8"))
	# 遠方的雪山(三座);中間那座是火山,山頂冒紅光與煙(紅龍在裡面睡覺),從梅林與蘭斯洛特中間看得到
	for i in VOLCANO_PEAKS.size():
		var pk := VOLCANO_PEAKS[i]
		var x := roundf(screen.x * pk.x)
		var h := roundf(clampf(room * pk.y, 24.0, room + 6.0))
		var w := pk.z
		s.draw_colored_polygon(PackedVector2Array([Vector2(x - w, horizon), Vector2(x, horizon - h), Vector2(x + w, horizon)]), far)
		# 山頂的雪(下緣鋸齒狀)
		var cap_h := roundf(h * 0.38)
		var cw := w * cap_h / h
		s.draw_colored_polygon(PackedVector2Array([Vector2(x - cw, horizon - h + cap_h), Vector2(x, horizon - h), Vector2(x + cw, horizon - h + cap_h)]), cap)
		for k in int(cw * 2.0 / 4.0):
			var jx := x - cw + 2.0 + k * 4.0
			s.draw_rect(Rect2(roundf(jx), horizon - h + cap_h, 2, 2 + (k % 2) * 2), cap)
		# 月光照到的稜線(右邊亮一點)
		s.draw_line(Vector2(x, horizon - h), Vector2(x + cw, horizon - h + cap_h), Color(1, 1, 1, 0.6), 1.0)
		if i == VOLCANO_INDEX:
			# 山頂冒著一點紅光和煙:紅龍在山裡睡覺(光暈在 glow)
			s.draw_rect(Rect2(x - 2, horizon - h - 1, 5, 2), Color("c8482a"))
			s.draw_rect(Rect2(x - 1, horizon - h - 1, 3, 1), Color(1, 0.7, 0.3).lerp(Color(1, 0.95, 0.6), 0.5 + 0.5 * sin(s.time * 2.3)))
			for k in 3:
				var puff_t := fmod(s.time * 0.25 + k / 3.0, 1.0)
				s.draw_circle(Vector2(x + 2 + puff_t * 6.0, horizon - h - 4 - puff_t * 12.0), 2.0 + puff_t * 2.5, Color(0.6, 0.55, 0.65, 0.4 * (1.0 - puff_t)))
	# 近處的雪坡與積雪的松樹
	var near := s.config.sky_bottom_color.darkened(0.45)
	var ridge := PackedVector2Array([Vector2(0, horizon + 1), Vector2(0, horizon - 10), Vector2(screen.x * 0.28, horizon - 14),
		Vector2(screen.x * 0.55, horizon - 7), Vector2(screen.x * 0.8, horizon - 13), Vector2(screen.x, horizon - 8), Vector2(screen.x, horizon + 1)])
	s.draw_colored_polygon(ridge, near)
	for i in range(1, ridge.size() - 2):
		s.draw_line(ridge[i], ridge[i + 1], Color(cap, 0.7), 1.0)
	for i in 6:
		var x := fmod(i * 67.0 + 30.0, screen.x + 20.0) - 10.0
		if x < 54.0 or absf(x - (screen.x - 22.0)) < 26.0:
			continue
		var base := Vector2(roundf(x), horizon - 8.0)
		var height := 12.0 + float(i % 3) * 4.0
		s.draw_pine(base, height, near.darkened(0.2))
		for layer in 3:
			var y := base.y - height * (0.3 + layer * 0.3) - height * 0.1
			var half := height * 0.45 * (1.0 - layer * 0.28)
			s.draw_rect(Rect2(roundf(base.x - half * 0.6), roundf(y), roundf(half * 1.2), 1), Color(cap, 0.85))
	_draw_hut(s, horizon)


static func _draw_hut(s: CampScenery, horizon: float) -> void:
	# 左邊的小木屋:木頭牆、積雪的屋頂與冰柱、亮燈的窗、門、煙囪冒煙(光暈在 glow)
	var wood := s.palette_color("wood_color", Color("6b4a38"))
	var dark := wood.darkened(0.35)
	var cap := s.palette_color("snowcap_color", Color("dde6f8"))
	var left := 0.0
	var right := 40.0
	var wall_top := horizon - 20.0
	s.draw_rect(Rect2(left, wall_top, right - left, horizon - wall_top + 1), wood)
	var y := wall_top + 3.0
	while y < horizon:
		s.draw_rect(Rect2(left, y, right - left, 1), dark)
		y += 4.0
	# 屋頂(三角形)與屋頂上的雪
	var peak := Vector2(20, wall_top - 15)
	s.draw_colored_polygon(PackedVector2Array([Vector2(left - 4, wall_top + 1), peak, Vector2(right + 4, wall_top + 1)]), dark)
	s.draw_colored_polygon(PackedVector2Array([Vector2(left - 5, wall_top - 1), peak + Vector2(0, -2), Vector2(right + 5, wall_top - 1),
		Vector2(right + 5, wall_top + 2), peak + Vector2(0, 2), Vector2(left - 5, wall_top + 2)]), cap)
	# 冰柱(慢慢閃一下)
	for k in 7:
		var ix := left + 2.0 + k * 6.0
		var length := 2.0 + float((k * 3) % 4)
		s.draw_rect(Rect2(ix, wall_top + 2, 1, length), Color(0.85, 0.95, 1.0, 0.85))
		if int(s.time * 1.5 + k) % 7 == 0:
			s.draw_rect(Rect2(ix, wall_top + 1 + length, 1, 1), Color(1, 1, 1, 1))
	# 煙囪與煙
	s.draw_rect(Rect2(28, wall_top - 15, 5, 9), Color("5a5060"))
	s.draw_rect(Rect2(27, wall_top - 16, 7, 2), cap)
	for k in 4:
		var t := fmod(s.time * 0.3 + k / 4.0, 1.0)
		s.draw_circle(Vector2(31 + sin(t * 4.0 + k) * 2.0 + t * 5.0, wall_top - 18 - t * 22.0), 1.5 + t * 3.0, Color(0.75, 0.75, 0.85, 0.35 * (1.0 - t)))
	# 窗戶(暖黃色的燈、十字窗框)
	var win := hut_window(s)
	var lamp := 0.8 + 0.2 * sin(s.time * 2.7) * sin(s.time * 1.3)
	s.draw_rect(Rect2(win - Vector2(5, 4), Vector2(10, 8)), dark)
	s.draw_rect(Rect2(win - Vector2(4, 3), Vector2(8, 6)), Color(1, 0.8, 0.4, lamp))
	s.draw_rect(Rect2(win - Vector2(0, 3), Vector2(1, 6)), dark)
	s.draw_rect(Rect2(win - Vector2(4, 0), Vector2(8, 1)), dark)
	s.draw_rect(Rect2(win + Vector2(-5, 4), Vector2(10, 1)), cap)
	# 門
	s.draw_rect(Rect2(28, horizon - 13, 8, 13), dark)
	s.draw_rect(Rect2(29, horizon - 12, 6, 12), wood.lightened(0.1))
	s.draw_rect(Rect2(33, horizon - 7, 1, 1), Color("ffe066"))


static func ground_snow(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	var snow := s.config.ground_color
	var light := s.config.ground_light_color
	# 雪堆(亮一點的小丘)
	for d: Vector3 in [Vector3(0.12, 22, 18), Vector3(0.5, 44, 22), Vector3(0.88, 36, 16), Vector3(0.3, 60, 14)]:
		var c := Vector2(roundf(screen.x * d.x), horizon + d.y)
		if absf(c.x - s.fire_spot.x) < 50.0 and absf(c.y - s.fire_spot.y - 10.0) < 16.0:
			continue
		s.draw_ellipse_px(c, Vector2(d.z, 3), light)
		s.draw_rect(Rect2(c + Vector2(-d.z * 0.4, -3), Vector2(d.z * 0.6, 1)), Color(1, 1, 1, 0.5))
	# 雪地上閃閃的冰晶
	for i in 26:
		var p := Vector2(fmod(i * 43.0 + 7.0, screen.x), horizon + 4.0 + fmod(i * 23.0, maxf(screen.y - horizon - 6.0, 8.0)))
		var tw := sin(s.time * (1.3 + (i % 4) * 0.5) + i * 2.1)
		if tw > 0.55:
			s.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 1, 1, (tw - 0.55) * 2.2))
		else:
			s.draw_rect(Rect2(p.round(), Vector2.ONE), Color(snow.darkened(0.12), 0.6))
	# 從小木屋走到營火的腳印
	var from := Vector2(32, horizon + 4.0)
	var to := s.fire_spot + Vector2(-18, 10)
	for k in 6:
		var t := (k + 0.5) / 6.0
		var p := from.lerp(to, t) + Vector2(2.0 if k % 2 == 0 else -2.0, 0)
		s.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(snow.darkened(0.28), 0.8))
	# 小木屋旁的柴堆
	var pile := Vector2(46, horizon + 2.0)
	for at_offset: Vector2 in [Vector2(0, 0), Vector2(4, 0), Vector2(8, 0), Vector2(2, -3), Vector2(6, -3)]:
		var at := pile + at_offset
		s.draw_rect(Rect2(at, Vector2(4, 3)), Color("5a3a24"))
		s.draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 1)), Color("c09060"))
	s.draw_rect(Rect2(pile + Vector2(-1, -6), Vector2(14, 1)), Color(light, 0.9))
	# 溫泉:岩石圍著的一池熱水(蒸氣在 glow 畫)
	var c := spring_center(s)
	var spring := s.palette_color("spring_color", Color("3f8aa0"))
	s.draw_ellipse_px(c + Vector2(0, 1), Vector2(22, 7), Color("4a4858"))
	s.draw_ellipse_px(c, Vector2(19, 5), spring)
	s.draw_ellipse_px(c + Vector2(-2, -1), Vector2(12, 2), spring.lightened(0.25))
	for k in 3:
		var rx := c.x - 10.0 + k * 8.0 + sin(s.time * 1.5 + k) * 2.0
		s.draw_rect(Rect2(roundf(rx), c.y - 1 + (k % 2), 3, 1), Color(0.85, 0.97, 1.0, 0.6))
	for k in 7:
		var a := PI * (1.05 + k * 0.15)
		var rock := c + Vector2(cos(a) * 21.0, sin(a) * 6.0 + 1.0)
		s.draw_rect(Rect2(rock.round() - Vector2(2, 2), Vector2(5, 3)), Color("5a5868"))
		s.draw_rect(Rect2(rock.round() - Vector2(2, 2), Vector2(5, 1)), Color(light, 0.95))
	# 溫泉的小木牌(♨)
	var sign := c + Vector2(-26, -10)
	s.draw_rect(Rect2(sign + Vector2(3, 4), Vector2(1, 7)), Color("4a3020"))
	s.draw_rect(Rect2(sign, Vector2(8, 6)), Color("8a6a42"))
	s.draw_rect(Rect2(sign + Vector2(2, 4), Vector2(4, 1)), Color("e05050"))
	for k in 3:
		s.draw_rect(Rect2(sign + Vector2(1 + k * 2, 1 + (k % 2)), Vector2(1, 2)), Color("e05050"))


# --- 第六章:秋天山丘上的野外圓桌(黃昏) ---

static func sky_autumn(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	# 夕陽已經躲到遠山後面,只剩天邊的暖光(光暈在 glow)
	# 遠山
	var far := s.palette_color("far_hill_color", Color("6a4060"))
	var hills := PackedVector2Array([Vector2(0, horizon), Vector2(0, horizon - 18), Vector2(screen.x * 0.2, horizon - 26),
		Vector2(screen.x * 0.45, horizon - 15), Vector2(screen.x * 0.7, horizon - 30), Vector2(screen.x * 0.9, horizon - 22),
		Vector2(screen.x, horizon - 24), Vector2(screen.x, horizon)])
	s.draw_colored_polygon(hills, far)
	# 遠方被莫德雷德佔領的卡美洛:城堡剪影、黑狼旗、紅色的窗
	_draw_occupied_castle(s, Vector2(roundf(screen.x * 0.7), horizon - 29.0), far.darkened(0.3))
	# 近處的山丘
	var near := s.palette_color("near_hill_color", Color("4a3a3a"))
	var hills2 := PackedVector2Array([Vector2(0, horizon + 1), Vector2(0, horizon - 8), Vector2(screen.x * 0.25, horizon - 12),
		Vector2(screen.x * 0.5, horizon - 5), Vector2(screen.x * 0.78, horizon - 11), Vector2(screen.x, horizon - 6), Vector2(screen.x, horizon + 1)])
	s.draw_colored_polygon(hills2, near)
	# 兩邊的楓樹(燈籠掛在樹枝上)
	var lanterns := lantern_spots(s)
	_draw_maple(s, Vector2(10, horizon + 2.0), lanterns[0], -1.0)
	_draw_maple(s, Vector2(roundf(screen.x - 10.0), horizon + 2.0), lanterns[1], 1.0)


static func _draw_occupied_castle(s: CampScenery, base: Vector2, color: Color) -> void:
	s.draw_rect(Rect2(base + Vector2(-14, -7), Vector2(28, 8)), color)
	for i in 5:
		s.draw_rect(Rect2(base + Vector2(-14 + i * 6, -9), Vector2(3, 2)), color)
	for tower: Vector3 in [Vector3(-14, 16, 5), Vector3(9, 16, 5), Vector3(-3, 23, 7)]:
		var top := base + Vector2(tower.x, -tower.y)
		s.draw_rect(Rect2(top, Vector2(tower.z, tower.y)), color)
		s.draw_colored_polygon(PackedVector2Array([top + Vector2(-1, 0), top + Vector2(tower.z * 0.5, -5), top + Vector2(tower.z + 1, 0)]), color)
		# 黑狼旗(飄動)
		var pole := top + Vector2(tower.z * 0.5, -10)
		s.draw_rect(Rect2(pole, Vector2(1, 5)), color)
		var wave := 1.0 if fmod(s.time * 2.5 + tower.x, 2.0) < 1.0 else 0.0
		s.draw_rect(Rect2(pole + Vector2(1, 0), Vector2(4, 3)), Color("161020"))
		s.draw_rect(Rect2(pole + Vector2(4, wave), Vector2(1, 3)), Color("161020"))
		s.draw_rect(Rect2(pole + Vector2(2, 1), Vector2(1, 1)), Color("9a9ab0"))
	for i in 4:
		var on := 0.5 + 0.5 * sin(s.time * 1.1 + i * 1.9)
		s.draw_rect(Rect2(base + Vector2(-10 + i * 6, -4), Vector2(1, 2)), Color(0.9, 0.3, 0.4, 0.4 + 0.5 * on))


static func _draw_maple(s: CampScenery, base: Vector2, lantern: Vector2, side: float) -> void:
	# 樹幹往畫面中間彎一點;樹冠是幾團橘紅黃的圓,邊緣有一點點亮光
	var trunk := Color("4a3028")
	var h := base.y - lantern.y + 22.0
	for k in 10:
		var t := k / 9.0
		var p := base + Vector2(-side * sin(t * 1.2) * 4.0, -t * h)
		s.draw_rect(Rect2(p.round() - Vector2(2, 0), Vector2(4, ceilf(h / 9.0) + 1)), trunk if k % 3 != 0 else trunk.lightened(0.1))
	var crown := base + Vector2(-side * sin(1.2) * 4.0, -h)
	var leaf_a := s.palette_color("leaf_color", Color("d8562e"))
	var leaf_b := s.palette_color("leaf_color_2", Color("f0a032"))
	var leaf_c := s.palette_color("leaf_color_3", Color("a8302a"))
	var puffs: Array[Vector3] = [Vector3(0, 0, 13), Vector3(-side * 12, 6, 10), Vector3(-side * 4, -9, 10), Vector3(side * 8, 5, 9),
		Vector3(-side * 16, -4, 7), Vector3(side * 2, 12, 8)]
	for i in puffs.size():
		var pf := puffs[i]
		var c := crown + Vector2(pf.x, pf.y)
		var col := leaf_c if i % 3 == 0 else (leaf_a if i % 3 == 1 else leaf_b)
		s.draw_circle(c.round(), pf.z, col.darkened(0.12))
		s.draw_circle((c + Vector2(-1, -1)).round(), pf.z - 2.0, col)
	# 樹冠上的亮點(夕陽照到的葉子,隨風一閃一閃)
	for k in 9:
		var p := crown + Vector2(sin(k * 2.3) * 14.0, cos(k * 1.7) * 10.0)
		var tw := 0.5 + 0.5 * sin(s.time * 2.0 + k)
		s.draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(leaf_b.lightened(0.35), 0.4 + 0.5 * tw))
	# 樹枝與燈籠(紙燈籠輕輕晃)
	var swing := sin(s.time * 1.6 + side) * 1.0
	s.draw_line(lantern + Vector2(-side * 4, -9), lantern + Vector2(0, -9), trunk, 2.0)
	s.draw_rect(Rect2(lantern + Vector2(swing, -9), Vector2(1, 4)), Color("2a1b2d"))
	var l := lantern + Vector2(swing, 0)
	s.draw_rect(Rect2(l + Vector2(-3, -5), Vector2(7, 9)), Color("2a1b2d"))
	s.draw_rect(Rect2(l + Vector2(-2, -4), Vector2(5, 7)), Color("ff9a3c"))
	s.draw_rect(Rect2(l + Vector2(-1, -4), Vector2(2, 7)), Color("ffd27a"))
	s.draw_rect(Rect2(l + Vector2(-3, -1), Vector2(7, 1)), Color("c8602a"))


static func ground_autumn(s: CampScenery) -> void:
	var screen := SafeArea.get_screen_size()
	var horizon := s.horizon_y
	# 地上的落葉
	var colors: Array[Color] = [s.palette_color("leaf_color", Color("d8562e")), s.palette_color("leaf_color_2", Color("f0a032")),
		s.palette_color("leaf_color_3", Color("a8302a"))]
	for i in 34:
		var p := Vector2(fmod(i * 41.0 + 17.0, screen.x), horizon + 3.0 + fmod(i * 29.0, maxf(screen.y - horizon - 6.0, 8.0)))
		if absf(p.x - s.fire_spot.x) < 40.0 and absf(p.y - s.fire_spot.y - 10.0) < 12.0:
			continue
		var col := Color(colors[i % 3], 0.85)
		s.draw_rect(Rect2(p.round(), Vector2(2, 1)), col)
		s.draw_rect(Rect2(p.round() + Vector2(1, -1 if i % 2 == 0 else 1), Vector2(1, 1)), col.darkened(0.15))
	# 樹下的落葉堆
	for x: float in [8.0, screen.x - 12.0]:
		s.draw_ellipse_px(Vector2(x, horizon + 4.0), Vector2(12, 2), Color(colors[0].darkened(0.2), 0.9))
		s.draw_ellipse_px(Vector2(x + 2.0, horizon + 3.0), Vector2(7, 1), Color(colors[1], 0.9))
	# 南瓜(右邊兩顆)
	for pk: Vector3 in [Vector3(screen.x - 20.0, 14.0, 5.0), Vector3(screen.x - 9.0, 18.0, 4.0)]:
		var c := Vector2(roundf(pk.x), horizon + pk.y)
		s.draw_ellipse_px(c + Vector2(0, pk.z * 0.7), Vector2(pk.z + 1.0, 1.5), Color(0, 0, 0, 0.25))
		s.draw_ellipse_px(c, Vector2(pk.z + 1.0, pk.z * 0.75), Color("c8601e"))
		s.draw_ellipse_px(c + Vector2(-1, -1), Vector2(pk.z * 0.6, pk.z * 0.5), Color("f08a2e"))
		s.draw_rect(Rect2(c + Vector2(0, -pk.z * 0.75 - 2.0), Vector2(1, 2)), Color("4a6a2a"))
		s.draw_rect(Rect2(c + Vector2(-0.5, -pk.z * 0.5), Vector2(1, pk.z)), Color(0.6, 0.3, 0.1, 0.5))
	# 樹下的小蘑菇
	for m: Vector2 in [Vector2(20, 6), Vector2(26, 9)]:
		var c := Vector2(m.x, horizon + m.y)
		s.draw_rect(Rect2(c + Vector2(0, -2), Vector2(1, 3)), Color("e8dcc8"))
		s.draw_rect(Rect2(c + Vector2(-1, -3), Vector2(3, 1)), Color("c8303a"))
		s.draw_rect(Rect2(c + Vector2(0, -4), Vector2(1, 1)), Color("c8303a"))


# --- 圓桌上的東西 ---

## 第六章的野外圓桌前面掛著圓桌旗布;第五章第二次營地桌上有摩根娜的水晶球。
static func table_extras(s: CampScenery) -> void:
	if s.chapter == 6 and s.config.table_texture == null:
		var c := s.table_spot
		var cloth := s.palette_color("cloth_color", Color("b8343a"))
		var pts := PackedVector2Array([c + Vector2(-24, 9), c + Vector2(24, 9)])
		for k in 7:
			var x := 24.0 - k * 8.0
			pts.append(c + Vector2(x - 4.0, 17.0 + (k % 2) * 2.0))
		s.draw_colored_polygon(pts, cloth)
		s.draw_rect(Rect2(c + Vector2(-24, 9), Vector2(48, 1)), Color("ffe066"))
		s.draw_arc(c + Vector2(0, 13), 3.0, 0, TAU, 12, Color("ffe066"), 1.0)
		# 桌上的一籃蘋果(阿瓦隆的蘋果)
		var basket := c + Vector2(-38, -8)
		s.draw_rect(Rect2(basket + Vector2(-5, 0), Vector2(10, 5)), Color("8a5a2a"))
		s.draw_rect(Rect2(basket + Vector2(-5, 2), Vector2(10, 1)), Color("6a4020"))
		for k in 3:
			s.draw_circle(basket + Vector2(-3 + k * 3, -1 - (k % 2)), 2.0, Color("d83a3a") if k != 1 else Color("e8c040"))
	if s.crystal_ball:
		var b := s.crystal_spot
		s.draw_rect(Rect2(b + Vector2(-4, 3), Vector2(9, 2)), Color("8a6a2a"))
		s.draw_rect(Rect2(b + Vector2(-3, 2), Vector2(7, 1)), Color("e0b040"))
		s.draw_circle(b, 5.0, Color("2a1b40"))
		s.draw_circle(b, 4.0, Color("8a5ad0"))
		var swirl := s.time * 2.0
		s.draw_circle(b + Vector2(cos(swirl), sin(swirl)) * 1.5, 1.5, Color("d8b0ff"))
		s.draw_rect(Rect2(b + Vector2(-2, -3), Vector2(1, 1)), Color(1, 1, 1, 0.9))


# --- 光暈(加亮混合) ---

static func glow(s: CampScenery) -> void:
	match s.chapter:
		4:
			_glow_beach(s)
		5:
			_glow_snow(s)
		6:
			_glow_autumn(s)
	if s.crystal_ball:
		var pulse := 0.5 + 0.5 * sin(s.time * 2.4)
		for i in 3:
			s.draw_circle(s.crystal_spot, 6.0 + i * 4.0 + pulse * 2.0, Color(0.7, 0.4, 1.0, 0.07 + 0.04 * pulse))


static func _glow_beach(s: CampScenery) -> void:
	# 海面的月光倒影
	var sea_y := sea_top(s)
	var y := sea_y + 1.0
	var k := 0
	while y < s.horizon_y - 1.0:
		var half := 2.0 + k * 1.4 + roundf(sin(s.time * 3.0 + k * 1.3) * 1.5)
		var a := 0.16 + 0.12 * sin(s.time * 2.4 + k * 0.9)
		s.draw_rect(Rect2(roundf(s.moon_spot.x - half + sin(s.time * 1.1 + k) * 1.5), roundf(y), roundf(half * 2.0), 1), Color(0.8, 0.9, 1.0, a))
		y += 2.0
		k += 1
	# 燈塔的燈:亮一下,光束慢慢左右掃過海面
	var lamp := Vector2(10.5, sea_y - 13.0 - 22.0 + 4.0)
	var blink := clampf(sin(s.time * PI) * 1.4, 0.0, 1.0)
	s.draw_circle(lamp, 4.0 + blink * 3.0, Color(1, 0.9, 0.5, 0.15 + 0.2 * blink))
	var sweep := sin(s.time * 0.6) * 0.35
	var dir := Vector2(cos(sweep), sin(sweep) * 0.3 + 0.12).normalized()
	var spread := Vector2(-dir.y, dir.x) * 7.0
	var tip := lamp + dir * 70.0
	s.draw_colored_polygon(PackedVector2Array([lamp, tip + spread, tip - spread]), Color(1, 0.95, 0.7, 0.06))


static func _glow_snow(s: CampScenery) -> void:
	# 小木屋窗戶的暖光
	var win := hut_window(s)
	var lamp := 0.8 + 0.2 * sin(s.time * 2.7) * sin(s.time * 1.3)
	for i in 3:
		s.draw_circle(win, 6.0 + i * 5.0, Color(1, 0.7, 0.3, (0.08 - i * 0.02) * lamp))
	# 遠方火山口的紅光
	var screen := SafeArea.get_screen_size()
	var room := s.horizon_y - s.top_y
	var pk := VOLCANO_PEAKS[VOLCANO_INDEX]
	var peak := Vector2(roundf(screen.x * pk.x), s.horizon_y - roundf(clampf(room * pk.y, 24.0, room + 6.0)))
	var pulse := 0.5 + 0.5 * sin(s.time * 1.7)
	s.draw_circle(peak, 5.0 + pulse * 2.0, Color(1, 0.35, 0.15, 0.12 + 0.08 * pulse))
	# 溫泉的蒸氣:一團一團往上飄、變大、變淡
	var c := spring_center(s)
	for i in 7:
		var t := fmod(s.time * 0.22 + i / 7.0, 1.0)
		var x := c.x - 12.0 + float(i % 4) * 8.0 + sin(t * 5.0 + i) * 3.0
		var p := Vector2(x, c.y - 2.0 - t * 34.0)
		s.draw_circle(p.round(), 2.0 + t * 5.0, Color(0.9, 0.95, 1.0, 0.16 * sin(t * PI)))
	s.draw_ellipse_px(c, Vector2(18, 4), Color(0.5, 0.9, 1.0, 0.06))


static func _glow_autumn(s: CampScenery) -> void:
	# 夕陽的光暈(在遠山後面)與地平線上的暖光
	var sun := sun_spot(s)
	for i in 5:
		s.draw_circle(sun, 12.0 + i * 9.0, Color(1, 0.62, 0.32, 0.045))
	var screen := SafeArea.get_screen_size()
	for i in 4:
		s.draw_rect(Rect2(0, s.horizon_y - 24.0 + i * 5.0, screen.x, 5), Color(1, 0.55, 0.3, 0.02 + i * 0.012))
	# 燈籠的光
	for l: Vector2 in lantern_spots(s):
		var flick := 0.85 + 0.15 * sin(s.time * 7.0 + l.x)
		for i in 3:
			s.draw_circle(l, (5.0 + i * 4.0) * flick, Color(1, 0.6, 0.25, 0.09 - i * 0.025))


# --- 畫在角色前面(Camp 的 Front,一般混合) ---

## 第五章的飄雪、第六章飄落的葉子。area:可以畫的範圍(避開標題與選單)。
static func draw_front(canvas: CanvasItem, chapter: int, time: float, area: Rect2, palette: Dictionary) -> void:
	match chapter:
		5:
			for i in SNOWFLAKES:
				var speed := 9.0 + float(i % 4) * 3.0
				var y := area.position.y + fmod(i * 53.0 + time * speed, area.size.y)
				var x := area.position.x + fmod(i * 37.0 + sin(time * 0.7 + i) * 6.0 + time * 2.0, area.size.x)
				var fade := clampf(minf(y - area.position.y, area.end.y - y) / 12.0, 0.0, 1.0)
				var size := Vector2(2, 2) if i % 5 == 0 else Vector2.ONE
				canvas.draw_rect(Rect2(Vector2(x, y).round(), size), Color(1, 1, 1, (0.55 + 0.35 * float(i % 3) / 2.0) * fade))
		6:
			var colors: Array[Color] = [palette.get("leaf_color", Color("d8562e")), palette.get("leaf_color_2", Color("f0a032")),
				palette.get("leaf_color_3", Color("a8302a"))]
			for i in LEAVES:
				var speed := 8.0 + float(i % 3) * 4.0
				var y := area.position.y + fmod(i * 61.0 + time * speed, area.size.y)
				var x := area.position.x + fmod(i * 43.0 + sin(time * 1.3 + i * 1.7) * 9.0 + time * 5.0, area.size.x)
				var fade := clampf(minf(y - area.position.y, area.end.y - y) / 14.0, 0.0, 1.0)
				var col := Color(colors[i % 3], fade)
				var p := Vector2(x, y).round()
				# 葉子翻轉:寬窄交替
				if sin(time * 3.0 + i) > 0.0:
					canvas.draw_rect(Rect2(p, Vector2(3, 2)), col)
					canvas.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), col.lightened(0.2))
				else:
					canvas.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 3)), col)
