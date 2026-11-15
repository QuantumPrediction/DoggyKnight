class_name MinigameGrading
extends Resource
## 小遊戲的評分與獎勵(DEV_PLAN 11 D3)。數值全部放在 .tres,方便 M3 調整。
##
## 評價 0 至 3:分數達到 grade_thresholds[i] 就至少是 i + 1 級。
## 獎勵(依評價取第 grade 個值):
## - 活力回復:vigor_restore_ratio × player_stats.max_vigor,最多回到上限。
## - 滿意度:加 satisfaction_gain,限制在 0 至 100。
## - next_level_bonus:直接設為 next_level_bonus 的值(0.05 = 下一關攻擊 +5%)。

const SATISFACTION_MIN: int = 0
const SATISFACTION_MAX: int = 100

## 評價 1、2、3 各自需要的最低分數(由小到大)。
@export var grade_thresholds: Array[int] = [80, 160, 240]
## 評價 0 至 3 的活力回復比例。
@export var vigor_restore_ratio: Array[float] = [0.25, 0.5, 0.75, 1.0]
## 評價 0 至 3 增加的滿意度。
@export var satisfaction_gain: Array[int] = [5, 10, 20, 30]
## 評價 0 至 3 給下一關的攻擊加成。
@export var next_level_bonus: Array[float] = [0.0, 0.05, 0.10, 0.15]


func max_grade() -> int:
	return grade_thresholds.size()


func grade_for(score: int) -> int:
	var grade := 0
	for i in grade_thresholds.size():
		if score >= grade_thresholds[i]:
			grade = i + 1
	return grade


## 把獎勵套用到 state(GameState Autoload,或測試用的同型物件)。
## 傳回實際的變化,給介面顯示:{"vigor": 回復量, "satisfaction": 增加量, "bonus": 加成}。
func apply_rewards(grade: int, state: Object) -> Dictionary:
	var g := clampi(grade, 0, max_grade())
	var stats := state.get(&"player_stats") as StatBlock
	var max_vigor: int = stats.max_vigor if stats != null else 100
	var old_vigor: int = state.get(&"vigor")
	var restore := roundi(_pick_float(vigor_restore_ratio, g) * max_vigor)
	var new_vigor := clampi(old_vigor + restore, 0, max_vigor)
	state.set(&"vigor", new_vigor)

	var old_satisfaction: int = state.get(&"satisfaction")
	var new_satisfaction := clampi(old_satisfaction + _pick_int(satisfaction_gain, g), SATISFACTION_MIN, SATISFACTION_MAX)
	state.set(&"satisfaction", new_satisfaction)

	var bonus := _pick_float(next_level_bonus, g)
	state.set(&"next_level_bonus", bonus)
	return {
		"vigor": new_vigor - old_vigor,
		"satisfaction": new_satisfaction - old_satisfaction,
		"bonus": bonus,
	}


static func _pick_float(values: Array[float], index: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(index, 0, values.size() - 1)]


static func _pick_int(values: Array[int], index: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(index, 0, values.size() - 1)]
