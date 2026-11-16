class_name FlowMain
extends Node
## 整個遊戲的流程(B1、B7、B8、B9;M3 打磨 BP1 至 BP6)。game/flow/main.tscn 的根節點;開機後顯示標題。
##
## 流程:標題 → 關卡 →(升級選把戲)→ 過關結算 →(1-2、1-4 之後)營地 → 下一關
##       金毛倒下 → 失敗結算 → 再試一次(立即回到戰鬥)或回標題
##       打敗黑騎士(1-6)→ 結算(is_final = true)→ 回標題
## 所有畫面切換都在這個檔案裡,而且都經過轉場(_go:蓋住 → 換畫面 → 露出;見 FlowTransition)。
## 過關與失敗的結算畫面直接疊在場地上(不蓋住),讓慶祝與結算連成一氣。
##
## 一關的開始(BP1):轉場蓋住時組裝場地(LevelSession.build),畫面露出後才發 level_started
## (LevelSession.begin),HUD 播標題卡;intro_duration 秒之後第一波。1-1 第一次玩時,第一波開始時
## 加入教學提示(BP4,第 20 層,不暫停遊戲、不吃掉觸控)。
##
## 節點(在 _ready 以程式建立):
##   Main(本節點,PROCESS_MODE_ALWAYS:暫停時仍要處理返回鍵與畫面切換)
##   ├─ Progression   經驗、升級、把戲(RunProgression,跨關保留)
##   ├─ World         PROCESS_MODE_PAUSABLE;放 LevelSession → 場地(arena)
##   ├─ Camp          PROCESS_MODE_PAUSABLE;營地場景放這裡
##   ├─ HudLayer      CanvasLayer 第 10 層:HUD
##   ├─ OverlayLayer  CanvasLayer 第 20 層:教學提示(最底)、把戲選擇、暫停畫面
##   ├─ ScreenLayer   CanvasLayer 第 30 層:標題、結算、失敗、製作名單、離開確認
##   └─ TransitionHost 轉場(ui/transition/transition.tscn,CanvasLayer 第 100 層;不存在就不播)
##
## 別線的零件按路徑載入(FlowParts),找不到就用 game/flow/stubs/ 的替身。
## 介面場景實例化、加進 CanvasLayer 之後才呼叫 setup(...)(所以 setup 可以用 @onready 節點)。
##
## 暫停(DEV_PLAN 4.9):get_tree().paused = 暫停選單開著 或 正在選把戲。
## 只有暫停選單會發 game_paused;暫停選單開著時音樂壓低(Music.set_ducked)。
##
## 音樂(BP5,DEV_PLAN 4.10):標題 title;每關開始 field(頭目關 boss);過關 victory
## (打完第一章 chapter_clear);失敗 fail。營地的 camp 由 D 線自己播。
##
## 星級(BP3):過關時依 StarRating 計算,最佳星數寫進 GameState.best_stars 並立即存檔。
##
## 存檔(B9、BP6):每關開始、過關、切到背景、關閉暫停選單、回標題、關閉視窗、看完教學時寫入
## (同步,不用 await)。

signal state_changed(new_state: State)

## SWITCHING:轉場中(舊畫面不再接受按鈕,新畫面還沒出現)。
enum State { BOOT, TITLE, LEVEL, RESULTS, FAILURE, CAMP, SWITCHING }

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
## 背景音樂(Music Autoload:play / stop / set_ducked / refresh)。留空就用 /root/Music;測試可以換掉。
var music: Object

var state: State = State.BOOT
var progression: RunProgression
var save_store: SaveStore
var transition: FlowTransition

var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reached_level: int = 0
var _camp_pending: bool = false
var _level_index: int = 0
var _snapshot: Dictionary = {}
var _last_result: Dictionary = {}
var _clear_record: Dictionary = {}
var _pause_open: bool = false
var _choice_open: bool = false
var _switch_serial: int = 0
var _switching: bool = false
var _session_waiting: bool = false
var _pause_when_ready: bool = false

var _world: Node
var _camp_holder: Node
var _hud_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _screen_layer: CanvasLayer

var _session: LevelSession
var _hud: Node
var _trick_choice: Node
var _pause: Node
var _tutorial: Node
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
	if music == null:
		music = get_node_or_null(^"/root/Music")
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

	transition = FlowTransition.new()
	transition.name = "TransitionHost"
	add_child(transition)
	transition.setup(FlowParts.optional_scene(FlowParts.TRANSITION, use_stand_ins), difficulty)

	save_store = SaveStore.new(save_path)
	_load_save()

	EventBus.back_requested.connect(_on_back_requested)
	EventBus.app_backgrounded.connect(_on_app_backgrounded)
	EventBus.resume_requested.connect(_on_resume_requested)
	EventBus.quit_to_title_requested.connect(_on_quit_to_title_requested)
	EventBus.camp_left.connect(_on_camp_left)
	show_title()


