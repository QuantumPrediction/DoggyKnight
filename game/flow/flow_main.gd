class_name FlowMain
extends Node
## 整個遊戲的流程(B1、B7、B8、B9;M3 打磨 BP1 至 BP6)。game/flow/main.tscn 的根節點;開機後顯示標題。
##
## 流程:標題 →(新遊戲:開場繪本 prologue)→ 關卡 →(升級選把戲)→ 過關結算 →(1-2、1-4 之後)營地 → 下一關
##       金毛倒下 → 失敗結算 → 再試一次(立即回到戰鬥,不重播對白)或回標題
##       打敗這一章的頭目(N-6)→ 結局對白 → 結算(is_final = true)→ 這一章的預告 → 回標題
## 所有畫面切換都在這個檔案裡,而且都經過轉場(_go:蓋住 → 換畫面 → 露出;見 FlowTransition)。
## 過關與失敗的結算畫面直接疊在場地上(不蓋住),讓慶祝與結算連成一氣。
##
## 一關的開始(BP1、BS2):轉場蓋住時組裝場地(LevelSession.build)→ 畫面露出 → 開打前的對白
## (LevelData.story_before;重試時不播)→ 發 level_started(LevelSession.begin),HUD 播標題卡 →
## intro_duration 秒之後第一波。所以 HUD 的關卡標題卡一定在對白之後才出現。1-1 第一次玩時,
## 第一波開始時加入教學提示(BP4,第 20 層,不暫停遊戲、不吃掉觸控)。
## 一關的結束:過關慶祝(results_delay 秒)→ 過關後的對白(story_after)→ 結算畫面。
##
## 故事(v2.3,BS2,docs/STORY.md 第 8 節):對白框(ui/dialogue/dialogue_box.tscn,第 40 層)在開機時加一次;
## 不存在時略過全部故事。對白播放期間 state = STORY:場地停止運作(World 的 process_mode = DISABLED,
## 敵人、金毛、計時都停住),返回鍵無效,切到背景只存檔(對白本身會等玩家點)。
##   新遊戲:prologue(整頁繪本,背景是 StoryBackdrop)→ 1-1 場地 → l1_before → 標題卡 → 第一波。
##   每關:場地出現 → story_before → 標題卡 → 波次;過關慶祝 → story_after → 結算。
##   重試同一關不播 story_before;「繼續冒險」播該關的 story_before。營地的 camp1、camp2 由 D 線播。
##   1-6:慶祝 → l6_after(結局)→ 結算(第一章完)→ teaser → 回標題。
##   打敗黑騎士時 GameState.chapter_cleared = true 並立即存檔(結局播到一半 App 被關掉也不會遺失)。
## 每段對白播完都存檔(GameState.story_seen 由對白框記錄)。
##
## 難度(v2.3,BS4):標題畫面在 new_game_pressed 之前設定 GameState.difficulty(只有 chapter_cleared
## 時才可能是 hard,否則一律 normal)。這一輪的難度隨存檔保存,「繼續冒險」沿用;困難模式的最佳星數
## 存在 best_stars["<關卡 id>:hard"];結算資料多一個 difficulty。
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
## v2.3:開場繪本、結局、預告播 story;1-4 稻草人隊長那一波開始時改播 boss;
## 一般關卡過關後的對白播回該關的曲子(field / boss,勝利短曲用 story_music_fade 秒淡出)。
##
## 星級(BP3):過關時依 StarRating 計算,最佳星數寫進 GameState.best_stars 並立即存檔。
##
## 存檔(B9、BP6):每關開始、過關、切到背景、關閉暫停選單、回標題、關閉視窗、看完教學時寫入
## (同步,不用 await)。v2.4 存檔第 4 版另存營地訓練等級、無盡試煉最佳波數(零食本來就有存)。
##
## v2.4 玩法深度(DEV_PLAN 4.12、第 17 節):
##   - 把戲進化:RunProgression / TrickDeck。數值在每關開始時重算(基準 → 營地訓練 → 把戲 → 事件)。
##   - 寶箱與零食:RunRewards(data/progression/economy.tres);過關依星數給零食。
##   - 抉擇事件:LevelEvents(data/levels/events.tres),每關一次,在中段兩波之間;遊戲暫停到選完
##     (state 仍是 LEVEL,is_event_open() = true)。沒有事件介面時自動選第一項。
##   - 復活:失敗結算的 revive_pressed(result["can_revive"])→ 扣零食、主角 revive()、回到同一關
##     (不重發 level_started;每關一次)。
##   - 營地訓練:標題的 training_pressed 打開 game/camp/training.tscn(D 線;不存在就略過),
##     它發 closed 時收起並存檔。
##   - 無盡試煉:標題的 endless_pressed(GameState.mode = &"endless",通關後才有)→ start_endless():
##     EndlessWaves 一波接一波產生,每 5 波頭目、每 10 波抉擇事件;倒下(沒有復活)就結束,
##     「再試一次」= 新的一輪無盡試煉。每清一波就更新 GameState.endless_best 並存檔。
##
## v2.6 三章(DEV_PLAN 4.13、第 19 節 BV3 至 BV6):
##   - chapters[N - 1] = 第 N 章(data/levels/chapter_<N>.tres)。每章是獨立的一輪(等級 1、沒有把戲;
##     營地訓練帶過去)。這一輪的章 = _run_chapter = GameState.chapter;chapter = 這一章的 ChapterData。
##   - 新遊戲:標題在 new_game_pressed 之前設定 GameState.chapter;只能選 1 至 max_selectable_chapter()
##     (= min(chapters_cleared + 1, GameState.CHAPTER_COUNT)),超過就用最高可選的章。播這一章的開場繪本(cN_prologue)。
##   - 打完第 N 章的最後一關:GameState.chapters_cleared = max(chapters_cleared, N),chapter_cleared = true,
##     立即存檔;結局 → 結算 → 這一章的預告(cN_teaser)→ 回標題。回標題前 GameState.chapter 改成
##     剛解鎖的下一章(標題預設選它)。
##   - 存檔第 5 版記住這一輪的章(chapter)與 chapters_cleared;「繼續冒險」回到存檔的章與關,
##     不理標題上選了哪一章。舊存檔:chapter_cleared → chapters_cleared = 1(SaveStore)。
##   - 音樂:每關 LevelData.music;空白時用這一章的 field_music / boss_music;中頭目那一波播
##     boss_music。音樂檔不存在時退回 field / boss(_track_or)。
##   - 結算資料多了 chapter、chapter_name、chapters_cleared、chapter_count、next_chapter_unlocked。
##   - 無盡試煉:EndlessWaves 用 tier = chapters_cleared(打完第二、三章才加入那一章的敵人與背景)。
##
## v2.7 六章(DEV_PLAN 4.14、第 20 節 BW1 至 BW7):
##   - 章數一律是 GameState.CHAPTER_COUNT(= 6),這個檔案不再寫死章數:載入 chapter_1 至 chapter_6、
##     可以選的章、存檔(SaveStore 第 6 版)、結算的 chapter_count 都用它。
##   - 結算資料多了 game_complete:打完最後一章(第六章)的最後一關 = true(C 線的結算顯示「全劇終」
##     UI_GAME_END;其他章的最後一關顯示「第 N 章 完」)。之後照樣播 c6_teaser(全破之後的訊息)再回標題。
##   - BW4:過關後的對白(story_after)播完,要等對白框淡出(看不見)才出結算;開打前的對白也一樣,
##     等淡出之後才發 level_started(標題卡)。正式對白框淡出約 0.18 秒;最多等 story_fade_wait 秒。
##   - 無盡試煉:tier 最高到 6,打完第四至六章再加入那一章的敵人、頭目與背景(data/levels/endless.tres)。
signal state_changed(new_state: State)

