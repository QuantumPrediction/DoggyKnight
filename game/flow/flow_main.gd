class_name FlowMain
extends Node
## 整個遊戲的流程(B1、B7、B8、B9)。game/flow/main.tscn 的根節點;開機後顯示標題。
##
## 流程:標題 → 關卡 →(升級選把戲)→ 過關結算 →(1-2、1-4 之後)營地 → 下一關
##       金毛倒下 → 失敗結算 → 再試一次(立即回到戰鬥)或回標題
##       打敗黑騎士(1-6)→ 結算(is_final = true)→ 回標題
## 所有畫面切換都在這個檔案裡。
##
## 節點(在 _ready 以程式建立):
##   Main(本節點,PROCESS_MODE_ALWAYS:暫停時仍要處理返回鍵與畫面切換)
##   ├─ Progression  經驗、升級、把戲(RunProgression,跨關保留)
##   ├─ World        PROCESS_MODE_PAUSABLE;放 LevelSession → 場地(arena)
##   ├─ Camp         PROCESS_MODE_PAUSABLE;營地場景放這裡
##   ├─ HudLayer     CanvasLayer 第 10 層:HUD
##   ├─ OverlayLayer CanvasLayer 第 20 層:把戲選擇、暫停畫面
##   └─ ScreenLayer  CanvasLayer 第 30 層:標題、結算、失敗、製作名單、離開確認
##
## 別線的零件按路徑載入(FlowParts),找不到就用 game/flow/stubs/ 的替身。
## 介面場景實例化、加進 CanvasLayer 之後才呼叫 setup(...)(所以 setup 可以用 @onready 節點)。
##
## 暫停(DEV_PLAN 4.9):get_tree().paused = 暫停選單開著 或 正在選把戲。
## 只有暫停選單會發 game_paused。
##
## 存檔(B9):每關開始、過關、切到背景、回標題、關閉視窗時寫入(同步,不用 await)。

signal state_changed(new_state: State)

enum State { BOOT, TITLE, LEVEL, RESULTS, FAILURE, CAMP }

const DEFAULT_CHAPTER: String = "res://data/levels/chapter_1.tres"
const DEFAULT_DIFFICULTY: String = "res://game/progression/difficulty.tres"

## 這一章的關卡;留空就用第一章。
@export var chapter: ChapterData
## 難度參數;留空就用 game/progression/difficulty.tres。
@export var difficulty: DifficultyData
## 存檔位置(測試與沙盒用別的檔名,才不會蓋掉正式存檔)。
@export var save_path: String = SaveStore.DEFAULT_PATH
## true:一律用 game/flow/stubs/ 的替身(沙盒用,不受別線影響)。
@export var use_stand_ins: bool = false
## 亂數種子;0 = 每次不同。測試用固定種子,把戲與出生點就每次一樣。
@export var rng_seed: int = 0

## 平台名稱(只有 "Android" 會在標題按返回鍵時詢問離開)。測試可以改。
var platform_name: String = OS.get_name()
## 確定離開遊戲時呼叫;預設 get_tree().quit。測試可以換掉。
var quit_handler: Callable

var state: State = State.BOOT
var progression: RunProgression
var save_store: SaveStore

var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reached_level: int = 0
var _level_index: int = 0
var _snapshot: Dictionary = {}
var _last_result: Dictionary = {}
var _pause_open: bool = false
var _choice_open: bool = false

var _world: Node
var _camp_holder: Node
var _hud_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _screen_layer: CanvasLayer

