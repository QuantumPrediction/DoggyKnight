class_name TrickDeck
extends RefCounted
## 把戲的抽選與數值套用(B5)。
##
## 抽選:從 DifficultyData.trick_pool 隨機抽 N 個「不同」的把戲(可傳入固定種子的 RNG 方便測試)。
## 同一個把戲可以在不同次升級時重複出現、重複選,效果疊加(DEV_PLAN 4.7)。
##
## 數值套用(DEV_PLAN 4.9):相加,以基準值計算。
##   新值 = 目前值 + 基準值 × 修正值
##   {"move_speed": 0.15}       → 移動速度 +基準的 15%(70 → 80.5)
##   {"damage_taken_mult": -0.2} → 1.0 → 0.8,再選一次 → 0.6
## 整數欄位(例如 max_vigor、attack_damage)四捨五入。任何數值都不會低於 0;
## damage_taken_mult 不會低於 DifficultyData.min_damage_taken_mult。
## 能力類把戲(is_ability)不改數值,由 A 線聽 trick_chosen 後啟用。

const TRICK_DIR: String = "res://data/tricks"

var _tricks: Dictionary = {}          # StringName → TrickData
var _order: Array[StringName] = []


func _init(pool: Array[StringName]) -> void:
	for id in pool:
		var trick := load_trick(id)
		if trick == null:
			push_warning("TrickDeck: 找不到把戲資料 %s" % id)
			continue
		_tricks[id] = trick
		_order.append(id)


static func trick_path(id: StringName) -> String:
	return "%s/%s.tres" % [TRICK_DIR, id]


static func load_trick(id: StringName) -> TrickData:
	var path := trick_path(id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TrickData


func size() -> int:
	return _order.size()


func has_trick(id: StringName) -> bool:
	return _tricks.has(id)


func get_trick(id: StringName) -> TrickData:
	return _tricks.get(id) as TrickData


## 隨機抽 count 個不同的把戲。牌堆不夠時,能抽多少就抽多少。
func draw(count: int, rng: RandomNumberGenerator) -> Array[TrickData]:
	var ids: Array[StringName] = _order.duplicate()
	# Fisher–Yates,只用傳入的 RNG,同一個種子永遠得到同一個結果。
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var result: Array[TrickData] = []
	for i in mini(count, ids.size()):
		result.append(_tricks[ids[i]])
	return result


## 把一個把戲的 stat_modifiers 加到 stats 上(相加,以 base 的數值為基準)。
static func apply_modifiers(stats: StatBlock, base: StatBlock, modifiers: Dictionary,
		min_damage_taken_mult: float = 0.0) -> void:
	for key: Variant in modifiers:
		var field := StringName(str(key))
		var current: Variant = stats.get(field)
		var base_value: Variant = base.get(field)
		if current == null or base_value == null or not (typeof(current) in [TYPE_INT, TYPE_FLOAT]):
			push_warning("TrickDeck: StatBlock 沒有數值欄位 %s" % field)
			continue
		var delta := float(base_value) * float(modifiers[key])
		var value := maxf(0.0, float(current) + delta)
		if field == &"damage_taken_mult":
			value = maxf(min_damage_taken_mult, value)
		if typeof(current) == TYPE_INT:
			stats.set(field, roundi(value))
		else:
			stats.set(field, value)