## SWITCHING:轉場中(舊畫面不再接受按鈕,新畫面還沒出現)。
## STORY(v2.3):正在播對白(開場繪本、關卡前後、結局、預告);場地停止運作。
enum State { BOOT, TITLE, LEVEL, RESULTS, FAILURE, CAMP, SWITCHING, STORY }

const NORMAL: StringName = &"normal"
const HARD: StringName = &"hard"
const REINFORCED: StringName = &"reinforced"
const STORY_MUSIC: StringName = &"story"

const DEFAULT_CHAPTER: String = "res://data/levels/chapter_1.tres"
## v2.6:第 N 章的資料檔(N = 1 至 GameState.CHAPTER_COUNT)。
const CHAPTER_PATH: String = "res://data/levels/chapter_%d.tres"
const FIELD_MUSIC: StringName = &"field"
const BOSS_MUSIC: StringName = &"boss"
const MUSIC_DIR: String = "res://assets/music/"
const DEFAULT_DIFFICULTY: String = "res://game/progression/difficulty.tres"
const DEFAULT_ECONOMY: String = "res://data/progression/economy.tres"
const DEFAULT_ENDLESS: String = "res://data/levels/endless.tres"
const STORY_MODE: StringName = &"story"
const ENDLESS_MODE: StringName = &"endless"

## 目前這一輪的章(執行時依 GameState.chapter 換成 chapters 裡的那一章)。
## 在加進場景樹之前設定的話,當作第一章的替代(舊的測試用法)。
@export var chapter: ChapterData
## chapters[0] = 第一章;留空就載入 data/levels/chapter_1.tres 至 chapter_<GameState.CHAPTER_COUNT>.tres。
@export var chapters: Array[ChapterData] = []
## 難度參數;留空就用 game/progression/difficulty.tres。
@export var difficulty: DifficultyData
## v2.4 零食經濟;留空就用 data/progression/economy.tres。
@export var economy: EconomyData
## v2.4 營地訓練;留空就用 data/progression/meta_upgrades.tres。
@export var meta_table: MetaUpgradeTable
## v2.4 抉擇事件;留空就用 data/levels/events.tres(測試可以放一個空的表,不出事件)。
@export var events: LevelEventTable
## v2.4 無盡試煉;留空就用 data/levels/endless.tres。
@export var endless_data: EndlessData
## v2.7(BW4 測試用):對白框的場景;留空就用 ui/dialogue/dialogue_box.tscn(use_stand_ins 時用替身)。
@export var dialogue_scene: PackedScene
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
var rewards: RunRewards
var level_events: LevelEvents
var save_store: SaveStore
var transition: FlowTransition

var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reached_level: int = 0
var _camp_pending: bool = false
var _level_index: int = 0
var _snapshot: Dictionary = {}
var _checkpoint: Dictionary = {}
## Source chapter whose boss reward is banked, until the next playable checkpoint or the credits close.
var _chapter_departure: int = 0
var _campaign_credits: bool = false
var _equipment_rng := RandomNumberGenerator.new()
var _equipment_screen: Control
var _restoring_checkpoint: bool = false
var _last_snack_balance: int = 0
var _last_result: Dictionary = {}
var _clear_record: Dictionary = {}
var _pause_open: bool = false
var _choice_open: bool = false
var _switch_serial: int = 0
var _switching: bool = false
var _session_waiting: bool = false
var _pause_when_ready: bool = false
## 這一輪冒險的難度(存檔;「繼續冒險」時寫回 GameState.difficulty)。
var _run_difficulty: StringName = NORMAL
## v2.6:這一輪冒險的章(1 至 GameState.CHAPTER_COUNT;存檔;「繼續冒險」時寫回 GameState.chapter)。
var _run_chapter: int = 1
var _run_hero_class: StringName = &"knight"
## 這一關開打前要先播 story_before(新的一關、繼續冒險;重試時為 false)。
var _story_before_pending: bool = false
## 轉場露出後要播的整頁故事(開場繪本、預告),與播完之後要做的事。
var _page_story: DialogueScript
var _page_story_then: Callable = Callable()
var _story_playing: bool = false
var _story_id: StringName = &""
## 每次開始播對白、或離開目前畫面時 +1;播完時不一樣就表示已被打斷(不再繼續原本的步驟)。
var _story_serial: int = 0
## v2.4
var _event_open: bool = false
var _revive_used: bool = false
var _endless_waves: EndlessWaves
var _endless_best_before: int = 0
var _endless_boss_music: bool = false
var _event_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_endless_event: StringName = &""

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
var _dialogue_box: Node
var _event_ui: Node
var _training: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_chapters()
	if difficulty == null:
		difficulty = load(DEFAULT_DIFFICULTY) as DifficultyData
	if economy == null:
		economy = load(DEFAULT_ECONOMY) as EconomyData
	if meta_table == null:
		meta_table = MetaUpgradeTable.load_default()
	if events == null:
		events = LevelEventTable.load_default()
	if endless_data == null:
		endless_data = load(DEFAULT_ENDLESS) as EndlessData
	if not quit_handler.is_valid():
		quit_handler = get_tree().quit
	if music == null:
		music = get_node_or_null(^"/root/Music")
	if rng_seed != 0:
		_spawn_rng.seed = rng_seed + 1
		_event_rng.seed = rng_seed + 3
	else:
		_spawn_rng.randomize()
		_event_rng.randomize()
	_build_nodes()

	progression = RunProgression.new()
	progression.name = "Progression"
	progression.setup(difficulty, rng_seed, meta_table)
	progression.choice_opened.connect(_on_choice_opened)
	progression.choice_closed.connect(_on_choice_closed)
	add_child(progression)

	rewards = RunRewards.new()
	rewards.name = "Rewards"
	rewards.setup(economy, progression, rng_seed)
	rewards.player_getter = func() -> Object: return _session.get_player() if _session != null else null
	add_child(rewards)

	level_events = LevelEvents.new()
	level_events.name = "LevelEvents"
	level_events.auto_pick_delay = difficulty.event_auto_pick_delay
	add_child(level_events)
	level_events.setup(progression, rewards)
	level_events.event_opened.connect(_on_event_opened)
	level_events.choice_applied.connect(_on_event_choice_applied)
	level_events.event_closed.connect(_on_event_closed)

	transition = FlowTransition.new()
	transition.name = "TransitionHost"
	add_child(transition)
	transition.setup(FlowParts.optional_scene(FlowParts.TRANSITION, use_stand_ins), difficulty)

	_add_dialogue_box()

	if rng_seed != 0:
		_equipment_rng.seed = rng_seed + 4
	else:
		_equipment_rng.randomize()
	save_store = SaveStore.new(save_path)
	_load_save()

	EventBus.equipment_requested.connect(_open_equipment)
	EventBus.guard_lesson_requested.connect(_replay_guard_lesson)
	EventBus.guard_lesson_completed.connect(_on_guard_lesson_completed)
	EventBus.guard_lesson_dismissed.connect(_on_guard_lesson_dismissed)
	EventBus.back_requested.connect(_on_back_requested)
	EventBus.app_backgrounded.connect(_on_app_backgrounded)
	EventBus.resume_requested.connect(_on_resume_requested)
	EventBus.quit_to_title_requested.connect(_on_quit_to_title_requested)
	EventBus.camp_left.connect(_on_camp_left)
	EventBus.snacks_changed.connect(_on_snacks_changed)
	show_title()


