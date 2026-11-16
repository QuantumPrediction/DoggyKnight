class_name MinigameBase
extends Control
## 所有營地小遊戲的共同基底(DEV_PLAN 11 D4)。
##
## 流程:start() → 倒數 → 遊戲中(計時)→ 時間到 → 結束動畫 → 評價畫面 → 點一下 → closed。
## - 時間到時算分、評價、套用獎勵(GameState)、發出 EventBus.minigame_finished,再發 finished。
## - 收到 EventBus.app_backgrounded(切到背景、來電、鎖螢幕)時暫停,計時停止;
##   點一下畫面繼續(或在設定 resume_on_foreground 時,回到前景就繼續)。
## - get_tree().paused(B 線的暫停選單)也會令整個小遊戲停住,因為根節點用預設的 process_mode。
##
## 加入新的小遊戲:繼承這個類別,覆寫以 _on_ 開頭的方法與 _compute_score(),
## 再在營地的 CampConfig 指定它的場景。範例見 game/minigames/scroll/scroll_minigame.gd。
##
## 座標:根節點是全螢幕的 Control(放在營地的 CanvasLayer 之下),
## 本地座標 = 畫面的邏輯像素;用 SafeArea 排版。
##
## 演出(DEV_PLAN 15 DP2):倒數是會彈出的大數字(每秒 countdown 音效),開始時顯示 _go_text();
## 時間到時手機震一下(medium);評價畫面的星星逐顆亮起(star 音效與閃光),分數由 0 數上去。

signal state_changed(new_state: State)
## 評價出爐:獎勵已套用、EventBus.minigame_finished 已發出。
signal finished(score: int, grade: int)
## 玩家看完評價,營地收到後移除小遊戲並回到選單。
signal closed()

enum State { IDLE, COUNTDOWN, PLAYING, PAUSED, ENDING, RESULTS, CLOSED }

@export var config: MinigameConfig
## 加入場景樹時自動開始。測試時可以關掉,改為手動呼叫 start() 與 step()。
@export var auto_start: bool = true

var state: State = State.IDLE
var time_left: float = 0.0
var countdown_left: float = 0.0
var play_elapsed: float = 0.0
var score: int = 0
var grade: int = 0
var rewards: Dictionary = {}
## 獎勵套用的對象;null 時用 GameState Autoload。測試可以換成假物件。
var reward_target: Object = null

var _paused_from: State = State.IDLE
var _state_time: float = 0.0
var _overlay: Control
var _countdown_label: Label
var _pause_box: VBoxContainer
var _results_box: VBoxContainer
var _results_grade_label: Label
var _results_score_label: Label
var _results_reward_label: Label
var _results_extra_label: Label
var _go_label: Label
var _clock: float = 0.0
var _last_count: int = -1
var _count_pop: float = 0.0
var _go_left: float = 0.0
var _stars_lit: int = 0
var _star_pop: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MinigameUi.apply_shared_theme(self)
	if config == null:
		config = MinigameConfig.new()
	if config.grading == null:
		config.grading = MinigameGrading.new()
	_on_build()
	_build_overlay()
	resized.connect(_relayout)
	EventBus.app_backgrounded.connect(_on_app_backgrounded)
	EventBus.app_foregrounded.connect(_on_app_foregrounded)
	_relayout()
	if auto_start:
		start()


func _process(delta: float) -> void:
	step(delta)


## 開始(或重新開始)倒數。
func start() -> void:
	time_left = config.duration_sec
	countdown_left = config.countdown_sec
	play_elapsed = 0.0
	score = 0
	grade = 0
	rewards = {}
	_last_count = -1
	_go_left = 0.0
	_stars_lit = 0
	_on_reset()
	if countdown_left > 0.0:
		_set_state(State.COUNTDOWN)
		_on_countdown_started()
	else:
		_begin_play()


