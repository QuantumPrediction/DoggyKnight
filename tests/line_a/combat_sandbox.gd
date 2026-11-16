extends Node2D
## A 線戰鬥沙盒(M1 驗收):可獨立執行,不依賴 B、C、D 線。
##
## 執行:godot --path . res://tests/line_a/combat_sandbox.tscn
## 操作:按住畫面任何地方拖曳 → 金毛移動;放手 → 停下自動揮劍。
## 上方的除錯按鈕(英文縮寫,只在沙盒出現)可生成敵人、同伴,加把戲,填滿忠誠度;
## 右下角 ULT 是必殺技按鈕的佔位(正式按鈕由 C 線的 HUD 提供)。
## M3:上方小字另外顯示連擊數(combo_changed)與頭目生命(boss_hp_changed);
## Win 模擬過關(level_completed:金毛與鬥牛犬歡呼);Shake 讓鏡頭震一下。
## Esc(= Android 返回鍵)暫停 / 繼續。所有按鈕都在群組 ui_touch_blocker,按按鈕不會觸發搖桿。

const ARENA_SCENE: PackedScene = preload("res://game/combat/arena.tscn")
const BLOCKER_GROUP: StringName = &"ui_touch_blocker"
const FONT_SIZE := 8
const BUTTON_SIZE := Vector2(34, 13)
const BUTTON_COLUMNS := 5
const BUTTON_GAP := 2.0
const ULT_SIZE := Vector2(28, 28)

var arena: CombatArena

var _ui: Control
var _readout: Label
var _paused_label: Label
var _ult_button: Button
var _buttons: Array[Button] = []
var _vigor: Vector2i = Vector2i.ZERO
var _loyalty: Vector2 = Vector2(0, 100)
var _exp: int = 0
var _kills: int = 0
var _boss_phase: int = 0
var _combo: int = 0
var _best_combo: int = 0
var _boss_hp: Vector2i = Vector2i.ZERO
var _spawn_index: int = 0


func _ready() -> void:
	GameState.reset_run()
	EventBus.vigor_changed.connect(func(current: int, maximum: int) -> void:
		_vigor = Vector2i(current, maximum)
		_refresh())
	EventBus.loyalty_changed.connect(func(current: float, maximum: float) -> void:
		_loyalty = Vector2(current, maximum)
		_refresh())
	EventBus.exp_collected.connect(func(amount: int) -> void:
		_exp += amount
		_refresh())
	EventBus.enemy_died.connect(func(_id: StringName, _pos: Vector2, _value: int) -> void:
		_kills += 1
		_refresh())
	EventBus.boss_phase_changed.connect(func(phase: int) -> void:
		_boss_phase = phase
		_refresh())
	EventBus.trick_chosen.connect(func(_id: StringName) -> void: _refresh.call_deferred())
	EventBus.combo_changed.connect(func(count: int) -> void:
		_combo = count
		_best_combo = maxi(_best_combo, count)
		_refresh())
	EventBus.boss_hp_changed.connect(func(current: int, maximum: int) -> void:
		_boss_hp = Vector2i(current, maximum)
		_refresh())
	EventBus.back_requested.connect(_toggle_pause)
	EventBus.app_backgrounded.connect(func() -> void: _set_paused(true))
	_build_ui()
	_new_arena()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()


func _new_arena() -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = ARENA_SCENE.instantiate() as CombatArena
	add_child(arena)
	move_child(arena, 0)
	_refresh()


# --- 按鈕 -----------------------------------------------------------------------

func _spawn(enemy_id: StringName) -> void:
	var points := arena.get_spawn_points()
	if points.is_empty():
		return
	arena.spawn_enemy(enemy_id, points[_spawn_index % points.size()])
	_spawn_index += 1


func _spawn_many(enemy_id: StringName, count: int) -> void:
	for i in count:
		_spawn(enemy_id)


func _spawn_boss() -> void:
	arena.spawn_enemy(&"black_knight", Vector2(Layout.ARENA_RECT.get_center().x, Layout.ARENA_RECT.position.y + 40))


func _add_trick(trick_id: StringName) -> void:
	EventBus.trick_chosen.emit(trick_id)
	GameState.active_tricks.append(trick_id)


func _fill_loyalty() -> void:
	var player := arena.get_player() as GoldiePlayer
	if player != null:
		player.add_loyalty(player.tuning.loyalty_max)


func _heal() -> void:
	var player := arena.get_player()
	if player != null:
		player.call(&"heal", GameState.player_stats.max_vigor)


