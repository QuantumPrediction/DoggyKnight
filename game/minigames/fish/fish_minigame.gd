class_name FishMinigame
extends MinigameBase
## 小遊戲「接住跳跳魚」(v2.7 DW3):第四至六章的營地和「拉扯王室卷軸」「叫醒騎士」輪流出現。
##
## 第四章全國的狗碗被偷空了。魚從上面的海裡一條一條跳出來,落向沙灘;金毛頭上頂著黃金狗碗,
## 玩家在畫面上左右拖曳(或按一下),金毛就跑過去接。魚要落下的地方先在沙灘上出現影子。
## 金魚分數多;舊靴子不要接(接到會「呸!」、連續中斷,很可愛,不會受傷)。越後面魚越多、飛得越快。
## 接到的魚堆在碗裡;時間到時評價 2 以上,金毛舉著滿滿的碗歡呼「汪!」。
##
## 分數:點數 ÷ 這一局最多能拿的點數 × 100(0 至 100 分);評價與獎勵和其他小遊戲一樣(MinigameGrading)。
## 只用觸控(只認第一根手指);直向 180×320 起,依 SafeArea 排版;拖曳範圍避開底部的系統手勢區,
## 金毛離左右邊緣 edge_margin,手指不用拖到螢幕邊緣。全部用程式畫(金毛用 C 線的 goldie_frames)。
##
## 給測試與自動試玩機器人用的方法:
## - move_to(x):讓金毛往畫面上的 x 走(和手指按在 x 一樣)。
## - bot_target_x():現在該往哪裡走(下一條要接的魚的落點;沒有魚時傳回目前位置)。
## - bot_step(delta):每格呼叫一次就會自己玩(= move_to(bot_target_x()))。
## - next_catch():下一條要接的魚 {"x", "time", "kind"};items:整份時間表。
## 時間表保證:每條魚都接得到(reach_factor),靴子不會落在「從上一條魚走到下一條魚」的路上。

const GOLDIE_FRAMES_PATH: String = "res://assets/sprites/goldie/goldie_frames.tres"
## 魚與靴子畫幾倍大(整數,像素保持方正)。
const ITEM_SCALE: float = 2.0

enum Kind { FISH, GOLDEN, BOOT }
enum Hit { NONE, PERFECT, GOOD, MISS, BOOT, DODGED }

## 時間表:{"land": 落到碗的高度的時間(開始後幾秒), "flight": 飛行秒數, "u": 落點(0 至 1,左到右),
## "launch_u": 跳出水面的位置(0 至 1), "kind": Kind, "result": Hit, "judged_at": 判定的時間}
var items: Array[Dictionary] = []
var points: int = 0
var max_points: int = 1
## 接到的魚(含金魚)、其中的金魚、「完美!」、沒接到的魚、接到的靴子。
var caught: int = 0
var goldens: int = 0
var perfects: int = 0
var misses: int = 0
var boots: int = 0
var combo: int = 0
var best_combo: int = 0
## 金毛(碗)的中心 x 與要去的 x(畫面邏輯像素)。
var goldie_x: float = 90.0
var target_x: float = 90.0

var _cfg: FishMinigameConfig
var _rng := RandomNumberGenerator.new()
var _goldie: AnimatedSprite2D
var _front: Node2D
var _fx_layer: Node2D
var _score_label: Label
var _combo_label: Label
var _hint_label: Label
var _anim_time: float = 0.0
var _finger: int = -1
## 跳出的字:{"text", "pos", "age", "color", "big"}
var _popups: Array[Dictionary] = []
## 水花:{"pos", "age"}
var _splashes: Array[Dictionary] = []
var _pile: int = 0
var _shake: float = 0.0
var _catch_pop: float = 0.0
var _score_bump: float = 0.0
var _cheer: bool = false
var _face_left: bool = false
var _decor: int = 0
var _palette: Dictionary = {}
# 版面(畫面邏輯像素)
var _sea_top: float = 26.0
var _shore_y: float = 110.0
var _feet_y: float = 280.0
var _goldie_y: float = 248.0
var _x_min: float = 22.0
var _x_max: float = 158.0
var _zone: Rect2 = Rect2()
var _frame_size: Vector2 = Vector2(32, 32)


func _on_build() -> void:
	_cfg = config as FishMinigameConfig
	if _cfg == null:
		_cfg = FishMinigameConfig.new()
		_cfg.grading = config.grading
		config = _cfg
	if _cfg.minigame_id == &"":
		_cfg.minigame_id = &"fish"
	if _cfg.goldie_frames == null and ResourceLoader.exists(GOLDIE_FRAMES_PATH):
		_cfg = _cfg.duplicate() as FishMinigameConfig
		_cfg.goldie_frames = load(GOLDIE_FRAMES_PATH) as SpriteFrames
		config = _cfg
	_palette = _cfg.chapter_palettes.get(GameState.chapter, _cfg.chapter_palettes.get(4, {}))
	_decor = int(_cfg.chapter_decor.get(GameState.chapter, 0))
	_goldie = AnimatedSprite2D.new()
	_goldie.name = "Goldie"
	_goldie.sprite_frames = _cfg.goldie_frames
	_goldie.scale = Vector2.ONE * _cfg.goldie_scale
	if _cfg.goldie_frames != null and _cfg.goldie_frames.has_animation(&"idle"):
		var tex := _cfg.goldie_frames.get_frame_texture(&"idle", 0)
		if tex != null:
			_frame_size = tex.get_size()
	add_child(_goldie)
	_play_goldie(&"idle")
	# 碗、魚、跳出的字畫在金毛前面
	_front = Node2D.new()
	_front.name = "Front"
	_front.draw.connect(_draw_front)
	add_child(_front)
	_fx_layer = Node2D.new()
	_fx_layer.name = "Fx"
	add_child(_fx_layer)
	_score_label = MinigameUi.make_label("", MinigameUi.FONT_S)
	_score_label.name = "Score"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_label)
	_combo_label = MinigameUi.make_label("", MinigameUi.FONT_S, Color("ffe066"))
	_combo_label.name = "Combo"
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_combo_label)
	_hint_label = MinigameUi.make_label(tr("MINIGAME_FISH_HINT"), MinigameUi.FONT_S)
	_hint_label.name = "Hint"
	add_child(_hint_label)


