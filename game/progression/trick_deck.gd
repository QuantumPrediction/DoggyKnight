class_name TrickDeck
extends RefCounted
## 把戲的抽選、進化與數值套用(B5、v2.4 BV1)。
##
## 抽選:從 DifficultyData.trick_pool(基本把戲)隨機抽 N 個「不同」的把戲(可傳入固定種子的 RNG)。
## 同一個把戲可以在不同次升級時重複選,效果疊加(DEV_PLAN 4.7),但最多 TrickData.max_level 次
## (基本把戲 3 次);已到上限的把戲不會再出現。
##
## 進化(DEV_PLAN 4.12):把戲 A 到了 max_level、而且已經學了 A.evolution_partner(至少 1 次),
## 還沒有 A.evolves_into 時,這個進化把戲「一定」出現在下一次三選一(排在最前面)。
## 進化把戲(is_evolution)不會出現在一般抽選;學了進化把戲之後,它的兩個來源也不會再出現。
## 選了進化:RunProgression 把兩個來源從 GameState.active_tricks 全部移除,換成進化把戲。
##
## owned_weight(DifficultyData.owned_trick_weight):已經學過、還沒到上限的把戲,抽中的機會是
## 其他把戲的這麼多倍(讓把戲比較容易練滿、進化)。1.0 = 平均。
##
## 數值套用(DEV_PLAN 4.9):相加,以基準值計算。
##   新值 = 目前值 + 基準值 × 修正值
##   {"move_speed": 0.15}       → 移動速度 +基準的 15%(70 → 80.5)
##   {"damage_taken_mult": -0.2} → 1.0 → 0.8,再選一次 → 0.6
## 整數欄位(例如 max_vigor、attack_damage)四捨五入。任何數值都不會低於 0;
## damage_taken_mult 不會低於 DifficultyData.min_damage_taken_mult。
## stat_modifiers 也可以有不是 StatBlock 欄位的「額外加成」(EXTRA_KEYS,例如嗅嗅的暴擊率):
## 這裡不套用,由 A 線用 TrickDeck.extra_bonus(鍵) 讀取目前的總和。
## 能力類把戲(is_ability)的效果由 A 線聽 trick_chosen / trick_evolved 後啟用;
## 有 stat_modifiers 的進化把戲(例如旋風尾的移動速度)數值部分仍由 B 線套用。

const TRICK_DIR: String = "res://data/tricks"
## 不是 StatBlock 欄位的額外加成(A 線讀取):
##   crit_chance  暴擊率(相加,0.08 = +8%)
##   snack_chance 敵人掉零食的機率(相乘的加成,0.5 = +50%)
##   snack_heal   吃到零食回復的活力(B 線在 snack_collected 時呼叫主角的 heal)
const EXTRA_KEYS: Array[StringName] = [&"crit_chance", &"snack_chance", &"snack_heal"]
## 安全下限(不是手感數值):摩根娜的誘惑選很多次也不會讓活力上限變 0、攻擊間隔變 0。
const SAFETY_FLOORS: Dictionary = {&"max_vigor": 10, &"attack_interval": 0.15, &"move_speed": 20.0}

## 已經學過的把戲,抽中機會的倍數(見檔頭)。
var owned_weight: float = 1.0

var _tricks: Dictionary = {}          # StringName → TrickData(基本把戲與進化把戲)
var _order: Array[StringName] = []    # 基本把戲(可以抽到的),依 trick_pool 的次序
var _evolutions: Array[StringName] = []


func _init(pool: Array[StringName]) -> void:
	for id in pool:
		var trick := load_trick(id)
		if trick == null:
			push_warning("TrickDeck: 找不到把戲資料 %s" % id)
			continue
		if trick.is_evolution:
			push_warning("TrickDeck: 進化把戲 %s 不應放在 trick_pool" % id)
			continue
		_tricks[id] = trick
		_order.append(id)
	for id in _order:
		var evolution_id := (_tricks[id] as TrickData).evolves_into
		if evolution_id == &"" or _tricks.has(evolution_id):
			continue
		var evolution := load_trick(evolution_id)
		if evolution == null:
			push_warning("TrickDeck: 找不到進化把戲資料 %s" % evolution_id)
			continue
		_tricks[evolution_id] = evolution
		_evolutions.append(evolution_id)


static func trick_path(id: StringName) -> String:
	return "%s/%s.tres" % [TRICK_DIR, id]


static func load_trick(id: StringName) -> TrickData:
	var path := trick_path(id)
	if id == &"" or not ResourceLoader.exists(path):
		return null
	return load(path) as TrickData


## 一個把戲在 owned(通常是 GameState.active_tricks)中出現幾次 = 等級。
static func count_in(owned: Array, id: StringName) -> int:
	var n := 0
	for item: Variant in owned:
		if StringName(item) == id:
			n += 1
	return n


## A 線用:目前所有把戲的某個額外加成(EXTRA_KEYS)的總和,依 GameState.active_tricks 計算。
static func extra_bonus(key: StringName, owned: Array = GameState.active_tricks) -> float:
	var total := 0.0
	for item: Variant in owned:
		var trick := load_trick(StringName(item))
		if trick != null and trick.stat_modifiers.has(String(key)):
			total += float(trick.stat_modifiers[String(key)])
		elif trick != null and trick.stat_modifiers.has(key):
			total += float(trick.stat_modifiers[key])
	return total