func _exit_tree() -> void:
	_switch_serial += 1          # 讓還在等轉場的步驟不再繼續
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


## 存檔記錄「上一關過關後應先進營地」(繼續冒險時先回到營地)。
func is_camp_pending() -> bool:
	return _camp_pending


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


func get_tutorial() -> Node:
	return _tutorial


func get_last_result() -> Dictionary:
	return _last_result.duplicate()


func get_level_index() -> int:
	return _level_index


func is_pause_open() -> bool:
	return _pause_open


func is_choice_open() -> bool:
	return _choice_open


## 正在轉場(由按下按鈕到新畫面完全露出)。
func is_switching() -> bool:
	return _switching


## 關卡已開始(已發 level_started,正在進行)。
func is_level_running() -> bool:
	return state == State.LEVEL and _session != null and _session.is_playing()


# --- 存檔 ---

func save_now() -> bool:
	return save_store.write_data({
		"level_index": _reached_level,
		"snacks": GameState.snacks,
		"sound_on": GameState.sound_on,
		"music_on": GameState.music_on,
		"haptics_on": GameState.haptics_on,
		"tutorial_done": GameState.tutorial_done,
		"best_stars": GameState.best_stars,
		"camp_pending": _camp_pending and _reached_level > 0,
	})


func _load_save() -> void:
	var data := save_store.read()
	if data.is_empty():
		_reached_level = 0
		_camp_pending = false
		return
	_reached_level = clampi(data["level_index"], 0, maxi(0, chapter.level_count() - 1))
	_camp_pending = data["camp_pending"] and _reached_level > 0 and chapter.has_camp_after(_reached_level - 1)
	GameState.snacks = data["snacks"]
	GameState.sound_on = data["sound_on"]
	GameState.music_on = data["music_on"]
	GameState.haptics_on = data["haptics_on"]
	GameState.tutorial_done = data["tutorial_done"]
	GameState.best_stars = (data["best_stars"] as Dictionary).duplicate()


# --- 畫面切換 ---

func show_title() -> void:
	_leave_current()
	_set_state(State.TITLE)
	_screen = _add_ui(FlowParts.TITLE, _screen_layer)
	FlowParts.call_if_present(_screen, &"setup", [has_save()])
	FlowParts.connect_if_present(_screen, &"new_game_pressed", _on_title_new_game)
	FlowParts.connect_if_present(_screen, &"continue_pressed", _on_title_continue)
	FlowParts.connect_if_present(_screen, &"credits_pressed", _on_title_credits)
	_music(&"play", [&"title"])


## 新遊戲:重設這一輪(數值、把戲、等級、活力、下一關加成),從第 1 關開始。
func start_new_game() -> void:
	GameState.reset_run()
	progression.reset_run()
	_camp_pending = false
	_start_level(0)


## 繼續:從存檔的關卡開始全新的一輪(DEV_PLAN B9:存檔只記到達的關卡)。
## 存檔記錄了「應先進營地」(上一關過關後、進營地之前 App 被關掉)時,先回到那個營地。
func continue_game() -> void:
	var index := _reached_level
	GameState.reset_run()
	progression.reset_run()
	if _camp_pending and index > 0 and chapter.has_camp_after(index - 1):
		_level_index = index - 1
		_enter_camp()
		return
	_camp_pending = false
	GameState.level_index = index
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
	_camp_pending = false
	_clear_record = {}
	save_now()

	# 介面先建立,才收得到主角進場時發出的 vigor_changed。
	_hud = _add_ui(FlowParts.HUD, _hud_layer)
	_trick_choice = _add_ui(FlowParts.TRICK_CHOICE, _overlay_layer)
	_pause = _add_ui(FlowParts.PAUSE, _overlay_layer)

	_session = LevelSession.new()
	_session.name = "LevelSession"
	_session.setup(level, index, difficulty, FlowParts.arena_for(level, use_stand_ins), _spawn_rng)
	_session.arriving = _arriving_companions(index)
	_session.cleared.connect(_on_level_cleared)
	_session.finished.connect(_on_level_finished)
	_session.intro_finished.connect(_on_intro_finished)
	_world.add_child(_session)
	_session.build()
	_set_state(State.LEVEL)
	_music(&"play", [&"boss" if level.is_boss else &"field"])
	if _switching:
		_session_waiting = true        # 轉場露出畫面之後才開始(_go)
	else:
		_begin_level()


