extends TestCase
## 標題、結算、失敗、製作名單(C10):DEV_PLAN 4.9 的方法與訊號。

const SCREENS: Dictionary = {
	"res://ui/screens/title.tscn": [["setup"], ["new_game_pressed", "continue_pressed", "credits_pressed",
			"endless_pressed", "training_pressed"]],
	"res://ui/screens/results.tscn": [["setup"], ["continue_pressed"]],
	"res://ui/screens/failure.tscn": [["setup"], ["retry_pressed", "title_pressed", "revive_pressed"]],
	"res://ui/screens/credits.tscn": [[], ["closed"]],
}

const SAMPLE_RESULT: Dictionary = {
	"level_id": &"1-2", "level_name": "LEVEL_1_2", "victory": true, "time_sec": 83.4, "kills": 27,
	"tricks": [&"sit", &"spin"], "hero_level": 3, "next_is_camp": true, "is_final": false,
}

var _nodes: Array[Node] = []


func after_each() -> void:
	# 不等下一格:訊號監看要在節點真正釋放前停止。
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _open(path: String) -> Control:
	var c := (load(path) as PackedScene).instantiate() as Control
	add_child(c)
	_nodes.append(c)
	return c


func test_every_screen_has_the_contract_interface() -> void:
	for path: String in SCREENS:
		var c := _open(path)
		assert_true(c is Control, "%s 的根節點是 Control" % path)
		assert_eq(c.anchor_right, 1.0, "%s 全螢幕錨點" % path)
		assert_eq(c.anchor_bottom, 1.0, "%s 全螢幕錨點" % path)
		for m: String in SCREENS[path][0]:
			assert_true(c.has_method(m), "%s 有方法 %s" % [path, m])
		for s: String in SCREENS[path][1]:
			assert_true(c.has_signal(s), "%s 有訊號 %s" % [path, s])


func test_title_continue_only_with_a_save() -> void:
	var title := _open("res://ui/screens/title.tscn")
	assert_eq(title.get_window().title, "黃金騎士 · The Golden Knight")
	assert_eq((title.get_node("Logo") as Control).accessibility_name, tr("GAME_TITLE"))
	title.call("setup", false)
	assert_false((title.get("continue_button") as Button).visible, "沒有存檔就不顯示「繼續冒險」")
	title.call("setup", true)
	assert_true((title.get("continue_button") as Button).visible)
	# setup 也可以在加入場景之前呼叫
	var early := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	early.call("setup", true)
	add_child(early)
	_nodes.append(early)
	assert_true((early.get("continue_button") as Button).visible)


func test_title_buttons_emit() -> void:
	var title := _open("res://ui/screens/title.tscn")
	title.call("setup", true)
	assert_true(title.find_child("CreditsButton", true, false) == null)
	for pair: Array in [["new_game_button", "new_game_pressed"], ["continue_button", "continue_pressed"]]:
		var w := watch_signal(Signal(title, pair[1]))
		(title.get(pair[0]) as Button).pressed.emit()
		if pair[0] == "new_game_button":
			title.get_class_select().confirm_button.pressed.emit()
		assert_eq(w.count, 1, pair[1])


func test_results_shows_data_and_final_message() -> void:
	var res := _open("res://ui/screens/results.tscn")
	res.call("setup", SAMPLE_RESULT)
	assert_eq((res.get("title_label") as Label).text, tr("UI_LEVEL_CLEAR"))
	assert_eq((res.get("time_value") as Label).text, "1:23")
	assert_eq((res.get("kills_value") as Label).text, "27")
	assert_true((res.get("footer_label") as Label).text == tr("UI_NEXT_CAMP"), "下一站是營地")
	await wait_frames(1)
	var icons := 0
	for chip in (res.get("tricks_row") as HFlowContainer).get_children():
		if chip.is_queued_for_deletion():
			continue
		for c in chip.get_children():
			if c is TextureRect:
				icons += 1
	assert_eq(icons, 2, "兩個把戲圖示")
	var final := SAMPLE_RESULT.duplicate()
	final["is_final"] = true
	final["next_is_camp"] = false
	res.call("setup", final)
	assert_eq((res.get("title_label") as Label).text, tr("UI_THE_END"))
	assert_eq((res.get("footer_label") as Label).text, tr("CHAPTER_2"))
	assert_eq((res.get("continue_button") as Button).text, tr("UI_CAMPAIGN_DEPART") % tr("UI_CHAPTER_SHORT_2"))
	final["chapter"] = 6
	res.call("setup", final)
	assert_eq((res.get("footer_label") as Label).text, tr("UI_CAMPAIGN_HOMECOMING"))
	assert_eq((res.get("continue_button") as Button).text, tr("UI_CAMPAIGN_EPILOGUE"))
	var w := watch_signal(Signal(res, "continue_pressed"))
	(res.get("continue_button") as Button).pressed.emit()
	assert_eq(w.count, 1)