## 推進時間。_process 每格呼叫;測試可以直接呼叫以精確控制時間。
func step(delta: float) -> void:
	_clock += delta
	_state_time += delta
	if state != State.PAUSED:
		_count_pop = maxf(0.0, _count_pop - delta)
		_go_left = maxf(0.0, _go_left - delta)
		for i in _star_pop.size():
			_star_pop[i] = maxf(0.0, _star_pop[i] - delta)
	match state:
		State.COUNTDOWN:
			countdown_left -= delta
			_on_countdown_process(delta)
			_tick_countdown()
			if countdown_left <= 0.0:
				countdown_left = 0.0
				_begin_play()
		State.PLAYING:
			time_left = maxf(0.0, time_left - delta)
			play_elapsed += delta
			_on_play_process(delta)
			if time_left <= 0.0:
				_end_play()
		State.ENDING:
			_on_ending_process(delta)
			if _state_time >= config.results_delay_sec:
				_show_results()
		State.RESULTS:
			_on_results_process(delta)
			_tick_results()
			if config.results_auto_close_sec > 0.0 and _state_time >= config.results_auto_close_sec:
				close()
		_:
			pass
	_update_overlay()
	queue_redraw()


func pause_game() -> void:
	if state != State.COUNTDOWN and state != State.PLAYING:
		return
	_paused_from = state
	_set_state(State.PAUSED)
	_on_paused(true)


func resume_game() -> void:
	if state != State.PAUSED:
		return
	_set_state(_paused_from)
	_on_paused(false)


func is_paused() -> bool:
	return state == State.PAUSED


## 進入目前狀態之後經過的秒數。
func get_state_time() -> float:
	return _state_time


## 扣掉(或加上)遊戲時間。秒數為負表示扣時間。
func add_time(seconds: float) -> void:
	time_left = clampf(time_left + seconds, 0.0, config.duration_sec)


## 評價畫面看完。
func close() -> void:
	if state == State.CLOSED:
		return
	_set_state(State.CLOSED)
	closed.emit()