## 這一關才加入的同伴(上一關沒有的),例如 1-3 的鬥牛犬:等畫面露出才出場。
func _arriving_companions(index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var level := chapter.get_level(index)
	var previous := chapter.get_level(index - 1)
	for companion_id in level.companions:
		if previous == null or not previous.companions.has(companion_id):
			result.append(companion_id)
	return result


## 發 level_started、開始開場倒數。
func _begin_level() -> void:
	_session_waiting = false
	if state == State.LEVEL and _session != null and is_instance_valid(_session):
		_session.begin(progression)


func _on_intro_finished() -> void:
	_maybe_show_tutorial()


func _on_level_cleared() -> void:
	var level := chapter.get_level(_level_index)
	# 過關:下一關加成用完歸零(失敗重試時保留,見 retry_level)。
	GameState.next_level_bonus = 0.0
	_reached_level = 0 if chapter.is_last(_level_index) else _level_index + 1
	_camp_pending = chapter.has_camp_after(_level_index) and _reached_level > 0
	_clear_record = _record_stars(level)
	if _level_index == 0:
		GameState.tutorial_done = true      # 打完 1-1:已懂得操作,教學不再出現
	_free_node(_tutorial)
	_tutorial = null
	save_now()
	_music(&"play", [&"chapter_clear" if chapter.is_last(_level_index) else &"victory"])
	if not level.is_boss:
		Haptics.play(&"medium")         # 打倒頭目的震動由 A 線負責(heavy)


## 計算這次過關的星數,更新並傳回 {"stars", "goals", "previous", "new_best"}。
func _record_stars(level: LevelData) -> Dictionary:
	var goals := StarRating.goals(level, true, _session.time_sec, _session.damage_taken)
	var stars := StarRating.count(goals)
	var key := String(level.id)
	var had_record := GameState.best_stars.has(key)
	var previous := int(GameState.best_stars.get(key, 0))
	GameState.best_stars[key] = maxi(previous, stars)
	return {"stars": stars, "goals": goals, "previous": previous, "new_best": had_record and stars > previous}


func _on_level_finished(victory: bool) -> void:
	progression.end_level()
	_close_pause()
	# 讓場地停在結算畫面之下(敵人不再移動)。
	_world.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	_last_result = _build_result(victory)
	if victory:
		_set_state(State.RESULTS)
		_screen = _add_ui(FlowParts.RESULTS, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate(true)])
		FlowParts.connect_if_present(_screen, &"continue_pressed", _on_results_continue)
	else:
		_music(&"play", [&"fail"])
		_set_state(State.FAILURE)
		_screen = _add_ui(FlowParts.FAILURE, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate(true)])
		FlowParts.connect_if_present(_screen, &"retry_pressed", _on_failure_retry)
		FlowParts.connect_if_present(_screen, &"title_pressed", _on_failure_title)


## 結算資料:DEV_PLAN 4.9 的九個鍵 + 4.10 的六個鍵 + damage_taken(這一關受到的傷害)。
func _build_result(victory: bool) -> Dictionary:
	var level := chapter.get_level(_level_index)
	var tricks: Array = []
	tricks.append_array(progression.tricks_this_level)
	var time_sec := _session.time_sec if _session != null else 0.0
	var damage := _session.damage_taken if _session != null else 0
	var goals: Array[Dictionary] = []
	var stars := 0
	var new_best := false
	if victory and not _clear_record.is_empty():
		goals.assign(_clear_record["goals"])
		stars = _clear_record["stars"]
		new_best = _clear_record["new_best"]
	else:
		goals = StarRating.goals(level, false, time_sec, damage)
	return {
		"level_id": level.id,
		"level_name": level.display_name,
		"victory": victory,
		"time_sec": time_sec,
		"kills": _session.kills if _session != null else 0,
		"tricks": tricks,
		"hero_level": GameState.hero_level,
		"next_is_camp": victory and chapter.has_camp_after(_level_index),
		"is_final": victory and chapter.is_last(_level_index),
		"stars": stars,
		"star_goals": goals,
		"best_stars": int(GameState.best_stars.get(String(level.id), 0)),
		"new_best": new_best,
		"level_index": _level_index,
		"level_count": chapter.level_count(),
		"damage_taken": damage,
	}


## 營地(D 線合約):營地顯示期間 GameState.level_index = 剛打完那一關的索引(1-2 之後 = 1)。
func _enter_camp() -> void:
	_leave_current()
	_set_state(State.CAMP)
	GameState.level_index = _level_index
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
	if _pause_open:
		EventBus.game_paused.emit(false)
		_music(&"set_ducked", [false])
	_pause_open = false
	_choice_open = false
	_session_waiting = false
	get_tree().paused = false
	if _session != null:
		_session.teardown()
		_free_node(_session)
		_session = null
	for node in [_hud, _trick_choice, _pause, _tutorial, _screen, _credits, _quit_dialog, _camp]:
		_free_node(node)
	_hud = null
	_trick_choice = null
	_pause = null
	_tutorial = null
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


