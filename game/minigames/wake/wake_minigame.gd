class_name WakeMinigame
extends MinigameBase
## 小遊戲「叫醒騎士」(v2.6 DV3):第二、三章的營地和「拉扯王室卷軸」輪流出現。
##
## 圓桌旁坐著三位中了午睡咒、一直打瞌睡的騎士(頭上冒 Zzz、鼻子吹泡泡)。
## 跟著節拍,有圈圈從大縮小、縮到某位騎士頭上的那一刻,點他那一欄(騎士本人或下面的按鈕墊都可以),
## 騎士就會跳起來醒一下:「完美!」或「好!」。太早點或沒點到,他就繼續呼嚕。
## 速度越來越快,後半段偶爾有半拍。
##
## 分數:點數 ÷ 這一局最多能拿的點數 × 100(0 至 100 分);評價與獎勵和其他小遊戲一樣(MinigameGrading)。
## 只用觸控(點一下);直向 180×320 起,依 SafeArea 排版,按鈕墊避開底部的系統手勢區。
## 全部用程式畫,不需要圖檔。測試可以用 tap_lane() 模擬點擊、用 step() 推進時間。

enum Hit { NONE, PERFECT, GOOD, MISS }

## 譜面:{"time": 開始後幾秒, "lane": 第幾欄, "result": Hit}
var notes: Array[Dictionary] = []
## 每一拍的時間(開始後幾秒)。
var beats: PackedFloat32Array = []
var points: int = 0
var max_points: int = 1
var perfects: int = 0
var goods: int = 0
var misses: int = 0
## 沒有音符時亂點的次數(會打斷連擊)。
var stray_taps: int = 0
var combo: int = 0
var best_combo: int = 0

var _cfg: WakeMinigameConfig
var _rng := RandomNumberGenerator.new()
var _fx_layer: Node2D
var _score_label: Label
var _combo_label: Label
var _hint_label: Label
var _anim_time: float = 0.0
var _next_beat: int = 0
var _beat_pulse: float = 0.0
## 每位騎士:{"awake": 剩下清醒的秒數, "snore": 打呼的彈跳, "pad": 按鈕墊被按的亮光, "cheer": bool}
var _knights: Array[Dictionary] = []
## 頭上跳出的字:{"text", "lane", "age", "color", "big"}
var _popups: Array[Dictionary] = []
var _score_bump: float = 0.0
var _ending_cheer: bool = false
# 版面(畫面邏輯像素)
var _lane_x: PackedFloat32Array = []
var _head_y: float = 160.0
var _table_y: float = 170.0
var _pad_y: float = 260.0
var _zone: Rect2 = Rect2()


func _on_build() -> void:
	_cfg = config as WakeMinigameConfig
	if _cfg == null:
		_cfg = WakeMinigameConfig.new()
		_cfg.grading = config.grading
		config = _cfg
	if _cfg.minigame_id == &"":
		_cfg.minigame_id = &"wake"
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
	_hint_label = MinigameUi.make_label(tr("MINIGAME_WAKE_HINT"), MinigameUi.FONT_S)
	_hint_label.name = "Hint"
	add_child(_hint_label)


func _on_layout() -> void:
	var safe := SafeArea.get_safe_rect()
	var lanes := maxi(_cfg.lane_count, 1)
	_lane_x.resize(lanes)
	for i in lanes:
		_lane_x[i] = roundf(safe.position.x + safe.size.x * (i + 0.5) / lanes)
	_pad_y = roundf(safe.end.y - _cfg.pad_bottom_margin - _cfg.pad_height)
	# 圓桌在畫面中間偏下;騎士的頭靠在桌面上
	_table_y = roundf(lerpf(safe.position.y + 60.0, _pad_y, 0.55))
	# 頭的下緣(頭的中心下面 6 格 × knight_scale)剛好靠在桌面上
	_head_y = _table_y - 6.0 - 6.0 * maxf(_cfg.knight_scale, 1.0)
	_zone = Rect2(safe.position.x, safe.position.y + 24.0, safe.size.x, _pad_y + _cfg.pad_height - safe.position.y - 24.0)
	_score_label.size = Vector2(70, 12)
	_score_label.position = Vector2(safe.end.x - 74.0, safe.position.y + 14.0)
	_combo_label.size = Vector2(80, 12)
	_combo_label.position = Vector2(safe.position.x + 4.0, safe.position.y + 14.0)
	_hint_label.size = Vector2(safe.size.x - 8.0, 14.0)
	_hint_label.position = Vector2(safe.position.x + 4.0, _pad_y - 20.0)


