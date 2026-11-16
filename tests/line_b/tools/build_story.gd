extends Node
## 由 docs/STORY.md 第 5 節重新產生 data/story/<段落 id>.tres(BS1)。不是自動化測試。
## STORY.md 改了次序、說話者、表情或插畫之後執行一次,再跑 tools/run_tests.sh line_b
## (test_story_data.gd 會逐句核對)。對白文字本身在 i18n/story.csv,改文字不用重新產生。
##
## 執行:godot --headless --path . res://tests/line_b/tools/build_story.tscn
##
## 產生的檔案和其他 B 線資料檔一樣是手寫風格的 .tres(沒有 uid),方便看 diff。

const StoryDoc := preload("res://tests/line_b/story_doc.gd")
const OUT_DIR: String = "res://data/story/"


func _ready() -> void:
	var scripts := StoryDoc.parse()
	if scripts.is_empty():
		push_error("build_story: 讀不到 docs/STORY.md 的對白表格")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var written := 0
	for id: String in scripts:
		var text := _resource_text(id, scripts[id])
		var path := OUT_DIR + id + ".tres"
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("build_story: 無法寫入 %s" % path)
			continue
		file.store_string(text)
		file.close()
		written += 1
		print("  %s:%d 句" % [path, (scripts[id] as Array).size()])
	print("build_story: 寫了 %d 個段落" % written)
	get_tree().quit(0)


func _resource_text(id: String, lines: Array) -> String:
	var pictures: PackedStringArray = []
	for line: Dictionary in lines:
		var path: String = line["illustration_path"]
		if not path.is_empty() and not pictures.has(path):
			pictures.append(path)
	var out := PackedStringArray()
	out.append('[gd_resource type="Resource" script_class="DialogueScript" format=3]')
	out.append("")
	out.append('[ext_resource type="Script" path="res://core/data/dialogue_script.gd" id="1_script"]')
	out.append('[ext_resource type="Script" path="res://core/data/dialogue_line.gd" id="2_line"]')
	for i in pictures.size():
		out.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % [pictures[i], _picture_id(i, pictures[i])])
	var refs := PackedStringArray()
	for i in lines.size():
		var line: Dictionary = lines[i]
		var sub_id := "line_%02d" % (i + 1)
		refs.append('SubResource("%s")' % sub_id)
		out.append("")
		out.append('[sub_resource type="Resource" id="%s"]' % sub_id)
		out.append('script = ExtResource("2_line")')
		out.append('speaker = &"%s"' % line["speaker"])
		out.append('expression = &"%s"' % line["expression"])
		out.append('text_key = "%s"' % line["key"])
		var path: String = line["illustration_path"]
		if not path.is_empty():
			var index := pictures.find(path)
			out.append('illustration = ExtResource("%s")' % _picture_id(index, path))
	out.append("")
	out.append("[resource]")
	out.append('script = ExtResource("1_script")')
	out.append('id = &"%s"' % id)
	out.append('lines = Array[ExtResource("2_line")]([%s])' % ", ".join(refs))
	out.append("skippable = true")
	out.append("")
	return "\n".join(out)


func _picture_id(index: int, path: String) -> String:
	return "%d_%s" % [index + 3, path.get_file().get_basename()]