func _music(method: StringName, args: Array = []) -> void:
	if music != null and is_instance_valid(music) and music.has_method(method):
		music.callv(method, args)


# --- 轉場(BP2) ---

## 換畫面:轉場蓋住 → step(換場景)→ 轉場露出 → 開始等著的關卡。
## 一開始就把狀態設為 SWITCHING,連按兩下也只會切換一次;舊畫面在轉場蓋住之前都還看得到。
## 沒有轉場時至少等一格,避免在按鈕自己的訊號裡移除按鈕。
## 轉場一定會結束(FlowTransition 有逾時);較新的 _go 會讓較舊的那個停在原地。
func _go(step: Callable) -> void:
	_switch_serial += 1
	var serial := _switch_serial
	_switching = true
	_pause_when_ready = false
	_set_state(State.SWITCHING)
	var frame := Engine.get_process_frames()
	await transition.cover()
	if Engine.get_process_frames() == frame:
		await get_tree().process_frame
	if serial != _switch_serial or not is_inside_tree():
		return
	step.call()
	await transition.reveal()
	if serial != _switch_serial or not is_inside_tree():
		return
	_switching = false
	if _session_waiting:
		_begin_level()
	if _pause_when_ready:
		_pause_when_ready = false      # 轉場中切到背景:回來時關卡已暫停
		_open_pause()


# --- 教學提示(BP4) ---

func _maybe_show_tutorial() -> void:
	if _level_index != 0 or GameState.tutorial_done or _tutorial != null or state != State.LEVEL:
		return
	var scene := FlowParts.optional_scene(FlowParts.TUTORIAL, use_stand_ins)
	if scene == null:
		return
	_tutorial = scene.instantiate()
	if _tutorial == null:
		return
	_tutorial.name = "Tutorial"
	_overlay_layer.add_child(_tutorial)
	_overlay_layer.move_child(_tutorial, 0)     # 在把戲選擇與暫停畫面之下
	FlowParts.connect_if_present(_tutorial, &"finished", _on_tutorial_finished)


func _on_tutorial_finished() -> void:
	GameState.tutorial_done = true
	save_now()
	_free_node.call_deferred(_tutorial)
	_tutorial = null


# --- 暫停 ---

func _apply_pause() -> void:
	get_tree().paused = state == State.LEVEL and (_pause_open or _choice_open)


func _open_pause() -> void:
	if state != State.LEVEL or _pause_open or _choice_open:
		return
	_pause_open = true
	_apply_pause()
	EventBus.game_paused.emit(true)
	_music(&"set_ducked", [true])


func _close_pause() -> void:
	if not _pause_open:
		return
	_pause_open = false
	_apply_pause()
	EventBus.game_paused.emit(false)
	_music(&"set_ducked", [false])
	save_now()            # 暫停畫面可能改了音效、音樂、震動開關


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
			pass                  # 結算、失敗、營地、轉場中:略過


func _on_app_backgrounded() -> void:
	# 先存檔(同步完成),再暫停。
	save_now()
	if state == State.LEVEL and not _choice_open:
		_open_pause()
	elif state == State.SWITCHING:
		_pause_when_ready = true        # 轉場完成、進入關卡時立即暫停


func _on_resume_requested() -> void:
	if state == State.LEVEL:
		_close_pause()


func _on_quit_to_title_requested() -> void:
	if state != State.LEVEL:
		return
	save_now()
	# 暫停選單留在畫面上直到轉場蓋住(遊戲維持暫停);show_title 會取消暫停。
	_go(show_title)


func _on_camp_left() -> void:
	if state != State.CAMP:
		return
	_go(_start_level.bind(_level_index + 1))


# --- 介面訊號 ---

func _title_is_idle() -> bool:
	return state == State.TITLE and _credits == null and _quit_dialog == null


func _on_title_new_game() -> void:
	if _title_is_idle():
		_go(start_new_game)


func _on_title_continue() -> void:
	if _title_is_idle() and has_save():
		_go(continue_game)


func _on_title_credits() -> void:
	if _title_is_idle():
		_go(_open_credits)


func _open_credits() -> void:
	_set_state(State.TITLE)
	_credits = _add_ui(FlowParts.CREDITS, _screen_layer)
	FlowParts.connect_if_present(_credits, &"closed", _close_credits)


func _close_credits() -> void:
	if state == State.TITLE and _credits != null:
		_go(_remove_credits)


func _remove_credits() -> void:
	_set_state(State.TITLE)
	_free_node(_credits)
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
		_go(_finish_chapter)
	elif _last_result.get("next_is_camp", false):
		_go(_enter_camp)
	else:
		_go(_start_level.bind(_level_index + 1))


func _on_failure_retry() -> void:
	if state == State.FAILURE:
		_go(retry_level)


func _on_failure_title() -> void:
	if state == State.FAILURE:
		_go(show_title)