var _session: LevelSession
var _hud: Node
var _trick_choice: Node
var _pause: Node
var _screen: Node
var _credits: Node
var _quit_dialog: Node
var _camp: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if chapter == null:
		chapter = load(DEFAULT_CHAPTER) as ChapterData
	if difficulty == null:
		difficulty = load(DEFAULT_DIFFICULTY) as DifficultyData
	if not quit_handler.is_valid():
		quit_handler = get_tree().quit
	if rng_seed != 0:
		_spawn_rng.seed = rng_seed + 1
	else:
		_spawn_rng.randomize()
	_build_nodes()

	progression = RunProgression.new()
	progression.name = "Progression"
	progression.setup(difficulty, rng_seed)
	progression.choice_opened.connect(_on_choice_opened)
	progression.choice_closed.connect(_on_choice_closed)
	add_child(progression)

	save_store = SaveStore.new(save_path)
	_load_save()

	EventBus.back_requested.connect(_on_back_requested)
	EventBus.app_backgrounded.connect(_on_app_backgrounded)
	EventBus.resume_requested.connect(_on_resume_requested)
	EventBus.quit_to_title_requested.connect(_on_quit_to_title_requested)
	EventBus.camp_left.connect(_on_camp_left)
	show_title()


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.back_requested, _on_back_requested],
		[EventBus.app_backgrounded, _on_app_backgrounded],
		[EventBus.resume_requested, _on_resume_requested],
		[EventBus.quit_to_title_requested, _on_quit_to_title_requested],
		[EventBus.camp_left, _on_camp_left],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	get_tree().paused = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_store != null:
		save_now()


# --- 給測試與沙盒讀取的狀態 ---

func has_save() -> bool:
	return _reached_level > 0


func get_reached_level() -> int:
	return _reached_level


func get_session() -> LevelSession:
	return _session


func get_arena() -> Node:
	return _session.arena if _session != null else null


func get_screen() -> Node:
	return _screen


func get_credits() -> Node:
	return _credits


func get_quit_dialog() -> Node:
	return _quit_dialog


func get_camp() -> Node:
	return _camp


func get_hud() -> Node:
	return _hud


func get_trick_choice() -> Node:
	return _trick_choice


func get_pause_screen() -> Node:
	return _pause


func get_last_result() -> Dictionary:
	return _last_result.duplicate()


func get_level_index() -> int:
	return _level_index


func is_pause_open() -> bool:
	return _pause_open


func is_choice_open() -> bool:
	return _choice_open


# --- 存檔 ---

func save_now() -> bool:
	return save_store.write(_reached_level, GameState.snacks, GameState.sound_on)


func _load_save() -> void:
	var data := save_store.read()
	if data.is_empty():
		_reached_level = 0
		return
	_reached_level = clampi(data["level_index"], 0, maxi(0, chapter.level_count() - 1))
	GameState.snacks = data["snacks"]
	GameState.sound_on = data["sound_on"]


# --- 畫面切換 ---

func show_title() -> void:
	_leave_current()
	_set_state(State.TITLE)
	_screen = _add_ui(FlowParts.TITLE, _screen_layer)
	FlowParts.call_if_present(_screen, &"setup", [has_save()])
	FlowParts.connect_if_present(_screen, &"new_game_pressed", _on_title_new_game)
	FlowParts.connect_if_present(_screen, &"continue_pressed", _on_title_continue)
	FlowParts.connect_if_present(_screen, &"credits_pressed", _on_title_credits)


## 新遊戲:重設這一輪(數值、把戲、等級、活力、下一關加成),從第 1 關開始。
func start_new_game() -> void:
	GameState.reset_run()
	progression.reset_run()
	_start_level(0)


## 繼續:從存檔的關卡開始全新的一輪(DEV_PLAN B9:存檔只記到達的關卡)。
func continue_game() -> void:
	var index := _reached_level
	GameState.reset_run()
	GameState.level_index = index
	progression.reset_run()
	_start_level(index)


## 失敗後再試一次:還原這一關開始時的快照,活力補滿,立即重新開始。
func retry_level() -> void:
	progression.restore_snapshot(_snapshot)
	GameState.vigor = GameState.player_stats.max_vigor
	_start_level(_level_index)


func _start_level(index: int) -> void:
	var level := chapter.get_level(index)
	if level == null:
		push_error("FlowMain: 沒有第 %d 關" % index)
		show_title()
		return
	_leave_current()
	_level_index = index
	GameState.level_index = index
	_snapshot = progression.take_snapshot()
	_reached_level = index
	save_now()

	# 介面先建立,才收得到主角進場時發出的 vigor_changed。
	_hud = _add_ui(FlowParts.HUD, _hud_layer)
	_trick_choice = _add_ui(FlowParts.TRICK_CHOICE, _overlay_layer)
	_pause = _add_ui(FlowParts.PAUSE, _overlay_layer)

	_session = LevelSession.new()
	_session.name = "LevelSession"
	_session.setup(level, index, difficulty, FlowParts.arena_for(level, use_stand_ins), _spawn_rng)
	_session.cleared.connect(_on_level_cleared)
	_session.finished.connect(_on_level_finished)
	_world.add_child(_session)
	_set_state(State.LEVEL)
	_session.start(progression)