func _on_reset() -> void:
	_rng.seed = _cfg.rng_seed if _cfg.rng_seed != 0 else int(Time.get_ticks_usec())
	var chart := build_chart(_cfg, _rng)
	beats = chart["beats"]
	notes.assign(chart["notes"])
	max_points = max_points_for(notes.size(), _cfg)
	points = 0
	perfects = 0
	goods = 0
	misses = 0
	stray_taps = 0
	combo = 0
	best_combo = 0
	_next_beat = 0
	_beat_pulse = 0.0
	_popups.clear()
	_ending_cheer = false
	_knights.clear()
	for i in maxi(_cfg.lane_count, 1):
		_knights.append({"awake": 0.0, "snore": 0.0, "pad": 0.0, "cheer": false})
	_update_labels()


## 產生譜面:{"beats": PackedFloat32Array, "notes": Array[Dictionary]}。同一個種子產生同一份譜面。
static func build_chart(cfg: WakeMinigameConfig, rng: RandomNumberGenerator) -> Dictionary:
	var beat_times := PackedFloat32Array()
	var t := cfg.first_beat_sec
	var last := cfg.duration_sec - cfg.last_note_margin_sec
	while t <= last:
		beat_times.append(t)
		var bpm := lerpf(cfg.bpm_start, cfg.bpm_end, clampf(t / maxf(cfg.duration_sec, 0.01), 0.0, 1.0))
		t += 60.0 / maxf(bpm, 20.0)
	var lanes := maxi(cfg.lane_count, 1)
	var result: Array[Dictionary] = []
	var last_lane := -1
	var same_run := 0
	var rested := false
	for i in beat_times.size():
		var beat := beat_times[i]
		if i > 0 and not rested and rng.randf() < cfg.rest_chance:
			rested = true
			continue
		rested = false
		var lane := rng.randi_range(0, lanes - 1)
		if lanes > 1:
			var want_same := last_lane >= 0 and same_run < 1 and rng.randf() < cfg.same_lane_chance
			if want_same:
				lane = last_lane
			else:
				while lane == last_lane:
					lane = rng.randi_range(0, lanes - 1)
		same_run = same_run + 1 if lane == last_lane else 0
		last_lane = lane
		result.append({"time": beat, "lane": lane, "result": Hit.NONE})
		# 後半段偶爾多一個半拍(叫另一位騎士)
		if i + 1 < beat_times.size() and beat / maxf(cfg.duration_sec, 0.01) >= cfg.offbeat_from_ratio \
				and rng.randf() < cfg.offbeat_chance:
			var half := (beat + beat_times[i + 1]) * 0.5
			var other := (lane + rng.randi_range(1, maxi(lanes - 1, 1))) % lanes
			result.append({"time": half, "lane": other, "result": Hit.NONE})
			last_lane = other
			same_run = 0
	return {"beats": beat_times, "notes": result}


## 全部「完美!」而且一直連擊時的點數。
static func max_points_for(note_count: int, cfg: WakeMinigameConfig) -> int:
	var bonus := (note_count / cfg.combo_step) * cfg.combo_bonus if cfg.combo_step > 0 else 0
	return maxi(1, note_count * cfg.perfect_points + bonus)


## 點了第 lane 欄(騎士或按鈕墊)。傳回判定;沒有音符可以判定時傳回 Hit.NONE(算亂點,打斷連擊)。
## 只在遊戲中有效。測試與截圖腳本也用這個方法。
func tap_lane(lane: int) -> Hit:
	if state != State.PLAYING or lane < 0 or lane >= _knights.size():
		return Hit.NONE
	_knights[lane]["pad"] = 1.0
	var now := play_elapsed
	var target := -1
	for i in notes.size():
		var n := notes[i]
		if int(n["result"]) != Hit.NONE or int(n["lane"]) != lane:
			continue
		var dt := now - float(n["time"])
		if dt > _cfg.good_window_sec:
			continue
		if -dt <= _cfg.early_miss_window_sec:
			target = i
		break
	if target < 0:
		stray_taps += 1
		combo = 0
		_knights[lane]["snore"] = 0.4
		_update_labels()
		return Hit.NONE
	var note := notes[target]
	var off := absf(now - float(note["time"]))
	var hit := Hit.PERFECT if off <= _cfg.perfect_window_sec else (Hit.GOOD if off <= _cfg.good_window_sec else Hit.MISS)
	_judge(target, hit)
	return hit