func _reset() -> void:
	_set_paused(false)
	GameState.reset_run()
	_exp = 0
	_kills = 0
	_boss_phase = 0
	_combo = 0
	_best_combo = 0
	_boss_hp = Vector2i.ZERO
	_new_arena()


func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	if _paused_label != null:
		_paused_label.visible = value


# --- 介面(除錯用,英文) -----------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_ui.theme = theme
	layer.add_child(_ui)

	_readout = Label.new()
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.add_theme_color_override(&"font_color", Color.WHITE)
	_readout.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_readout.add_theme_constant_override(&"outline_size", 2)
	_readout.add_theme_constant_override(&"line_spacing", -2)
	_ui.add_child(_readout)

	var actions: Array = [
		["Scare", _spawn.bind(&"scarecrow")],
		["Elite", _spawn.bind(&"scarecrow_elite")],
		["Crow", _spawn.bind(&"crow")],
		["Boss", _spawn_boss],
		["Dog", func() -> void: arena.spawn_companion(&"bulldog")],
		["10xS", _spawn_many.bind(&"scarecrow", 10)],
		["Loyal", _fill_loyalty],
		["Heal", _heal],
		["+Shk", _add_trick.bind(&"shake")],
		["+Spn", _add_trick.bind(&"spin")],
		["+Brk", _add_trick.bind(&"bark")],
		["Reset", _reset],
		["Win", func() -> void: EventBus.level_completed.emit(&"sandbox")],
		["Shake", func() -> void: arena.add_trauma(0.6)],
	]
	for action: Array in actions:
		var button := _make_button(action[0])
		button.pressed.connect(action[1])
		_buttons.append(button)

	_ult_button = _make_button("ULT")
	_ult_button.disabled = true
	_ult_button.pressed.connect(func() -> void: EventBus.ultimate_requested.emit())

	_paused_label = Label.new()
	_paused_label.text = "PAUSED (Esc)"
	_paused_label.visible = false
	_paused_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paused_label.add_theme_constant_override(&"outline_size", 2)
	_paused_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_ui.add_child(_paused_label)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_to_group(BLOCKER_GROUP)
	_ui.add_child(button)
	return button


func _layout_ui() -> void:
	var game := SafeArea.get_game_rect()
	var safe := SafeArea.get_safe_rect()
	var left := maxf(game.position.x, safe.position.x) + 2.0
	var top := maxf(game.position.y, safe.position.y) + 1.0
	_readout.position = Vector2(left, top)
	_readout.size = Vector2(176, 20)
	_readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	for i in _buttons.size():
		var col := i % BUTTON_COLUMNS
		@warning_ignore("integer_division")
		var row := i / BUTTON_COLUMNS
		var button := _buttons[i]
		button.position = Vector2(left + col * (BUTTON_SIZE.x + BUTTON_GAP), top + 20.0 + row * (BUTTON_SIZE.y + BUTTON_GAP))
		button.size = BUTTON_SIZE
	# 必殺技按鈕:戰鬥區右下角、安全區之內(DEV_PLAN 4.9)。
	var corner := game.position + Layout.ARENA_RECT.end - ULT_SIZE - Vector2(4, 4)
	corner.x = minf(corner.x, safe.end.x - ULT_SIZE.x - 2.0)
	corner.y = minf(corner.y, safe.end.y - ULT_SIZE.y - 2.0)
	_ult_button.position = corner
	_ult_button.size = ULT_SIZE
	_paused_label.position = game.get_center() - Vector2(28, 4)


func _refresh() -> void:
	if _readout == null:
		return
	var tricks := "-"
	var player := arena.get_player() as GoldiePlayer if arena != null else null
	if player != null and player.abilities != null:
		tricks = "shk%d spn%d brk%d" % [player.abilities.stacks(&"shake"), player.abilities.stacks(&"spin"),
				player.abilities.stacks(&"bark")]
	_readout.text = "VIG %d/%d  EXP %d  LOY %d/%d  COMBO %d (best %d)\nKO %d  %s  boss P%d %d/%d  foes %d" % [
		_vigor.x, _vigor.y, _exp, int(_loyalty.x), int(_loyalty.y), _combo, _best_combo, _kills, tricks,
		_boss_phase, _boss_hp.x, _boss_hp.y, get_tree().get_nodes_in_group(&"enemy").size()]
	if _ult_button != null:
		_ult_button.disabled = _loyalty.x < _loyalty.y


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 15 == 0:
		_refresh()