func _on_level_cleared() -> void:
	# 過關:下一關加成用完歸零(失敗重試時保留,見 retry_level)。
	GameState.next_level_bonus = 0.0
	_reached_level = 0 if chapter.is_last(_level_index) else _level_index + 1
	save_now()


func _on_level_finished(victory: bool) -> void:
	progression.end_level()
	_close_pause()
	# 讓場地停在結算畫面之下(敵人不再移動)。
	_world.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	_last_result = _build_result(victory)
	if victory:
		_set_state(State.RESULTS)
		_screen = _add_ui(FlowParts.RESULTS, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate()])
		FlowParts.connect_if_present(_screen, &"continue_pressed", _on_results_continue)
	else:
		_set_state(State.FAILURE)
		_screen = _add_ui(FlowParts.FAILURE, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate()])
		FlowParts.connect_if_present(_screen, &"retry_pressed", _on_failure_retry)
		FlowParts.connect_if_present(_screen, &"title_pressed", _on_failure_title)


## 結算資料(DEV_PLAN 4.9 的九個鍵)。
func _build_result(victory: bool) -> Dictionary:
	var level := chapter.get_level(_level_index)
	var tricks: Array = []
	tricks.append_array(progression.tricks_this_level)
	return {
		"level_id": level.id,
		"level_name": level.display_name,
		"victory": victory,
		"time_sec": _session.time_sec if _session != null else 0.0,
		"kills": _session.kills if _session != null else 0,
		"tricks": tricks,
		"hero_level": GameState.hero_level,
		"next_is_camp": victory and chapter.has_camp_after(_level_index),
		"is_final": victory and chapter.is_last(_level_index),
	}


func _enter_camp() -> void:
	_leave_current()
	_set_state(State.CAMP)
	var scene := FlowParts.scene_for(FlowParts.CAMP, use_stand_ins)
	_camp = scene.instantiate() if scene != null else null
	if _camp == null:
		push_warning("FlowMain: 沒有營地場景,直接進下一關")
		_start_level(_level_index + 1)
		return
	_camp.name = "Camp"
	_camp_holder.add_child(_camp)


func _finish_chapter() -> void:
	show_title()


## 移除目前的關卡、營地、畫面,取消暫停。
func _leave_current() -> void:
	if progression != null:
		progression.end_level()
	_pause_open = false
	_choice_open = false
	get_tree().paused = false
	if _session != null:
		_session.teardown()
		_free_node(_session)
		_session = null
	for node in [_hud, _trick_choice, _pause, _screen, _credits, _quit_dialog, _camp]:
		_free_node(node)
	_hud = null
	_trick_choice = null
	_pause = null
	_screen = null
	_credits = null
	_quit_dialog = null
	_camp = null
	# 用 set_deferred:與 _on_level_finished 的 set_deferred 依先後次序生效。
	_world.set_deferred(&"process_mode", Node.PROCESS_MODE_PAUSABLE)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)


func _add_ui(path: String, layer: CanvasLayer) -> Node:
	var scene := FlowParts.scene_for(path, use_stand_ins)
	if scene == null:
		push_error("FlowMain: 無法載入 %s,也沒有替身" % path)
		return null
	var node := scene.instantiate()
	layer.add_child(node)
	return node


func _free_node(node: Variant) -> void:
	if is_instance_valid(node) and node is Node:
		var n := node as Node
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()