## 第 lane 欄的音符中,還沒判定、最早的那一個的時間;沒有時傳回 -1。
func next_note_time(lane: int) -> float:
	for n: Dictionary in notes:
		if int(n["lane"]) == lane and int(n["result"]) == Hit.NONE:
			return float(n["time"])
	return -1.0


## 畫面上的 x 是第幾欄。
func lane_at(x: float) -> int:
	var safe := SafeArea.get_safe_rect()
	var lanes := maxi(_cfg.lane_count, 1)
	return clampi(int((x - safe.position.x) / maxf(safe.size.x / lanes, 1.0)), 0, lanes - 1)


## 第 lane 欄的按鈕墊(畫面邏輯像素)。
func pad_rect(lane: int) -> Rect2:
	var safe := SafeArea.get_safe_rect()
	var w := safe.size.x / maxi(_cfg.lane_count, 1)
	return Rect2(roundf(safe.position.x + w * lane + 3.0), _pad_y, roundf(w - 6.0), _cfg.pad_height)


## 可以點的範圍(整個遊戲區,扣掉上面的計時條)。
func touch_zone() -> Rect2:
	return _zone


## 第 lane 位騎士頭的中心(畫面邏輯像素)。
func knight_head(lane: int) -> Vector2:
	return Vector2(_lane_x[lane], _head_y)


func is_knight_awake(lane: int) -> bool:
	return lane >= 0 and lane < _knights.size() and (float(_knights[lane]["awake"]) > 0.0 or bool(_knights[lane]["cheer"]))


func _judge(index: int, hit: Hit) -> void:
	var note := notes[index]
	note["result"] = hit
	var lane := int(note["lane"])
	var head := knight_head(lane)
	if hit == Hit.MISS:
		misses += 1
		combo = 0
		_knights[lane]["snore"] = 0.6
		_popups.append({"text": tr("MINIGAME_WAKE_SNORE"), "lane": lane, "age": 0.0, "color": Color("b8c4e8"), "big": false})
		_update_labels()
		return
	combo += 1
	best_combo = maxi(best_combo, combo)
	if hit == Hit.PERFECT:
		perfects += 1
		points += _cfg.perfect_points
		Sfx.play(_cfg.perfect_sfx)
		_popups.append({"text": tr("MINIGAME_PERFECT"), "lane": lane, "age": 0.0, "color": Color("ffe066"), "big": true})
	else:
		goods += 1
		points += _cfg.good_points
		Sfx.play(_cfg.good_sfx)
		_popups.append({"text": tr("MINIGAME_GOOD"), "lane": lane, "age": 0.0, "color": Color("bfe36d"), "big": false})
	if _cfg.combo_step > 0 and combo % _cfg.combo_step == 0:
		points += _cfg.combo_bonus
	_knights[lane]["awake"] = _cfg.wake_sec
	_score_bump = 0.3
	Haptics.play(&"light")
	_spawn_fx(_cfg.wake_fx, head + Vector2(0, -10))
	_update_labels()


func _compute_score() -> int:
	return clampi(roundi(100.0 * points / maxf(max_points, 1)), 0, 100)


func _format_score(value: int) -> String:
	return tr("MINIGAME_WAKE_SCORE") % value


func _go_text() -> String:
	return tr("MINIGAME_WAKE_GO")


func _result_extra_lines() -> PackedStringArray:
	return PackedStringArray([tr("MINIGAME_WAKE_RESULT") % [perfects, best_combo]])


func _results_top_min() -> float:
	return SafeArea.get_safe_rect().position.y + 24.0