func _on_layout() -> void:
	var safe := SafeArea.get_safe_rect()
	_sea_top = safe.position.y + 26.0
	var bottom := safe.end.y
	_shore_y = roundf(_sea_top + (bottom - _sea_top) * _cfg.sea_ratio)
	_feet_y = roundf(bottom - _cfg.feet_bottom_margin)
	_goldie_y = roundf(_feet_y - _frame_size.y * _cfg.goldie_scale * 0.5)
	_x_min = roundf(safe.position.x + _cfg.edge_margin)
	_x_max = roundf(safe.end.x - _cfg.edge_margin)
	_zone = Rect2(safe.position.x, _sea_top, safe.size.x, bottom - _cfg.touch_bottom_margin - _sea_top)
	goldie_x = clampf(goldie_x, _x_min, _x_max)
	target_x = clampf(target_x, _x_min, _x_max)
	_score_label.size = Vector2(70, 12)
	_score_label.position = Vector2(safe.end.x - 74.0, safe.position.y + 14.0)
	_combo_label.size = Vector2(80, 12)
	_combo_label.position = Vector2(safe.position.x + 4.0, safe.position.y + 14.0)
	_hint_label.size = Vector2(safe.size.x - 8.0, 14.0)
	_hint_label.position = Vector2(safe.position.x + 4.0, _shore_y + 10.0)
	_place_goldie()


func _on_reset() -> void:
	_rng.seed = _cfg.rng_seed if _cfg.rng_seed != 0 else int(Time.get_ticks_usec())
	items.assign(build_chart(_cfg, _rng, _x_max - _x_min))
	max_points = max_points_for(items, _cfg)
	points = 0
	caught = 0
	goldens = 0
	perfects = 0
	misses = 0
	boots = 0
	combo = 0
	best_combo = 0
	_pile = 0
	_shake = 0.0
	_cheer = false
	_finger = -1
	_popups.clear()
	_splashes.clear()
	goldie_x = roundf((_x_min + _x_max) * 0.5)
	target_x = goldie_x
	_face_left = false
	_play_goldie(&"idle")
	_place_goldie()
	_update_labels()


