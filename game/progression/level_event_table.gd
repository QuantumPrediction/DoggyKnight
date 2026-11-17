class_name LevelEventTable
extends Resource
## 抉擇事件表(v2.4 BV3)。資料在 data/levels/events.tres。
##
## 每關一個事件(level_events:關卡 id → 事件 id),在「中段兩波之間」出現:
##   第 floor(波數 / 2) 波清空之後(2 波 → 第 1 波後;3 波 → 第 1 波後;4 波 → 第 2 波後);
##   只有一波的關卡(1-6 頭目戰)在開場標題卡之後、頭目出場時出現。after_wave 可以逐關覆寫。
## 無盡試煉每 EndlessData.event_every 波一次,從 endless_pool 隨機抽(不連續重複)。

const DEFAULT_PATH: String = "res://data/levels/events.tres"

@export var events: Array[LevelEvent] = []
## 關卡 id → 事件 id。
@export var level_events: Dictionary = {}
## 關卡 id → 第幾波清空之後(0 = 開場之後);沒有寫就用 floor(波數 / 2)。
@export var after_wave: Dictionary = {}
## 無盡試煉可以抽到的事件 id。
@export var endless_pool: Array[StringName] = []


static func load_default() -> LevelEventTable:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return null
	return load(DEFAULT_PATH) as LevelEventTable


func get_event(id: StringName) -> LevelEvent:
	for event in events:
		if event != null and event.id == id:
			return event
	return null


func event_for_level(level_id: StringName) -> LevelEvent:
	var id: Variant = level_events.get(level_id, level_events.get(String(level_id), null))
	if id == null:
		return null
	return get_event(StringName(id))


## 這一關的事件在第幾波清空之後出現(0 = 開場之後;-1 = 這一關沒有事件)。
func trigger_wave(level: LevelData) -> int:
	if level == null or event_for_level(level.id) == null:
		return -1
	var override: Variant = after_wave.get(level.id, after_wave.get(String(level.id), null))
	if override is int or override is float:
		return clampi(int(override), 0, maxi(0, level.waves.size() - 1))
	@warning_ignore("integer_division")
	return level.waves.size() / 2


## 無盡試煉:隨機抽一個事件(盡量不和 previous 相同)。
func random_endless(rng: RandomNumberGenerator, previous: StringName = &"") -> LevelEvent:
	var pool: Array[StringName] = []
	for id in endless_pool:
		if get_event(id) != null:
			pool.append(id)
	if pool.is_empty():
		return null
	if pool.size() > 1:
		pool.erase(previous)
	return get_event(pool[rng.randi_range(0, pool.size() - 1)])
