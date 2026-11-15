extends TestCase
## D1 營地:進入時發 camp_entered、按「繼續冒險」發 camp_left、小遊戲來回、預留入口。

const CAMP_SCENE := preload("res://game/camp/camp.tscn")

var _camp: Camp


func before_each() -> void:
	GameState.reset_run()


func after_each() -> void:
	if _camp != null and is_instance_valid(_camp):
		_camp.queue_free()
	_camp = null
	await wait_frames(1)
	GameState.reset_run()


func _enter() -> void:
	_camp = CAMP_SCENE.instantiate() as Camp
	add_child(_camp)


func test_emits_camp_entered_on_ready() -> void:
	var entered := watch_signal(EventBus.camp_entered)
	_enter()
	assert_eq(entered.count, 1, "進入營地發一次 camp_entered")
	assert_true(_camp.is_menu_visible(), "顯示三個入口")


func test_continue_emits_camp_left_once() -> void:
	var left := watch_signal(EventBus.camp_left)
	_enter()
	_camp.leave_camp()
	_camp.leave_camp()
	assert_eq(left.count, 1, "只發一次 camp_left")
	assert_true(is_instance_valid(_camp), "營地不會自己消失(由 B 線移除)")
	_camp.open_minigame()
	assert_null(_camp.get_minigame(), "離開後不能再開小遊戲")


func test_continue_button_is_wired() -> void:
	var left := watch_signal(EventBus.camp_left)
	_enter()
	var button := _camp.find_child("ContinueButton", true, false) as Button
	assert_not_null(button)
	assert_eq(button.text, tr("UI_CAMP_CONTINUE"))
	button.pressed.emit()
	assert_eq(left.count, 1)


func test_companion_entry_shows_coming_soon() -> void:
	_enter()
	var button := _camp.find_child("CompanionButton", true, false) as Button
	assert_eq(button.text, tr("UI_CAMP_COMPANION"))
	button.pressed.emit()
	var toast := _camp.find_child("Toast", true, false) as Label
	assert_true(toast.visible, "顯示提示")
	assert_eq(toast.text, tr("UI_COMING_SOON"))
	assert_null(_camp.get_minigame(), "沒有開啟任何東西")


func test_minigame_round_trip() -> void:
	var finished := watch_signal(EventBus.minigame_finished)
	var left := watch_signal(EventBus.camp_left)
	GameState.vigor = 20
	_enter()
	_camp.open_minigame()
	var game := _camp.get_minigame()
	assert_not_null(game, "開啟小遊戲")
	assert_false(_camp.is_menu_visible(), "小遊戲進行中選單隱藏")
	game.set_process(false)
	game.step(game.config.countdown_sec + 0.01)
	game.step(game.config.duration_sec + 0.01)
	assert_eq(finished.count, 1)
	assert_true(GameState.vigor > 20, "活力已回復")
	game.step(game.config.results_delay_sec + game.config.results_min_sec + 0.1)
	game.close()
	await wait_frames(1)
	assert_null(_camp.get_minigame(), "回到營地")
	assert_true(_camp.is_menu_visible(), "選單重新出現")
	assert_eq(_camp.minigame_plays, 1)
	assert_eq(left.count, 0, "玩小遊戲不會離開營地")


func test_minigame_plays_per_visit_limit() -> void:
	_enter()
	_camp.config = _camp.config.duplicate() as CampConfig
	_camp.config.minigame_plays_per_visit = 1
	_camp.minigame_plays = 1
	_camp.open_minigame()
	assert_null(_camp.get_minigame(), "今晚已經玩過")
	var toast := _camp.find_child("Toast", true, false) as Label
	assert_eq(toast.text, tr("CAMP_MINIGAME_DONE"))


func test_layout_fits_every_phone_size() -> void:
	_enter()
	var root := get_tree().root
	var original := root.size
	# 手機實體像素 → ScreenFit 算出的邏輯畫面
	var phones := {
		Vector2i(1080, 1920): Vector2(180, 320), Vector2i(1080, 2400): Vector2(180, 400),
		Vector2i(1179, 2556): Vector2(196, 426), Vector2i(750, 1334): Vector2(187, 333),
		Vector2i(1290, 2796): Vector2(184, 399),
	}
	for phone: Vector2i in phones:
		root.size = phone
		ScreenFit.call(&"_refit")
		await wait_frames(2)
		var size := SafeArea.get_screen_size()
		assert_eq(size, phones[phone], "%s 的邏輯畫面" % phone)
		var safe := SafeArea.get_safe_rect()
		var menu := _camp.find_child("Menu", true, false) as Control
		var rect := Rect2(menu.global_position, menu.size)
		assert_true(safe.encloses(rect), "%s:選單在安全區內" % size)
		assert_true(rect.end.y <= safe.end.y - 16.0, "%s:選單避開底部手勢區" % size)
		for button_name in ["MinigameButton", "CompanionButton", "ContinueButton"]:
			var b := _camp.find_child(button_name, true, false) as Button
			assert_true(b.size.y >= 24.0 and b.size.x >= 24.0, "%s:%s 至少 24×24" % [size, button_name])
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)
