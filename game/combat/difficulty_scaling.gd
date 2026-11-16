class_name DifficultyScaling
extends Resource
## 難度與挑戰曲線(AS6、AS7)。實際值在 data/enemies/difficulty_scaling.tres(A 線)。
##
## 1. 難度(modes):GameState.difficulty 是 &"normal" 或 &"hard";spawn_enemy() 生成敵人時套用
##    對應的 EnemyDifficulty(生命、傷害、預警、速度、攻擊間隔)。找不到的難度當作一般模式。
## 2. 挑戰曲線(依 GameState.level_index,0 = 第 1 關):後段關卡的敵人更會合作。
##    - 同時進攻的近戰敵人上限(melee_slots_by_level):其他近戰敵人在攻擊距離外繞圈等空位。
##    - 同時瞄準的弓兵上限(ranged_slots_by_level)。
##    - 交叉火力(crossfire_from_level 起):近戰敵人開始預警時,冷卻快好的弓兵立刻瞄準同一個目標。
##    - 夾擊(pincer_from_level 起):一隻近戰敵人開始預警時,附近等著的同伴也一起出手(從不同方向)。
##    陣列比關卡少時,用最後一個值。

const PATH := "res://data/enemies/difficulty_scaling.tres"
const NORMAL: StringName = &"normal"
const MELEE: StringName = &"melee"
const RANGED: StringName = &"ranged"

@export var modes: Array[EnemyDifficulty] = []

@export_group("挑戰曲線(依關卡,AS7)")
@export var melee_slots_by_level: PackedInt32Array = PackedInt32Array([2, 3, 3, 3, 4, 4])
@export var ranged_slots_by_level: PackedInt32Array = PackedInt32Array([1, 1, 1, 2, 2, 2])
@export var crossfire_from_level: int = 3        ## 從第幾關(0 起算)開始交叉火力;< 0 = 不用
@export var crossfire_ready: float = 1.2         ## 弓兵的冷卻剩下不到這麼多秒時,會配合近戰提早瞄準
@export var pincer_from_level: int = 4           ## 從第幾關(0 起算)開始夾擊;< 0 = 不用
@export var pincer_reach: float = 16.0           ## 等著的同伴離自己的攻擊距離不到這麼遠,才會一起出手

## 測試用:換一份(null = 回到資料檔)。
static var override: DifficultyScaling
static var _loaded: DifficultyScaling
static var _identity: EnemyDifficulty


static func get_default() -> DifficultyScaling:
	if override != null:
		return override
	if _loaded == null:
		_loaded = load(PATH) as DifficultyScaling if ResourceLoader.exists(PATH) else DifficultyScaling.new()
	return _loaded


## 目前難度(GameState.difficulty)的倍數。
static func current_mode() -> EnemyDifficulty:
	return get_default().mode(GameState.difficulty)


func mode(mode_id: StringName) -> EnemyDifficulty:
	var fallback: EnemyDifficulty = null
	for m in modes:
		if m == null:
			continue
		if m.id == mode_id:
			return m
		if m.id == NORMAL:
			fallback = m
	if fallback != null:
		return fallback
	if _identity == null:
		_identity = EnemyDifficulty.new()
	return _identity


## 同時進攻(kind = melee)或瞄準(kind = ranged)的敵人上限。
func slot_limit(kind: StringName, level_index: int, mode_data: EnemyDifficulty) -> int:
	var table := ranged_slots_by_level if kind == RANGED else melee_slots_by_level
	var base := 99
	if not table.is_empty():
		base = table[clampi(level_index, 0, table.size() - 1)]
	var bonus := 0
	if mode_data != null:
		bonus = mode_data.ranged_slot_bonus if kind == RANGED else mode_data.melee_slot_bonus
	return maxi(1, base + bonus)


func crossfire_on(level_index: int) -> bool:
	return crossfire_from_level >= 0 and level_index >= crossfire_from_level


func pincer_on(level_index: int) -> bool:
	return pincer_from_level >= 0 and level_index >= pincer_from_level
