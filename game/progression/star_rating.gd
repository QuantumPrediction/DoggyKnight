class_name StarRating
extends RefCounted
## 星級(BP3,DEV_PLAN 4.10)。每一關有三個目標,達成一個就得一顆星:
##   ★ 過關(STAR_CLEAR)
##   ★ 在 LevelData.par_time 秒內過關(STAR_TIME,文字含一個 %d = 秒數)
##   ★ 這一關受到的傷害不超過 LevelData.damage_budget(STAR_DAMAGE,文字含一個 %d = 點數;
##     damage_budget 為 0 時改用 STAR_NO_DAMAGE「不被打中過關」,沒有 %d)
## 時間與傷害兩個目標只有過關時才算達成;失敗一律 0 星。三個目標各自獨立
## (例如慢慢打但完全沒受傷 = 2 星)。
##
## star_goals 每一項:{"key": 翻譯鍵, "met": bool, "value": int(門檻;過關那項是 0),
##                     "text": 已翻譯、已填入數字的文字}
## 介面可以直接顯示 text;或者 tr(key),含 %d 時再 % value。

const KEY_CLEAR: String = "STAR_CLEAR"
const KEY_TIME: String = "STAR_TIME"
const KEY_DAMAGE: String = "STAR_DAMAGE"
const KEY_NO_DAMAGE: String = "STAR_NO_DAMAGE"
const MAX_STARS: int = 3
## 困難模式的最佳星數存在「關卡 id + 這個字尾」(DEV_PLAN 4.11:best_stars["1-1:hard"])。
const HARD_SUFFIX: String = ":hard"


## best_stars 的鍵:一般模式 = 關卡 id("1-1");困難模式 = "1-1:hard"。
static func record_key(level_id: StringName, difficulty: StringName = &"normal") -> String:
	return String(level_id) + (HARD_SUFFIX if difficulty == &"hard" else "")


## 三個目標(依序:過關、時間、傷害)。
static func goals(level: LevelData, victory: bool, time_sec: float, damage_taken: int) -> Array[Dictionary]:
	var par := par_seconds(level)
	var budget := maxi(0, level.damage_budget) if level != null else 0
	var damage_key := KEY_NO_DAMAGE if budget == 0 else KEY_DAMAGE
	var result: Array[Dictionary] = [
		_goal(KEY_CLEAR, victory, 0),
		_goal(KEY_TIME, victory and time_sec <= float(par) + 0.0001, par),
		_goal(damage_key, victory and damage_taken <= budget, budget),
	]
	return result


## 達成的目標數目 = 星數(0 至 3)。
static func count(goal_list: Array) -> int:
	var stars := 0
	for goal: Dictionary in goal_list:
		if goal.get("met", false):
			stars += 1
	return mini(stars, MAX_STARS)


## 時間目標的秒數(整數,介面顯示用;判定也用這個整數)。
static func par_seconds(level: LevelData) -> int:
	if level == null:
		return 0
	return maxi(1, floori(level.par_time))


static func _goal(key: String, met: bool, value: int) -> Dictionary:
	return {"key": key, "met": met, "value": value, "text": format(key, value)}


## 翻譯並填入數字(文字裡沒有 %d 時不填)。
static func format(key: String, value: int) -> String:
	var text := String(TranslationServer.translate(key))
	if text.contains("%d"):
		return text % value
	return text
