class_name LevelSession
extends Node
## 一關的進行(B1、B2、B7、BP1、BP3)。由 FlowMain 建立,放在會被暫停的 World 節點之下。
##
## 兩個步驟(FlowMain 在轉場蓋住畫面時 build(),畫面露出後 begin(),玩家才看得到開場):
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
## 計時都在 _process 裡做,遊戲暫停(選把戲、暫停選單、切到背景)時不會走。

signal intro_finished()
signal cleared()
signal finished(victory: bool)

enum State { READY, PLAYING, WON, DOWNED, OVER }

var level: LevelData
var level_index: int = 0
var difficulty: DifficultyData
var arena_scene: PackedScene
var rng: RandomNumberGenerator
## 這一關才加入的同伴(畫面露出後才出場);其他同伴在 build() 時就已經在場上。
var arriving: Array[StringName] = []

var state: State = State.READY
var time_sec: float = 0.0
var kills: int = 0
## 這一關金毛受到的傷害總和(player_damaged 的數值,已乘上受傷倍率)。
var damage_taken: int = 0

var arena: Node
var spawner: WaveSpawner
var _countdown: float = 0.0
var _built: bool = false
var _intro_done: bool = false


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
	spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	spawner.wave_began.connect(_on_wave_began)
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
	_intro_done = false
	EventBus.level_started.emit(level.id)
	if progression != null:
		progression.begin_level()
	spawner.start(maxf(0.0, difficulty.intro_duration) + maxf(0.0, difficulty.first_wave_delay))


func is_built() -> bool:
	return _built


func is_playing() -> bool:
	return state == State.PLAYING


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


func _on_wave_began(index: int) -> void:
	if index == 1 and not _intro_done:
		_intro_done = true
		intro_finished.emit()


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
	if spawner != null:
		spawner.stop()
