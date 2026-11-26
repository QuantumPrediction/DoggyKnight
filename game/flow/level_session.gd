class_name LevelSession
extends Node
## 一關的進行(B1、B2、B7、BP1、BP3)。由 FlowMain 建立,放在會被暫停的 World 節點之下。
##
## 兩個步驟(FlowMain 在轉場蓋住畫面時 build(),畫面露出、開打前的對白(story_before)播完之後
## 才 begin(),玩家才看得到開場):
##   build():組裝(DEV_PLAN 4.9「一關的組成」)
##     1. 實例化場地(FlowParts.arena_for),加為子節點。
##     2. arena.set_background(LevelData.background)。
##     3. 為 LevelData.companions 的每個代號呼叫 arena.spawn_companion()
##        (這一關才「加入」的同伴(arriving,例如 1-3 的鬥牛犬)留到 begin() 才出場,玩家看得到)。
##   begin():新加入的同伴出場;發 EventBus.level_started,開始計時;等 intro_duration 秒
##     (HUD 播關卡標題卡,金毛可以走動)才開始第一波,這時發本地訊號 intro_finished。
##   start() = build() + begin()(沒有轉場時用)。
## 進行中:記錄擊倒數(enemy_died)、受到的傷害(player_damaged,星級用)與用時
##   (由 begin() 起算,只在遊戲沒有暫停時累計)。
## 結束:
##   - 最後一波清空 → 發 level_completed、發本地訊號 cleared;
##     再等 results_delay 秒(HUD 慶祝、經驗珠飛完)→ 發 finished(true)。
##   - 收到 player_downed → 停止生成敵人;等 failure_delay 秒 → 發 level_failed、發 finished(false)。
## 音效 clear / fail 由結算畫面自己播(C 線),音樂由 FlowMain 播,這裡都不播,避免重複。
## v2.4:
##   - 抉擇事件:event_after_wave >= 1 時,第 event_after_wave 波清空 event_delay 秒之後發 event_due;
##     0 = 開場結束(第一波開始)時發;event_every > 0(無盡試煉)= 每清 event_every 波一次。
##   - 倒下時波次生成器先停住(hold),failure_delay 秒後照樣發 level_failed / finished(false);
##     revive() 讓這一關從原處繼續(復活)。真的離開時由 teardown() 結束。
##   - waves_cleared:已清空的波數(無盡試煉的紀錄)。
## 計時都在 _process 裡做,遊戲暫停(選把戲、暫停選單、切到背景)時不會走。

signal intro_finished()
signal cleared()
signal finished(victory: bool)
## 有中頭目(1-4 的稻草人隊長)的一波開始(v2.3;FlowMain 改播頭目音樂)。
signal boss_wave_started(index: int)
## v2.4:該出抉擇事件了(index = 剛清空的波;0 = 開場之後)。
signal event_due(index: int)
## v2.4:第 index 波開始 / 清空(轉發 WaveSpawner 的 wave_began / wave_done)。
signal wave_began(index: int)
signal wave_done(index: int)

enum State { READY, PLAYING, WON, DOWNED, OVER }

var level: LevelData
var level_index: int = 0
var difficulty: DifficultyData
var arena_scene: PackedScene
var rng: RandomNumberGenerator
## 這一關才加入的同伴(畫面露出後才出場);其他同伴在 build() 時就已經在場上。
var arriving: Array[StringName] = []
## v2.3:&"normal" 或 &"hard"(困難模式每組多加幾隻,見 WaveSpawner.spawn_count)。
var difficulty_mode: StringName = &"normal"
## v2.4 抉擇事件在第幾波清空之後(0 = 開場之後;-1 = 沒有)。
var event_after_wave: int = -1
## v2.4 無盡試煉:每清這麼多波一次事件(0 = 不用)。
var event_every: int = 0
## v2.4 無盡試煉(WaveSpawner.endless)。
var endless: bool = false

var state: State = State.READY
var time_sec: float = 0.0
var kills: int = 0
## 這一關金毛受到的傷害總和(player_damaged 的數值,已乘上受傷倍率)。
var damage_taken: int = 0
## v2.4:已清空的波數。
var waves_cleared: int = 0
## v2.4:這一關復活過幾次。
var revives: int = 0

var arena: Node
var spawner: WaveSpawner
var _countdown: float = 0.0
var _built: bool = false
var _intro_done: bool = false
var _event_countdown: float = -1.0
var _event_index: int = 0


func setup(level_data: LevelData, index: int, curve: DifficultyData, scene: PackedScene,
		random: RandomNumberGenerator) -> void:
	level = level_data
	level_index = index
	difficulty = curve
	arena_scene = scene
	rng = random


func _enter_tree() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_downed.connect(_on_player_downed)
	EventBus.player_damaged.connect(_on_player_damaged)


func _exit_tree() -> void:
	EventBus.enemy_died.disconnect(_on_enemy_died)
	EventBus.player_downed.disconnect(_on_player_downed)
	EventBus.player_damaged.disconnect(_on_player_damaged)


## 建立場地並開始這一關(沒有轉場時用)。
func start(progression: RunProgression) -> void:
	build()
	begin(progression)