func _exit_tree() -> void:
	_switch_serial += 1          # 讓還在等轉場的步驟不再繼續
	for pair: Array in [
		[EventBus.equipment_requested, _open_equipment],
		[EventBus.guard_lesson_requested, _replay_guard_lesson],
		[EventBus.guard_lesson_completed, _on_guard_lesson_completed],
		[EventBus.guard_lesson_dismissed, _on_guard_lesson_dismissed],
		[EventBus.back_requested, _on_back_requested],
		[EventBus.app_backgrounded, _on_app_backgrounded],
		[EventBus.resume_requested, _on_resume_requested],
		[EventBus.quit_to_title_requested, _on_quit_to_title_requested],
		[EventBus.camp_left, _on_camp_left],
		[EventBus.snacks_changed, _on_snacks_changed],
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
	return _chapter_departure > 0 or _reached_level > 0 or not _checkpoint.is_empty()


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


## 目前要玩家選擇的介面:平常是把戲選擇;v2.4 抉擇事件開著時傳回事件介面(有 choose(index),
## 讓只會「點第一張卡」的試玩機器人與整合測試也能繼續)。只要把戲選擇介面:get_trick_choice_ui()。
func get_trick_choice() -> Node:
	if _event_open and _event_ui != null and is_instance_valid(_event_ui):
		return _event_ui
	return _trick_choice


func get_trick_choice_ui() -> Node:
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


## 正在選擇(升級或寶箱的把戲三選一,或 v2.4 的抉擇事件;遊戲暫停中)。
## 只問把戲:is_trick_choice_open();只問事件:is_event_open()。
func is_choice_open() -> bool:
	return _choice_open or _event_open


func is_trick_choice_open() -> bool:
	return _choice_open



## 正在轉場(由按下按鈕到新畫面完全露出)。
func is_switching() -> bool:
	return _switching


## 關卡已開始(已發 level_started,正在進行)。
func is_level_running() -> bool:
	return state == State.LEVEL and _session != null and _session.is_playing()


## 對白框(沒有時為 null:略過全部故事)。
func get_dialogue_box() -> Node:
	return _dialogue_box


## 正在播對白(state == STORY)。
func is_story_playing() -> bool:
	return _story_playing


## 正在播的段落 id(沒有在播時為 &"")。
func get_story_id() -> StringName:
	return _story_id


## 這一輪冒險的難度(&"normal" 或 &"hard")。
func get_run_difficulty() -> StringName:
	return _run_difficulty


## v2.6:這一輪冒險的章(1 至 GameState.CHAPTER_COUNT;「繼續冒險」會回到這一章)。
func get_run_chapter() -> int:
	return _run_chapter


## 有幾章可以玩:GameState.CHAPTER_COUNT(正式遊戲是 6);資料檔缺了後面的章時,只算到最後一個有資料的章。
func chapter_count() -> int:
	var count := 0
	for data in chapters:
		if data == null or count >= GameState.CHAPTER_COUNT:
			break
		count += 1
	return maxi(1, count)


## v2.7:這一章是不是最後一章(打完就是全劇終)。
func is_final_chapter(number: int) -> bool:
	return number >= GameState.CHAPTER_COUNT


## v2.6:第 number 章的資料(1 起算;沒有那一章時傳回第一章)。
func get_chapter_data(number: int) -> ChapterData:
	var index := clampi(number, 1, chapter_count()) - 1
	return chapters[index] if index < chapters.size() and chapters[index] != null else chapter


## 標題可以選的最高章 = min(chapters_cleared + 1, GameState.CHAPTER_COUNT)(DEV_PLAN 4.13、4.14)。
func max_selectable_chapter() -> int:
	return clampi(GameState.chapters_cleared + 1, 1, chapter_count())


## v2.4:抉擇事件開著(遊戲暫停中,等 event_chosen)。試玩機器人與測試可以用
## EventBus.event_chosen.emit(get_open_event_id(), 0) 或 choose_event(0) 選第一項。
func is_event_open() -> bool:
	return _event_open


func get_open_event_id() -> StringName:
	return level_events.get_open_id()


func choose_event(index: int) -> bool:
	return level_events.choose(index)


## v2.4:事件介面(沒有時為 null:自動選第一項)。
func get_event_ui() -> Node:
	return _event_ui


## v2.4:營地訓練介面(從標題打開時;沒有打開時為 null)。
func get_training() -> Node:
	return _training


## v2.4:正在玩無盡試煉。
func is_endless() -> bool:
	return GameState.mode == ENDLESS_MODE


## 這段對白能不能播(有內容,而且有對白框)。
func can_play_story(script: DialogueScript) -> bool:
	return script != null and not script.lines.is_empty() and _dialogue_box != null \
			and is_instance_valid(_dialogue_box) and _dialogue_box.has_method(&"play")


# --- 存檔 ---

func save_now() -> bool:
	if state in [State.CAMP, State.RESULTS] and not _checkpoint.is_empty():
		_capture_checkpoint()
	elif not _has_unbanked_level() and not _checkpoint.is_empty():
		_checkpoint["snacks"] = GameState.snacks
	return save_store.write_data({
		"equipment": GameState.equipment,
		"checkpoint": _checkpoint,
		"hero_class": String(_run_hero_class),
		"level_index": _reached_level,
		"snacks": int(_checkpoint.get("snacks", GameState.snacks)) if _has_unbanked_level() else GameState.snacks,
		"sound_on": GameState.sound_on,
		"music_on": GameState.music_on,
		"haptics_on": GameState.haptics_on,
		"tutorial_done": GameState.tutorial_done,
		"guard_lesson_done": GameState.guard_lesson_done,
		"best_stars": GameState.best_stars,
		"camp_pending": _camp_pending and _reached_level > 0,
		"difficulty": String(_run_difficulty),
		"chapter_cleared": GameState.chapter_cleared,
		"story_seen": GameState.story_seen,
		"meta_upgrades": GameState.meta_upgrades,
		# 無盡試煉進行中:存檔先記下這一輪清了幾波(App 被關掉也不遺失);GameState.endless_best
		# 等倒下(或離開)才更新,HUD 才能比較「新紀錄!」。
		"endless_best": maxi(GameState.endless_best, _endless_run_waves()),
		"chapter": _chapter_departure if _chapter_departure > 0 else _run_chapter,
		"chapter_departure": _chapter_departure,
		"chapters_cleared": GameState.chapters_cleared,
	})


func _load_save() -> void:
	var data := save_store.read()
	GameState.guard_lesson_done = bool(data.get("guard_lesson_done", false))
	GameState.equipment = EquipmentInventory.sanitize(data.get("equipment", {}))
	_checkpoint = AdventureCheckpoint.sanitize(data.get("checkpoint", {}))
	_chapter_departure = int(data.get("chapter_departure", 0))
	if data.is_empty():
		_reached_level = 0
		_camp_pending = false
		_use_chapter(mini(GameState.chapter, max_selectable_chapter()))
		return
	_run_hero_class = HeroClasses.valid_id(data["hero_class"])
	GameState.hero_class = _run_hero_class
	GameState.chapters_cleared = data["chapters_cleared"]
	_use_chapter(mini(int(data["chapter"]), max_selectable_chapter()))
	_reached_level = clampi(data["level_index"], 0, maxi(0, chapter.level_count() - 1))
	_camp_pending = data["camp_pending"] and _reached_level > 0 and chapter.has_camp_after(_reached_level - 1)
	GameState.snacks = data["snacks"]
	_last_snack_balance = GameState.snacks
	GameState.sound_on = data["sound_on"]
	GameState.music_on = data["music_on"]
	GameState.haptics_on = data["haptics_on"]
	GameState.tutorial_done = data["tutorial_done"]
	GameState.best_stars = (data["best_stars"] as Dictionary).duplicate()
	GameState.chapter_cleared = data["chapter_cleared"]
	_run_difficulty = StringName(data["difficulty"])  # SaveStore 已驗證舊檔與可用模式
	GameState.difficulty = _run_difficulty      # 標題的難度選擇預設 = 上一輪的難度
	var seen := {}
	for id: String in (data["story_seen"] as Dictionary):
		seen[StringName(id)] = true
	GameState.story_seen = seen
	var meta := {}
	var stored := data["meta_upgrades"] as Dictionary
	for id: String in stored:
		meta[StringName(id)] = int(stored[id])
	GameState.meta_upgrades = meta
	GameState.endless_best = data["endless_best"]


# --- 畫面切換 ---

func show_title() -> void:
	if _has_unbanked_level():
		GameState.snacks = int(_checkpoint.get("snacks", GameState.snacks))
	_end_endless_mode()      # 先記錄無盡試煉的波數(_leave_current 會移除關卡)
	_leave_current()
	_set_state(State.TITLE)
	_screen = _add_ui(FlowParts.TITLE, _screen_layer)
	FlowParts.call_if_present(_screen, &"setup", [has_save()])
	FlowParts.connect_if_present(_screen, &"new_game_pressed", _on_title_new_game)
	FlowParts.connect_if_present(_screen, &"continue_pressed", _on_title_continue)
	FlowParts.connect_if_present(_screen, &"credits_pressed", _on_title_credits)
	if _screen != null and _screen.has_signal(&"endless_pressed"):
		_screen.connect(&"endless_pressed", _on_title_endless)
	if _screen != null and _screen.has_signal(&"training_pressed"):
		_screen.connect(&"training_pressed", _on_title_training)
	_music(&"play", [&"title"])


## 新遊戲:重設這一輪(數值、把戲、等級、活力、下一關加成),播開場繪本,從第 1 關開始。
## 難度用標題畫面設定的 GameState.difficulty(第一章可自選援軍；困難仍須通關解鎖)。
## v2.6:章用標題畫面設定的 GameState.chapter(只能選已解鎖的章,否則用最高可選的章)。
## 舊的進度立即作廢(開場繪本播到一半 App 被關掉,也不會「繼續」舊的那一輪)。
func start_new_game() -> void:
	_chapter_departure = 0
	_start_chapter_run(GameState.chapter)


func _start_chapter_run(number: int) -> void:
	_checkpoint = {}
	_run_hero_class = HeroClasses.valid_id(GameState.hero_class)
	_end_endless_mode()
	_use_chapter(mini(number, max_selectable_chapter()))
	GameState.reset_run()
	progression.reset_run()
	_prepare_run()
	var allow_reinforcements := GameState.difficulty == REINFORCED and _run_chapter == 1
	if not allow_reinforcements and (GameState.difficulty != HARD or not GameState.chapter_cleared):
		GameState.difficulty = NORMAL
	_run_difficulty = GameState.difficulty
	_camp_pending = false
	if can_play_story(chapter.prologue):
		_reached_level = 0
		save_now()
		_show_page_story(chapter.prologue, _go.bind(_start_level.bind(0, true)))
	else:
		_start_level(0)


## v8 繼續:還原最近的關卡檢查點；v1–v7 缺當局資料時沿用舊版相容行為。
## 存檔記錄了「應先進營地」(上一關過關後、進營地之前 App 被關掉)時,先回到那個營地。
func continue_game() -> void:
	GameState.hero_class = _run_hero_class
	var index := _reached_level
	_end_endless_mode()
	_use_chapter(_run_chapter)                  # 存檔那一輪的章(不理標題上選了哪一章)
	if _chapter_departure > 0:
		GameState.difficulty = _run_difficulty
		var aftermath := chapter.get_level(chapter.level_count() - 1).story_after
		if can_play_story(aftermath) and not GameState.story_seen.has(aftermath.id):
			_show_page_story(aftermath, _go.bind(_finish_chapter.bind(true)))
		else:
			_finish_chapter(true)
		return
	GameState.reset_run()
	progression.reset_run()
	_prepare_run()
	GameState.difficulty = _run_difficulty         # 沿用存檔那一輪的難度
	if not _checkpoint.is_empty():
		progression.import_checkpoint(_checkpoint)
		_spawn_rng.state = int(_checkpoint.spawn_rng)
		_event_rng.state = int(_checkpoint.event_rng)
		_equipment_rng.state = int(_checkpoint.equipment_rng)
		GameState.snacks = int(_checkpoint.snacks)
		_last_snack_balance = GameState.snacks
		_restoring_checkpoint = true
	if _camp_pending and index > 0 and chapter.has_camp_after(index - 1):
		# A resumed camp is a safe place to change equipment before the next level.
		_restoring_checkpoint = false
		_level_index = index - 1
		_enter_camp()
		return
	_camp_pending = false
	GameState.level_index = index
	_start_level(index)


## 失敗後再試一次:還原這一關開始時的快照,活力補滿,立即重新開始(不重播開打前的對白)。
func retry_level() -> void:
	if is_endless():
		start_endless()
		return
	progression.restore_snapshot(_snapshot)
	if not _checkpoint.is_empty():
		GameState.snacks = int(_checkpoint.snacks)
		progression.rng.state = int(_checkpoint.rng)
		_spawn_rng.state = int(_checkpoint.spawn_rng)
		GameState.run_equipment = _checkpoint.equipment.duplicate(true)
		_restoring_checkpoint = true
	GameState.vigor = GameState.player_stats.max_vigor
	_start_level(_level_index, false)


## 開始第 index 關。with_story = false(重試)時不播 story_before。
func _start_level(index: int, with_story: bool = true) -> void:
	var level := chapter.get_level(index)
	if level == null:
		push_error("FlowMain: 沒有第 %d 關" % index)
		show_title()
		return
	_leave_current()
	_level_index = index
	GameState.level_index = index
	if not _restoring_checkpoint:
		GameState.run_equipment = EquipmentInventory.loadout(GameState.equipment, String(GameState.hero_class))
	_restoring_checkpoint = false
	progression.rebuild_stats()          # v2.4:營地訓練(在營地剛練的)從這一關生效
	_snapshot = progression.take_snapshot()
	_reached_level = index
	_camp_pending = false
	_clear_record = {}
	_capture_checkpoint()
	_chapter_departure = 0
	save_now()
	_open_session(level, index, _arriving_companions(index))
	_story_before_pending = with_story
	_set_state(State.LEVEL)
	_music(&"play", [_level_track(level)])
	if _switching:
		_session_waiting = true        # 轉場露出畫面之後才開始(_go)
	else:
		_begin_level()


## 建立這一關的介面與 LevelSession(還沒開始)。endless = true:無盡試煉。
func _open_session(level: LevelData, index: int, arriving: Array[StringName], endless: bool = false) -> void:
	_revive_used = false
	# 介面先建立,才收得到主角進場時發出的 vigor_changed。
	_hud = _add_ui(FlowParts.HUD, _hud_layer)
	_trick_choice = _add_ui(FlowParts.TRICK_CHOICE, _overlay_layer)
	var event_scene := FlowParts.optional_scene(FlowParts.EVENT_CHOICE, use_stand_ins)
	_event_ui = event_scene.instantiate() if event_scene != null else null
	if _event_ui != null:
		_event_ui.name = "EventChoice"
		_overlay_layer.add_child(_event_ui)
	level_events.has_ui = _event_ui != null
	_pause = _add_ui(FlowParts.PAUSE, _overlay_layer)

	_session = LevelSession.new()
	_session.name = "LevelSession"
	_session.setup(level, index, difficulty, FlowParts.arena_for(level, use_stand_ins), _spawn_rng)
	_session.arriving = arriving
	_session.difficulty_mode = NORMAL if endless else _run_difficulty
	_session.endless = endless
	_session.cleared.connect(_on_level_cleared)
	_session.finished.connect(_on_level_finished)
	_session.intro_finished.connect(_on_intro_finished)
	_session.boss_wave_started.connect(_on_boss_wave_started)
	_session.event_due.connect(_on_event_due)
	if endless:
		_session.event_every = endless_data.event_every
		_session.wave_began.connect(_on_endless_wave_began)
		_session.wave_done.connect(_on_endless_wave_done)
	elif events != null:
		_session.event_after_wave = events.trigger_wave(level)
	_world.add_child(_session)
	_session.build()


## 這一關才加入的同伴(上一關沒有的),例如 1-3 的鬥牛犬:等畫面露出才出場。
func _arriving_companions(index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var level := chapter.get_level(index)
	var previous := chapter.get_level(index - 1)
	for companion_id in level.companions:
		if previous == null or not previous.companions.has(companion_id):
			result.append(companion_id)
	return result


## (先播開打前的對白)發 level_started、開始開場倒數。
func _begin_level() -> void:
	_session_waiting = false
	if state != State.LEVEL or _session == null or not is_instance_valid(_session):
		return
	var session := _session
	var story: DialogueScript = session.level.story_before if _story_before_pending else null
	_story_before_pending = false
	if can_play_story(story):
		_set_state(State.STORY)
		_freeze_world(true)
		if not await _play_story(story) or session != _session or state != State.STORY:
			return
		# BW4:對白框淡出之後才發 level_started(標題卡不會從還在淡出的對白框底下冒出來)
		if not await _wait_story_hidden() or session != _session or state != State.STORY:
			return
		_freeze_world(false)
		_set_state(State.LEVEL)
	level_events.reset_level()
	rewards.begin_level()
	session.begin(progression)


func _on_boss_wave_started(_index: int) -> void:
	_music(&"play", [_chapter_boss_track()])


func _on_intro_finished() -> void:
	_maybe_show_tutorial()
	_show_guard_lesson(false)


func _on_level_cleared() -> void:
	if not _clear_record.is_empty():
		return
	var level := chapter.get_level(_level_index)
	# 過關:下一關加成用完歸零(失敗重試時保留,見 retry_level)。
	GameState.next_level_bonus = 0.0
	_reached_level = 0 if chapter.is_last(_level_index) else _level_index + 1
	_camp_pending = chapter.has_camp_after(_level_index) and _reached_level > 0
	if chapter.is_last(_level_index):
		GameState.chapter_cleared = true    # 打完一章(第一章:解鎖困難模式與無盡試煉;立即存檔)
		GameState.chapters_cleared = maxi(GameState.chapters_cleared, _run_chapter)   # 解鎖下一章
	_clear_record = _record_stars(level)
	var bonus := economy.clear_reward(_clear_record["stars"], _run_difficulty == HARD)
	_clear_record["snack_bonus"] = bonus
	GameState.snacks += bonus
	rewards.snacks_this_level += bonus
	level_events.cancel()
	_clear_record["equipment_reward"] = EquipmentInventory.reward_clear(GameState.equipment, _run_chapter, level.is_boss, _run_difficulty == HARD, _equipment_rng)
	if chapter.is_last(_level_index):
		_chapter_departure = _run_chapter
		_checkpoint = {}
	else:
		_capture_checkpoint()
	if _level_index == 0:
		GameState.tutorial_done = true      # 打完 1-1:已懂得操作,教學不再出現
	_free_node(_tutorial)
	_tutorial = null
	EventBus.snacks_changed.emit(GameState.snacks)
	save_now()
	_music(&"play", [&"chapter_clear" if chapter.is_last(_level_index) else &"victory"])
	if not level.is_boss:
		Haptics.play(&"medium")         # 打倒頭目的震動由 A 線負責(heavy)


## 計算這次過關的星數,更新並傳回 {"stars", "goals", "previous", "new_best"}。
func _record_stars(level: LevelData) -> Dictionary:
	var goals := StarRating.goals(level, true, _session.time_sec, _session.damage_taken)
	var stars := StarRating.count(goals)
	var key := StarRating.record_key(level.id, _run_difficulty)
	var had_record := GameState.best_stars.has(key)
	var previous := int(GameState.best_stars.get(key, 0))
	GameState.best_stars[key] = maxi(previous, stars)
	return {"stars": stars, "goals": goals, "previous": previous, "new_best": had_record and stars > previous}


func _on_level_finished(victory: bool) -> void:
	progression.end_level()
	rewards.end_level()
	level_events.cancel()
	_close_pause()
	if not victory and is_endless():
		_record_endless()
	# 讓場地停在對白與結算畫面之下(敵人不再移動)。
	_freeze_world(true)
	_last_result = _build_result(victory)
	if victory:
		if not _checkpoint.is_empty():
			_capture_checkpoint()
		save_now()
		var level := chapter.get_level(_level_index)
		var story := level.story_after
		if can_play_story(story):
			var session := _session
			_set_state(State.STORY)
			var track := STORY_MUSIC if chapter.is_last(_level_index) else _level_track(level)
			_music(&"play", [track, difficulty.story_music_fade])
			if not await _play_story(story) or session != _session or state != State.STORY:
				return
			# BW4:過關慶祝 → story_after → 結算。對白框(第 40 層)播完後還要淡出一下;結算畫面(第 30 層)
			# 等它完全看不見才出現,不會被對白蓋住。
			if not await _wait_story_hidden() or session != _session or state != State.STORY:
				return
		_set_state(State.RESULTS)
		_screen = _add_ui(FlowParts.RESULTS, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate(true)])
		FlowParts.connect_if_present(_screen, &"continue_pressed", _on_results_continue)
		FlowParts.connect_if_present(_screen, &"rest_pressed", _on_results_rest)
	else:
		_music(&"play", [&"fail"])
		_set_state(State.FAILURE)
		_screen = _add_ui(FlowParts.FAILURE, _screen_layer)
		FlowParts.call_if_present(_screen, &"setup", [_last_result.duplicate(true)])
		FlowParts.connect_if_present(_screen, &"retry_pressed", _on_failure_retry)
		FlowParts.connect_if_present(_screen, &"title_pressed", _on_failure_title)
		if _screen != null and _screen.has_signal(&"revive_pressed"):
			_screen.connect(&"revive_pressed", _on_failure_revive)



## 結算資料:DEV_PLAN 4.9 的九個鍵 + 4.10 的六個鍵 + damage_taken(這一關受到的傷害)
## + difficulty(v2.3:&"normal" 或 &"hard";best_stars 是這個難度的最佳星數)。
## v2.4 另加:
##   mode(&"story" / &"endless")、snacks(零食總數)、snacks_earned(這一關得到的,含過關獎勵)、
##   snack_bonus(過關獎勵)、revive_cost、can_revive(失敗畫面顯示「用 N 個零食復活」)、
##   event_tone(這一關選了 "merlin" / "morgana";沒有事件時 "")、
##   無盡試煉:endless_wave(清了幾波)、endless_best、endless_new_best
##   (level_id = &"endless"、level_name = "LEVEL_ENDLESS"、level_index = -1、level_count = 0、
##   star_goals 是空的)。
func _build_result(victory: bool) -> Dictionary:
	if is_endless():
		return _build_endless_result()
	var level := chapter.get_level(_level_index)
	var tricks: Array = []
	tricks.append_array(progression.tricks_this_level)
	var hero := _session.get_player() as GoldiePlayer if _session != null else null
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
	var result := {
		"equipment_reward": _clear_record.get("equipment_reward", {}),
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
		"best_stars": int(GameState.best_stars.get(StarRating.record_key(level.id, _run_difficulty), 0)),
		"new_best": new_best,
		"level_index": _level_index,
		"level_count": chapter.level_count(),
		"damage_taken": damage,
		"difficulty": _run_difficulty,
		"mode": STORY_MODE,
		"snacks": GameState.snacks,
		"snacks_earned": rewards.snacks_this_level,
		"snack_bonus": int(_clear_record.get("snack_bonus", 0)) if victory else 0,
		"revive_cost": economy.revive_cost(_level_index),
		"can_revive": not victory and _can_revive(economy.revive_cost(_level_index)),
		"event_tone": String(level_events.last_choice.get("tone", "")),
		"chapter": _run_chapter,
		"chapter_name": chapter.display_name,
		"chapters_cleared": GameState.chapters_cleared,
		"chapter_count": chapter_count(),
		"next_chapter_unlocked": victory and chapter.is_last(_level_index) and _run_chapter < chapter_count(),
		"game_complete": victory and chapter.is_last(_level_index) and is_final_chapter(_run_chapter),
	}
	if hero != null and hero.abilities != null and not hero.abilities.landed_pairs.is_empty():
		result["landed_pairs"] = hero.abilities.landed_pairs.duplicate()
	return result


func _build_endless_result() -> Dictionary:
	var cleared := _session.waves_cleared if _session != null else 0
	var cost := economy.endless_revive_cost(cleared)
	var tricks: Array = []
	tricks.append_array(progression.tricks_this_level)
	return {
		"level_id": endless_data.level_id,
		"level_name": endless_data.display_name,
		"victory": false,
		"time_sec": _session.time_sec if _session != null else 0.0,
		"kills": _session.kills if _session != null else 0,
		"tricks": tricks,
		"hero_level": GameState.hero_level,
		"next_is_camp": false,
		"is_final": false,
		"stars": 0,
		"star_goals": [] as Array[Dictionary],
		"best_stars": 0,
		"new_best": cleared > _endless_best_before,
		"level_index": -1,
		"level_count": 0,
		"damage_taken": _session.damage_taken if _session != null else 0,
		"difficulty": NORMAL,
		"mode": ENDLESS_MODE,
		"snacks": GameState.snacks,
		"snacks_earned": rewards.snacks_this_level,
		"snack_bonus": 0,
		"revive_cost": cost,
		"can_revive": _can_revive(cost),
		"event_tone": String(level_events.last_choice.get("tone", "")),
		"endless_wave": cleared,
		"endless_best": GameState.endless_best,
		"endless_new_best": cleared > _endless_best_before,
		"chapter": 0,
		"chapter_name": "",
		"chapters_cleared": GameState.chapters_cleared,
		"chapter_count": chapter_count(),
		"next_chapter_unlocked": false,
		"game_complete": false,
	}


## 能不能復活:這一關還沒復活過、金毛正睡著、零食夠、主角有 revive()。
func _can_revive(cost: int) -> bool:
	if _revive_used or _session == null or not _session.is_downed() or GameState.snacks < cost:
		return false
	var player := _session.get_player()
	return player != null and player.has_method(&"revive")


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


## Chapter rewards were saved when the boss fell. The handoff lasts across both story pages.
func _finish_chapter(resuming: bool = false) -> void:
	var teaser := chapter.teaser
	var destination := _open_campaign_credits if is_final_chapter(_run_chapter) else _depart_for_next_chapter
	if can_play_story(teaser) and (not resuming or not GameState.story_seen.has(teaser.id)):
		_show_page_story(teaser, _go.bind(destination))
	else:
		destination.call()


func _depart_for_next_chapter() -> void:
	GameState.hero_class = _run_hero_class
	GameState.difficulty = _run_difficulty
	_start_chapter_run(_chapter_departure + 1)


func _open_campaign_credits() -> void:
	_leave_current()
	_campaign_credits = true
	_open_credits()


# --- 章(v2.6) ---

## chapters 留空時載入 data/levels/chapter_1.tres 至 chapter_<GameState.CHAPTER_COUNT>.tres;
## 在加進場景樹之前放了 chapter 的話,用它當第一章(測試)。
func _init_chapters() -> void:
	if chapters.is_empty():
		for number in range(1, GameState.CHAPTER_COUNT + 1):
			var path := CHAPTER_PATH % number
			chapters.append(load(path) as ChapterData if ResourceLoader.exists(path) else null)
		if chapter != null:
			chapters[0] = chapter
	if chapters[0] == null:
		chapters[0] = chapter if chapter != null else load(DEFAULT_CHAPTER) as ChapterData
	chapter = chapters[0]


## 這一輪用第 number 章(1 至 chapter_count())。
func _use_chapter(number: int) -> void:
	_run_chapter = clampi(number, 1, chapter_count())
	GameState.chapter = _run_chapter
	chapter = get_chapter_data(_run_chapter)


## 移除目前的關卡、營地、畫面,取消暫停。
func _leave_current() -> void:
	if progression != null:
		progression.end_level()
	if rewards != null:
		rewards.end_level()
	if level_events != null:
		level_events.cancel()
	_event_open = false
	if _pause_open:
		EventBus.game_paused.emit(false)
		_music(&"set_ducked", [false])
	_pause_open = false
	_choice_open = false
	_session_waiting = false
	_story_before_pending = false
	_page_story = null
	_page_story_then = Callable()
	_stop_story()
	get_tree().paused = false
	if _session != null:
		_session.teardown()
		_free_node(_session)
		_session = null
	for node in [_equipment_screen, _hud, _trick_choice, _pause, _tutorial, _screen, _credits, _quit_dialog, _camp, _event_ui, _training]:
		_free_node(node)
	_equipment_screen = null
	_event_ui = null
	_training = null
	_hud = null
	_trick_choice = null
	_pause = null
	_tutorial = null
	_screen = null
	_credits = null
	_campaign_credits = false
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
	elif _page_story != null:
		_play_page_story()
	if _pause_when_ready:
		_pause_when_ready = false      # 轉場中切到背景:回來時關卡已暫停
		_open_pause()


# --- 故事(v2.3,BS2) ---

func _add_dialogue_box() -> void:
	var scene := dialogue_scene if dialogue_scene != null else FlowParts.optional_scene(FlowParts.DIALOGUE, use_stand_ins)
	if scene == null:
		push_warning("FlowMain: 沒有對白框,略過全部故事")
		return
	_dialogue_box = scene.instantiate()
	if _dialogue_box == null:
		return
	_dialogue_box.name = "DialogueBox"
	add_child(_dialogue_box)


## 播一段對白,播完傳回 true;中途離開畫面(_leave_current)時傳回 false,呼叫的一方就不再繼續。
func _play_story(script: DialogueScript) -> bool:
	_story_serial += 1
	var serial := _story_serial
	_story_playing = true
	_story_id = script.id
	await _dialogue_box.play(script)
	if serial != _story_serial or not is_inside_tree():
		return false
	_story_playing = false
	_story_id = &""
	save_now()                # GameState.story_seen(對白框已記下)
	return true


## BW4:對白框還看得見嗎(播完之後的淡出也算)。對白框有 is_showing() 就問它;否則看它的直接子節點
## (C 線正式對白框的 DialogueRoot、替身的 Root)是否還 visible。
func is_dialogue_showing() -> bool:
	var box := _dialogue_box
	if box == null or not is_instance_valid(box) or not box.is_inside_tree():
		return false
	if box.has_method(&"is_showing"):
		return bool(box.call(&"is_showing"))
	if box.has_method(&"is_active") and bool(box.call(&"is_active")):
		return true
	if box is CanvasLayer and not (box as CanvasLayer).visible:
		return false
	for child in box.get_children():
		var item := child as CanvasItem
		if item != null and item.visible and item.modulate.a > 0.0:
			return true
	return false


## BW4:等對白框淡出(看不見)。最多等 difficulty.story_fade_wait 秒(真實時間,保證不會卡住)。
## 中途離開畫面(_leave_current → _stop_story)時傳回 false,呼叫的一方就不再繼續。
func _wait_story_hidden() -> bool:
	var serial := _story_serial
	var deadline := Time.get_ticks_msec() + int(maxf(0.0, difficulty.story_fade_wait) * 1000.0)
	while is_dialogue_showing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if serial != _story_serial or not is_inside_tree():
			return false
	return serial == _story_serial and is_inside_tree()


## 離開畫面時:還在播的對白直接結束(等著它的步驟不再繼續)。
func _stop_story() -> void:
	_story_serial += 1
	_story_playing = false
	_story_id = &""
	if _dialogue_box != null and is_instance_valid(_dialogue_box) and _dialogue_box.has_method(&"is_active") \
			and _dialogue_box.call(&"is_active"):
		_dialogue_box.call(&"skip")


## 整頁的故事(開場繪本、預告):換成 StoryBackdrop,播 story 音樂;畫面露出後播對白,播完呼叫 then。
func _show_page_story(script: DialogueScript, then: Callable) -> void:
	_leave_current()
	_set_state(State.STORY)
	_screen = StoryBackdrop.new()
	_screen.name = "StoryBackdrop"
	_screen_layer.add_child(_screen)
	_music(&"play", [STORY_MUSIC])
	_page_story = script
	_page_story_then = then
	if not _switching:
		_play_page_story()


func _play_page_story() -> void:
	var script := _page_story
	var then := _page_story_then
	_page_story = null
	_page_story_then = Callable()
	if script == null or state != State.STORY:
		return
	if not await _play_story(script) or state != State.STORY:
		return
	if then.is_valid():
		then.call()


## 對白期間場地停止運作。用 set_deferred:與 _leave_current 的 set_deferred 依先後次序生效。
func _freeze_world(frozen: bool) -> void:
	_world.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_PAUSABLE)


