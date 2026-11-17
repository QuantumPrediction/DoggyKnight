class_name SaveStore
extends RefCounted
## 存檔(B9、BP6、BS6)。存在本機 user://,不連網,不存任何個人資料或裝置識別碼。
##
## 檔案格式(JSON,第 4 版):
##   {"version": 4, "level_index": 2, "snacks": 0, "sound_on": true, "music_on": true,
##    "haptics_on": true, "tutorial_done": true, "best_stars": {"1-1": 3, "1-2": 2, "1-1:hard": 1},
##    "camp_pending": false, "difficulty": "normal", "chapter_cleared": false,
##    "story_seen": {"prologue": true, "l1_before": true},
##    "meta_upgrades": {"strength": 2, "luck": 1}, "endless_best": 12}
##   level_index:下次「繼續冒險」要從哪一關開始(0 起算;0 = 沒有可以繼續的進度)。
##   camp_pending:上一關過關後應該先進營地(結算畫面出現後 App 被關掉,繼續時先回到營地)。
##   best_stars:每關最佳星數(鍵是關卡 id 字串,困難模式加 ":hard";值 0 至 3)。
##   difficulty(v3):這一輪冒險的難度 "normal" 或 "hard"(繼續冒險時沿用)。
##   chapter_cleared(v3):打完第一章(解鎖困難模式)。
##   story_seen(v3):看過的對白段落 {段落 id: true}。
##   snacks:零食總數(v2.4 起真的會增減:擊倒、寶箱、過關、復活、營地訓練)。
##   meta_upgrades(v4):營地訓練等級 {升級 id: 0 至 MAX_META_LEVEL}。
##   endless_best(v4):無盡試煉最佳波數。
## 向下相容:第 1、2、3 版存檔都可以讀,缺的欄位用預設值;
## 但第 1 版存檔已經到達第 2 關以後,表示玩家玩過第一關,tutorial_done 視為 true。
##
## 防止存檔損毀:先把完整內容寫到「<路徑>.tmp」,關檔之後才改名成正式檔名。
## App 在寫入中途被系統強制關閉時,正式存檔仍是上一次的完整版本;
## 讀檔時會略過(並刪除)殘留的 .tmp。
##
## 寫入是同步的(不用 await),所以在 app_backgrounded 裡呼叫可以立即完成。

const VERSION: int = 4
## 營地訓練等級的上限(存檔清理用;實際上限在 data/progression/meta_upgrades.tres)。
const MAX_META_LEVEL: int = 99
const DEFAULT_PATH: String = "user://save.json"
const MAX_STARS: int = 3
const DIFFICULTIES: Array[String] = ["normal", "hard"]

var path: String
## 只給測試用:模擬「寫暫存檔寫到一半 App 就被關掉」。為 true 時 write() 只寫一半就停。
var simulate_crash_during_write: bool = false


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func temp_path() -> String:
	return path + ".tmp"


## 所有欄位與預設值(沒有存檔、或舊版存檔缺少欄位時用這些)。
static func defaults() -> Dictionary:
	return {
		"level_index": 0,
		"snacks": 0,
		"sound_on": true,
		"music_on": true,
		"haptics_on": true,
		"tutorial_done": false,
		"best_stars": {},
		"camp_pending": false,
		"difficulty": "normal",
		"chapter_cleared": false,
		"story_seen": {},
		"meta_upgrades": {},
		"endless_best": 0,
	}


## 寫入存檔(舊的寫法:只給三個欄位,其餘用預設值)。成功傳回 true。
func write(level_index: int, snacks: int, sound_on: bool) -> bool:
	return write_data({"level_index": level_index, "snacks": snacks, "sound_on": sound_on})


