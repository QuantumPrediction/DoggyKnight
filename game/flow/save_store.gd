class_name SaveStore
extends RefCounted
## 存檔(B9)。只存三樣東西:到達的關卡、零食數量、音效開關。存在本機 user://,不連網。
##
## 檔案格式(JSON):{"version": 1, "level_index": 2, "snacks": 0, "sound_on": true}
##   level_index:下次「繼續冒險」要從哪一關開始(0 起算;0 = 沒有可以繼續的進度)。
##
## 防止存檔損毀:先把完整內容寫到「<路徑>.tmp」,關檔之後才改名成正式檔名。
## App 在寫入中途被系統強制關閉時,正式存檔仍是上一次的完整版本;
## 讀檔時會略過(並刪除)殘留的 .tmp。
##
## 寫入是同步的(不用 await),所以在 app_backgrounded 裡呼叫可以立即完成。

const VERSION: int = 1
const DEFAULT_PATH: String = "user://save.json"

var path: String
## 只給測試用:模擬「寫暫存檔寫到一半 App 就被關掉」。為 true 時 write() 只寫一半就停。
var simulate_crash_during_write: bool = false


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func temp_path() -> String:
	return path + ".tmp"


## 寫入存檔。成功傳回 true。
func write(level_index: int, snacks: int, sound_on: bool) -> bool:
	var data := {
		"version": VERSION,
		"level_index": maxi(0, level_index),
		"snacks": maxi(0, snacks),
		"sound_on": sound_on,
	}
	var text := JSON.stringify(data, "\t")
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
## 成功時保證有 level_index (int)、snacks (int)、sound_on (bool) 三個鍵。
func read() -> Dictionary:
	if FileAccess.file_exists(temp_path()):
		# 上一次寫到一半就被中斷;正式檔仍是上一次的完整版本。
		DirAccess.remove_absolute(temp_path())
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("SaveStore: 存檔內容無效,當作沒有存檔")
		return {}
	var raw := parsed as Dictionary
	var result := {
		"level_index": _int_field(raw, "level_index", 0),
		"snacks": _int_field(raw, "snacks", 0),
		"sound_on": raw.get("sound_on", true) if raw.get("sound_on", true) is bool else true,
	}
	return result


func exists() -> bool:
	return not read().is_empty()


func delete() -> void:
	for p in [path, temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _int_field(raw: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = raw.get(key, fallback)
	if value is float or value is int:
		return maxi(0, int(value))
	return fallback