## 這一關的曲子(v2.6 BV4):LevelData.music;空白時這一章的 field_music / boss_music;
## 音樂檔不存在時退回 field / boss。無盡試煉一律 field。
func _level_track(level: LevelData) -> StringName:
	var boss := level != null and level.is_boss
	var fallback := BOSS_MUSIC if boss else FIELD_MUSIC
	if is_endless() or level == null:
		return fallback
	var wanted := level.music
	if wanted == &"":
		wanted = chapter.boss_music if boss else chapter.field_music
	return _track_or(wanted, fallback)


## 這一章的頭目曲(中頭目那一波);不存在時 boss。
func _chapter_boss_track() -> StringName:
	if is_endless():
		return BOSS_MUSIC
	return _track_or(chapter.boss_music, BOSS_MUSIC)


## wanted 這首曲子存在就用它,否則用 fallback。
func _track_or(wanted: StringName, fallback: StringName) -> StringName:
	if wanted == &"" or wanted == fallback:
		return fallback
	return wanted if has_music_track(wanted) else fallback


## 曲子存在嗎:音樂播放器有 has_track() 就問它(測試的假播放器),否則找 assets/music/<id>.ogg / .wav。
func has_music_track(track: StringName) -> bool:
	if music != null and is_instance_valid(music) and music.has_method(&"has_track"):
		return bool(music.call(&"has_track", track))
	for ext: String in ["ogg", "wav"]:
		if ResourceLoader.exists("%s%s.%s" % [MUSIC_DIR, track, ext]):
			return true
	return false