func _countdown_center() -> Vector2:
	var safe := SafeArea.get_safe_rect()
	return Vector2(safe.get_center().x, roundf(lerpf(safe.position.y + 30.0, _head_y - 20.0, 0.5)))


func _on_play_input(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or not _zone.has_point(touch.position):
		return false
	tap_lane(lane_at(touch.position.x))
	return true


func _on_countdown_process(delta: float) -> void:
	_tick(delta)


func _on_play_process(delta: float) -> void:
	# 節拍:每一拍閃一下、輕輕「嗒」一聲
	while _next_beat < beats.size() and play_elapsed >= beats[_next_beat]:
		_next_beat += 1
		_beat_pulse = 1.0
		if _cfg.beat_sfx != &"":
			Sfx.play(_cfg.beat_sfx, _cfg.beat_volume_db)
	# 圈圈過了還沒點:沒叫醒
	for i in notes.size():
		var n := notes[i]
		if int(n["result"]) == Hit.NONE and play_elapsed - float(n["time"]) > _cfg.good_window_sec:
			_judge(i, Hit.MISS)
	_tick(delta)


func _on_ending_process(delta: float) -> void:
	_tick(delta)


func _on_results_process(delta: float) -> void:
	_tick(delta)


func _on_play_ended(_final_score: int, final_grade: int) -> void:
	# 評價 2 以上:大家都醒來歡呼「汪!」;不然大家又睡著了。
	_ending_cheer = final_grade >= 2
	for i in _knights.size():
		_knights[i]["cheer"] = _ending_cheer
		_knights[i]["awake"] = 0.0
		if _ending_cheer:
			_popups.append({"text": tr("MINIGAME_WAKE_CHEER"), "lane": i, "age": -0.12 * i, "color": MinigameUi.WHITE, "big": false})
			_spawn_fx(_cfg.wake_fx, knight_head(i) + Vector2(0, -10))
	if _ending_cheer:
		Sfx.play(_cfg.cheer_sfx)


func _tick(delta: float) -> void:
	_anim_time += delta
	_beat_pulse = maxf(0.0, _beat_pulse - delta * 4.0)
	_score_bump = maxf(0.0, _score_bump - delta)
	for k: Dictionary in _knights:
		k["awake"] = maxf(0.0, float(k["awake"]) - delta)
		k["snore"] = maxf(0.0, float(k["snore"]) - delta)
		k["pad"] = maxf(0.0, float(k["pad"]) - delta * 5.0)
	for p: Dictionary in _popups:
		p["age"] = float(p["age"]) + delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 0.8)
	_hint_label.visible = state == State.COUNTDOWN or (state == State.PLAYING and play_elapsed < _cfg.hint_play_sec)
	_update_labels()


func _update_labels() -> void:
	if _score_label == null:
		return
	_score_label.text = tr("MINIGAME_WAKE_SCORE") % _compute_score()
	_score_label.pivot_offset = Vector2(_score_label.size.x, _score_label.size.y * 0.5)
	var bump := _score_bump / 0.3
	_score_label.scale = Vector2.ONE * (1.0 + 0.4 * bump * bump)
	_score_label.visible = state != State.RESULTS
	_combo_label.text = tr("MINIGAME_WAKE_COMBO") % combo
	_combo_label.visible = combo >= 2 and state == State.PLAYING


func _spawn_fx(scene: PackedScene, at: Vector2) -> void:
	if scene == null or _fx_layer == null:
		return
	var fx := scene.instantiate()
	if fx is Node2D:
		(fx as Node2D).position = at.round()
	_fx_layer.add_child(fx)


# --- 繪圖 ---

func _draw() -> void:
	if _cfg == null or _knights.is_empty():
		return
	var screen := SafeArea.get_screen_size()
	_draw_hall(screen)
	for i in _knights.size():
		_draw_knight(i)
	_draw_table(screen)
	_draw_rings()
	_draw_pads()
	_draw_popups()
	if state == State.COUNTDOWN:
		_draw_hint()