## 基本把戲的數目(可以抽到的)。
func size() -> int:
	return _order.size()


func has_trick(id: StringName) -> bool:
	return _tricks.has(id)


func get_trick(id: StringName) -> TrickData:
	return _tricks.get(id) as TrickData


func evolution_ids() -> Array[StringName]:
	return _evolutions.duplicate()


## 進化把戲的兩個來源(基本把戲中 evolves_into == evolution_id 的)。
func sources_of(evolution_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in _order:
		if (_tricks[id] as TrickData).evolves_into == evolution_id:
			result.append(id)
	return result


## 這個把戲已經到上限(max_level <= 0 表示沒有上限)。
func is_maxed(id: StringName, owned: Array) -> bool:
	var trick := get_trick(id)
	if trick == null:
		return false
	return trick.max_level > 0 and count_in(owned, id) >= trick.max_level


## 現在可以進化的進化把戲(依 trick_pool 的次序,不重複)。
func eligible_evolutions(owned: Array) -> Array[TrickData]:
	var result: Array[TrickData] = []
	for id in _order:
		var trick := _tricks[id] as TrickData
		var evolution_id := trick.evolves_into
		if evolution_id == &"" or trick.evolution_partner == &"" or not _tricks.has(evolution_id):
			continue
		if owned.has(evolution_id) or count_in(owned, evolution_id) > 0:
			continue
		if not is_maxed(id, owned) or count_in(owned, trick.evolution_partner) < 1:
			continue
		var evolution := _tricks[evolution_id] as TrickData
		if not result.has(evolution):
			result.append(evolution)
	return result


## 現在抽得到的基本把戲:沒到上限,而且不是已學會的進化把戲的來源。
func available(owned: Array) -> Array[StringName]:
	var consumed: Array[StringName] = []
	for evolution_id in _evolutions:
		if count_in(owned, evolution_id) > 0:
			consumed.append_array(sources_of(evolution_id))
	var result: Array[StringName] = []
	for id in _order:
		if not consumed.has(id) and not is_maxed(id, owned):
			result.append(id)
	return result


## 三選一:可以進化的進化把戲排最前面,其餘隨機抽「不同」的基本把戲。能抽多少就抽多少。
## owned 留空時(舊的呼叫方式)= 沒有學過任何把戲。
func draw(count: int, rng: RandomNumberGenerator, owned: Array = []) -> Array[TrickData]:
	var result: Array[TrickData] = []
	for evolution in eligible_evolutions(owned):
		if result.size() < count:
			result.append(evolution)
	var ids := available(owned)
	var has_owned := false
	for id in ids:
		if count_in(owned, id) > 0:
			has_owned = true
			break
	if has_owned and not is_equal_approx(owned_weight, 1.0) and owned_weight > 0.0:
		ids = _weighted_order(ids, owned, rng)
	else:
		# Fisher–Yates,只用傳入的 RNG,同一個種子永遠得到同一個結果。
		for i in range(ids.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := ids[i]
			ids[i] = ids[j]
			ids[j] = tmp
	for id in ids:
		if result.size() >= count:
			break
		result.append(_tricks[id])
	return result


## 加權不放回抽樣(Efraimidis–Spirakis):鍵 = u^(1/權重),由大到小。
func _weighted_order(ids: Array[StringName], owned: Array, rng: RandomNumberGenerator) -> Array[StringName]:
	var keyed: Array[Array] = []
	for id in ids:
		var weight := owned_weight if count_in(owned, id) > 0 else 1.0
		var u := maxf(rng.randf(), 0.000001)
		keyed.append([pow(u, 1.0 / weight), id])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var result: Array[StringName] = []
	for pair in keyed:
		result.append(pair[1])
	return result


## 把一個把戲的 stat_modifiers 加到 stats 上(相加,以 base 的數值為基準)。EXTRA_KEYS 略過。
static func apply_modifiers(stats: StatBlock, base: StatBlock, modifiers: Dictionary,
		min_damage_taken_mult: float = 0.0) -> void:
	for key: Variant in modifiers:
		var field := StringName(str(key))
		if EXTRA_KEYS.has(field):
			continue
		var current: Variant = stats.get(field)
		var base_value: Variant = base.get(field)
		if current == null or base_value == null or not (typeof(current) in [TYPE_INT, TYPE_FLOAT]):
			push_warning("TrickDeck: StatBlock 沒有數值欄位 %s" % field)
			continue
		var delta := float(base_value) * float(modifiers[key])
		var value := maxf(0.0, float(current) + delta)
		if field == &"damage_taken_mult":
			value = maxf(min_damage_taken_mult, value)
		elif SAFETY_FLOORS.has(field):
			value = maxf(float(SAFETY_FLOORS[field]), value)
		if typeof(current) == TYPE_INT:
			stats.set(field, roundi(value))
		else:
			stats.set(field, value)