## 產生時間表(同一個種子產生同一份)。width:金毛可以走的寬度(邏輯像素),用來保證每條魚都接得到。
## 傳回 Array[Dictionary](見 items 的說明),依落下的時間排序。
static func build_chart(cfg: FishMinigameConfig, rng: RandomNumberGenerator, width: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var duration := maxf(cfg.duration_sec, 0.01)
	var t := cfg.first_land_sec
	var last := cfg.duration_sec - cfg.last_land_margin_sec
	while t <= last:
		var ratio := clampf(t / duration, 0.0, 1.0)
		var kind := Kind.FISH
		if t >= cfg.boot_from_sec and rng.randf() < lerpf(cfg.boot_chance_start, cfg.boot_chance_end, ratio):
			kind = Kind.BOOT
		elif rng.randf() < cfg.golden_chance:
			kind = Kind.GOLDEN
		result.append({"land": t, "flight": lerpf(cfg.flight_start_sec, cfg.flight_end_sec, ratio), "u": 0.5, "launch_u": 0.5,
			"kind": kind, "result": Hit.NONE, "judged_at": -1.0})
		t += lerpf(cfg.interval_start_sec, cfg.interval_end_sec, ratio) * rng.randf_range(0.85, 1.15)
	# 要接的魚:每一條都從上一條走得到(金毛速度 × reach_factor),而且盡量要走一點路
	var w := maxf(width, 1.0)
	var prev_u := 0.5
	var prev_t := 0.0
	for item in result:
		if int(item["kind"]) == Kind.BOOT:
			continue
		var reach := cfg.goldie_speed * cfg.reach_factor * (float(item["land"]) - prev_t) / w
		var lo := maxf(0.0, prev_u - reach)
		var hi := minf(1.0, prev_u + reach)
		var u := rng.randf_range(lo, hi)
		var shift := cfg.min_shift / w
		for _attempt in 4:
			if absf(u - prev_u) >= shift or hi - lo < shift * 2.0:
				break
			u = rng.randf_range(lo, hi)
		item["u"] = u
		prev_u = u
		prev_t = float(item["land"])
	# 靴子:落在「上一條魚到下一條魚」那段路的外面;沒有地方放時就不放
	var keep: Array[Dictionary] = []
	var gap := cfg.catch_half_width * 2.0 / w
	for i in result.size():
		var item := result[i]
		if int(item["kind"]) == Kind.BOOT:
			var before := _neighbor_u(result, i, -1)
			var after := _neighbor_u(result, i, 1)
			var band_lo := minf(before, after) - gap
			var band_hi := maxf(before, after) + gap
			var room_left := band_lo
			var room_right := 1.0 - band_hi
			if room_left <= 0.0 and room_right <= 0.0:
				continue
			if room_right <= 0.0 or (room_left > 0.0 and rng.randf() < room_left / (room_left + room_right)):
				item["u"] = rng.randf_range(0.0, room_left)
			else:
				item["u"] = rng.randf_range(band_hi, 1.0)
		item["launch_u"] = clampf(float(item["u"]) + rng.randf_range(-1.0, 1.0) * cfg.launch_spread / w, 0.0, 1.0)
		keep.append(item)
	return keep


## 第 index 個之前(dir = -1)或之後(dir = 1)最近一條要接的魚的落點;沒有時:之前用正中間,之後用之前那條。
static func _neighbor_u(chart: Array[Dictionary], index: int, dir: int) -> float:
	var i := index + dir
	while i >= 0 and i < chart.size():
		if int(chart[i]["kind"]) != Kind.BOOT:
			return float(chart[i]["u"])
		i += dir
	return 0.5 if dir < 0 else _neighbor_u(chart, index, -1)


## 全部「完美!」而且一直連續時的點數。
static func max_points_for(chart: Array[Dictionary], cfg: FishMinigameConfig) -> int:
	var total := 0
	var good := 0
	for item in chart:
		match int(item["kind"]):
			Kind.FISH:
				total += cfg.fish_points + cfg.perfect_bonus
				good += 1
			Kind.GOLDEN:
				total += cfg.golden_points + cfg.perfect_bonus
				good += 1
	if cfg.combo_step > 0:
		total += (good / cfg.combo_step) * cfg.combo_bonus
	return maxi(1, total)


# --- 給測試與自動試玩機器人 ---

## 讓金毛往畫面上的 x 走(和手指按在 x 一樣;會限制在可以走的範圍內)。
func move_to(x: float) -> void:
	target_x = clampf(x, _x_min, _x_max)


## 第 item 個東西的落點(畫面邏輯像素)。
func item_x(item: Dictionary) -> float:
	return roundf(lerpf(_x_min, _x_max, float(item["u"])))


## 下一條還沒落下、要接的魚(不含靴子):{"x": 落點, "time": 落下的時間, "kind": Kind};沒有時傳回空字典。
func next_catch() -> Dictionary:
	for item in items:
		if int(item["result"]) == Hit.NONE and int(item["kind"]) != Kind.BOOT:
			return {"x": item_x(item), "time": float(item["land"]), "kind": int(item["kind"])}
	return {}


## 自動試玩:金毛現在該往哪裡走(下一條要接的魚的落點;沒有魚時留在原地)。
func bot_target_x() -> float:
	var next := next_catch()
	return float(next["x"]) if not next.is_empty() else goldie_x


## 自動試玩:每格呼叫一次就會自己玩(遊戲中才有作用)。
func bot_step(_delta: float) -> void:
	if state == State.PLAYING:
		move_to(bot_target_x())


## 金毛目前的動畫(測試用):idle、run,評價 2 以上時 victory。
func goldie_animation() -> StringName:
	return _goldie.animation if _goldie != null else &""


## 碗的中心(畫面邏輯像素)。
func bowl_center() -> Vector2:
	var offset := _cfg.bowl_offset
	if _face_left:
		offset.x = -offset.x
	var shake := roundf(sin(_shake * 40.0) * 2.0) if _shake > 0.0 else 0.0
	return Vector2(roundf(goldie_x) + offset.x + shake, _goldie_y + offset.y + _bob())


## 碗接東西的高度(畫面邏輯像素)。
func catch_y() -> float:
	return _goldie_y + _cfg.bowl_offset.y


## 可以拖曳的範圍。
func touch_zone() -> Rect2:
	return _zone


## 金毛可以走的範圍(碗的中心 x)。
func goldie_range() -> Vector2:
	return Vector2(_x_min, _x_max)


## 第 item 個東西現在的位置(畫面邏輯像素);還沒跳出水面時傳回 Vector2.INF。
func item_position(item: Dictionary) -> Vector2:
	var now := _now()
	var launch := float(item["land"]) - float(item["flight"])
	if now < launch:
		return Vector2.INF
	var u := (now - launch) / maxf(float(item["flight"]), 0.05)
	var from := Vector2(lerpf(_x_min, _x_max, float(item["launch_u"])), _launch_y(item))
	var to := Vector2(item_x(item), catch_y())
	var p := from.lerp(to, u)
	p.y -= 4.0 * _cfg.arc_height * u * (1.0 - u)
	return p


# --- 遊戲進行 ---

func _on_play_input(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if _finger != -1 or not _zone.has_point(touch.position):
				return false
			_finger = touch.index
			move_to(touch.position.x)
			return true
		if touch.index == _finger:
			_finger = -1
			return true
		return false
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _finger:
		move_to(drag.position.x)
		return true
	return false


func _on_play_started() -> void:
	_finger = -1


func _on_countdown_process(delta: float) -> void:
	_tick(delta)


func _on_play_process(delta: float) -> void:
	# 金毛跑向手指的位置
	var before := goldie_x
	goldie_x = move_toward(goldie_x, target_x, _cfg.goldie_speed * delta)
	if absf(goldie_x - before) > 0.01:
		_face_left = goldie_x < before
		_play_goldie(&"run")
	else:
		_play_goldie(&"idle")
	# 跳出水面的水花
	for item in items:
		if not item.has("splashed") and _now() >= float(item["land"]) - float(item["flight"]):
			item["splashed"] = true
			_splashes.append({"pos": Vector2(lerpf(_x_min, _x_max, float(item["launch_u"])), _launch_y(item)), "age": 0.0})
	# 落到碗的高度:判定
	for i in items.size():
		if int(items[i]["result"]) == Hit.NONE and play_elapsed >= float(items[i]["land"]):
			_judge(i)
	_tick(delta)


func _on_ending_process(delta: float) -> void:
	_tick(delta)


func _on_results_process(delta: float) -> void:
	_tick(delta)


func _on_paused(paused: bool) -> void:
	if paused:
		_goldie.pause()
		_finger = -1
	else:
		_goldie.play()


func _on_play_ended(_final_score: int, final_grade: int) -> void:
	# 評價 2 以上:金毛舉著滿滿的碗歡呼「汪!」
	_cheer = final_grade >= 2
	_finger = -1
	_play_goldie(&"victory" if _cheer else &"idle")
	if _cheer:
		Sfx.play(_cfg.cheer_sfx)
		_popups.append({"text": tr("MINIGAME_FISH_CHEER"), "pos": bowl_center() + Vector2(0, -22), "age": 0.0, "color": MinigameUi.WHITE, "big": true})
		_spawn_fx(_cfg.catch_fx, bowl_center() + Vector2(0, -8))


func _judge(index: int) -> void:
	var item := items[index]
	item["judged_at"] = play_elapsed
	var dx := absf(goldie_x - item_x(item))
	var kind := int(item["kind"])
	if kind == Kind.BOOT:
		if dx <= _cfg.catch_half_width:
			item["result"] = Hit.BOOT
			boots += 1
			combo = 0
			_shake = 0.5
			Sfx.play(_cfg.boot_sfx)
			Haptics.play(&"light")
			_popups.append({"text": tr("MINIGAME_FISH_BOOT"), "pos": bowl_center() + Vector2(0, -16), "age": 0.0, "color": Color("c8b8a0"), "big": false})
		else:
			item["result"] = Hit.DODGED
		_update_labels()
		return
	if dx > _cfg.catch_half_width:
		item["result"] = Hit.MISS
		misses += 1
		combo = 0
		_popups.append({"text": tr("MINIGAME_FISH_MISS"), "pos": Vector2(item_x(item), _feet_y - 18.0), "age": 0.0, "color": Color("b8d8f0"), "big": false})
		_update_labels()
		return
	var perfect := dx <= _cfg.perfect_half_width
	item["result"] = Hit.PERFECT if perfect else Hit.GOOD
	caught += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	_pile += 1
	_catch_pop = 0.25
	_score_bump = 0.3
	var golden := kind == Kind.GOLDEN
	points += _cfg.golden_points if golden else _cfg.fish_points
	if golden:
		goldens += 1
	if perfect:
		perfects += 1
		points += _cfg.perfect_bonus
	if _cfg.combo_step > 0 and combo % _cfg.combo_step == 0:
		points += _cfg.combo_bonus
	Sfx.play(_cfg.golden_sfx if golden else (_cfg.perfect_sfx if perfect else _cfg.catch_sfx))
	Haptics.play(&"light")
	var text := tr("MINIGAME_PERFECT") if perfect else tr("MINIGAME_GOOD")
	_popups.append({"text": text, "pos": bowl_center() + Vector2(0, -18), "age": 0.0,
		"color": Color("ffe066") if perfect or golden else Color("bfe36d"), "big": perfect or golden})
	_spawn_fx(_cfg.catch_fx, bowl_center() + Vector2(0, -4))
	_update_labels()


func _compute_score() -> int:
	return clampi(roundi(100.0 * points / maxf(max_points, 1)), 0, 100)


func _format_score(value: int) -> String:
	return tr("MINIGAME_FISH_SCORE") % value


func _go_text() -> String:
	return tr("MINIGAME_FISH_GO")


func _result_extra_lines() -> PackedStringArray:
	return PackedStringArray([tr("MINIGAME_FISH_RESULT") % [caught, goldens]])


func _countdown_center() -> Vector2:
	var safe := SafeArea.get_safe_rect()
	return Vector2(safe.get_center().x, roundf(lerpf(_shore_y, catch_y(), 0.62)))


func _tick(delta: float) -> void:
	_anim_time += delta
	_shake = maxf(0.0, _shake - delta)
	_catch_pop = maxf(0.0, _catch_pop - delta)
	_score_bump = maxf(0.0, _score_bump - delta)
	for p: Dictionary in _popups:
		p["age"] = float(p["age"]) + delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 0.8)
	for s: Dictionary in _splashes:
		s["age"] = float(s["age"]) + delta
	_splashes = _splashes.filter(func(s: Dictionary) -> bool: return float(s["age"]) < 0.5)
	_hint_label.visible = state == State.COUNTDOWN or (state == State.PLAYING and play_elapsed < _cfg.hint_play_sec)
	_place_goldie()
	_update_labels()
	_front.queue_redraw()


func _place_goldie() -> void:
	if _goldie == null:
		return
	_goldie.position = Vector2(roundf(goldie_x), _goldie_y + _bob())
	_goldie.scale = Vector2(-_cfg.goldie_scale if _face_left else _cfg.goldie_scale, _cfg.goldie_scale)


## 金毛跳一下:接到魚時、歡呼時。
func _bob() -> float:
	if _cheer:
		return -absf(roundf(sin(_anim_time * 8.0) * 3.0))
	if _catch_pop > 0.0:
		return -roundf(sin(_catch_pop / 0.25 * PI) * 2.0)
	return 0.0


func _play_goldie(anim: StringName) -> void:
	if _goldie == null or _goldie.sprite_frames == null:
		return
	var pick := anim if _goldie.sprite_frames.has_animation(anim) else &"idle"
	if _goldie.sprite_frames.has_animation(pick) and _goldie.animation != pick:
		_goldie.play(pick)


func _update_labels() -> void:
	if _score_label == null:
		return
	_score_label.text = tr("MINIGAME_FISH_SCORE") % _compute_score()
	_score_label.pivot_offset = Vector2(_score_label.size.x, _score_label.size.y * 0.5)
	var bump := _score_bump / 0.3
	_score_label.scale = Vector2.ONE * (1.0 + 0.4 * bump * bump)
	_score_label.visible = state != State.RESULTS
	_combo_label.text = tr("MINIGAME_FISH_COMBO") % combo
	_combo_label.visible = combo >= 2 and state == State.PLAYING


func _spawn_fx(scene: PackedScene, at: Vector2) -> void:
	if scene == null or _fx_layer == null:
		return
	var fx := scene.instantiate()
	if fx is Node2D:
		(fx as Node2D).position = at.round()
	_fx_layer.add_child(fx)


## 遊戲時間(倒數時是負的),讓魚在倒數時也在正確的位置。
func _now() -> float:
	return play_elapsed if state != State.COUNTDOWN else -countdown_left


## 魚跳出水面的高度:每條魚在海裡的深淺不同(遠的在上面)。
func _launch_y(item: Dictionary) -> float:
	var depth := fmod(float(item["land"]) * 7.3, 1.0)
	return roundf(lerpf(_sea_top + 14.0, _shore_y - 6.0, 0.3 + 0.6 * depth))


func _pc(key: String, fallback: Color) -> Color:
	var value: Variant = _palette.get(key, fallback)
	return value if value is Color else fallback


# --- 繪圖 ---

func _draw() -> void:
	if _cfg == null:
		return
	var screen := SafeArea.get_screen_size()
	_draw_backdrop(screen)
	_draw_shadows()


## 背景:天空、海(浪、閃光、岸邊的泡沫)、沙灘(依章:海邊、雪、秋天)。
func _draw_backdrop(screen: Vector2) -> void:
	var sky := _pc("sky_color", Color("8fd3ff"))
	var sea := _pc("sea_color", Color("2f8fd0"))
	var sea_light := _pc("sea_light_color", Color("6ccaf0"))
	var sand := _pc("sand_color", Color("f0d49a"))
	var sand_light := _pc("sand_light_color", Color("fff0c0"))
	var foam := _pc("foam_color", Color.WHITE)
	draw_rect(Rect2(0, 0, screen.x, _sea_top + 4.0), sky)
	# 天空的雲
	for i in 3:
		var cx := fmod(i * 67.0 + _anim_time * (3.0 + i), screen.x + 40.0) - 20.0
		var cy := roundf(_sea_top * (0.3 + i * 0.2))
		for puff: Vector3 in [Vector3(0, 0, 5), Vector3(6, 1, 4), Vector3(-6, 1, 4)]:
			draw_circle(Vector2(roundf(cx) + puff.x, cy + puff.y), puff.z, Color(1, 1, 1, 0.55))
	# 海:遠深近淺
	var bands := 6
	for i in bands:
		var y0 := _sea_top + roundf((_shore_y - _sea_top) * i / bands)
		var y1 := _sea_top + roundf((_shore_y - _sea_top) * (i + 1) / bands)
		draw_rect(Rect2(0, y0, screen.x, y1 - y0 + 1), sea.lerp(sea_light, float(i) / bands))
	draw_rect(Rect2(0, _sea_top, screen.x, 1), sea_light.lightened(0.3))
	for i in 20:
		var wy := _sea_top + 4.0 + fmod(i * 7.0, maxf(_shore_y - _sea_top - 8.0, 1.0))
		var wx := fmod(i * 31.0 + _anim_time * (5.0 + (i % 3) * 2.0), screen.x + 12.0) - 6.0
		var a := 0.35 + 0.25 * sin(_anim_time * 2.0 + i)
		draw_rect(Rect2(roundf(wx), roundf(wy), 3 + (i % 3) * 2, 1), Color(1, 1, 1, a))
	# 沙灘(雪地、秋天的草地)與岸邊來回的泡沫
	draw_rect(Rect2(0, _shore_y, screen.x, screen.y - _shore_y), sand)
	var reach := roundf(2.0 + 2.0 * sin(_anim_time * 1.6))
	draw_rect(Rect2(0, _shore_y, screen.x, reach + 2.0), sand.darkened(0.12))
	for x in range(0, int(screen.x) + 2, 2):
		draw_rect(Rect2(x, _shore_y + reach + roundf(sin(x * 0.3 + _anim_time * 2.0)), 2, 1), Color(foam, 0.85))
	for i in 24:
		var p := Vector2(fmod(i * 43.0 + 11.0, screen.x), _shore_y + 8.0 + fmod(i * 29.0, maxf(screen.y - _shore_y - 10.0, 8.0)))
		draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(sand_light, 0.7))
	match _decor:
		1:
			_draw_snow_decor(screen)
		2:
			_draw_autumn_decor(screen)
		_:
			_draw_beach_decor(screen)


