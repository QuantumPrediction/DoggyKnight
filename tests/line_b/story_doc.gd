extends RefCounted
## 讀 docs/STORY.md 第 5 節的對白表格(BS1、BS7)。檔名不是 test_*,測試執行器不會把它當成測試。
## 給 tests/line_b/test_story_data.gd(核對 data/story/*.tres)與 tests/line_b/tools/build_story.gd
## (由 STORY.md 重新產生 data/story/*.tres)共用。
##
## 表格格式(docs/STORY.md 第 5 節):
##   ### `<段落 id>`:說明
##   | 鍵 | speaker | 表情 | 插畫 |      ← 插畫欄可有可無
##   | STORY_PROLOGUE_01 | narrator | | prologue_1 |
## 規則:
## - 表情空白 → expression = &""(旁白沒有頭像)。
## - 插畫空白 = 「不換插畫」:沿用同一段上一句的插畫(資料檔直接填上同一張圖,
##   對白框不用記得上一句);一段之中還沒出現過插畫時為空。

const STORY_DOC: String = "res://docs/STORY.md"
const ILLUSTRATION_DIR: String = "res://assets/story/"


## 傳回 {段落 id(String): Array[Dictionary]},依文件中出現的次序。每句:
## {"key": String, "speaker": String, "expression": String, "illustration": String(插畫 id,可空白),
##  "illustration_path": String(沿用規則套用後的完整路徑,可空白)}
static func parse(path: String = STORY_DOC) -> Dictionary:
	var result := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var heading := RegEx.create_from_string("^###\\s+`([a-z0-9_]+)`")
	var current := ""
	var last_picture := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		var m := heading.search(line)
		if m != null:
			current = m.get_string(1)
			last_picture = ""
			continue
		if line.begins_with("## "):
			current = ""          # 第 5 節以外的大標題:不再屬於任何段落
			continue
		if current.is_empty() or not line.begins_with("| STORY_"):
			continue
		var cells := line.split("|")
		# "| A | B | C |" → ["", " A ", " B ", " C ", ""]
		var values: PackedStringArray = []
		for i in range(1, cells.size() - 1):
			values.append(cells[i].strip_edges())
		if values.size() < 3:
			continue
		var picture := values[3] if values.size() >= 4 else ""
		if not picture.is_empty():
			last_picture = picture
		if not result.has(current):
			result[current] = []
		(result[current] as Array).append({
			"key": values[0],
			"speaker": values[1],
			"expression": values[2],
			"illustration": picture,
			"illustration_path": (ILLUSTRATION_DIR + last_picture + ".png") if not last_picture.is_empty() else "",
		})
	return result