# --- 教學提示(BP4) ---

func _maybe_show_tutorial() -> void:
	if is_endless() or _level_index != 0 or GameState.tutorial_done or _tutorial != null or state != State.LEVEL:
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
	get_tree().paused = state == State.LEVEL and (_pause_open or _choice_open or _event_open)


func _open_pause() -> void:
	if state != State.LEVEL or _pause_open or _choice_open or _event_open:
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


func _on_event_opened() -> void:
	var offer_shield := events != null and events.resource_path == LevelEventTable.DEFAULT_PATH \
			and BuildRoutes.is_route_event(level_events.get_open_id()) and _session != null and _session.can_borrow_shield()
	if _event_ui != null and _event_ui.has_method(&"set_shield_echo_available"):
		_event_ui.call(&"set_shield_echo_available", offer_shield)
	_event_open = true
	_apply_pause()


func _on_event_choice_applied(id: StringName) -> void:
	if BuildRoutes.is_route_event(id) and _session != null and _session.can_borrow_shield() \
			and _event_ui != null and _event_ui.has_method(&"wants_shield_echo"):
		_session.spawner.borrow_shield = _event_ui.call(&"wants_shield_echo")


func _on_event_closed() -> void:
	_event_open = false
	_apply_pause()


## LevelSession:該出抉擇事件了。
func _on_event_due(_index: int) -> void:
	if state != State.LEVEL or events == null or _session == null:
		return
	var event: LevelEvent = null
	if is_endless():
		event = events.random_endless(_event_rng, _last_endless_event)
		if event != null:
			_last_endless_event = event.id
	else:
		event = events.event_for_level(_session.level.id)
		# Override only the production first-chapter table. Custom test/lab tables
		# and later chapters/endless keep their existing event contract.
		if events.resource_path == LevelEventTable.DEFAULT_PATH and _session.level.id == &"1-1" and GameState.run_route == &"":
			event = BuildRoutes.event_for(GameState.hero_class)
		elif events.resource_path == LevelEventTable.DEFAULT_PATH:
			var encounter := BuildRoutes.encounter_for(_session.level.id)
			if encounter != null:
				event = encounter
	level_events.offer(event)