## 城堡大廳:石牆、拱窗(月亮)、兩面圓桌旗、燭台。
func _draw_hall(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), _cfg.wall_color)
	var dark := _cfg.wall_dark_color
	# 石塊
	var y := 0.0
	var row := 0
	while y < _table_y:
		draw_rect(Rect2(0, y, screen.x, 1), dark)
		var bx := 7.0 if row % 2 == 0 else 0.0
		while bx < screen.x:
			draw_rect(Rect2(bx, y + 1, 1, 8), dark)
			bx += 14.0
		y += 9.0
		row += 1
	# 拱窗與月亮
	var cx := roundf(screen.x * 0.5)
	var win := Rect2(cx - 18, maxf(_head_y - 108.0, SafeArea.get_safe_rect().position.y + 44.0), 36, 44)
	draw_rect(win.grow(2), dark)
	draw_circle(Vector2(cx, win.position.y), 20.0, dark)
	draw_rect(win, _cfg.window_color)
	draw_circle(Vector2(cx, win.position.y), 18.0, _cfg.window_color)
	draw_circle(Vector2(cx + 7, win.position.y + 4), 6.0, Color("fff3c4"))
	draw_circle(Vector2(cx + 10, win.position.y + 2), 5.0, _cfg.window_color)
	for s in 5:
		var star := Vector2(cx - 12 + s * 6, win.position.y + 10 + (s % 2) * 9)
		var tw := 0.4 + 0.6 * absf(sin(_anim_time * 1.7 + s))
		draw_rect(Rect2(star, Vector2.ONE), Color(1, 1, 0.85, tw))
	draw_rect(Rect2(cx - 1, win.position.y - 18, 2, 62), dark)
	draw_rect(Rect2(cx - 18, win.position.y + 18, 36, 2), dark)
	# 圓桌旗(左右各一面)
	for side: float in [-1.0, 1.0]:
		var bx2 := roundf(cx + side * screen.x * 0.33)
		var top := maxf(_head_y - 104.0, SafeArea.get_safe_rect().position.y + 40.0)
		draw_rect(Rect2(bx2 - 8, top - 2, 16, 2), Color("8a6a3a"))
		draw_rect(Rect2(bx2 - 7, top, 14, 30), Color("3d5aa8"))
		draw_colored_polygon(PackedVector2Array([Vector2(bx2 - 7, top + 30), Vector2(bx2, top + 36), Vector2(bx2 + 7, top + 30)]), Color("3d5aa8"))
		draw_arc(Vector2(bx2, top + 14), 4.0, 0, TAU, 14, Color("ffe066"), 1.0)
	# 地板
	draw_rect(Rect2(0, _table_y, screen.x, screen.y - _table_y), _cfg.floor_color)
	draw_rect(Rect2(0, _table_y, screen.x, 1), _cfg.floor_color.lightened(0.15))


func _draw_table(screen: Vector2) -> void:
	var c := Vector2(roundf(screen.x * 0.5), _table_y + 2.0)
	var half := roundf(SafeArea.get_safe_rect().size.x * 0.5) + 8.0
	draw_rect(Rect2(c.x - half, c.y - 4, half * 2.0, 12), _cfg.table_edge_color)
	draw_rect(Rect2(c.x - half, c.y - 6, half * 2.0, 8), _cfg.table_color)
	draw_rect(Rect2(c.x - half, c.y - 6, half * 2.0, 1), _cfg.table_color.lightened(0.2))
	for i in 4:
		draw_rect(Rect2(c.x - half + 12 + i * 44, c.y - 3, 14, 1), _cfg.table_color.darkened(0.15))
	# 桌腳
	for x: float in [c.x - half + 10.0, c.x + half - 14.0]:
		draw_rect(Rect2(x, c.y + 8, 4, 16), _cfg.table_edge_color)
	# 騎士之間的蠟燭:每一拍火焰跳一下(節拍提示)
	for i in range(1, _lane_x.size()):
		var candle := Vector2(roundf((_lane_x[i - 1] + _lane_x[i]) * 0.5), c.y - 6)
		draw_rect(Rect2(candle + Vector2(-2, -8), Vector2(4, 8)), Color("fff1c9"))
		var h := 4.0 + roundf(_beat_pulse * 5.0)
		draw_colored_polygon(PackedVector2Array([candle + Vector2(-2, -8), candle + Vector2(0, -8 - h), candle + Vector2(2, -8)]), Color("ff9a2e"))
		draw_rect(Rect2(candle + Vector2(0, -10), Vector2(1, 2)), Color("ffe36a"))
		if _beat_pulse > 0.0:
			draw_circle(candle + Vector2(0, -12), 3.0 + 6.0 * _beat_pulse, Color(1, 0.8, 0.4, 0.2 * _beat_pulse))


