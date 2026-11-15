class_name ScrollMinigame
extends MinigameBase
## 小遊戲「拉扯王室卷軸」(DEV_PLAN 11 D2)。
##
## 金毛咬住卷軸,玩家在下半部向下滑動把卷軸拉出來;拉得越長分數越高。
## 卷軸上的墨水漬會跟著紙往下走;墨水漬到達金毛咬住的地方時要停手一下,
## 金毛換個地方咬,墨水漬就會滑過去。停手時還在滑,金毛的臉會沾到墨水,並扣時間。
## 時間到,金毛被卷軸纏住(可愛的結束動畫),然後顯示評價。
##
## 不需要文字:倒數時有手勢動畫與向下的箭頭;墨水漬靠近時金毛頭上出現「!」,
## 到達時出現紅色的「停」手掌。

enum Ink { NONE, STOP, PASSING }

const GOLDIE_FRAMES_PATH: String = "res://assets/sprites/goldie/goldie_frames.tres"

var pulled_px: float = 0.0
var ink_state: Ink = Ink.NONE
var blots: Array[float] = []
var next_blot: int = 0
var blots_passed: int = 0
var mistakes: int = 0
var swipe_count: int = 0

var _cfg: ScrollMinigameConfig
var _rng := RandomNumberGenerator.new()
var _goldie: AnimatedSprite2D
var _front: Control
var _score_label: Label
var _touch_index: int = -1
var _swipe_distance: float = 0.0
var _still_time: float = 0.0
var _stop_drag: float = 0.0
## 每次手指按下算一個新手勢。墨水漬到達時正在進行的手勢,以及已經被罰過的手勢,不會再被罰。
var _gesture: int = 0
var _exempt_gesture: int = -1
var _pass_from: float = 0.0
var _pass_to: float = 0.0
var _pass_t: float = 0.0
var _idle_time: float = 0.0
var _pull_speed: float = 0.0
var _pulled_this_frame: float = 0.0
var _sfx_accum: float = 0.0
var _ink_face_time: float = 0.0
var _hop_time: float = 0.0
var _floaters: Array[Dictionary] = []
var _anim_time: float = 0.0

# 版面(畫面的邏輯像素),由 _on_layout 計算。
var _roll_y: float = 30.0
var _bite_y: float = 88.0
var _paper_rect: Rect2 = Rect2()
var _swipe_zone: Rect2 = Rect2()
var _goldie_pos: Vector2 = Vector2.ZERO


func _on_build() -> void:
	_cfg = config as ScrollMinigameConfig
	if _cfg == null:
		_cfg = ScrollMinigameConfig.new()
		_cfg.grading = config.grading
		config = _cfg
	if _cfg.minigame_id == &"":
		_cfg.minigame_id = &"scroll"
	if _cfg.goldie_frames == null and ResourceLoader.exists(GOLDIE_FRAMES_PATH):
		_cfg.goldie_frames = load(GOLDIE_FRAMES_PATH) as SpriteFrames

	_goldie = AnimatedSprite2D.new()
	_goldie.name = "Goldie"
	_goldie.sprite_frames = _cfg.goldie_frames
	_goldie.scale = Vector2.ONE * _cfg.goldie_scale
	_play_goldie(_cfg.goldie_animation)
	add_child(_goldie)

	_front = Control.new()
	_front.name = "Front"
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)

	_score_label = MinigameUi.make_label("", 10)
	_score_label.name = "Score"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_label)


func _on_layout() -> void:
	var safe := SafeArea.get_safe_rect()
	var cx := roundf(safe.get_center().x)
	_roll_y = roundf(safe.position.y + 30.0)
	_bite_y = _roll_y + 58.0
	var paper_x := cx - roundf(_cfg.paper_width * 0.5) + 12.0
	var screen := SafeArea.get_screen_size()
	_paper_rect = Rect2(paper_x, _roll_y, _cfg.paper_width, screen.y - _roll_y + 4.0)
	var zone_top := _bite_y + 14.0
	var zone_bottom := safe.end.y - _cfg.swipe_zone_bottom_margin
	_swipe_zone = Rect2(safe.position.x + 4.0, zone_top, safe.size.x - 8.0, maxf(40.0, zone_bottom - zone_top))
	_goldie_pos = Vector2(paper_x - 12.0 * _cfg.goldie_scale * 0.5 - 4.0, _bite_y + 2.0)
	_goldie.position = _goldie_pos
	_score_label.size = Vector2(70, 12)
	_score_label.position = Vector2(safe.end.x - 74.0, safe.position.y + 14.0)


