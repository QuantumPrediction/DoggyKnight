extends Control
## 第一關的操作提示(DEV_PLAN 4.10、CP8)。擁有者:C 線。
##
## B 線在 1-1 且 GameState.tutorial_done == false 時把它加到第 20 層 CanvasLayer;
## 完成時發 finished,B 線設 tutorial_done = true 並存檔。
## 提示觀察角色實際走位與普通出招。介面忽略輸入，浮動搖桿與按鈕照常運作。
## 等候出招逾時就淡出。finished 表示看過提示，只有角色確實出手才播放鼓勵。

signal finished

enum Step { MOVE, ATTACK, DONE, EXPIRED }

const MOVE_DISTANCE: float = 1.0
const ATTACK_TIMEOUT: float = 4.0
const FINGER: Texture2D = preload("res://assets/ui/finger.png")
const FINGER_PRESSED: Texture2D = preload("res://assets/ui/finger_pressed.png")
const SPARKLE: PackedScene = preload("res://assets/fx/particles/sparkle.tscn")

var step: Step = Step.MOVE
var finger: TextureRect
var bubble: PanelContainer
var bubble_label: Label

var _player: GoldiePlayer
var _last_position: Vector2
var _travelled: float = 0.0
var _starting_swings: int = 0
var _time: float = 0.0
var _step_time: float = 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.THEME
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.theme_type_variation = &"PanelDark"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label = UiKit.label("", &"LabelLight")
	bubble_label.name = "Text"
	bubble.add_child(bubble_label)
	add_child(bubble)
	finger = UiKit.texture_rect(FINGER)
	finger.name = "Finger"
	finger.visible = not UiKit.uses_keyboard_hints()
	add_child(finger)
	_enter(Step.MOVE)


func _enter(s: Step) -> void:
	step = s
	_step_time = 0.0
	match s:
		Step.MOVE:
			bubble_label.text = tr("UI_TUTORIAL_MOVE_PC" if UiKit.uses_keyboard_hints() else "UI_TUTORIAL_MOVE")
		Step.ATTACK:
			_starting_swings = _player.swing_count
			bubble_label.text = tr("UI_TUTORIAL_ATTACK_PC" if UiKit.uses_keyboard_hints() else "UI_TUTORIAL_ATTACK")
			if GameState.hero_class != &"knight":
				bubble_label.text = tr("UI_TUTORIAL_RANGED")
			UiKit.play_sfx(&"ui_tap")
		Step.EXPIRED:
			finger.visible = false
			_trail.clear()
			set_physics_process(false)
			_finish_after(0.0)
			return
		Step.DONE:
			set_physics_process(false)
			bubble_label.text = tr("UI_TUTORIAL_DONE")
			finger.visible = false
			_trail.clear()
			UiKit.play_sfx(&"star")
			_burst()
			_finish_after(0.9)
	bubble.size = bubble.get_minimum_size()
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _finish_after(delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _burst() -> void:
	var fx := SPARKLE.instantiate() as Node2D
	fx.position = bubble.position + bubble.size * 0.5
	add_child(fx)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as GoldiePlayer
		if _player != null:
			_last_position = _player.global_position
			_starting_swings = _player.swing_count
		return
	var position_now := _player.global_position
	if step == Step.MOVE:
		# 按住介面、撞牆或只點一下都沒有完成走位。
		if _player.get_move_input() != Vector2.ZERO and not _player.is_downed():
			_travelled += _last_position.distance_to(position_now)
			if _travelled >= MOVE_DISTANCE:
				_enter(Step.ATTACK)
	elif step == Step.ATTACK:
		_step_time += delta
		if _player.swing_count > _starting_swings:
			_enter(Step.DONE)
		elif _step_time >= ATTACK_TIMEOUT:
			_enter(Step.EXPIRED)
	_last_position = position_now


func _process(delta: float) -> void:
	_time += delta
	_layout()
	_animate_finger()
	queue_redraw()


func _layout() -> void:
	# 提示泡泡放在戰鬥區下緣、金毛起點的腳下(下方是玩家最少走到的地方,不擋住金毛與敵人);
	# 手指在泡泡下面示範。
	var safe := SafeArea.get_safe_rect()
	var game := SafeArea.get_game_rect()
	var start := game.position + Layout.PLAYER_START
	var arena_bottom := game.position.y + Layout.ARENA_RECT.end.y
	bubble.size = bubble.get_minimum_size()
	var y := minf(arena_bottom - 46.0, safe.end.y - 64.0)
	bubble.position = Vector2(floorf(clampf(start.x - bubble.size.x * 0.5, safe.position.x + 2,
			safe.end.x - bubble.size.x - 2)), floorf(maxf(y, start.y + 16.0)))


func _finger_origin() -> Vector2:
	var game := SafeArea.get_game_rect()
	var start := game.position + Layout.PLAYER_START
	return Vector2(floorf(start.x - 22), floorf(bubble.position.y + bubble.size.y + 2.0))


func _animate_finger() -> void:
	if not finger.visible:
		return
	var base := _finger_origin()
	if step == Step.MOVE:
		# 1.6 秒一輪:按下(0.2)→ 往右拖(0.7)→ 放開(0.3)→ 回原位(0.4)
		var t := fmod(_time, 1.6)
		var drag := 0.0
		var down := false
		if t < 0.2:
			down = true
		elif t < 0.9:
			down = true
			drag = (t - 0.2) / 0.7
		elif t < 1.2:
			drag = 1.0
		else:
			drag = 1.0 - (t - 1.2) / 0.4
		finger.texture = FINGER_PRESSED if down else FINGER
		finger.position = (base + Vector2(30 * ease(drag, -1.8), 0)).floor()
		_trail.clear()
		if down and drag > 0.0:
			for k in range(0, int(30 * ease(drag, -1.8)), 4):
				_trail.append(base + Vector2(k + 6, 2))
	elif step == Step.ATTACK:
		# 手指抬起、停一下、再按下
		var t := fmod(_time, 1.2)
		var lift := clampf(t / 0.35, 0.0, 1.0) if t < 0.8 else 1.0 - (t - 0.8) / 0.4
		finger.texture = FINGER if lift > 0.1 else FINGER_PRESSED
		finger.position = (base + Vector2(10, -8.0 * lift)).floor()
		_trail.clear()


func _draw() -> void:
	if finger == null or not finger.visible:
		return
	# 拖曳的軌跡:一串小圓點;放手提示:手指上方一圈小光點
	for p in _trail:
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(PaletteColors.WHITE, 0.8))
	if step == Step.MOVE and finger.texture == FINGER_PRESSED:
		var c := _finger_origin() + Vector2(8, 2)
		draw_arc(c, 9.0, 0.0, TAU, 16, Color(PaletteColors.WHITE, 0.5), 1.0)
	if step == Step.ATTACK:
		var c := finger.position + Vector2(8, -2)
		var r := 6.0 + 3.0 * sin(_time * 8.0)
		for k in 6:
			var a := TAU * k / 6.0 + _time
			draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * r).floor(), Vector2(1, 1)), PaletteColors.YELLOW)