func _draw_beach_decor(screen: Vector2) -> void:
	# 左邊的椰子樹、右邊的沙堡與貝殼
	var base := Vector2(6, _shore_y + 22.0)
	for k in 10:
		var t := k / 9.0
		draw_rect(Rect2(base + Vector2(sin(t * 1.3) * 6.0 - 1.0, -t * 46.0), Vector2(3, 6)), Color("a8784a") if k % 2 == 0 else Color("8a5a32"))
	var crown := base + Vector2(sin(1.3) * 6.0, -46.0)
	var sway := sin(_anim_time * 1.3) * 1.5
	for dir: Vector2 in [Vector2(1, 0.4), Vector2(0.8, -0.3), Vector2(-0.6, 0.5), Vector2(0.2, -0.9)]:
		for k in 8:
			var t := k / 7.0
			draw_rect(Rect2((crown + Vector2(dir.x * t * 15.0, dir.y * t * 9.0 + t * t * 7.0 + sway * t)).round(), Vector2(2, 2)), Color("3a9a4a"))
	draw_circle(crown + Vector2(1, 3), 2.0, Color("6a4a2a"))
	var castle := Vector2(screen.x - 12.0, _feet_y - 6.0)
	draw_rect(Rect2(castle + Vector2(-8, -6), Vector2(16, 8)), Color("e0bc78"))
	draw_rect(Rect2(castle + Vector2(-6, -12), Vector2(5, 6)), Color("e0bc78"))
	draw_rect(Rect2(castle + Vector2(1, -14), Vector2(5, 8)), Color("e0bc78"))
	draw_rect(Rect2(castle + Vector2(3, -19), Vector2(1, 5)), Color("8a5a32"))
	draw_rect(Rect2(castle + Vector2(4, -19), Vector2(3, 2)), Color("e8434f"))
	draw_rect(Rect2(castle + Vector2(-2, -3), Vector2(3, 5)), Color("b8945a"))