## 一位騎士:盔甲肩膀、狗頭(毛色各不同)、頭盔與羽飾。睡著時頭低低、閉眼、鼻子吹泡泡、冒 Zzz;
## 醒著時跳起來、眼睛圓圓、耳朵豎起。
func _draw_knight(lane: int) -> void:
	var k := _knights[lane]
	var awake := float(k["awake"]) > 0.0 or bool(k["cheer"])
	var fur: Color = _cfg.fur_colors[lane % _cfg.fur_colors.size()] if not _cfg.fur_colors.is_empty() else Color("e0a050")
	var plume: Color = _cfg.plume_colors[lane % _cfg.plume_colors.size()] if not _cfg.plume_colors.is_empty() else Color("e8434f")
	var ink := MinigameUi.INK
	var base := knight_head(lane)
	var s := maxf(_cfg.knight_scale, 1.0)
	var lift := 0.0
	if awake:
		var t := 1.0 - float(k["awake"]) / maxf(_cfg.wake_sec, 0.01) if not bool(k["cheer"]) else fmod(_anim_time * 2.0 + lane * 0.3, 1.0)
		lift = -roundf(sin(clampf(t, 0.0, 1.0) * PI) * 4.0) - 2.0
	else:
		# 打瞌睡:頭慢慢點一下;打呼(沒叫醒)時抖一下
		lift = (1.0 if sin(_anim_time * 1.6 + lane * 1.1) > 0.0 else 0.0) + 1.0
		if float(k["snore"]) > 0.0:
			lift += 1.0 if sin(float(k["snore"]) * 30.0) > 0.0 else 0.0
	# 以頭的中心為原點、放大 knight_scale 倍來畫(像素保持方正)
	draw_set_transform(base, 0.0, Vector2(s, s))
	var c := Vector2(0, lift)
	# 盔甲肩膀(被桌子蓋住下半)
	draw_rect(Rect2(-11, 5, 22, 10), ink)
	draw_rect(Rect2(-10, 6, 20, 9), _cfg.armor_color)
	draw_rect(Rect2(-10, 6, 20, 1), _cfg.armor_color.lightened(0.25))
	draw_rect(Rect2(-1, 8, 3, 3), plume)
	# 耳朵:睡著時垂下,醒來豎起
	for side: float in [-1.0, 1.0]:
		var ear := c + Vector2(-11.0 if side < 0 else 8.0, 0)
		if awake:
			draw_rect(Rect2(ear + Vector2(0, -11), Vector2(3, 7)), ink)
			draw_rect(Rect2(ear + Vector2(1 if side < 0 else 0, -10), Vector2(2, 5)), fur.darkened(0.2))
		else:
			draw_rect(Rect2(ear + Vector2(0, -5), Vector2(3, 9)), ink)
			draw_rect(Rect2(ear + Vector2(1 if side < 0 else 0, -4), Vector2(2, 7)), fur.darkened(0.2))
	# 頭
	# 圓角:四個角各缺一格
	draw_rect(Rect2(c + Vector2(-8, -7), Vector2(16, 13)), ink)
	draw_rect(Rect2(c + Vector2(-9, -6), Vector2(18, 11)), ink)
	draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 11)), fur)
	draw_rect(Rect2(c + Vector2(-8, -5), Vector2(16, 9)), fur)
	draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 1)), fur.lightened(0.15))
	# 頭盔:頭頂的半圓與羽飾
	draw_rect(Rect2(c + Vector2(-9, -10), Vector2(18, 5)), ink)
	draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 3)), _cfg.armor_color)
	draw_rect(Rect2(c + Vector2(-5, -12), Vector2(10, 3)), ink)
	draw_rect(Rect2(c + Vector2(-4, -11), Vector2(8, 2)), _cfg.armor_color.lightened(0.2))
	var sway := 1.0 if sin(_anim_time * (5.0 if awake else 2.0) + lane) > 0.0 else 0.0
	draw_rect(Rect2(c + Vector2(-1, -17), Vector2(3, 6)), plume)
	draw_rect(Rect2(c + Vector2(sway, -19), Vector2(2, 3)), plume.lightened(0.2))
	# 口鼻
	draw_rect(Rect2(c + Vector2(-3, 1), Vector2(6, 4)), fur.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-1, 1), Vector2(2, 1)), ink)
	# 眼睛與腮紅
	if awake:
		for side: float in [-1.0, 1.0]:
			var e := c + Vector2(-5.0 if side < 0 else 3.0, -4)
			draw_rect(Rect2(e, Vector2(2, 2)), ink)
			draw_rect(Rect2(e, Vector2(1, 1)), MinigameUi.WHITE)
		draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 1)), Color("e85a6a"))   # 開心張嘴
	else:
		for side: float in [-1.0, 1.0]:
			var e := c + Vector2(-5.0 if side < 0 else 3.0, -2)
			draw_rect(Rect2(e, Vector2(2, 1)), ink)
	draw_rect(Rect2(c + Vector2(-7, 0), Vector2(2, 1)), Color(1, 0.55, 0.6, 0.8))
	draw_rect(Rect2(c + Vector2(5, 0), Vector2(2, 1)), Color(1, 0.55, 0.6, 0.8))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if awake:
		return
	# 鼻子吹的泡泡(慢慢變大變小)與 Zzz(用畫面座標畫,不跟著放大)
	var nose := base + Vector2(1, lift + 2) * s
	var bubble := roundf(2.0 + 3.0 * (0.5 + 0.5 * sin(_anim_time * 2.0 + lane * 1.7)))
	var bpos := nose + Vector2(3 + bubble, 0)
	draw_circle(bpos, bubble, Color(0.75, 0.9, 1.0, 0.45))
	draw_arc(bpos, bubble, 0, TAU, 12, Color(0.9, 0.97, 1.0, 0.9), 1.0)
	draw_rect(Rect2(bpos + Vector2(-bubble * 0.4, -bubble * 0.5), Vector2(1, 1)).abs(), MinigameUi.WHITE)
	var font := _score_label.get_theme_font(&"font")
	for z in 2:
		var phase := fmod(_anim_time * 0.6 + z * 0.5 + lane * 0.21, 1.0)
		var zp := base + Vector2(8 * s + z * 4 + phase * 4.0, -8 * s - phase * 12.0)
		draw_string_outline(font, zp.round(), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, 2, Color(MinigameUi.INK, 0.6 * (1.0 - phase)))
		draw_string(font, zp.round(), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, Color(1, 1, 1, 0.85 * (1.0 - phase)))