func _on_reset() -> void:
	pulled_px = 0.0
	ink_state = Ink.NONE
	next_blot = 0
	blots_passed = 0
	mistakes = 0
	swipe_count = 0
	_touch_index = -1
	_swipe_distance = 0.0
	_idle_time = 0.0
	_ink_face_time = 0.0
	_hop_time = 0.0
	_floaters.clear()
	_goldie.rotation = 0.0
	_play_goldie(_cfg.goldie_animation)
	if _cfg.rng_seed != 0:
		_rng.seed = _cfg.rng_seed
	else:
		_rng.randomize()
	blots.clear()
	var at := _cfg.ink_first_at
	# 15 秒內不可能拉到這麼長,預先放足夠的墨水漬。
	while at < 40000.0 and blots.size() < 200:
		blots.append(at)
		at += _rng.randf_range(_cfg.ink_gap_min, _cfg.ink_gap_max)
	_update_score_label()


func _on_play_started() -> void:
	_idle_time = 0.0


func _on_countdown_process(delta: float) -> void:
	_anim_time += delta
	_front.queue_redraw()


func _on_play_process(delta: float) -> void:
	_anim_time += delta
	_pull_speed = lerpf(_pull_speed, _pulled_this_frame / maxf(delta, 0.001), 0.25)
	if _pulled_this_frame > 0.0:
		_idle_time = 0.0
	else:
		_idle_time += delta
	_pulled_this_frame = 0.0
	match ink_state:
		Ink.STOP:
			_still_time += delta
			if _still_time >= _cfg.ink_still_sec:
				_start_ink_pass()
		Ink.PASSING:
			_pass_t += delta
			var t := clampf(_pass_t / maxf(_cfg.ink_pass_sec, 0.001), 0.0, 1.0)
			pulled_px = lerpf(_pass_from, _pass_to, t * t * (3.0 - 2.0 * t))
			if t >= 1.0:
				pulled_px = _pass_to
				ink_state = Ink.NONE
				next_blot += 1
				blots_passed += 1
				_add_floater("♥", _goldie_pos + Vector2(0, -26), Color("ff8fb0"))
		_:
			pass
	_ink_face_time = maxf(0.0, _ink_face_time - delta)
	_hop_time = maxf(0.0, _hop_time - delta)
	_update_floaters(delta)
	_animate_goldie()
	_update_score_label()
	_front.queue_redraw()