# --- 復活(v2.4 BV4) ---

## 失敗畫面的 revive_pressed:扣零食、叫醒金毛、回到同一關(波次從原處繼續)。
func _on_failure_revive() -> void:
	if state != State.FAILURE or not _last_result.get("can_revive", false) or _session == null:
		return
	var cost := int(_last_result.get("revive_cost", 0))
	if not _can_revive(cost) or not rewards.spend(cost):
		return
	_revive_used = true
	_free_node(_screen)
	_screen = null
	_freeze_world(false)
	_session.revive()
	FlowParts.call_if_present(_session.get_player(), &"revive")
	progression.resume_level()
	rewards.resume_level()
	_set_state(State.LEVEL)
	_music(&"play", [BOSS_MUSIC if _endless_boss_music else _level_track(_current_level())])
	save_now()


## 目前這一關的資料(無盡試煉是產生出來的那一關)。
func _current_level() -> LevelData:
	if _session != null and is_instance_valid(_session) and _session.level != null:
		return _session.level
	return chapter.get_level(_level_index)


# --- 新的一輪 ---

## 新遊戲、繼續冒險、無盡試煉:reset_run() 之後套用營地訓練,活力補滿。
func _prepare_run() -> void:
	progression.rebuild_stats()
	GameState.vigor = GameState.player_stats.max_vigor


