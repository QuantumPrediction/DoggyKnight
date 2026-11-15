extends TestCase
## D8 本機遊玩記錄:每關一行合法的 JSON,沒有識別碼。

const PLAY_LOG_SCRIPT := preload("res://platform/play_log.gd")
const TEST_PATH := "user://test_line_d_playlog.jsonl"

var _log: Node


func before_each() -> void:
	_cleanup_files()
	_log = PLAY_LOG_SCRIPT.new()
	_log.set(&"log_path", TEST_PATH)
	add_child(_log)


func after_each() -> void:
	_log.queue_free()
	await wait_frames(1)
	_cleanup_files()


func _cleanup_files() -> void:
	for path in [TEST_PATH, TEST_PATH.get_basename() + ".old.jsonl"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func _raw_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		return lines
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(line)
	return lines


func test_level_completed_writes_one_json_line() -> void:
	EventBus.level_started.emit(&"1_1")
	EventBus.trick_chosen.emit(&"sit")
	EventBus.trick_chosen.emit(&"spin")
	await wait_frames(3)
	EventBus.level_completed.emit(&"1_1")
	var lines := _raw_lines()
	assert_eq(lines.size(), 1, "一行")
	var json := JSON.new()
	assert_eq(json.parse(lines[0]), OK, "合法的 JSON")
	var entry: Dictionary = json.data
	assert_eq(entry["v"], 1)
	assert_eq(entry["event"], "level")
	assert_eq(entry["level"], "1_1")
	assert_eq(entry["result"], "completed")
	assert_eq(entry["tricks"], ["sit", "spin"])
	assert_true(float(entry["duration_sec"]) >= 0.0, "有戰鬥時間")
	assert_true(float(entry["wall_sec"]) >= 0.0, "有經過時間")
	assert_true(String(entry["time"]).ends_with("Z"), "UTC 時間")
	assert_eq(int(entry["hero_level"]), GameState.hero_level)


func test_failed_and_minigame_lines_append() -> void:
	EventBus.level_started.emit(&"1_2")
	EventBus.level_failed.emit(&"1_2")
	EventBus.level_started.emit(&"1_2")
	EventBus.trick_chosen.emit(&"wag")
	EventBus.level_completed.emit(&"1_2")
	EventBus.minigame_finished.emit(&"scroll", 123, 1)
	var entries: Array[Dictionary] = _log.call(&"read_entries")
	assert_eq(entries.size(), 3, "三行")
	assert_eq(entries[0]["result"], "failed")
	assert_eq(entries[0]["tricks"], [], "失敗那一關沒選把戲")
	assert_eq(entries[1]["result"], "completed")
	assert_eq(entries[1]["tricks"], ["wag"], "重試時把戲清單重新計算")
	assert_eq(entries[2]["event"], "minigame")
	assert_eq(int(entries[2]["score"]), 123)
	assert_eq(int(entries[2]["grade"]), 1)
	for line in _raw_lines():
		assert_true(JSON.parse_string(line) is Dictionary, "每一行都是 JSON 物件")


func test_no_identifiers_in_entries() -> void:
	EventBus.level_started.emit(&"1_3")
	EventBus.level_completed.emit(&"1_3")
	var allowed := ["v", "time", "event", "level", "result", "duration_sec", "wall_sec", "tricks", "hero_level"]
	var entry: Dictionary = (_log.call(&"read_entries") as Array)[0]
	for key: String in entry.keys():
		assert_true(key in allowed, "只有允許的欄位:%s" % key)
	var text := FileAccess.get_file_as_string(TEST_PATH)
	assert_false(text.contains(OS.get_unique_id()) and not OS.get_unique_id().is_empty(), "沒有裝置識別碼")


func test_unknown_level_end_is_still_logged() -> void:
	EventBus.level_completed.emit(&"1_4")
	var entries: Array[Dictionary] = _log.call(&"read_entries")
	assert_eq(entries.size(), 1)
	assert_almost_eq(float(entries[0]["duration_sec"]), -1.0, 0.0001, "沒收到 level_started 時記為 -1")


func test_rotation_keeps_one_old_file() -> void:
	_log.set(&"max_bytes", 200)
	for i in 6:
		EventBus.minigame_finished.emit(&"scroll", i, 0)
	var old_path := ProjectSettings.globalize_path(TEST_PATH.get_basename() + ".old.jsonl")
	assert_true(FileAccess.file_exists(old_path), "超過大小時舊檔改名")
	var current := _raw_lines()
	assert_true(current.size() < 6, "新檔重新開始")
	for line in current:
		assert_true(JSON.parse_string(line) is Dictionary)


func test_disabled_writes_nothing() -> void:
	_log.set(&"enabled", false)
	EventBus.minigame_finished.emit(&"scroll", 1, 0)
	assert_false(FileAccess.file_exists(TEST_PATH))