## 組裝場地、背景、同伴與波次生成器(還不開始)。
func build() -> void:
	if _built:
		return
	_built = true
	arena = arena_scene.instantiate() if arena_scene != null else null
	if arena == null:
		push_error("LevelSession: 無法建立場地")
		return
	arena.name = "Arena"
	if arena is Node2D:
		(arena as Node2D).position = Vector2.ZERO     # 場地在世界原點(相機、邊界、主角都在場地內)
	add_child(arena)
	if level.background != null:
		FlowParts.call_if_present(arena, &"set_background", [level.background])
	for companion_id in level.companions:
		if not arriving.has(companion_id):
			FlowParts.call_if_present(arena, &"spawn_companion", [companion_id])

	spawner = WaveSpawner.new()
	spawner.name = "WaveSpawner"
	spawner.setup(level, arena, difficulty, rng)
	spawner.difficulty_mode = difficulty_mode
	spawner.endless = endless
	spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	spawner.wave_began.connect(_on_wave_began)
	spawner.boss_wave_began.connect(boss_wave_started.emit)
	spawner.wave_done.connect(_on_wave_done)
	add_child(spawner)


## 開始這一關:發 level_started,開場 intro_duration 秒之後第一波。progression 會發出經驗初始值。
func begin(progression: RunProgression) -> void:
	build()
	if state != State.READY or arena == null:
		return
	for companion_id in arriving:
		if level.companions.has(companion_id):
			FlowParts.call_if_present(arena, &"spawn_companion", [companion_id])
	state = State.PLAYING
	time_sec = 0.0
	kills = 0
	damage_taken = 0
	waves_cleared = 0
	revives = 0
	_intro_done = false
	_event_countdown = -1.0
	EventBus.level_started.emit(level.id)
	if progression != null:
		progression.begin_level()
	spawner.start(maxf(0.0, difficulty.intro_duration) + maxf(0.0, difficulty.first_wave_delay))


func is_built() -> bool:
	return _built


func is_playing() -> bool:
	return state == State.PLAYING


## 金毛已倒下(等待失敗結算或已顯示失敗結算)。
func is_downed() -> bool:
	return state == State.DOWNED or (state == State.OVER and spawner != null and spawner.is_held())


## 復活(v2.4):倒下之後回到戰鬥,波次從原處繼續。傳回是否成功。主角的 revive() 由 FlowMain 呼叫。
func revive() -> bool:
	if not is_downed():
		return false
	state = State.PLAYING
	revives += 1
	if spawner != null:
		spawner.release()
	return true


## 開場(標題卡)已結束、第一波已開始。
func is_intro_done() -> bool:
	return _intro_done


func get_player() -> Node2D:
	if arena != null and arena.has_method(&"get_player"):
		return arena.call(&"get_player") as Node2D
	return null


## 移除場地之前呼叫:清掉敵人,並讓它們立即離開 "enemy" 群組,
## 這樣緊接著開始的下一關(例如重試)不會把舊敵人算進去。
func teardown() -> void:
	state = State.OVER
	if spawner != null:
		spawner.stop()
	if arena != null and is_instance_valid(arena):
		FlowParts.call_if_present(arena, &"clear")
		for node in get_tree().get_nodes_in_group(&"enemy"):
			if arena.is_ancestor_of(node):
				node.remove_from_group(&"enemy")


func _process(delta: float) -> void:
	match state:
		State.PLAYING:
			time_sec += delta
			if _event_countdown >= 0.0:
				_event_countdown -= delta
				if _event_countdown <= 0.0:
					_event_countdown = -1.0
					event_due.emit(_event_index)
		State.WON:
			_countdown -= delta
			if _countdown <= 0.0:
				state = State.OVER
				finished.emit(true)
		State.DOWNED:
			_countdown -= delta
			if _countdown <= 0.0:
				state = State.OVER
				EventBus.level_failed.emit(level.id)
				finished.emit(false)


func can_borrow_shield() -> bool:
	return state == State.PLAYING and level != null and spawner != null and not endless \
			and difficulty_mode in [FlowMain.NORMAL, FlowMain.REINFORCED] \
			and level.id == &"1-1" and waves_cleared == 1 and spawner.current_wave() == 1 \
			and level.waves.size() > 1 and not level.waves[1].shield_echo_spawns.is_empty()


func _on_wave_began(index: int) -> void:
	if index == 2 and spawner != null and spawner.borrow_shield:
		FlowParts.call_if_present(arena, &"spawn_companion", [&"shield_echo"])
	if index == 1 and not _intro_done:
		_intro_done = true
		intro_finished.emit()
		if event_after_wave == 0 and event_every <= 0 and state == State.PLAYING:
			event_due.emit(0)
	wave_began.emit(index)


func _on_wave_done(index: int) -> void:
	if state != State.PLAYING:
		return
	waves_cleared = index
	wave_done.emit(index)
	var due := (event_every > 0 and index % event_every == 0) or (event_every <= 0 and event_after_wave > 0 \
			and index == event_after_wave)
	if due and (spawner == null or index < spawner.total_waves() or endless):
		_event_index = index
		_event_countdown = maxf(0.0, difficulty.event_delay)
		if _event_countdown <= 0.0:
			_event_countdown = -1.0
			event_due.emit(index)


func _on_enemy_died(_enemy_id: StringName, _position: Vector2, _exp_value: int) -> void:
	if state == State.PLAYING:
		kills += 1


func _on_player_damaged(amount: int) -> void:
	if state == State.PLAYING:
		damage_taken += maxi(0, amount)


func _on_all_waves_cleared() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	_countdown = difficulty.results_delay
	EventBus.level_completed.emit(level.id)
	cleared.emit()


func _on_player_downed() -> void:
	if state != State.PLAYING:
		return
	state = State.DOWNED
	_countdown = difficulty.failure_delay
	_event_countdown = -1.0
	if spawner != null:
		spawner.hold()