func test_failure_buttons_emit() -> void:
	var fail := _open("res://ui/screens/failure.tscn")
	fail.call("setup", SAMPLE_RESULT)
	assert_eq((fail.get("time_value") as Label).text, "1:23")
	var retry := watch_signal(Signal(fail, "retry_pressed"))
	var title := watch_signal(Signal(fail, "title_pressed"))
	(fail.get("retry_button") as Button).pressed.emit()
	(fail.get("title_button") as Button).pressed.emit()
	assert_eq(retry.count, 1)
	assert_eq(title.count, 1)


func test_credits_lists_licenses_and_closes() -> void:
	var credits := _open("res://ui/screens/credits.tscn")
	await wait_frames(1)
	var text: String = credits.call("get_all_text")
	assert_true(text.contains("OpenAI GPT Image"), "列出繪本插畫製作方式")
	for font in ["Noto Sans CJK TC", "Noto Serif CJK TC", "Golden Knight Quill"]:
		assert_true(text.contains(font), "列出遊戲使用的 %s" % font)
	var credit_lines := [tr("UI_CREDITS_GAME"), tr("UI_CREDITS_ART"), tr("UI_CREDITS_ENGINE"), tr("UI_CREDITS_FONT")]
	var scroll := credits.get("scroll") as ScrollContainer
	var right_edge := scroll.get_v_scroll_bar().get_global_rect().position.x
	var visible_credits := 0
	for row in (credits.get("content") as VBoxContainer).get_children():
		if row is Label and credit_lines.has(row.text):
			visible_credits += 1
			assert_true(row.get_global_rect().end.x <= right_edge + 1, "署名行留在捲動欄內")
			assert_true(row.get_line_count() * row.get_line_height() <= row.size.y + 1, "署名可完整換行")
	assert_eq(visible_credits, credit_lines.size())
	assert_true(text.contains("Cubic 11"), "列出字型")
	assert_true(text.contains("SIL OPEN FONT LICENSE"), "附上 OFL 全文")
	assert_true(text.contains("Godot Engine"), "列出 Godot")
	var godot_first_line := Engine.get_license_text().split("\n")[0].strip_edges()
	assert_true(text.contains(godot_first_line), "Engine.get_license_text()")
	var info: Dictionary = Engine.get_license_info()
	if not info.is_empty():
		assert_true(text.contains(String(info.keys()[0])), "Engine.get_license_info()")
	var copyright: Array = Engine.get_copyright_info()
	if not copyright.is_empty():
		assert_true(text.contains(String(copyright[0]["name"])), "Engine.get_copyright_info()")
	var w := watch_signal(Signal(credits, "closed"))
	(credits.get("close_button") as Button).pressed.emit()
	assert_eq(w.count, 1)


func test_credits_mirror_docs_licenses() -> void:
	var f := FileAccess.open("res://docs/licenses.md", FileAccess.READ)
	assert_not_null(f, "docs/licenses.md")
	if f == null:
		return
	var md := f.get_as_text()
	var script := load("res://ui/screens/credits.gd") as GDScript
	var entries: Array = script.get_script_constant_map()["LICENSE_ENTRIES"]
	assert_true(md.contains("Godot Engine 4.7.2") and String(entries[0]["name"]).contains("Godot Engine 4.7.2"))
	assert_true(md.contains("Cubic 11") and String(entries[1]["name"]).contains("Cubic 11"))
	assert_true(md.contains("SIL Open Font License 1.1") and String(entries[1]["license"]).contains("SIL Open Font License 1.1"))