func _draw_snow_decor(screen: Vector2) -> void:
	# 海上的浮冰、岸邊的雪堆、飄雪(慢、小,不會和魚搞混)
	for i in 3:
		var x := fmod(i * 59.0 + 20.0 + _anim_time * 2.0, screen.x + 30.0) - 15.0
		var y := roundf(lerpf(_sea_top + 8.0, _shore_y - 8.0, (i + 0.5) / 3.0))
		draw_rect(Rect2(roundf(x) - 6, y, 12, 3), Color("eef6ff"))
		draw_rect(Rect2(roundf(x) - 6, y + 3, 12, 1), Color("a8c8e0"))
	for d: Vector3 in [Vector3(8, 14, 12), Vector3(screen.x - 10.0, 30, 14)]:
		var c := Vector2(d.x, _shore_y + d.y)
		draw_circle(c, d.z * 0.5, Color.WHITE)
		draw_rect(Rect2(c + Vector2(-d.z * 0.5, 0), Vector2(d.z, d.z * 0.3)), Color.WHITE)
	for i in 18:
		var y := fmod(i * 41.0 + _anim_time * (8.0 + (i % 3) * 3.0), screen.y)
		var x := fmod(i * 29.0 + sin(_anim_time * 0.8 + i) * 5.0, screen.x)
		draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE), Color(1, 1, 1, 0.75))