func _on_play_input(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index < 0 and _swipe_zone.has_point(touch.position):
			_touch_index = touch.index
			_begin_gesture()
			return true
		if not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			if _swipe_distance >= 12.0:
				swipe_count += 1
			return true
		return false
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		if drag.relative.y > 0.0:
			pull(drag.relative.y)
		return true
	return false


## 手指向下滑了 finger_dy 像素。測試與截圖腳本也用這個方法模擬滑動。
func pull(finger_dy: float) -> void:
	if state != State.PLAYING or finger_dy <= 0.0:
		return
	_swipe_distance += finger_dy
	match ink_state:
		Ink.NONE:
			var amount := minf(finger_dy, _cfg.max_pull_per_event) * _cfg.pull_ratio
			_advance(amount)
		Ink.STOP:
			_stop_drag += finger_dy
			if _stop_drag >= _cfg.ink_swipe_tolerance_px:
				# 手還在動,金毛沒辦法換位置咬;新的一次滑動就算犯錯。
				_still_time = 0.0
				if _gesture != _exempt_gesture:
					_exempt_gesture = _gesture
					_ink_mistake()
		_:
			pass


## 模擬一次完整的滑動(按下、往下滑、放開)。
func simulate_swipe(distance: float, steps: int = 6) -> void:
	_begin_gesture()
	for i in steps:
		pull(distance / steps)
	if distance >= 12.0:
		swipe_count += 1


## 下一個墨水漬到達咬住位置時,pulled_px 的值。
func next_ink_stop_at() -> float:
	if next_blot >= blots.size():
		return INF
	return blots[next_blot] - _stop_margin()


func _compute_score() -> int:
	return floori(pulled_px / maxf(_cfg.px_per_score, 0.001))


func _countdown_center() -> Vector2:
	return Vector2(_paper_rect.get_center().x, minf(_swipe_zone.position.y + 128.0, _swipe_zone.end.y - 26.0))


func _format_score(value: int) -> String:
	return tr("MINIGAME_SCROLL_LENGTH") % value


func _on_paused(paused: bool) -> void:
	_touch_index = -1
	if paused:
		_goldie.pause()
	else:
		_goldie.play()


func _on_play_ended(_final_score: int, _final_grade: int) -> void:
	_touch_index = -1
	ink_state = Ink.NONE
	_anim_time = 0.0
	_play_goldie(_cfg.goldie_tangled_animation)
	_update_score_label()


func _on_ending_process(delta: float) -> void:
	_anim_time += delta
	# 被卷軸纏住:左右扭動。
	_goldie.rotation = sin(_anim_time * 18.0) * 0.12 * maxf(0.0, 1.0 - _anim_time)
	_goldie.position = _goldie_pos + Vector2(0, -absf(sin(_anim_time * 9.0)) * 2.0)
	_update_floaters(delta)
	if fmod(_anim_time, 0.35) < delta:
		_add_floater("♥", _goldie_pos + Vector2(_rng.randf_range(-10, 10), -24), Color("ff8fb0"))
	_front.queue_redraw()


func _on_results_process(delta: float) -> void:
	_anim_time += delta
	_update_floaters(delta)
	_goldie.rotation = 0.0
	_front.queue_redraw()


# --- 內部 ---

func _stop_margin() -> float:
	return _cfg.ink_size * 0.5 + 2.0


func _advance(amount: float) -> void:
	var stop_at := next_ink_stop_at()
	if pulled_px + amount >= stop_at:
		amount = maxf(0.0, stop_at - pulled_px)
		pulled_px = stop_at
		_enter_ink_stop()
	else:
		pulled_px += amount
	_pulled_this_frame += amount
	_sfx_accum += amount
	if _sfx_accum >= _cfg.scroll_sfx_every_px:
		_sfx_accum = 0.0
		Sfx.play(&"scroll")


func _begin_gesture() -> void:
	_gesture += 1
	_swipe_distance = 0.0
	_stop_drag = 0.0


func _enter_ink_stop() -> void:
	ink_state = Ink.STOP
	_still_time = 0.0
	_stop_drag = 0.0
	# 把墨水漬拉到咬住位置的那一下滑動不算犯錯(玩家來不及反應)。
	_exempt_gesture = _gesture


func _start_ink_pass() -> void:
	ink_state = Ink.PASSING
	_pass_t = 0.0
	_pass_from = pulled_px
	_pass_to = blots[next_blot] + _stop_margin() + 1.0
	_hop_time = 0.35
	Sfx.play(&"scroll")


func _ink_mistake() -> void:
	mistakes += 1
	add_time(-_cfg.ink_penalty_sec)
	_ink_face_time = _cfg.ink_face_sec
	_still_time = 0.0
	Sfx.play(&"ink")
	var bar := _time_bar_rect()
	_add_floater("-%.1f" % _cfg.ink_penalty_sec, Vector2(bar.get_center().x - 8.0, bar.end.y + 12.0), Color("ff6b5a"))


func _play_goldie(animation: StringName) -> void:
	if _goldie == null or _goldie.sprite_frames == null:
		return
	if _goldie.sprite_frames.has_animation(animation):
		_goldie.play(animation)
	elif _goldie.sprite_frames.has_animation(&"idle"):
		_goldie.play(&"idle")


func _animate_goldie() -> void:
	var offset := Vector2.ZERO
	if ink_state == Ink.NONE and _pull_speed > 5.0:
		# 用力拉:身體往後一頓一頓。
		offset.x = -roundf(absf(sin(_anim_time * 22.0)) * 1.5)
	if _hop_time > 0.0:
		offset.y = -roundf(sin(_hop_time / 0.35 * PI) * 4.0)
	if _ink_face_time > 0.0:
		offset.x += roundf(sin(_anim_time * 40.0) * 1.0)
	_goldie.position = _goldie_pos + offset


func _update_score_label() -> void:
	if _score_label != null:
		_score_label.text = tr("MINIGAME_SCROLL_LENGTH") % _compute_score()


func _add_floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"text": text, "pos": at, "color": color, "age": 0.0})


