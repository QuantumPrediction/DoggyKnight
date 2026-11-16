extends Control
## 教學提示的替身。正式版:ui/hints/tutorial.tscn(C 線)。介面相同(DEV_PLAN 4.10):
##   B 線在 1-1 且 GameState.tutorial_done == false 時加到第 20 層;它自己看觸控輸入決定下一步,
##   不吃掉觸控(mouse_filter = IGNORE,只在 _input 裡觀察,不 accept);完成時發 finished。
## 步驟:「Drag to move」→ 拖曳一段距離 →「Release to attack」→ 放手 →「Nice!」→ finished。

signal finished()

enum Step { MOVE, RELEASE, DONE }

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")
const DRAG_DISTANCE: float = 12.0
const DONE_HOLD_SEC: float = 0.8

var step: Step = Step.MOVE
var _label: Label
var _press_at: Variant = null
var _done_left: float = 0.0


func _ready() -> void:
	StubUI.prepare_root(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := SafeArea.get_safe_rect()
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override(&"font_color", StubUI.ACCENT)
	_label.position = Vector2(safe.position.x, Layout.PLAYER_START.y + 28.0)
	_label.size = Vector2(safe.size.x, 12)
	add_child(_label)
	_show()


func _process(delta: float) -> void:
	if step == Step.DONE:
		_done_left -= delta
		if _done_left <= 0.0:
			set_process(false)
			finished.emit()


func _input(event: InputEvent) -> void:
	var pressed: Variant = null
	var position_now: Variant = null
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		pressed = (event as InputEventScreenTouch).pressed
		position_now = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		position_now = (event as InputEventScreenDrag).position
	else:
		return
	match step:
		Step.MOVE:
			if pressed == true:
				_press_at = position_now
			elif pressed == false:
				_press_at = null
			elif _press_at != null and (position_now as Vector2).distance_to(_press_at) >= DRAG_DISTANCE:
				step = Step.RELEASE
				_show()
		Step.RELEASE:
			if pressed == false:
				step = Step.DONE
				_done_left = DONE_HOLD_SEC
				_show()


func _show() -> void:
	match step:
		Step.MOVE:
			_label.text = "Drag to move"
		Step.RELEASE:
			_label.text = "Release to attack"
		Step.DONE:
			_label.text = "Nice!"
