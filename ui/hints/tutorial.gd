extends Control
## 第一關的操作提示(DEV_PLAN 4.10、CP8)。擁有者:C 線。
##
## B 線在 1-1 且 GameState.tutorial_done == false 時把它加到第 20 層 CanvasLayer;
## 完成時發 finished,B 線設 tutorial_done = true 並存檔。
## 它只「看」觸控(_input,不呼叫 set_input_as_handled),根節點與所有子節點都是
## MOUSE_FILTER_IGNORE,所以 A 線的搖桿完全照常運作。
##
## 步驟:
## 1. 「按住畫面拖曳,金毛就會走」:手指圖示按下、往右拖、放開,一直重複,直到玩家拖曳約 20 像素。
## 2. 「放手!金毛會自動揮劍」:手指往上抬起、冒出閃光;玩家在敵人附近放手、打倒任何敵人,
##    或過了 4 秒,就算完成。
## 3. 「做得好!」彈一下,淡出,發 finished。

signal finished

enum Step { MOVE, ATTACK, DONE }

## 拖曳多遠(邏輯像素)算學會移動。
const DRAG_DISTANCE: float = 20.0
## 第二步最多等幾秒。
const ATTACK_TIMEOUT: float = 4.0
## 放手時,金毛與最近的敵人距離在這之內算「在敵人附近」。
const NEAR_ENEMY: float = 44.0
const FINGER: Texture2D = preload("res://assets/ui/finger.png")
const FINGER_PRESSED: Texture2D = preload("res://assets/ui/finger_pressed.png")
const SPARKLE: PackedScene = preload("res://assets/fx/particles/sparkle.tscn")

var step: Step = Step.MOVE
var finger: TextureRect
var bubble: PanelContainer
var bubble_label: Label

var _press_at: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _time: float = 0.0
var _step_time: float = 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
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
	finger.visible = not OS.has_feature("pc")
	add_child(finger)
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	_enter(Step.MOVE)


func _enter(s: Step) -> void:
	step = s
	_step_time = 0.0
	match s:
		Step.MOVE:
			bubble_label.text = tr("UI_TUTORIAL_MOVE_PC" if OS.has_feature("pc") else "UI_TUTORIAL_MOVE")
		Step.ATTACK:
			bubble_label.text = tr("UI_TUTORIAL_ATTACK_PC" if OS.has_feature("pc") else "UI_TUTORIAL_ATTACK")
			if GameState.hero_class != &"knight":
				bubble_label.text = tr("UI_TUTORIAL_RANGED")
			UiKit.play_sfx(&"ui_tap")
		Step.DONE:
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


func _input(event: InputEvent) -> void:
	# 只看,不吃掉觸控(不呼叫 set_input_as_handled)。
	if event is InputEventKey:
		for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
			if step == Step.MOVE and event.is_action_pressed(action) and not event.is_echo():
				_enter(Step.ATTACK)
			elif step == Step.ATTACK and event.is_action_released(action) and _released_near_enemy():
				_enter(Step.DONE)
		return
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.index != 0:
			return
		pos = e.position
		pressed = e.pressed
		released = not e.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != 0:
			return
		pos = d.position
		moved = true
	else:
		return
	if pressed:
		_pressing = true
		_press_at = pos
	elif moved and _pressing:
		if step == Step.MOVE and pos.distance_to(_press_at) >= DRAG_DISTANCE:
			_enter(Step.ATTACK)
	elif released:
		_pressing = false
		if step == Step.ATTACK and _released_near_enemy():
			_enter(Step.DONE)


## 測試與沙盒用:模擬玩家的動作。
func simulate_drag(distance: float) -> void:
	_pressing = true
	_press_at = Vector2(90, 200)
	if step == Step.MOVE and distance >= DRAG_DISTANCE:
		_enter(Step.ATTACK)


func simulate_release(near_enemy: bool) -> void:
	_pressing = false
	if step == Step.ATTACK and near_enemy:
		_enter(Step.DONE)


func _released_near_enemy() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return false
	for e in get_tree().get_nodes_in_group(&"enemy"):
		if e is Node2D and (e as Node2D).global_position.distance_to(player.global_position) <= NEAR_ENEMY:
			return true
	return false


func _on_enemy_died(_id: StringName, _pos: Vector2, _exp: int) -> void:
	if step == Step.ATTACK or step == Step.MOVE:
		_enter(Step.DONE)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if step == Step.ATTACK and _step_time >= ATTACK_TIMEOUT:
		_enter(Step.DONE)
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
