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

var _ramped: Dictionary = {}

@export_group("挑戰曲線(依關卡,AS7)")
## v2.4 整合:故事模式每關的敵人生命與傷害倍數(第 1 關起算;第 1 關保持溫和,之後逐步加強)。
@export var hp_ramp_by_level: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
@export var damage_ramp_by_level: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
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


## 目前難度(GameState.difficulty)的倍數,再乘上故事模式該關的成長曲線(hp/damage_ramp_by_level)。
static func current_mode() -> EnemyDifficulty:
	var scaling := get_default()
	var base := scaling.mode(GameState.difficulty)
	var index := GameState.level_index if GameState.mode == &"story" else -1
	var hp_k := _ramp(scaling.hp_ramp_by_level, index)
	var dmg_k := _ramp(scaling.damage_ramp_by_level, index)
	if is_equal_approx(hp_k, 1.0) and is_equal_approx(dmg_k, 1.0):
		return base
	var key := "%s:%d" % [base.id, index]
	if not scaling._ramped.has(key):
		var m := base.duplicate() as EnemyDifficulty
		m.hp_mult *= hp_k
		m.boss_hp_mult *= hp_k
		m.damage_mult *= dmg_k
		scaling._ramped[key] = m
	return scaling._ramped[key]


static func _ramp(values: PackedFloat32Array, index: int) -> float:
	if index < 0 or values.is_empty():
		return 1.0
	return values[mini(index, values.size() - 1)]


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