## 圈圈:音符前 approach_beats 拍出現,縮到騎士頭上時就是點的時候。
func _draw_rings() -> void:
	if state != State.PLAYING and state != State.COUNTDOWN and state != State.PAUSED:
		return
	var now := play_elapsed if state != State.COUNTDOWN else -countdown_left
	for n: Dictionary in notes:
		if int(n["result"]) != Hit.NONE:
			continue
		var time := float(n["time"])
		var lead := _approach_sec(time)
		var p := 1.0 - (time - now) / lead
		if p < 0.0:
			continue
		if p > 1.0 + _cfg.good_window_sec / lead:
			continue
		var lane := int(n["lane"])
		var plume: Color = _cfg.plume_colors[lane % _cfg.plume_colors.size()] if not _cfg.plume_colors.is_empty() else Color.WHITE
		var center := knight_head(lane) + Vector2(0, -3)
		var target := _cfg.ring_end_radius
		var r := lerpf(_cfg.ring_start_radius, target, clampf(p, 0.0, 1.0))
		var alpha := clampf(p * 2.5, 0.0, 1.0)
		# 終點的淡圈(看得到圈圈要縮到哪裡)
		draw_arc(center, target, 0, TAU, 24, Color(1, 1, 1, 0.25 * alpha), 1.0)
		draw_arc(center, r + 1.0, 0, TAU, 28, Color(MinigameUi.INK, 0.6 * alpha), 1.0)
		draw_arc(center, r, 0, TAU, 28, Color(plume.lightened(0.35), alpha), 2.0)
		if p >= 0.9:
			# 快到了:閃白光,騎士頭上冒「!」
			var flash := clampf((p - 0.9) / 0.1, 0.0, 1.0)
			draw_arc(center, target, 0, TAU, 24, Color(1, 1, 1, 0.6 * flash), 2.0)


