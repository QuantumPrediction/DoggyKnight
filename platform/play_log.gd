extends Node
## 本機遊玩記錄(DEV_PLAN 11 D8)。設計成 Autoload,名稱「PlayLog」(申請見 docs/requests/)。
## 因為要當 Autoload,這個檔案沒有 class_name(class_name 與 Autoload 同名會衝突)。
##
## 聽 EventBus 的 level_started / trick_chosen / level_completed / level_failed / minigame_finished,
## 每關結束時在 user://playlog.jsonl 加一行 JSON(JSON Lines 格式),供 M3 調整難度。
##
## 每一行的欄位:
##   v            格式版本(目前 1)
##   time         UTC 時間,例如 "2026-11-15T08:30:00Z"
##   event        "level" 或 "minigame"
##   level        關卡 id,例如 "1_1"
##   result       "completed" 或 "failed"
##   duration_sec 實際戰鬥秒數(不含暫停、升級選把戲、切到背景)
##   wall_sec     從開始到結束的實際經過秒數
##   tricks       這一關選的把戲 id
##   hero_level   結束時的等級
##   minigame/score/grade  小遊戲的結果
##
## 隱私:不含任何裝置識別碼、帳號或個人資料;只存在手機上,不上傳(DEV_PLAN 規則 10)。
## 檔案超過 max_bytes 時,舊檔改名為 playlog.old.jsonl(只保留一份舊檔)。
##
## 擁有人怎樣拿到記錄:見 platform/README.md。

const DEFAULT_PATH: String = "user://playlog.jsonl"
const FORMAT_VERSION: int = 1

@export var log_path: String = DEFAULT_PATH
@export var max_bytes: int = 512 * 1024
@export var enabled: bool = true

var _level_id: StringName = &""
var _in_level: bool = false
var _active_sec: float = 0.0
var _start_msec: int = 0
var _tricks: Array[String] = []


func _ready() -> void:
	EventBus.level_started.connect(_on_level_started)
	EventBus.trick_chosen.connect(_on_trick_chosen)
	EventBus.level_completed.connect(_on_level_finished.bind("completed"))
	EventBus.level_failed.connect(_on_level_finished.bind("failed"))
	EventBus.minigame_finished.connect(_on_minigame_finished)


## 戰鬥時間只在遊戲沒有暫停時累計(process_mode 預設會隨 get_tree().paused 暫停)。
func _process(delta: float) -> void:
	if _in_level:
		_active_sec += delta


## 讀回全部記錄(測試用,也方便日後做「匯出記錄」功能)。
func read_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(log_path):
		return entries
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return entries
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			entries.append(parsed)
	return entries


func clear() -> void:
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


func _on_level_started(level_id: StringName) -> void:
	_level_id = level_id
	_in_level = true
	_active_sec = 0.0
	_start_msec = Time.get_ticks_msec()
	_tricks.clear()


func _on_trick_chosen(trick_id: StringName) -> void:
	_tricks.append(String(trick_id))


func _on_level_finished(level_id: StringName, result: String) -> void:
	# 沒收到 level_started(例如讀檔後直接結束)時,時間記為 -1。
	var known := _in_level and level_id == _level_id
	var tricks: Array = []
	var duration := -1.0
	var wall := -1.0
	if known:
		tricks.assign(_tricks)
		duration = snappedf(_active_sec, 0.1)
		wall = snappedf((Time.get_ticks_msec() - _start_msec) / 1000.0, 0.1)
	var hero_level: int = GameState.hero_level
	append_entry({
		"event": "level",
		"level": String(level_id),
		"result": result,
		"duration_sec": duration,
		"wall_sec": wall,
		"tricks": tricks,
		"hero_level": hero_level,
	})
	_in_level = false
	_tricks.clear()


func _on_minigame_finished(minigame_id: StringName, score: int, grade: int) -> void:
	append_entry({
		"event": "minigame",
		"minigame": String(minigame_id),
		"score": score,
		"grade": grade,
	})


## 加一行記錄。立即寫入並關檔,App 被系統關掉也不會遺失已寫的部分。
func append_entry(fields: Dictionary) -> void:
	if not enabled:
		return
	var entry := {"v": FORMAT_VERSION, "time": Time.get_datetime_string_from_system(true) + "Z"}
	entry.merge(fields)
	_rotate_if_needed()
	var file: FileAccess
	if FileAccess.file_exists(log_path):
		file = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		push_warning("PlayLog: cannot open %s (%s)" % [log_path, error_string(FileAccess.get_open_error())])
		return
	file.store_line(JSON.stringify(entry))
	file.close()


func _rotate_if_needed() -> void:
	if max_bytes <= 0 or not FileAccess.file_exists(log_path):
		return
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return
	var length := file.get_length()
	file.close()
	if length < max_bytes:
		return
	var absolute := ProjectSettings.globalize_path(log_path)
	var old := absolute.get_basename() + ".old.jsonl"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	DirAccess.rename_absolute(absolute, old)