func _draw_autumn_decor(screen: Vector2) -> void:
	# 左上角的楓樹枝、岸邊的落葉、飄落的葉子
	var leaf_colors: Array[Color] = [Color("d8562e"), Color("f0a032"), Color("a8302a")]
	for k in 6:
		draw_circle(Vector2(4 + k * 5.0, _sea_top + 6.0 + (k % 2) * 4.0), 5.0, leaf_colors[k % 3])
	draw_line(Vector2(0, _sea_top + 2.0), Vector2(30, _sea_top + 10.0), Color("4a3028"), 2.0)
	for i in 20:
		var p := Vector2(fmod(i * 37.0 + 5.0, screen.x), _shore_y + 6.0 + fmod(i * 23.0, maxf(screen.y - _shore_y - 8.0, 8.0)))
		draw_rect(Rect2(p.round(), Vector2(2, 1)), leaf_colors[i % 3])
	for i in 8:
		var y := fmod(i * 53.0 + _anim_time * (10.0 + (i % 3) * 3.0), screen.y)
		var x := fmod(i * 41.0 + sin(_anim_time * 1.3 + i) * 8.0, screen.x)
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 1)), Color(leaf_colors[i % 3], 0.8))


## 魚要落下的地方:沙灘上的影子,越接近越大越深。
func _draw_shadows() -> void:
	var now := _now()
	for item in items:
		if int(item["result"]) != Hit.NONE:
			continue
		var launch := float(item["land"]) - float(item["flight"])
		if now < launch:
			continue
		var u := clampf((now - launch) / maxf(float(item["flight"]), 0.05), 0.0, 1.0)
		var x := item_x(item)
		var size := lerpf(3.0, 9.0, u)
		var boot := int(item["kind"]) == Kind.BOOT
		var color := Color(0.25, 0.15, 0.1, 0.18 + 0.27 * u) if not boot else Color(0.35, 0.2, 0.15, 0.12 + 0.18 * u)
		var half := roundf(size)
		draw_rect(Rect2(x - half, _feet_y, half * 2.0 + 1.0, 2), color)
		draw_rect(Rect2(x - roundf(half * 0.6), _feet_y - 1.0, roundf(half * 1.2) + 1.0, 4), color)
		if u > 0.5 and not boot:
			# 快落下了:影子的中心閃一下
			var blink := 0.5 + 0.5 * sin(_anim_time * 18.0)
			draw_rect(Rect2(x - 1, _feet_y, 3, 1), Color(1, 1, 1, 0.35 * blink * u))


func _draw_front() -> void:
	if _cfg == null:
		return
	_draw_splashes()
	_draw_bowl()
	_draw_items()
	_draw_popups()
	if state == State.COUNTDOWN:
		_draw_hint()


