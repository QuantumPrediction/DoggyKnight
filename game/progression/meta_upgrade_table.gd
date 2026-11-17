class_name MetaUpgradeTable
extends Resource
## 營地訓練的升級表(v2.4 BV5)。data/progression/meta_upgrades.tres(B 線);介面是 D 線的
## game/camp/training.tscn(營地與標題都可以打開)。
##
## 升級 id:vitality(活力上限)、strength(攻擊)、agility(移動速度)、loyalty(忠誠度累積)、
## luck(寶箱與零食機率),每項 5 級,價格逐級上升。等級在 GameState.meta_upgrades。
##
## 怎樣用:
##   var table := MetaUpgradeTable.load_default()
##   table.level_of(&"strength")      目前等級
##   table.next_cost(&"strength")     下一級的價格(已滿級 = -1)
##   table.can_buy(&"strength")       零食夠、還沒滿級
##   table.purchase(&"strength")      扣零食、升一級、發 EventBus.snacks_changed;成功傳回 true
##   MetaUpgradeTable.current_bonus(&"luck")   目前效果(等級 × per_level),例如 0.2 = +20%
## B 線在新遊戲 reset_run() 之後、以及每一關開始時,把 stat 不是空白的升級加到金毛的數值
## (RunProgression.rebuild_stats),所以在營地練的下一關就生效。存檔由 B 線負責
## (訓練介面關閉、下一關開始、切到背景時都會存)。

const DEFAULT_PATH: String = "res://data/progression/meta_upgrades.tres"
const IDS: Array[StringName] = [&"vitality", &"strength", &"agility", &"loyalty", &"luck"]

@export var entries: Array[MetaUpgrade] = []


static func load_default() -> MetaUpgradeTable:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return null
	return load(DEFAULT_PATH) as MetaUpgradeTable


## 目前的效果(用正式的升級表):等級 × per_level。找不到升級表或 id 時傳回 0。
static func current_bonus(id: StringName) -> float:
	var table := load_default()
	return table.bonus(id) if table != null else 0.0


## GameState.meta_upgrades 裡的等級(鍵可以是 StringName 或 String;讀檔後一律是 StringName)。
static func stored_level(id: StringName) -> int:
	var value: Variant = GameState.meta_upgrades.get(id, GameState.meta_upgrades.get(String(id), 0))
	if value is int or value is float:
		return maxi(0, int(value))
	return 0


func get_entry(id: StringName) -> MetaUpgrade:
	for entry in entries:
		if entry != null and entry.id == id:
			return entry
	return null


func level_of(id: StringName) -> int:
	var entry := get_entry(id)
	if entry == null:
		return 0
	return mini(stored_level(id), entry.max_level)


func is_maxed(id: StringName) -> bool:
	var entry := get_entry(id)
	return entry == null or level_of(id) >= entry.max_level


func next_cost(id: StringName) -> int:
	var entry := get_entry(id)
	if entry == null:
		return -1
	return entry.cost_for(level_of(id))


func can_buy(id: StringName) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and GameState.snacks >= cost


## 買一級:扣零食、等級 +1、發 snacks_changed。零食不夠或已滿級時不做任何事,傳回 false。
func purchase(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var cost := next_cost(id)
	var level := level_of(id)
	GameState.snacks -= cost
	GameState.meta_upgrades.erase(String(id))
	GameState.meta_upgrades[id] = level + 1
	EventBus.snacks_changed.emit(GameState.snacks)
	return true


func bonus(id: StringName) -> float:
	var entry := get_entry(id)
	if entry == null:
		return 0.0
	return float(level_of(id)) * entry.per_level


## 把有 stat 的升級加到 stats(相加,以 base 為基準)。
func apply_to(stats: StatBlock, base: StatBlock) -> void:
	for entry in entries:
		if entry == null or entry.stat == &"":
			continue
		var level := level_of(entry.id)
		if level > 0:
			TrickDeck.apply_modifiers(stats, base, {String(entry.stat): float(level) * entry.per_level})