func _build_nodes() -> void:
	_world = _make_child(Node.new(), "World") as Node
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	_camp_holder = _make_child(Node.new(), "Camp") as Node
	_camp_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud_layer = _make_child(CanvasLayer.new(), "HudLayer") as CanvasLayer
	_hud_layer.layer = 10
	_overlay_layer = _make_child(CanvasLayer.new(), "OverlayLayer") as CanvasLayer
	_overlay_layer.layer = 20
	_screen_layer = _make_child(CanvasLayer.new(), "ScreenLayer") as CanvasLayer
	_screen_layer.layer = 30


func _make_child(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node


# --- 暫停 ---

func _apply_pause() -> void:
	get_tree().paused = state == State.LEVEL and (_pause_open or _choice_open)


func _open_pause() -> void:
	if state != State.LEVEL or _pause_open or _choice_open:
		return
	_pause_open = true
	_apply_pause()
	EventBus.game_paused.emit(true)


func _close_pause() -> void:
	if not _pause_open:
		return
	_pause_open = false
	_apply_pause()
	EventBus.game_paused.emit(false)


func _on_choice_opened() -> void:
	_choice_open = true
	_apply_pause()


func _on_choice_closed() -> void:
	_choice_open = false
	_apply_pause()


# --- EventBus ---

func _on_back_requested() -> void:
	match state:
		State.TITLE:
			if _quit_dialog != null:
				_close_quit_dialog()
			elif _credits != null:
				_close_credits()
			elif platform_name == "Android":
				_open_quit_dialog()
			# iOS 與桌面:沒有「離開」這回事,略過。
		State.LEVEL:
			if _choice_open:
				return            # 正在選把戲:返回鍵無效
			if _pause_open:
				_close_pause()
			else:
				_open_pause()
		_:
			pass                  # 結算、失敗、營地:略過


func _on_app_backgrounded() -> void:
	# 先存檔(同步完成),再暫停。
	save_now()
	if state == State.LEVEL and not _choice_open:
		_open_pause()


func _on_resume_requested() -> void:
	if state == State.LEVEL:
		_close_pause()
		save_now()            # 暫停畫面可能改了音效開關


func _on_quit_to_title_requested() -> void:
	if state != State.LEVEL:
		return
	save_now()
	_close_pause()
	_transition(show_title)


func _on_camp_left() -> void:
	if state != State.CAMP:
		return
	_transition(_start_level.bind(_level_index + 1))


# --- 介面訊號 ---
# 畫面切換延到這一格的最後才做(call_deferred),避免在按鈕自己的訊號裡移除按鈕;
# 同時先把狀態設為 BOOT,連按兩下也只會切換一次。

func _transition(step: Callable) -> void:
	_set_state(State.BOOT)
	step.call_deferred()


func _title_is_idle() -> bool:
	return state == State.TITLE and _credits == null and _quit_dialog == null


func _on_title_new_game() -> void:
	if _title_is_idle():
		_transition(start_new_game)


func _on_title_continue() -> void:
	if _title_is_idle() and has_save():
		_transition(continue_game)


func _on_title_credits() -> void:
	if not _title_is_idle():
		return
	_credits = _add_ui(FlowParts.CREDITS, _screen_layer)
	FlowParts.connect_if_present(_credits, &"closed", _close_credits)


func _close_credits() -> void:
	_free_node.call_deferred(_credits)
	_credits = null


func _open_quit_dialog() -> void:
	var dialog := QuitConfirm.new()
	dialog.confirmed.connect(_on_quit_confirmed)
	dialog.cancelled.connect(_close_quit_dialog)
	_screen_layer.add_child(dialog)
	_quit_dialog = dialog


func _close_quit_dialog() -> void:
	_free_node.call_deferred(_quit_dialog)
	_quit_dialog = null


func _on_quit_confirmed() -> void:
	save_now()
	quit_handler.call()


func _on_results_continue() -> void:
	if state != State.RESULTS:
		return
	if _last_result.get("is_final", false):
		_transition(_finish_chapter)
	elif _last_result.get("next_is_camp", false):
		_transition(_enter_camp)
	else:
		_transition(_start_level.bind(_level_index + 1))


func _on_failure_retry() -> void:
	if state == State.FAILURE:
		_transition(retry_level)


func _on_failure_title() -> void:
	if state == State.FAILURE:
		_transition(show_title)