func _update_floaters(delta: float) -> void:
	for f: Dictionary in _floaters:
		f["age"] = float(f["age"]) + delta
		f["pos"] = (f["pos"] as Vector2) + Vector2(0, -14.0 * delta)
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["age"]) < 0.9)


func _show_hint() -> bool:
	if state == State.COUNTDOWN:
		return true
	if state != State.PLAYING or ink_state != Ink.NONE:
		return false
	return swipe_count < _cfg.hint_swipes_to_hide or _idle_time >= _cfg.hint_idle_sec


func _blot_screen_y(blot_at: float) -> float:
	return _bite_y + pulled_px - blot_at


# --- 繪圖 ---

func _draw() -> void:
	var screen := SafeArea.get_screen_size()
	# 夜空與圓桌
	var steps := 8
	for i in steps:
		var c := _cfg.sky_top_color.lerp(_cfg.sky_bottom_color, float(i) / (steps - 1))
		draw_rect(Rect2(0, screen.y * i / steps, screen.x, screen.y / steps + 1), c)
	for i in 14:
		var star := Vector2(fmod(i * 37.0 + 11.0, screen.x), fmod(i * 23.0 + 5.0, _roll_y + 20.0))
		var twinkle := 0.5 + 0.5 * sin(_anim_time * 2.0 + i)
		draw_rect(Rect2(star.round(), Vector2.ONE), Color(1, 1, 0.85, 0.35 + 0.5 * twinkle))
	var table_top := _roll_y + 12.0
	draw_rect(Rect2(0, table_top, screen.x, screen.y - table_top), _cfg.table_color)
	for i in int(screen.y / 18.0) + 1:
		draw_rect(Rect2(0, table_top + i * 18.0, screen.x, 1), _cfg.table_edge_color)
	draw_rect(Rect2(0, table_top, screen.x, 2), _cfg.table_edge_color.darkened(0.2))

	# 滑動範圍(淡淡的框)
	var zone := _swipe_zone
	draw_rect(zone, Color(1, 1, 1, 0.04))
	for x in range(int(zone.position.x), int(zone.end.x), 6):
		draw_rect(Rect2(x, zone.position.y, 3, 1), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(x, zone.end.y - 1, 3, 1), Color(1, 1, 1, 0.12))

	# 卷軸紙(會隨 pulled_px 往下移動)
	var paper := _paper_rect
	draw_rect(Rect2(paper.position + Vector2(2, 2), paper.size), Color(0, 0, 0, 0.25))
	draw_rect(paper, _cfg.paper_color)
	draw_rect(Rect2(paper.position, Vector2(2, paper.size.y)), _cfg.paper_edge_color)
	draw_rect(Rect2(paper.end.x - 2, paper.position.y, 2, paper.size.y), _cfg.paper_edge_color)
	var line_gap := 8.0
	var first := floori((pulled_px - (screen.y - _bite_y)) / line_gap) - 1
	var last := ceili((pulled_px + (_bite_y - _roll_y)) / line_gap) + 1
	for k in range(first, last):
		var y := _bite_y + pulled_px - k * line_gap
		if y < _roll_y + 8.0 or y > screen.y:
			continue
		var w := 18.0 + float(posmod(k * 7, 5)) * 5.0
		draw_rect(Rect2(paper.position.x + 7, y, w, 1), _cfg.paper_line_color)
		if posmod(k, 3) != 0:
			draw_rect(Rect2(paper.position.x + 10 + w, y, 10, 1), _cfg.paper_line_color)

	# 墨水漬
	for i in range(next_blot, blots.size()):
		var y := _blot_screen_y(blots[i])
		if y < _roll_y + 6.0:
			break
		_draw_blot(Vector2(paper.get_center().x, y), i)
	for i in range(maxi(0, next_blot - 4), next_blot):
		var y := _blot_screen_y(blots[i])
		if y <= screen.y + 10.0:
			_draw_blot(Vector2(paper.get_center().x, y), i)

	# 卷軸本體(木軸與捲著的紙),紋路隨拉出的長度轉動
	var roll := Rect2(paper.position.x - 6, _roll_y - 6, paper.size.x + 12, 14)
	draw_rect(Rect2(roll.position.x - 10, _roll_y - 2, roll.size.x + 20, 5), _cfg.roll_wood_color)
	draw_rect(Rect2(roll.position.x - 14, _roll_y - 4, 5, 9), _cfg.roll_knob_color)
	draw_rect(Rect2(roll.end.x + 9, _roll_y - 4, 5, 9), _cfg.roll_knob_color)
	draw_rect(roll, _cfg.paper_color.darkened(0.08))
	draw_rect(Rect2(roll.position, Vector2(roll.size.x, 2)), _cfg.paper_color.lightened(0.3))
	draw_rect(Rect2(roll.position.x, roll.end.y - 2, roll.size.x, 2), _cfg.paper_color.darkened(0.3))
	var stripe := fmod(pulled_px * 0.5, 6.0)
	for i in 3:
		var sy := roll.position.y + 2 + fmod(stripe + i * 4.0, 10.0)
		draw_rect(Rect2(roll.position.x + 1, sy, roll.size.x - 2, 1), _cfg.paper_line_color)
	draw_rect(Rect2(roll.position.x, roll.position.y, 2, roll.size.y), _cfg.paper_edge_color)
	draw_rect(Rect2(roll.end.x - 2, roll.position.y, 2, roll.size.y), _cfg.paper_edge_color)


