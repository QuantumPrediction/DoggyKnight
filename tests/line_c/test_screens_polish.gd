extends TestCase
## 畫面打磨(CP5、CP10):結算星星與新紀錄、舊資料相容、把戲卡層數、暫停的音樂與震動開關、
## 製作名單自動捲動、按鈕擠壓動畫。

const RESULT_V22: Dictionary = {
	"level_id": &"1-2", "level_name": "LEVEL_1_2", "victory": true, "time_sec": 71.0, "kills": 25,
	"tricks": [&"sit"], "hero_level": 4, "next_is_camp": true, "is_final": false,
	"stars": 2, "best_stars": 2, "new_best": true, "level_index": 1, "level_count": 6,
	"star_goals": [
		{"key": "STAR_CLEAR", "met": true, "value": 0, "text": "過關"},
		{"key": "STAR_TIME", "met": true, "value": 75, "text": "75 秒內過關"},
		{"key": "STAR_NO_DAMAGE", "met": false, "value": 20, "text": "受到的傷害不超過 20"},
	],
}

var _nodes: Array[Node] = []
var _music_before: bool
var _haptics_before: bool
var _tricks_before: Array[StringName] = []


func before_each() -> void:
	_music_before = GameState.music_on
	_haptics_before = GameState.haptics_on
	_tricks_before = GameState.active_tricks.duplicate()


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	GameState.music_on = _music_before
	GameState.haptics_on = _haptics_before
	GameState.active_tricks = _tricks_before
	Music.stop(0.0)


func _open(path: String) -> Control:
	var c := (load(path) as PackedScene).instantiate() as Control
	add_child(c)
	_nodes.append(c)
	return c


func test_results_stars_light_up_one_by_one() -> void:
	var res := _open("res://ui/screens/results.tscn")
	res.call("setup", RESULT_V22)
	assert_eq((res.get("time_value") as Label).text, "1:11", "最終數值立刻可讀(數字遞增在下一格才開始)")
	assert_eq(res.call("shown_stars"), 0)
	await get_tree().create_timer(0.45).timeout
	assert_eq(res.call("shown_stars"), 1, "第一顆先亮")
	await get_tree().create_timer(0.9).timeout
	assert_eq(res.call("shown_stars"), 2, "拿到兩顆就亮兩顆")
	assert_true((res.get("new_best_label") as Label).visible, "新紀錄!")
	var goals: VBoxContainer = res.get("goals_box")
	var texts: PackedStringArray = []
	for row in goals.get_children():
		for c in row.get_children():
			if c is Label:
				texts.append((c as Label).text)
	assert_true(texts.has("75 秒內過關"), "目標顯示 B 線給的 text:%s" % [texts])
	assert_true((res.get("progress") as Control).visible, "第一章進度")
	assert_eq((res.get("progress_label") as Label).text, tr("UI_CHAPTER_PROGRESS") % [2, 6])


func test_results_without_v22_keys_still_work() -> void:
	var res := _open("res://ui/screens/results.tscn")
	res.call("setup", {"level_name": "LEVEL_1_1", "time_sec": 60.0, "kills": 10, "tricks": [],
		"hero_level": 2, "next_is_camp": false, "is_final": false})
	await wait_frames(2)
	assert_false((res.get("stars_row") as Control).visible, "沒有 stars 就不顯示星星")
	assert_false((res.get("goals_box") as Control).visible)
	assert_false((res.get("progress") as Control).visible)
	assert_false((res.get("new_best_label") as Label).visible)
	assert_eq((res.get("kills_value") as Label).text, "10")


func test_trick_cards_show_new_or_level() -> void:
	GameState.active_tricks = [&"shake"] as Array[StringName]
	var ui := _open("res://ui/trick_choice/trick_choice.tscn")
	var opts := [load("res://data/tricks/shake.tres"), load("res://data/tricks/spin.tres")]
	ui.call("show_options", opts)
	var cards: Array = ui.get("cards")
	var shake_badge := (cards[0] as Control).get_node("Badge/Text") as Label
	var spin_badge := (cards[1] as Control).get_node("Badge/Text") as Label
	assert_eq(shake_badge.text, tr("UI_TRICK_LEVEL") % 2, "學過一次:選了變 Lv2")
	assert_eq(spin_badge.text, tr("UI_TRICK_NEW"), "沒學過:NEW")
	for c: Control in cards:
		assert_eq((c.get_node("Badge") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_pause_music_and_haptics_toggles() -> void:
	var ui := _open("res://ui/pause/pause.tscn")
	EventBus.game_paused.emit(true)
	GameState.music_on = true
	var music: Button = ui.get("music_button")
	var haptics: Button = ui.get("haptics_button")
	ui.call("_refresh_sound")
	assert_eq(music.text, tr("UI_MUSIC_ON"))
	Music.play(&"field", 0.0)
	music.pressed.emit()
	assert_false(GameState.music_on, "關掉音樂")
	assert_false(Music.is_playing(), "Music.refresh() 讓音樂立刻停止")
	assert_eq(music.text, tr("UI_MUSIC_OFF"))
	music.pressed.emit()
	assert_true(GameState.music_on)
	GameState.haptics_on = true
	haptics.pressed.emit()
	assert_false(GameState.haptics_on, "關掉震動")
	assert_eq(haptics.text, tr("UI_HAPTICS_OFF"))
	haptics.pressed.emit()
	assert_true(GameState.haptics_on)
	EventBus.game_paused.emit(false)


func test_buttons_squash_when_pressed() -> void:
	var b := UiKit.button("x")
	add_child(b)
	_nodes.append(b)
	await wait_frames(1)
	b.button_down.emit()
	await get_tree().create_timer(0.08).timeout
	assert_true(b.scale.y < 0.995 and b.scale.y >= 0.975, "按下時輕微收縮(scale %s)" % b.scale)
	b.button_up.emit()
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(b.scale.y, 1.0, 0.01)


func test_credits_scroll_by_themselves() -> void:
	var credits := _open("res://ui/screens/credits.tscn")
	await get_tree().create_timer(2.0).timeout
	assert_true(float(credits.call("auto_scroll_position")) > 5.0, "製作名單會自己慢慢往上捲")


func test_title_has_animated_parts() -> void:
	var title := _open("res://ui/screens/title.tscn")
	title.call("setup", false)
	await wait_frames(1)
	assert_not_null(title.get_node_or_null("Petals"), "花瓣")
	assert_not_null(title.get_node_or_null("SwordGlint"), "石中劍閃光")
	assert_not_null(title.get_node_or_null("Cloud0"), "會飄的雲")
	var cloud := title.get_node("Cloud0") as Control
	var x0 := cloud.position.x
	await get_tree().create_timer(1.2).timeout
	assert_ne(cloud.position.x, x0, "雲在移動")
