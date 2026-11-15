class_name LevelSession
extends Node
## 一關的進行(B1、B2、B7)。由 FlowMain 建立,放在會被暫停的 World 節點之下。
##
## 組裝(DEV_PLAN 4.9「一關的組成」):
##   1. 實例化場地(FlowParts.arena_for),加為子節點。
##   2. arena.set_background(LevelData.background)。
##   3. 為 LevelData.companions 的每個代號呼叫 arena.spawn_companion()。
##   4. 發 EventBus.level_started,開始波次。
## 進行中:記錄擊倒數(enemy_died)與用時(只在遊戲沒有暫停時累計)。
## 結束:
##   - 最後一波清空 → 發 level_completed、發本地訊號 cleared;
##     再等 results_delay 秒(讓經驗珠飛完)→ 發 finished(true)。
##   - 收到 player_downed → 停止生成敵人;等 failure_delay 秒 → 發 level_failed、發 finished(false)。
## 音效 clear / fail 由結算畫面自己播(C 線的 results / failure 畫面出現時播放),這裡不播,避免重複。
## 計時都在 _process 裡做,遊戲暫停(選把戲、暫停選單、切到背景)時不會走。

signal cleared()
signal finished(victory: bool)

enum State { READY, PLAYING, WON, DOWNED, OVER }

var level: LevelData
var level_index: int = 0
var difficulty: DifficultyData
var arena_scene: PackedScene
var rng: RandomNumberGenerator

var state: State = State.READY
var time_sec: float = 0.0
var kills: int = 0

var arena: Node
var spawner: WaveSpawner
var _countdown: float = 0.0


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


func _exit_tree() -> void:
	EventBus.enemy_died.disconnect(_on_enemy_died)
	EventBus.player_downed.disconnect(_on_player_downed)


## 建立場地並開始這一關。progression 會在 level_started 之後發出經驗初始值。
func start(progression: RunProgression) -> void:
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
		FlowParts.call_if_present(arena, &"spawn_companion", [companion_id])

	spawner = WaveSpawner.new()
	spawner.name = "WaveSpawner"
	spawner.setup(level, arena, difficulty, rng)
	spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	add_child(spawner)

	state = State.PLAYING
	time_sec = 0.0
	kills = 0
	EventBus.level_started.emit(level.id)
	if progression != null:
		progression.begin_level()
	spawner.start()


func is_playing() -> bool:
	return state == State.PLAYING


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


func _on_enemy_died(_enemy_id: StringName, _position: Vector2, _exp_value: int) -> void:
	if state == State.PLAYING:
		kills += 1


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