func _draw_splashes() -> void:
	for s: Dictionary in _splashes:
		var t := float(s["age"]) / 0.5
		var p := s["pos"] as Vector2
		for k in 5:
			var a := PI * (1.1 + k * 0.2)
			var d := Vector2(cos(a), sin(a)) * (2.0 + t * 7.0) + Vector2(0, t * t * 6.0)
			_front.draw_rect(Rect2((p + d).round(), Vector2.ONE), Color(1, 1, 1, 1.0 - t))
		_front.draw_rect(Rect2(p + Vector2(-3 - t * 3.0, 0), Vector2(6 + t * 6.0, 1)).abs(), Color(1, 1, 1, 0.6 * (1.0 - t)))


## 黃金狗碗(頂在金毛頭上)與碗裡越堆越高的魚。
func _draw_bowl() -> void:
	var c := bowl_center()
	var pile := mini(_pile, _cfg.bowl_pile_max)
	# 碗裡的魚尾巴(交錯堆疊)
	for i in pile:
		var x := c.x - 6.0 + float((i * 5) % 12)
		var y := c.y - 3.0 - floorf(i / 3.0) * 2.0
		var col := Color("8ab8e0") if i % 4 != 3 else Color("ffd34d")
		_front.draw_rect(Rect2(Vector2(x, y), Vector2(4, 3)), MinigameUi.INK)
		_front.draw_rect(Rect2(Vector2(x + 1, y), Vector2(2, 2)), col)
		_front.draw_rect(Rect2(Vector2(x, y - 2), Vector2(1, 2)), col.darkened(0.2))
		_front.draw_rect(Rect2(Vector2(x + 3, y - 2), Vector2(1, 2)), col.darkened(0.2))
	# 碗:上寬下窄的金色碗,碗口一圈亮邊
	var ink := MinigameUi.INK
	var gold := Color("f0b830")
	_front.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -2), c + Vector2(12, -2), c + Vector2(8, 5), c + Vector2(-8, 5)]), ink)
	_front.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -1), c + Vector2(11, -1), c + Vector2(7, 4), c + Vector2(-7, 4)]), gold)
	_front.draw_rect(Rect2(c + Vector2(-11, -2), Vector2(22, 1)), Color("ffe680"))
	_front.draw_rect(Rect2(c + Vector2(-7, 2), Vector2(14, 1)), Color("c88a20"))
	_front.draw_rect(Rect2(c + Vector2(-5, 0), Vector2(2, 1)), Color(1, 1, 1, 0.8))
	# 狗掌印(碗上的花紋)
	_front.draw_rect(Rect2(c + Vector2(2, 1), Vector2(2, 2)), Color("c88a20"))


func _draw_items() -> void:
	var now := _now()
	for item in items:
		var result := int(item["result"])
		var kind := int(item["kind"])
		var p := item_position(item)
		if p == Vector2.INF:
			continue
		var since := now - float(item["judged_at"]) if result != Hit.NONE else 0.0
		match result:
			Hit.PERFECT, Hit.GOOD:
				continue   # 進了碗(碗裡的魚另外畫)
			Hit.MISS, Hit.DODGED:
				# 繼續落到沙灘上,彈兩下,淡出
				var fall := minf(since * 220.0, _feet_y - 4.0 - catch_y())
				p = Vector2(item_x(item), catch_y() + fall)
				if since > 0.9:
					continue
				if fall >= _feet_y - 4.0 - catch_y():
					p.y -= absf(sin(since * 14.0)) * 3.0 * maxf(0.0, 1.0 - since)
				_draw_item(kind, p, 0.0 if kind == Kind.BOOT else sin(since * 20.0) * 0.6, clampf((0.9 - since) / 0.3, 0.0, 1.0))
			Hit.BOOT:
				# 被碗彈飛、轉著飛出去
				if since > 0.7:
					continue
				var side := -1.0 if item_x(item) > 90.0 else 1.0
				var q := Vector2(item_x(item) + side * since * 90.0, catch_y() - since * 60.0 + since * since * 160.0)
				_draw_item(kind, q, since * 12.0, clampf((0.7 - since) / 0.2, 0.0, 1.0))
			_:
				var launch := float(item["land"]) - float(item["flight"])
				var u := clampf((now - launch) / maxf(float(item["flight"]), 0.05), 0.0, 1.0)
				if kind == Kind.BOOT:
					# 靴子翻著筋斗落下(每次轉 90 度,像素保持方正)
					_draw_item(kind, p, floorf(now * 5.0) * PI * 0.5, 1.0)
					continue
				# 頭朝著左右前進的方向,往上跳時頭朝上、落下時頭朝下(最多斜 50 度,看起來還是一條魚)
				var drop := maxf(catch_y() - _launch_y(item), 1.0)
				var dy := lerpf(-1.0, 1.0, u) * 4.0 * _cfg.arc_height / drop + 1.0
				var dx := (item_x(item) - lerpf(_x_min, _x_max, float(item["launch_u"]))) / drop
				var dir := -1.0 if dx < 0.0 else 1.0
				# 只用三個角度(頭朝上 45 度、平的、頭朝下 45 度):斜線是整齊的像素階梯
				var tilt := snappedf(clampf(atan2(dy, absf(dx)), -PI * 0.25, PI * 0.25), PI * 0.25)
				_draw_item(kind, p, tilt * dir, 1.0, dir)


