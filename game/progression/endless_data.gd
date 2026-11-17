class_name EndlessData
extends Resource
## 無盡試煉的參數(v2.4 BV6)。資料在 data/levels/endless.tres;波次由 EndlessWaves 依這些參數產生。
##
## 一波接一波,沒有盡頭;每波的「敵人預算」= budget_base + (波數 − 1) × budget_per_wave,
## 用 enemy_costs 買敵人(新解鎖的敵人在解鎖那一波一定出現),分成幾組陸續出場,隊形隨機。
## 每 boss_every 波是頭目波:boss_every × 2 的倍數是黑騎士,其他是稻草人隊長,另加少量護衛。
## 每 event_every 波清空之後有一次抉擇事件(data/levels/events.tres 的 endless_pool)。
## 從第 hard_from_wave 波起,敵人改用困難模式的倍數(A 線依 GameState.difficulty 放大)。

@export var level_id: StringName = &"endless"
@export var display_name: String = "LEVEL_ENDLESS"
## 每次開始隨機選一個背景。
@export var backgrounds: Array[PackedScene] = []
@export var companions: Array[StringName] = [&"bulldog"]

@export_group("Enemies")
@export var enemy_ids: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_archer", &"scarecrow_elite",
		&"armored_husk"]
## 每種敵人花多少預算(與 enemy_ids 同次序)。
@export var enemy_costs: Array[int] = [1, 1, 2, 3, 3]
## 每種敵人從第幾波開始出現(與 enemy_ids 同次序)。
@export var enemy_unlock_wave: Array[int] = [1, 2, 3, 4, 6]
## 抽中機會的權重(與 enemy_ids 同次序)。
@export var enemy_weights: Array[float] = [3.0, 2.0, 1.5, 1.0, 1.0]

@export_group("Budget")
@export var budget_base: float = 6.0
@export var budget_per_wave: float = 1.6
## 每波最多幾隻(不含頭目)。
@export var max_enemies_per_wave: int = 24
## 每波分成幾組(隨機,含兩端)。
@export var groups_min: int = 2
@export var groups_max: int = 4
## 每組相隔的秒數。
@export var group_gap: float = 4.5
## 隊形(SpawnEntry.pattern)。surround 從 surround_from_wave 起才會出現。
@export var patterns: Array[StringName] = [&"edges", &"line_top", &"corners", &"surround"]
@export var surround_from_wave: int = 3

@export_group("Bosses")
@export var boss_every: int = 5
@export var mini_boss_id: StringName = &"scarecrow_captain"
@export var boss_id: StringName = &"black_knight"
## 頭目波的護衛 = 該波預算 × 這個比例(黑騎士波從第 boss_escort_from 波起才有護衛)。
@export var escort_ratio: float = 0.35
@export var boss_escort_from: int = 20

@export_group("Flow")
@export var event_every: int = 10
## 從這一波起敵人用困難模式的倍數(0 = 不切換)。
@export var hard_from_wave: int = 16


func is_boss_wave(wave: int) -> bool:
	return boss_every > 0 and wave > 0 and wave % boss_every == 0


func boss_for_wave(wave: int) -> StringName:
	if not is_boss_wave(wave):
		return &""
	return boss_id if wave % (boss_every * 2) == 0 else mini_boss_id


func is_event_wave(wave: int) -> bool:
	return event_every > 0 and wave > 0 and wave % event_every == 0


func budget_for(wave: int) -> float:
	return budget_base + float(maxi(0, wave - 1)) * budget_per_wave
