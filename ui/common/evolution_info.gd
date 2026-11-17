class_name EvolutionInfo
extends RefCounted
## 進化把戲由哪兩個把戲合成(C 線介面用:進化卡片的小圖示、進化演出)。
##
## 先讀 B 線的 data/tricks/*.tres(把戲的 evolves_into 與 evolution_partner);
## 讀不到時用 DEV_PLAN 4.12 的表。只讀資料,不改任何東西。

const TRICKS_DIR: String = "res://data/tricks"
## DEV_PLAN 4.12 的進化表(資料檔還沒有時的後備)。
const FALLBACK: Dictionary = {
	&"tornado_tail": [&"spin", &"wag"],
	&"lion_roar": [&"bark", &"sit"],
	&"high_five": [&"shake", &"fetch"],
	&"meteor_pounce": [&"pounce", &"zoomies"],
}

static var _cache: Dictionary = {}
static var _scanned: bool = false


## 進化把戲 evolution_id 的兩個原把戲 id;不知道時傳回空陣列。
static func parents_of(evolution_id: StringName) -> Array[StringName]:
	if not _scanned:
		_scan()
	var out: Array[StringName] = []
	var found: Array = _cache.get(evolution_id, FALLBACK.get(evolution_id, []))
	for id: Variant in found:
		out.append(StringName(id))
	return out


## 把戲圖示(B 線資料檔的 icon 優先,沒有就用 assets/icons/tricks/<id>.png)。
static func icon_of(trick_id: StringName) -> Texture2D:
	var path := "res://assets/icons/tricks/%s.png" % trick_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## 把戲名稱的翻譯鍵(TRICK_<ID>_NAME;B 線的命名)。
static func name_key(trick_id: StringName) -> String:
	return "TRICK_%s_NAME" % String(trick_id).to_upper()


## 測試用:清掉快取,下次重新讀資料檔。
static func reset() -> void:
	_cache.clear()
	_scanned = false


static func _scan() -> void:
	_scanned = true
	if not DirAccess.dir_exists_absolute(TRICKS_DIR):
		return
	for file in ResourceLoader.list_directory(TRICKS_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var trick := load(TRICKS_DIR.path_join(file)) as TrickData
		if trick == null or trick.evolves_into == &"" or trick.evolution_partner == &"":
			continue
		if not _cache.has(trick.evolves_into):
			_cache[trick.evolves_into] = [trick.id, trick.evolution_partner]