## 遊戲時間的進度,1 = 剛開始,0 = 時間到。
func time_ratio() -> float:
	if config.duration_sec <= 0.0:
		return 0.0
	return clampf(time_left / config.duration_sec, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		if state == State.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()
			return
		if state == State.RESULTS and _state_time >= config.results_min_sec:
			close()
			get_viewport().set_input_as_handled()
			return
	if state == State.PLAYING:
		if _on_play_input(event):
			get_viewport().set_input_as_handled()


# --- 子類別覆寫 ---

## 建立自己的畫面節點(在 _ready 裡、蓋在上面的提示層之前呼叫)。
func _on_build() -> void:
	pass


## 畫面大小改變(轉向、不同手機)時重新排版。
func _on_layout() -> void:
	pass


## start() 時重設自己的狀態。
func _on_reset() -> void:
	pass


func _on_countdown_started() -> void:
	pass


func _on_countdown_process(_delta: float) -> void:
	pass


func _on_play_started() -> void:
	pass


func _on_play_process(_delta: float) -> void:
	pass


## 遊戲中的輸入。處理了就傳回 true。
func _on_play_input(_event: InputEvent) -> bool:
	return false


func _on_paused(_paused: bool) -> void:
	pass


## 時間到,分數與評價已經算好。在這裡開始結束動畫。
func _on_play_ended(_final_score: int, _final_grade: int) -> void:
	pass


func _on_ending_process(_delta: float) -> void:
	pass


func _on_results_process(_delta: float) -> void:
	pass


func _compute_score() -> int:
	return 0


## 評價畫面上的分數文字。
func _format_score(value: int) -> String:
	return str(value)


## 開始時彈出的字(例如「拉!」)。空字串表示不顯示。
func _go_text() -> String:
	return ""


## 評價畫面上、分數下面的額外說明(例如「完美停住 ×3」)。
func _result_extra_lines() -> PackedStringArray:
	return PackedStringArray()


## 倒數數字的中心(畫面邏輯像素)。
func _countdown_center() -> Vector2:
	return SafeArea.get_safe_rect().get_center()


## 計時條的位置(畫面邏輯像素)。
func _time_bar_rect() -> Rect2:
	var safe := SafeArea.get_safe_rect()
	return Rect2(Vector2(safe.get_center().x - 50, safe.position.y + 6), Vector2(100, 6))


# --- 內部 ---

func _begin_play() -> void:
	_set_state(State.PLAYING)
	if _go_text() != "":
		_go_left = 0.7
		_go_label.text = _go_text()
		Sfx.play(&"whoosh")
	_on_play_started()


## 倒數每換一個數字:countdown 音效,數字彈出來。
func _tick_countdown() -> void:
	var count := maxi(1, ceili(countdown_left))
	if count != _last_count:
		_last_count = count
		_count_pop = 0.3
		Sfx.play(&"countdown")


## 評價畫面的星星逐顆亮起。
func _tick_results() -> void:
	var target := mini(grade, int(_state_time / maxf(config.results_star_interval_sec, 0.01)))
	while _stars_lit < target:
		_star_pop[_stars_lit] = 0.35
		_stars_lit += 1
		Sfx.play(&"star")
		_spawn_star_fx(_star_center(_stars_lit - 1))
		if _stars_lit == grade and grade == config.grading.max_grade():
			Haptics.play(&"light")


func _star_center(index: int) -> Vector2:
	var panel := _results_panel_rect()
	return Vector2(panel.get_center().x + (index - 1) * 26, panel.position.y + 22)


func _spawn_star_fx(at: Vector2) -> void:
	if config.star_fx == null:
		return
	var fx := config.star_fx.instantiate()
	if fx is Node2D:
		(fx as Node2D).position = at.round()
	_overlay.add_child(fx)


func _end_play() -> void:
	score = maxi(0, _compute_score())
	grade = config.grading.grade_for(score)
	var target: Object = reward_target if reward_target != null else get_node_or_null(^"/root/GameState")
	if target != null:
		rewards = config.grading.apply_rewards(grade, target)
	EventBus.minigame_finished.emit(config.minigame_id, score, grade)
	finished.emit(score, grade)
	Haptics.play(&"medium")
	_set_state(State.ENDING)
	_on_play_ended(score, grade)


func _show_results() -> void:
	_set_state(State.RESULTS)
	_results_grade_label.text = tr("UI_GRADE_%d" % grade)
	_results_score_label.text = _format_score(score)
	var lines: PackedStringArray = []
	if int(rewards.get("vigor", 0)) > 0:
		lines.append(tr("MINIGAME_REWARD_VIGOR") % int(rewards["vigor"]))
	if rewards.has("satisfaction"):
		lines.append(tr("MINIGAME_REWARD_SATISFACTION") % int(rewards["satisfaction"]))
	if rewards.has("bonus") and float(rewards["bonus"]) > 0.0:
		lines.append(tr("MINIGAME_REWARD_BONUS") % roundi(float(rewards["bonus"]) * 100.0))
	_results_reward_label.text = "\n".join(lines)
	_results_extra_label.text = "\n".join(_result_extra_lines())
	_results_extra_label.visible = _results_extra_label.text != ""
	_stars_lit = 0
	Sfx.play(&"clear" if grade > 0 else &"ui_tap")


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_update_overlay()
	state_changed.emit(new_state)


func _on_app_backgrounded() -> void:
	pause_game()


func _on_app_foregrounded() -> void:
	if config.resume_on_foreground:
		resume_game()


func _relayout() -> void:
	_on_layout()
	if _overlay != null:
		_layout_overlay()
	queue_redraw()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_countdown_label = MinigameUi.make_label("", MinigameUi.FONT_XL, Color("ffe066"))
	_countdown_label.name = "Countdown"
	_countdown_label.add_theme_constant_override(&"outline_size", 6)
	_overlay.add_child(_countdown_label)

	_go_label = MinigameUi.make_label("", MinigameUi.FONT_XL, Color("ffe066"))
	_go_label.name = "Go"
	_go_label.add_theme_constant_override(&"outline_size", 6)
	_go_label.visible = false
	_overlay.add_child(_go_label)

	_pause_box = VBoxContainer.new()
	_pause_box.name = "PauseBox"
	_pause_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_box.add_child(MinigameUi.make_label(tr("UI_PAUSED"), MinigameUi.FONT_L))
	_pause_box.add_child(MinigameUi.make_label(tr("MINIGAME_TAP_TO_CONTINUE"), MinigameUi.FONT_S))
	_overlay.add_child(_pause_box)

	_results_box = VBoxContainer.new()
	_results_box.name = "ResultsBox"
	_results_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_box.add_theme_constant_override(&"separation", 2)
	var star_space := Control.new()
	star_space.custom_minimum_size = Vector2(0, 34)
	star_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_box.add_child(star_space)
	_results_grade_label = MinigameUi.make_title("")
	_results_box.add_child(_results_grade_label)
	_results_score_label = MinigameUi.make_label("", MinigameUi.FONT_S)
	_results_box.add_child(_results_score_label)
	_results_extra_label = MinigameUi.make_label("", MinigameUi.FONT_S, Color("ffe066"))
	_results_box.add_child(_results_extra_label)
	_results_reward_label = MinigameUi.make_label("", MinigameUi.FONT_S)
	_results_box.add_child(_results_reward_label)
	_overlay.add_child(_results_box)
	_update_overlay()


func _layout_overlay() -> void:
	var safe := SafeArea.get_safe_rect()
	var center := safe.get_center()
	_countdown_label.size = Vector2(80, 48)
	_countdown_label.position = (_countdown_center() - _countdown_label.size * 0.5).round()
	_countdown_label.pivot_offset = _countdown_label.size * 0.5
	_go_label.size = Vector2(120, 48)
	_go_label.position = (_countdown_center() - _go_label.size * 0.5).round()
	_go_label.pivot_offset = _go_label.size * 0.5
	_pause_box.size = Vector2(safe.size.x - 16, 0)
	_pause_box.position = Vector2(safe.position.x + 8, center.y + 16).round()
	_results_box.size = Vector2(_results_panel_rect().size.x - 8, 0)
	_results_box.position = (_results_panel_rect().position + Vector2(4, 6)).round()


func _results_panel_rect() -> Rect2:
	var safe := SafeArea.get_safe_rect()
	var panel_size := Vector2(minf(160.0, safe.size.x - 12.0), 168.0)
	var top := safe.get_center().y - panel_size.y * 0.5
	# 盡量不要蓋住結束動畫(例如被卷軸包起來的金毛),但不能超出畫面底部
	top = minf(maxf(top, _results_top_min()), safe.end.y - panel_size.y - 28.0)
	return Rect2(Vector2(safe.get_center().x - panel_size.x * 0.5, top).round(), panel_size)


## 評價面板的上緣至少要在哪裡(畫面邏輯像素)。子類別可以覆寫,讓結束動畫露出來。
func _results_top_min() -> float:
	return 0.0


func _update_overlay() -> void:
	if _overlay == null:
		return
	_countdown_label.visible = state == State.COUNTDOWN
	if state == State.COUNTDOWN:
		_countdown_label.text = str(maxi(1, ceili(countdown_left)))
		# 每個數字出現時從大縮回來
		var pop := _count_pop / 0.3
		_countdown_label.scale = Vector2.ONE * (1.0 + 0.6 * pop * pop)
	_go_label.visible = _go_left > 0.0 and state == State.PLAYING
	if _go_label.visible:
		var t := 1.0 - _go_left / 0.7
		_go_label.scale = Vector2.ONE * (1.6 - 0.6 * minf(1.0, t * 4.0) + 0.15 * maxf(0.0, t - 0.5))
		_go_label.modulate.a = clampf(_go_left / 0.25, 0.0, 1.0)
	_pause_box.visible = state == State.PAUSED
	_results_box.visible = state == State.RESULTS
	if state == State.RESULTS:
		# 文字在星星亮完之後才淡入;分數由 0 數上去
		var reveal := clampf((_state_time - config.results_star_interval_sec * grade) / 0.3, 0.0, 1.0)
		_results_grade_label.modulate.a = reveal
		_results_reward_label.modulate.a = clampf(reveal * 2.0 - 1.0, 0.0, 1.0)
		_results_extra_label.modulate.a = reveal
		_results_score_label.text = _format_score(roundi(score * clampf(_state_time / 0.6, 0.0, 1.0)))
		_results_box.position.y = roundf(_results_panel_rect().position.y + 8.0 + _panel_rise())
	_overlay.queue_redraw()


## 評價面板從下面彈上來的位移。
func _panel_rise() -> float:
	return roundf(pow(1.0 - clampf(_state_time / 0.25, 0.0, 1.0), 2.0) * 24.0)


func _draw_overlay() -> void:
	if state == State.IDLE or state == State.CLOSED:
		return
	if state == State.COUNTDOWN or state == State.PLAYING or state == State.PAUSED:
		_draw_time_bar()
	match state:
		State.COUNTDOWN:
			# 倒數數字後面的圓,每秒縮小一次。
			var frac := countdown_left - floorf(countdown_left)
			var center := _countdown_label.position + _countdown_label.size * 0.5
			_overlay.draw_circle(center, 20.0 + frac * 6.0, Color(MinigameUi.INK, 0.55))
			_overlay.draw_arc(center, 22.0 + frac * 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color("ffe066"), 2.0)
		State.PAUSED:
			var screen := SafeArea.get_screen_size()
			_overlay.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.55))
			var center := SafeArea.get_safe_rect().get_center()
			MinigameUi.draw_pause_icon(_overlay, center - Vector2(0, 12), MinigameUi.WHITE)
			var press := fmod(_clock, 1.0) < 0.3
			MinigameUi.draw_hand(_overlay, center + Vector2(2, 80), press)
		State.RESULTS:
			var screen := SafeArea.get_screen_size()
			var dim := clampf(_state_time / 0.25, 0.0, 1.0)
			_overlay.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.5 * dim))
			var panel := _results_panel_rect()
			var rise := _panel_rise()
			panel.position.y += rise
			_overlay.draw_rect(Rect2(panel.position + Vector2(2, 3), panel.size), Color(0, 0, 0, 0.35))
			_overlay.draw_rect(panel.grow(1), MinigameUi.INK)
			_overlay.draw_rect(panel, Color("3b2f4f"))
			_overlay.draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2)), Color("6b5a8a"))
			_overlay.draw_rect(Rect2(panel.position + Vector2(0, panel.size.y - 2), Vector2(panel.size.x, 2)), Color("2a2040"))
			# 星星的底座,星星逐顆亮起時彈一下
			var inner := Rect2(panel.position + Vector2(10, 6), Vector2(panel.size.x - 20, 32))
			_overlay.draw_rect(inner, Color(MinigameUi.INK, 0.6))
			for i in 3:
				var center := _star_center(i) + Vector2(0, rise)
				var lit := i < _stars_lit
				var pop := _star_pop[i] / 0.35
				var radius := 10.0 + (4.0 * sin(pop * PI) if lit else 0.0)
				MinigameUi.draw_star(_overlay, center, radius, lit)
			if _state_time >= config.results_min_sec:
				var press := fmod(_clock, 1.0) < 0.3
				MinigameUi.draw_hand(_overlay, Vector2(panel.end.x - 14, panel.end.y + 18), press)
		_:
			pass


func _draw_time_bar() -> void:
	var rect := _time_bar_rect()
	var ratio := time_ratio()
	var warning := state == State.PLAYING and time_left <= config.time_warning_sec and fmod(_clock, 0.4) < 0.2
	_overlay.draw_rect(rect.grow(1), MinigameUi.INK)
	_overlay.draw_rect(rect, Color("4a4560"))
	var fill := Color("ff6b5a") if warning else Color("7ed957")
	_overlay.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * ratio), rect.size.y)), fill)
	# 沙漏圖示
	var icon := rect.position + Vector2(-9, -1)
	_overlay.draw_rect(Rect2(icon, Vector2(6, 1)), MinigameUi.WHITE)
	_overlay.draw_rect(Rect2(icon + Vector2(0, 7), Vector2(6, 1)), MinigameUi.WHITE)
	_overlay.draw_colored_polygon(PackedVector2Array([icon + Vector2(1, 1), icon + Vector2(5, 1), icon + Vector2(3, 4)]), Color("ffd34d"))
	_overlay.draw_colored_polygon(PackedVector2Array([icon + Vector2(3, 4), icon + Vector2(5, 7), icon + Vector2(1, 7)]), Color("ffd34d"))