func _draw_blot(center: Vector2, index: int) -> void:
	var r := _cfg.ink_size * 0.5
	var c := center.round()
	draw_circle(c, r, _cfg.ink_color)
	var offsets := [Vector2(-r, -2), Vector2(r - 1, 2), Vector2(2, r - 1), Vector2(-3, -r + 1)]
	for j in offsets.size():
		if (index + j) % 3 != 0:
			draw_circle(c + (offsets[j] as Vector2), 2.0, _cfg.ink_color)
	draw_rect(Rect2(c + Vector2(-2, -3), Vector2(2, 1)), Color(1, 1, 1, 0.35))


func _draw_front() -> void:
	var bite := Vector2(_paper_rect.position.x, _bite_y)
	# 咬住的位置:橫跨紙面的一排齒印,墨水漬碰到這條線就要停手
	var line_color := Color("ff6b5a") if ink_state == Ink.STOP else Color("8a6a4a")
	for x in range(int(_paper_rect.position.x) + 3, int(_paper_rect.end.x) - 2, 4):
		_front.draw_rect(Rect2(x, _bite_y - 1, 2, 2), line_color)
	# 嘴巴咬住紙邊:深色的嘴與兩顆白牙
	_front.draw_rect(Rect2(bite + Vector2(-4, -3), Vector2(7, 6)), Color("5a2a1a"))
	_front.draw_rect(Rect2(bite + Vector2(-2, -3), Vector2(2, 2)), MinigameUi.WHITE)
	_front.draw_rect(Rect2(bite + Vector2(-2, 1), Vector2(2, 2)), MinigameUi.WHITE)

	var head := _goldie.position + Vector2(4, -10) * _cfg.goldie_scale * 0.5
	if state == State.PLAYING:
		# 墨水漬快到了:金毛頭上的「!」
		var stop_at := next_ink_stop_at()
		var close_to_bite := stop_at - pulled_px <= _cfg.ink_warn_px
		if ink_state == Ink.STOP or (ink_state == Ink.NONE and close_to_bite):
			var bubble := (head + Vector2(-2, -18)).round()
			_front.draw_rect(Rect2(bubble + Vector2(-5, -8), Vector2(11, 14)), MinigameUi.INK)
			_front.draw_rect(Rect2(bubble + Vector2(-4, -7), Vector2(9, 12)), Color("ffd34d") if ink_state == Ink.NONE else Color("ff6b5a"))
			_front.draw_rect(Rect2(bubble + Vector2(-1, -5), Vector2(2, 5)), MinigameUi.INK)
			_front.draw_rect(Rect2(bubble + Vector2(-1, 1), Vector2(2, 2)), MinigameUi.INK)
		if ink_state == Ink.STOP:
			# 紅色的「停」手掌:蓋在滑動範圍上方,一閃一閃
			var pulse := 0.75 + 0.25 * sin(_anim_time * 12.0)
			var palm := Vector2(_paper_rect.get_center().x, _swipe_zone.position.y + 30.0)
			MinigameUi.draw_stop_palm(_front, palm, Color(0.9, 0.25, 0.25, pulse))
			# 停手的進度圈
			var progress := clampf(_still_time / maxf(_cfg.ink_still_sec, 0.001), 0.0, 1.0)
			_front.draw_arc(palm, 14.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, MinigameUi.WHITE, 2.0)
	if _ink_face_time > 0.0:
		# 臉上沾到墨水(可愛的墨點,不是受傷)
		for i in 4:
			var spot := head + Vector2(-6 + i * 4, -2 + (i % 2) * 4)
			_front.draw_circle(spot.round(), 1.5 + (i % 2), _cfg.ink_color)
	if state == State.ENDING or state == State.RESULTS:
		_draw_tangle()
	if _show_hint():
		_draw_hint()
	for f: Dictionary in _floaters:
		var alpha := 1.0 - float(f["age"]) / 0.9
		var font := ThemeDB.fallback_font
		var col := f["color"] as Color
		var text: String = f["text"]
		var pos := (f["pos"] as Vector2).round()
		_front.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(MinigameUi.INK, alpha))
		_front.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col, alpha))