## 寫入存檔。data 缺的欄位用預設值;不認識的欄位不寫。成功傳回 true。
func write_data(data: Dictionary) -> bool:
	var clean := sanitize(data)
	var out := {"version": VERSION}
	out.merge(clean)
	var text := JSON.stringify(out, "\t")
	var tmp := temp_path()
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveStore: 無法寫入 %s(%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	if simulate_crash_during_write:
		file.store_string(text.substr(0, text.length() >> 1))
		file.close()
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_warning("SaveStore: 寫入暫存檔失敗(%s)" % error_string(write_error))
		return false
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		# 少數平台不允許改名覆蓋既有檔案:先刪舊檔再改名(暫存檔已是完整內容)。
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("SaveStore: 無法把暫存檔改名為 %s(%s)" % [path, error_string(err)])
		return false
	return true


## 讀取存檔。沒有存檔或存檔無效時傳回空的 Dictionary。
## 成功時保證有 defaults() 的全部欄位,型別正確(另加 "version": 讀到的版本號)。
func read() -> Dictionary:
	if FileAccess.file_exists(temp_path()):
		# 上一次寫到一半就被中斷;正式檔仍是上一次的完整版本。
		DirAccess.remove_absolute(temp_path())
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	if not parsed is Dictionary:
		push_warning("SaveStore: 存檔內容無效,當作沒有存檔")
		return {}
	var raw := parsed as Dictionary
	var result := sanitize(raw)
	var version := _int_field(raw, "version", 1)
	result["version"] = version
	if version < 2 and not raw.has("tutorial_done") and int(result["level_index"]) > 0:
		result["tutorial_done"] = true     # 舊存檔已過了第一關:玩家懂得操作
	return result


func exists() -> bool:
	return not read().is_empty()


func delete() -> void:
	for p in [path, temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 只留認識的欄位,型別不對或超出範圍就用預設值。
static func sanitize(raw: Dictionary) -> Dictionary:
	var d := defaults()
	return {
		"level_index": _int_field(raw, "level_index", d["level_index"]),
		"snacks": _int_field(raw, "snacks", d["snacks"]),
		"sound_on": _bool_field(raw, "sound_on", d["sound_on"]),
		"music_on": _bool_field(raw, "music_on", d["music_on"]),
		"haptics_on": _bool_field(raw, "haptics_on", d["haptics_on"]),
		"tutorial_done": _bool_field(raw, "tutorial_done", d["tutorial_done"]),
		"best_stars": _stars_field(raw.get("best_stars", {})),
		"camp_pending": _bool_field(raw, "camp_pending", d["camp_pending"]),
		"difficulty": _difficulty_field(raw.get("difficulty", d["difficulty"])),
		"chapter_cleared": _bool_field(raw, "chapter_cleared", d["chapter_cleared"]),
		"story_seen": _seen_field(raw.get("story_seen", {})),
		"meta_upgrades": _meta_field(raw.get("meta_upgrades", {})),
		"endless_best": _int_field(raw, "endless_best", d["endless_best"]),
	}


## {升級 id: 等級}:鍵一律轉成字串,等級限制在 0 至 MAX_META_LEVEL,不是數字的項目略過。
static func _meta_field(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key: Variant in (value as Dictionary).keys():
		var level: Variant = (value as Dictionary)[key]
		if (key is String or key is StringName) and (level is int or level is float):
			result[String(key)] = clampi(int(level), 0, MAX_META_LEVEL)
	return result



static func _int_field(raw: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = raw.get(key, fallback)
	if value is float or value is int:
		return maxi(0, int(value))
	return fallback


static func _bool_field(raw: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = raw.get(key, fallback)
	return value if value is bool else fallback


## "normal" 或 "hard";其他值 → "normal"。
static func _difficulty_field(value: Variant) -> String:
	if (value is String or value is StringName) and DIFFICULTIES.has(String(value)):
		return String(value)
	return "normal"


## {段落 id: true}:鍵一律轉成字串,只留值是 true 的項目。
static func _seen_field(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key: Variant in (value as Dictionary).keys():
		if (key is String or key is StringName) and (value as Dictionary)[key] is bool and (value as Dictionary)[key]:
			result[String(key)] = true
	return result


## {關卡 id: 星數}:鍵一律轉成字串,星數限制在 0 至 3,不是數字的項目略過。
static func _stars_field(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key: Variant in (value as Dictionary).keys():
		var stars: Variant = (value as Dictionary)[key]
		if (key is String or key is StringName) and (stars is int or stars is float):
			result[String(key)] = clampi(int(stars), 0, MAX_STARS)
	return result