## 離開無盡試煉:回到故事模式,難度回到這一輪冒險的難度(無盡試煉後段會切到困難的倍數)。
func _end_endless_mode() -> void:
	if GameState.mode == ENDLESS_MODE:
		_record_endless()
		GameState.mode = STORY_MODE
		GameState.difficulty = _run_difficulty


# --- 無盡試煉(v2.4 BV6) ---

## 開始一輪無盡試煉(標題的 endless_pressed;失敗後「再試一次」)。故事進度不受影響。
func start_endless() -> void:
	_record_endless()
	_leave_current()

	GameState.reset_run()
	progression.reset_run()
	GameState.mode = ENDLESS_MODE
	GameState.difficulty = NORMAL
	_prepare_run()
	_endless_waves = EndlessWaves.new(endless_data, _spawn_rng, GameState.chapters_cleared)
	var level := _endless_waves.make_level()
	_endless_waves.ensure_waves(level, 2)
	_endless_best_before = GameState.endless_best
	_endless_boss_music = false
	_last_endless_event = &""
	_clear_record = {}
	_snapshot = {}
	save_now()
	_open_session(level, 0, [] as Array[StringName], true)
	_story_before_pending = false
	_set_state(State.LEVEL)
	_music(&"play", [&"field"])
	if _switching:
		_session_waiting = true
	else:
		_begin_level()