## 結束:卷軸一圈圈纏住金毛。
func _draw_tangle() -> void:
	var t := clampf(_anim_time / maxf(config.results_delay_sec, 0.1), 0.0, 1.0) if state == State.ENDING else 1.0
	var center := _goldie.position
	var half := 12.0 * _cfg.goldie_scale
	var bands := [
		Vector2(-6, 0.30), Vector2(4, -0.25), Vector2(10, 0.15), Vector2(-12, -0.1),
	]
	var count := ceili(t * bands.size())
	for i in count:
		var b: Vector2 = bands[i]
		var xf := Transform2D(b.y + sin(_anim_time * 6.0 + i) * 0.03, center + Vector2(0, b.x))
		_front.draw_set_transform_matrix(xf)
		_front.draw_rect(Rect2(-half - 3, -3, half * 2 + 6, 6), _cfg.paper_color)
		_front.draw_rect(Rect2(-half - 3, -3, half * 2 + 6, 1), _cfg.paper_edge_color)
		_front.draw_rect(Rect2(-half - 3, 2, half * 2 + 6, 1), _cfg.paper_edge_color)
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	# 卷軸的尾巴從金毛身上垂到紙上
	_front.draw_line(center + Vector2(half, 4), Vector2(_paper_rect.get_center().x, _bite_y + 20), _cfg.paper_color, 4.0)


## 提示:一隻手在下半部向下滑,下面有閃動的箭頭。
func _draw_hint() -> void:
	var zone := _swipe_zone
	var x := _paper_rect.get_center().x + 6.0
	var cycle := 0.9
	var t := fmod(_anim_time, cycle) / cycle
	var travel := minf(70.0, zone.size.y - 60.0)
	var down := t < 0.7
	var progress := t / 0.7 if down else 1.0 - (t - 0.7) / 0.3
	var tip := Vector2(x, zone.position.y + 26.0 + travel * progress)
	var alpha := 1.0 if down else 0.5
	if down:
		# 手指劃過的軌跡
		_front.draw_line(Vector2(x, zone.position.y + 16.0), tip, Color(1, 1, 1, 0.35), 2.0)
	MinigameUi.draw_hand(_front, tip, down, alpha)
	for i in 3:
		var on := int(_anim_time * 6.0) % 3 == i
		var cy := zone.position.y + 30.0 + i * 12.0
		MinigameUi.draw_down_chevron(_front, Vector2(_paper_rect.position.x - 26.0, cy), 5.0, Color(1, 0.95, 0.6, 0.9 if on else 0.3))
		MinigameUi.draw_down_chevron(_front, Vector2(_paper_rect.end.x + 26.0, cy), 5.0, Color(1, 0.95, 0.6, 0.9 if on else 0.3))
