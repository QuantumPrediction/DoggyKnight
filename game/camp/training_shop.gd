class_name TrainingShop
extends RefCounted
## 營地訓練的規則(DEV_PLAN 17 DV1),和畫面分開,方便測試。只用遊戲內的零食,不涉及真錢。
##
## - 讀升級表:先找 B 線的 data/progression/meta_upgrades.tres,沒有時用 D 線的 game/camp/training_upgrades.tres。
##   兩者都是「有 entries 陣列的 Resource」;每一項可以是 Resource 或 Dictionary,
##   欄位 id、name_key、desc_key、max_level、costs、per_level(依名稱讀,不檢查類別)。
## - 買得起(零食 ≥ 價格,而且還沒滿級)才可以買:GameState.snacks -= 價格,GameState.meta_upgrades[id] += 1。
##   EventBus.snacks_changed 由呼叫的介面發出(見 CampTraining)。
## - state 是 GameState Autoload,或測試用、有 snacks 與 meta_upgrades 欄位的物件。

const PRIMARY_PATH: String = "res://data/progression/meta_upgrades.tres"
const FALLBACK_PATH: String = "res://game/camp/training_upgrades.tres"


## 讀出升級表,整理成 Array[Dictionary]:
## {"id": StringName, "name_key": String, "desc_key": String, "max_level": int, "costs": Array[int], "per_level": float}。
## paths 依序嘗試,用第一個有內容的。
static func load_entries(paths: PackedStringArray = [PRIMARY_PATH, FALLBACK_PATH]) -> Array[Dictionary]:
	for path in paths:
		if path == "" or not ResourceLoader.exists(path):
			continue
		var entries := entries_from(load(path))
		if not entries.is_empty():
			return entries
	return []


## 從一個資源(或 Dictionary、Array)取出升級表。格式不對的項目略過。
static func entries_from(source: Variant) -> Array[Dictionary]:
	var raw: Variant = source
	if source is Object and source != null:
		raw = (source as Object).get(&"entries")
	elif source is Dictionary:
		raw = (source as Dictionary).get("entries", [])
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	for item: Variant in raw:
		var entry := normalize(item)
		if not entry.is_empty():
			out.append(entry)
	return out


## 把一項(Resource 或 Dictionary)整理成固定的 Dictionary;沒有 id 時傳回空的 Dictionary。
static func normalize(item: Variant) -> Dictionary:
	var id := StringName(str(_field(item, "id", "")))
	if id == &"":
		return {}
	var costs: Array[int] = []
	var raw_costs: Variant = _field(item, "costs", [])
	if raw_costs is Array or raw_costs is PackedInt32Array or raw_costs is PackedInt64Array:
		for c: Variant in raw_costs:
			costs.append(maxi(0, int(c)))
	var upper := String(id).to_upper()
	var name_key := str(_field(item, "name_key", ""))
	var desc_key := str(_field(item, "desc_key", ""))
	return {
		"id": id,
		"name_key": name_key if name_key != "" else "TRAINING_%s_NAME" % upper,
		"desc_key": desc_key if desc_key != "" else "TRAINING_%s_DESC" % upper,
		"max_level": maxi(0, int(_field(item, "max_level", 5))),
		"costs": costs,
		"per_level": float(_field(item, "per_level", 0.0)),
	}


static func level_of(state: Object, id: StringName) -> int:
	var levels: Variant = state.get(&"meta_upgrades")
	if not levels is Dictionary:
		return 0
	return maxi(0, int((levels as Dictionary).get(id, 0)))


static func snacks_of(state: Object) -> int:
	return int(state.get(&"snacks"))


static func is_maxed(entry: Dictionary, level: int) -> bool:
	return level >= int(entry["max_level"])


## 從 level 升到 level + 1 的價格。滿級時傳回 -1。
static func cost_for(entry: Dictionary, level: int) -> int:
	if is_maxed(entry, level):
		return -1
	var costs: Array[int] = entry["costs"]
	if costs.is_empty():
		return 0
	return costs[clampi(level, 0, costs.size() - 1)]


static func can_buy(state: Object, entry: Dictionary) -> bool:
	var level := level_of(state, entry["id"])
	var cost := cost_for(entry, level)
	return cost >= 0 and snacks_of(state) >= cost


## 買一級。成功傳回新的等級;買不起或滿級傳回 -1(狀態不變)。
static func buy(state: Object, entry: Dictionary) -> int:
	if not can_buy(state, entry):
		return -1
	var id: StringName = entry["id"]
	var level := level_of(state, id)
	state.set(&"snacks", snacks_of(state) - cost_for(entry, level))
	var levels: Variant = state.get(&"meta_upgrades")
	var table: Dictionary = levels if levels is Dictionary else {}
	table[id] = level + 1
	state.set(&"meta_upgrades", table)
	return level + 1


## 等級 level 時的總效果,給介面顯示:小於 1 的 per_level 顯示百分比(「+20%」),否則顯示點數(「+20」)。
static func effect_text(entry: Dictionary, level: int) -> String:
	var per := float(entry["per_level"])
	var total := per * level
	if absf(per) < 1.0:
		return "+%d%%" % roundi(total * 100.0)
	return "+%d" % roundi(total)


static func _field(item: Variant, key: String, default_value: Variant) -> Variant:
	if item is Dictionary:
		return (item as Dictionary).get(key, default_value)
	if item is Object and item != null:
		var value: Variant = (item as Object).get(StringName(key))
		return default_value if value == null else value
	return default_value