## 畫一條魚、一條金魚或一隻舊靴子(中心在 at,轉 angle;dir = -1 時左右翻過來,魚頭朝左)。
func _draw_item(kind: int, at: Vector2, angle: float, alpha: float, dir: float = 1.0) -> void:
	var ink := Color(MinigameUi.INK, alpha)
	# 圖是 1 倍的像素座標,畫成 ITEM_SCALE 倍大(和金毛一樣是 2 倍)
	_front.draw_set_transform(at.round(), angle, Vector2(ITEM_SCALE * dir, ITEM_SCALE))
	match kind:
		Kind.BOOT:
			var leather := Color(Color("7a5236"), alpha)
			_front.draw_rect(Rect2(-4, -6, 6, 9), ink)
			_front.draw_rect(Rect2(-4, 1, 10, 4), ink)
			_front.draw_rect(Rect2(-3, -5, 4, 8), leather)
			_front.draw_rect(Rect2(-3, 2, 8, 2), leather)
			_front.draw_rect(Rect2(-3, 4, 9, 1), Color(Color("3a2a20"), alpha))
			_front.draw_rect(Rect2(-2, -4, 2, 1), Color(Color("d8c8a0"), alpha))
			# 掛著的海草
			_front.draw_rect(Rect2(1, -7, 1, 4), Color(Color("3a9a4a"), alpha))
			_front.draw_rect(Rect2(2, -8, 1, 2), Color(Color("3a9a4a"), alpha))
		_:
			var golden := kind == Kind.GOLDEN
			var body := Color(Color("ffd34d") if golden else Color("7ab8e8"), alpha)
			var belly := Color(Color("fff2b0") if golden else Color("d8eef8"), alpha)
			var fin := body.darkened(0.2)
			# 圓圓的身體朝右(+x)、分叉的尾巴在左:先畫墨色的外框,再畫身體
			for r: Rect2 in [Rect2(-3, -4, 7, 8), Rect2(-5, -3, 11, 6), Rect2(-6, -2, 13, 4), Rect2(-1, -5, 3, 1),
					Rect2(-10, -4, 3, 3), Rect2(-10, 1, 3, 3), Rect2(-8, -2, 3, 4)]:
				_front.draw_rect(r, ink)
			for r: Rect2 in [Rect2(-2, -3, 5, 6), Rect2(-4, -2, 9, 4), Rect2(-5, -1, 11, 2)]:
				_front.draw_rect(r, body)
			for r: Rect2 in [Rect2(-9, -3, 2, 2), Rect2(-9, 1, 2, 2), Rect2(-7, -1, 2, 2), Rect2(0, -4, 2, 1)]:
				_front.draw_rect(r, fin)
			_front.draw_rect(Rect2(-3, 1, 7, 1), belly)
			_front.draw_rect(Rect2(-2, 2, 5, 1), belly)
			_front.draw_rect(Rect2(1, -1, 1, 2), fin)
			_front.draw_rect(Rect2(3, -2, 2, 2), ink)
			_front.draw_rect(Rect2(3, -2, 1, 1), Color(1, 1, 1, alpha))
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	if kind == Kind.GOLDEN and alpha > 0.5:
		var tw := 0.5 + 0.5 * sin(_anim_time * 12.0 + at.x)
		_front.draw_rect(Rect2(at.round() + Vector2(8, -11), Vector2(2, 2)), Color(1, 1, 1, tw))
		_front.draw_rect(Rect2(at.round() + Vector2(-12, 7), Vector2(2, 2)), Color(1, 1, 1, 1.0 - tw))


func _draw_popups() -> void:
	var font := _score_label.get_theme_font(&"font")
	for p: Dictionary in _popups:
		var age := float(p["age"])
		var big: bool = p["big"]
		var pop := clampf(age / 0.12, 0.0, 1.0)
		var alpha := clampf((0.8 - age) / 0.25, 0.0, 1.0)
		var text: String = p["text"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S).x
		var at := (p["pos"] as Vector2) + Vector2(-width * 0.5, -age * 16.0)
		var safe := SafeArea.get_safe_rect()
		at.x = clampf(at.x, safe.position.x + 2.0, safe.end.x - width - 2.0)
		var s := (0.6 + 0.4 * pop) * (1.25 if big else 1.0)
		_front.draw_set_transform(at.round() + Vector2(width * 0.5, 0), 0.0, Vector2.ONE * s)
		_front.draw_string_outline(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, 4, Color(MinigameUi.INK, alpha))
		_front.draw_string(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, Color(p["color"] as Color, alpha))
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)


## 倒數時的提示:手指左右拖,一條示範的魚落進碗裡。
func _draw_hint() -> void:
	var cycle := 1.6
	var t := fmod(_anim_time, cycle) / cycle
	var hand_x := roundf((_x_min + _x_max) * 0.5 + sin(t * TAU) * 28.0)
	MinigameUi.draw_hand(_front, Vector2(hand_x + 2.0, _feet_y + 10.0), absf(sin(t * TAU)) < 0.3)
	# 左右箭頭
	var y := _feet_y + 4.0
	for side: float in [-1.0, 1.0]:
		var tip := Vector2((_x_min + _x_max) * 0.5 + side * 44.0, y)
		_front.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-side * 5.0, -4), tip + Vector2(-side * 5.0, 4)]), Color(1, 1, 1, 0.8))
	# 示範的魚:從海裡跳出來,落進碗裡
	var c := bowl_center()
	var from := Vector2(c.x + 30.0, _shore_y - 10.0)
	var p := from.lerp(c + Vector2(0, -2), t)
	p.y -= 4.0 * 24.0 * t * (1.0 - t)
	if t < 0.92:
		var tilt := snappedf(clampf(atan2(lerpf(-1.0, 1.0, t) * 3.0 + 1.0, 0.3), -PI * 0.25, PI * 0.25), PI * 0.25)
		_draw_item(Kind.FISH, p, -tilt, 0.85, -1.0)

