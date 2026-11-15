class_name HeroExperience
extends RefCounted
## 經驗與等級的計算(B4),不碰場景,方便測試。
##
## 經驗乘上 exp_mult 後可能有小數(例如「尋回」+20%:1 顆經驗珠 = 1.2)。
## 這裡以「百分之一」為單位用整數累計(centi),所以小數部分會保留到下一顆,
## 不會被四捨五入吃掉,也不會有浮點誤差。exp_changed 顯示時取整數部分(無條件捨去)。

const CENTI: int = 100

var level: int = 1
var _centi: int = 0
var _curve: DifficultyData


func _init(curve: DifficultyData, start_level: int = 1, start_centi: int = 0) -> void:
	_curve = curve
	level = maxi(1, start_level)
	_centi = maxi(0, start_centi)


## 加入原始經驗 amount(乘上 mult)。傳回這次升了幾級(可能大於 1)。
func add(amount: int, mult: float = 1.0) -> int:
	if amount <= 0:
		return 0
	_centi += maxi(0, roundi(float(amount) * mult * CENTI))
	var gained := 0
	while _centi >= needed() * CENTI:
		_centi -= needed() * CENTI
		level += 1
		gained += 1
	return gained


## 這一級已累積的經驗(整數部分)。
func current() -> int:
	@warning_ignore("integer_division")
	return _centi / CENTI


## 升到下一級需要的經驗。
func needed() -> int:
	return _curve.exp_to_next(level)


## 內部累計值(百分之一為單位),給重試快照用。
func get_centi() -> int:
	return _centi


func set_state(new_level: int, centi: int) -> void:
	level = maxi(1, new_level)
	_centi = maxi(0, centi)