func _on_endless_wave_began(index: int) -> void:
	if _session == null or _endless_waves == null:
		return
	_endless_waves.ensure_waves(_session.level, index + 1)   # 永遠有下一波
	var boss := endless_data.is_boss_wave(index)
	if not boss and _endless_boss_music:
		_music(&"play", [&"field"])
	_endless_boss_music = boss


func _on_endless_wave_done(index: int) -> void:
	var amount := economy.endless_snacks_per_wave
	if endless_data.is_boss_wave(index):
		amount += economy.endless_boss_wave_snacks
	rewards.add_snacks(amount)
	if endless_data.hard_from_wave > 0 and index + 1 >= endless_data.hard_from_wave:
		GameState.difficulty = HARD        # 之後出場的敵人用困難模式的倍數(A 線)
	save_now()                             # 存檔記下這一輪的波數(GameState.endless_best 倒下才更新)


## 這一輪無盡試煉清了幾波(不在無盡試煉時為 0)。
func _endless_run_waves() -> int:
	if is_endless() and _session != null and is_instance_valid(_session) and _session.endless:
		return _session.waves_cleared
	return 0


## 這一輪結束(倒下、回標題):更新 GameState.endless_best 並存檔。
func _record_endless() -> void:
	var waves := _endless_run_waves()
	if waves > GameState.endless_best:
		GameState.endless_best = waves
	save_now()


# --- 營地訓練(v2.4 BV5) ---

func _open_training() -> void:
	_set_state(State.TITLE)
	var scene := FlowParts.optional_scene(FlowParts.TRAINING, use_stand_ins)
	_training = scene.instantiate() if scene != null else null
	if _training == null:
		return
	_training.name = "Training"
	_screen_layer.add_child(_training)
	for signal_name: StringName in [&"closed", &"close_pressed", &"back_pressed"]:
		if _training.has_signal(signal_name):
			_training.connect(signal_name, _close_training)
	_training.tree_exiting.connect(_on_training_gone.bind(_training))


func _close_training() -> void:
	if state == State.TITLE and _training != null:
		_go(_remove_training)


func _remove_training() -> void:
	_set_state(State.TITLE)
	var node := _training
	_training = null
	_free_node(node)
	save_now()


## 訓練介面自己移除了自己(沒有發 closed):一樣存檔。
func _on_training_gone(node: Node) -> void:
	if _training == node:
		_training = null
		save_now()


# --- EventBus ---

func _on_back_requested() -> void:
	if _equipment_screen != null:
		if not _equipment_screen.back():
			_close_equipment()
		return
	match state:
		State.TITLE:
			if _quit_dialog != null:
				_close_quit_dialog()
			elif _training != null:
				pass              # 訓練介面自己處理返回鍵(發 closed);不詢問離開
			elif _credits != null:
				_close_credits()
			elif _screen != null and _screen.has_method(&"close_class_select") and _screen.call(&"close_class_select"):
				pass
			elif platform_name == "Android":
				_open_quit_dialog()
			# iOS 與桌面:沒有「離開」這回事,略過。
		State.LEVEL:
			if _choice_open or _event_open:
				return            # 正在選把戲或抉擇事件:返回鍵無效
			if _pause_open:
				_close_pause()
			else:
				_open_pause()
		_:
			pass                  # 結算、失敗、營地、轉場中、對白中:略過


func _on_app_backgrounded() -> void:
	# 先存檔(同步完成),再暫停。
	save_now()
	if state == State.LEVEL and not _choice_open and not _event_open:
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


## 零食改變:在標題(訓練)與營地(訓練、小遊戲獎勵)立即存檔;關卡中不存(太頻繁),
## 由過關、復活、切到背景、離開關卡時存。
func _on_snacks_changed(_total: int) -> void:
	if _has_unbanked_level() and _total < _last_snack_balance:
		_checkpoint["snacks"] = maxi(0, int(_checkpoint.get("snacks", 0)) + _total - _last_snack_balance)
	_last_snack_balance = _total
	if (state == State.TITLE or state == State.CAMP) and save_store != null:
		save_now()


func _on_camp_left() -> void:

	if state != State.CAMP:
		return
	_go(_start_level.bind(_level_index + 1))


# --- 介面訊號 ---

func _title_is_idle() -> bool:
	return state == State.TITLE and _credits == null and _quit_dialog == null and _training == null and _equipment_screen == null


## v2.4:標題的「無盡試煉」(打完第一章才有;C 線的標題已先設定 GameState.mode)。
func _on_title_endless() -> void:
	if not _title_is_idle():
		return
	if not GameState.chapter_cleared:
		GameState.mode = STORY_MODE
		return
	_go(start_endless)


## v2.4:標題的「訓練」(D 線的 game/camp/training.tscn;不存在就略過)。
func _on_title_training() -> void:
	if not _title_is_idle():
		return
	if FlowParts.optional_scene(FlowParts.TRAINING, use_stand_ins) == null:
		push_warning("FlowMain: 沒有訓練介面,略過")
		return
	_go(_open_training)



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
	if _campaign_credits:
		_chapter_departure = 0
		save_now()
		show_title()
		return
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


func _on_results_rest() -> void:
	if state == State.RESULTS and _chapter_departure > 0:
		_go(show_title)


func _on_failure_retry() -> void:
	if state == State.FAILURE:
		_go(retry_level)


func _on_failure_title() -> void:
	if state == State.FAILURE:
		_go(show_title)


# --- Equipment and level-boundary adventure checkpoint (v8) ---
func _capture_checkpoint() -> void:
	_checkpoint = progression.export_checkpoint()
	_checkpoint["spawn_rng"] = str(_spawn_rng.state)
	_checkpoint["event_rng"] = str(_event_rng.state)
	_checkpoint["equipment_rng"] = str(_equipment_rng.state)
	_checkpoint["snacks"] = GameState.snacks
	_last_snack_balance = GameState.snacks

func _has_unbanked_level() -> bool:
	return _session != null and not is_endless() and _clear_record.is_empty() and not _checkpoint.is_empty()

func _open_equipment() -> void:
	if state not in [State.TITLE, State.CAMP] or _equipment_screen != null or _switching or _story_playing:
		return
	_equipment_screen = EquipmentScreen.new()
	_equipment_screen.commit = _equipment_transaction
	_equipment_screen.closed.connect(_close_equipment)
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	layer.add_child(_equipment_screen)
	_equipment_screen.tree_exited.connect(layer.queue_free)

func _equipment_transaction(action: String, id: String, hero: String, slot: String, currency: String) -> Dictionary:
	if state not in [State.TITLE, State.CAMP]:
		return {"ok": false, "message": "請在營地或標題配裝。"}
	var before := GameState.equipment.duplicate(true)
	var result := EquipmentInventory.transact(GameState.equipment, action, id, hero, slot, currency, max_selectable_chapter())
	if result.ok and not save_now():
		GameState.equipment = before
		return {"ok": false, "message": "未能儲存，交易已取消。"}
	return result


func _close_equipment() -> void:
	if _equipment_screen != null:
		_equipment_screen.queue_free()
		_equipment_screen = null


func _show_guard_lesson(replay: bool) -> void:
	if state != State.LEVEL or is_endless() or _hud == null or not _hud.has_method(&"show_guard_lesson"):
		return
	var level := chapter.get_level(_level_index)
	if level == null or not level.companions.has(&"bulldog"):
		return
	if not replay and (_run_chapter != 1 or _level_index not in [2, 3] or GameState.guard_lesson_done or GameState.guard_lesson_skipped):
		return
	GameState.guard_lesson_skipped = false
	_hud.call(&"show_guard_lesson")


func _replay_guard_lesson() -> void:
	_show_guard_lesson(true)


func _on_guard_lesson_completed() -> void:
	if state != State.LEVEL:
		return
	GameState.guard_lesson_done = true
	save_now()


func _on_guard_lesson_dismissed() -> void:
	GameState.guard_lesson_skipped = true
