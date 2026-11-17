class_name Loot
extends RefCounted
## 寶箱與零食的掉落規則(AV2、AV3)。數值在 data/enemies/loot_tuning.tres(LootTuning)。
## 敵人倒下時,場地的 drop_loot() 用這裡決定掉甚麼;純函式,方便測試。
##
## - luck 等級:GameState.meta_upgrades["luck"](營地訓練,B 線存檔;鍵可以是 String 或 StringName)。
## - 挖寶層數:GameState.active_tricks 裡 &"dig" 的數目(數值類把戲,StatBlock 沒有對應欄位)。

const DEFAULT_TUNING: LootTuning = preload("res://data/enemies/loot_tuning.tres")
const DIG_ID: StringName = &"dig"

static var _tuning: LootTuning
static var _rng := RandomNumberGenerator.new()


static func tuning() -> LootTuning:
	return _tuning if _tuning != null else DEFAULT_TUNING


## 測試用:換一份掉落數值(null = 回到 data/enemies/loot_tuning.tres)。
static func set_tuning(t: LootTuning) -> void:
	_tuning = t


## 測試用:固定亂數種子。
static func seed_rng(value: int) -> void:
	_rng.seed = value


static func luck_level() -> int:
	var key := tuning().luck_id
	var upgrades := GameState.meta_upgrades
	if upgrades.has(key):
		return maxi(0, int(upgrades[key]))
	if upgrades.has(String(key)):
		return maxi(0, int(upgrades[String(key)]))
	return 0


## luck 帶來的機率倍數(1 = 沒有加成)。
static func luck_mult() -> float:
	return 1.0 + tuning().luck_bonus_per_level * float(luck_level())


static func dig_stacks() -> int:
	return GameState.active_tricks.count(DIG_ID)


## 一般敵人掉寶箱的機率。
static func chest_chance() -> float:
	var t := tuning()
	return clampf(t.chest_chance * luck_mult(), 0.0, t.chest_chance_max)


## 一般敵人掉零食的機率。
static func snack_chance() -> float:
	var t := tuning()
	return clampf(t.snack_chance * luck_mult() * (1.0 + t.dig_snack_bonus * float(dig_stacks())), 0.0, t.snack_chance_max)


## 必掉的寶箱等級(-1 = 不是必掉)。guaranteed_chests 優先;其次精英 1 級、頭目 2 級。
static func guaranteed_chest_tier(enemy_id: StringName, elite: bool, boss: bool) -> int:
	var table := tuning().guaranteed_chests
	if table.has(enemy_id):
		return clampi(int(table[enemy_id]), 0, 2)
	if table.has(String(enemy_id)):
		return clampi(int(table[String(enemy_id)]), 0, 2)
	if boss:
		return 2
	if elite:
		return 1
	return -1


## 必掉的零食數。
static func guaranteed_snacks(enemy_id: StringName) -> int:
	var table := tuning().guaranteed_snacks
	if table.has(enemy_id):
		return maxi(0, int(table[enemy_id]))
	if table.has(String(enemy_id)):
		return maxi(0, int(table[String(enemy_id)]))
	return 0


## 這隻敵人倒下時掉甚麼:{"chest": 等級或 -1, "snacks": 個數}。random_chests_on_field 是場上隨機寶箱數。
static func roll(enemy_id: StringName, elite: bool, boss: bool, random_chests_on_field: int = 0) -> Dictionary:
	var t := tuning()
	var chest := guaranteed_chest_tier(enemy_id, elite, boss)
	if chest < 0 and random_chests_on_field < t.max_random_chests and _rng.randf() < chest_chance():
		chest = 0
	var snacks := guaranteed_snacks(enemy_id)
	if snacks == 0 and _rng.randf() < snack_chance():
		snacks = 1
	return {"chest": chest, "snacks": snacks}