func _approach_sec(note_time: float) -> float:
	var bpm := lerpf(_cfg.bpm_start, _cfg.bpm_end, clampf(note_time / maxf(_cfg.duration_sec, 0.01), 0.0, 1.0))
	return maxf(_cfg.approach_beats * 60.0 / maxf(bpm, 20.0), 0.2)


## 下面的三個按鈕墊(手指好按的地方;整欄都可以點)。
func _draw_pads() -> void:
	for i in _knights.size():
		var rect := pad_rect(i)
		var plume: Color = _cfg.plume_colors[i % _cfg.plume_colors.size()] if not _cfg.plume_colors.is_empty() else Color.WHITE
		var lit := float(_knights[i]["pad"])
		var press := roundf(lit * 2.0)
		var r := Rect2(rect.position + Vector2(0, press), rect.size - Vector2(0, press))
		draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size), Color(0, 0, 0, 0.35))
		draw_rect(r.grow(1), MinigameUi.INK)
		draw_rect(r, plume.darkened(0.35).lerp(plume, 0.3 + 0.7 * lit + 0.25 * _beat_pulse))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), plume.lightened(0.3))
		# 墊子上畫一個小鬧鐘(叫醒!)
		var c := r.get_center().round()
		draw_circle(c, 6.0, MinigameUi.INK)
		draw_circle(c, 5.0, MinigameUi.WHITE)
		draw_rect(Rect2(c + Vector2(0, -3), Vector2(1, 4)), MinigameUi.INK)
		draw_rect(Rect2(c + Vector2(0, 0), Vector2(3, 1)), MinigameUi.INK)
		draw_rect(Rect2(c + Vector2(-6, -7), Vector2(3, 2)), MinigameUi.INK)
		draw_rect(Rect2(c + Vector2(4, -7), Vector2(3, 2)), MinigameUi.INK)


func _draw_popups() -> void:
	var font := _score_label.get_theme_font(&"font")
	for p: Dictionary in _popups:
		var age := float(p["age"])
		if age < 0.0:
			continue
		var big: bool = p["big"]
		var font_size := MinigameUi.FONT_S
		var pop := clampf(age / 0.12, 0.0, 1.0)
		var alpha := clampf((0.8 - age) / 0.25, 0.0, 1.0)
		var text: String = p["text"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var head := knight_head(int(p["lane"]))
		var at := Vector2(head.x - width * 0.5, head.y - 30.0 - age * 16.0)
		var safe := SafeArea.get_safe_rect()
		at.x = clampf(at.x, safe.position.x + 2.0, safe.end.x - width - 2.0)
		var s := (0.6 + 0.4 * pop) * (1.25 if big else 1.0)
		draw_set_transform(at.round() + Vector2(width * 0.5, 0), 0.0, Vector2.ONE * s)
		draw_string_outline(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(MinigameUi.INK, alpha))
		draw_string(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(p["color"] as Color, alpha))
		draw_set_transform_matrix(Transform2D.IDENTITY)


## 倒數時的提示:示範圈圈縮到中間的騎士頭上,手指點中間的按鈕墊。
func _draw_hint() -> void:
	var lane := mini(1, _knights.size() - 1)
	var cycle := 1.2
	var t := fmod(_anim_time, cycle) / cycle
	var center := knight_head(lane) + Vector2(0, -3)
	var r := lerpf(_cfg.ring_start_radius, _cfg.ring_end_radius, minf(t / 0.75, 1.0))
	if t < 0.85:
		draw_arc(center, _cfg.ring_end_radius, 0, TAU, 24, Color(1, 1, 1, 0.3), 1.0)
		draw_arc(center, r, 0, TAU, 28, Color(1, 1, 0.7, 0.9), 2.0)
	var pad := pad_rect(lane)
	var pressed := t >= 0.75 and t < 0.9
	MinigameUi.draw_hand(self, pad.get_center() + Vector2(2, 4 if pressed else -2), pressed)
