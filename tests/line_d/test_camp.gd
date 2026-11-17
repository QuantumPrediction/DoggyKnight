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
	_camp.finish_intro()
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
		_camp.finish_intro()
		var size := SafeArea.get_screen_size()
		assert_eq(size, phones[phone], "%s 的邏輯畫面" % phone)
		var safe := SafeArea.get_safe_rect()
		var menu := _camp.find_child("Menu", true, false) as Control
		var rect := Rect2(menu.global_position, menu.size)
		assert_true(safe.encloses(rect), "%s:選單在安全區內" % size)
		assert_true(rect.end.y <= safe.end.y - 16.0, "%s:選單避開底部手勢區" % size)
		for button_name in ["MinigameButton", "TrainingButton", "CompanionButton", "ContinueButton"]:
			var b := _camp.find_child(button_name, true, false) as Button
			assert_true(b.size.y >= 24.0 and b.size.x >= 24.0, "%s:%s 至少 24×24" % [size, button_name])
		# 摸頭的範圍:夠大、在畫面內、不和選單重疊
		var pet := _camp.find_child("PetZone", true, false) as Control
		var pet_rect := Rect2(pet.global_position, pet.size)
		assert_true(pet_rect.size.x >= 24.0 and pet_rect.size.y >= 24.0, "%s:金毛夠大好點" % size)
		assert_true(Rect2(Vector2.ZERO, size).encloses(pet_rect.grow(-6.0)), "%s:金毛在畫面內" % size)
		assert_false(pet_rect.intersects(rect), "%s:摸頭範圍不蓋住選單" % size)
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)


# --- DP1:營火旁的摸摸頭、鬥牛犬、音樂 ---

func _enter_with(changes: Dictionary) -> void:
	_camp = CAMP_SCENE.instantiate() as Camp
	var cfg := (_camp.config as CampConfig).duplicate() as CampConfig
	for key: String in changes:
		cfg.set(key, changes[key])
	_camp.config = cfg
	add_child(_camp)


func test_camp_plays_its_own_music() -> void:
	GameState.music_on = true
	_enter()
	assert_eq(Music.current, &"camp", "營地自己播 camp 音樂")


func test_petting_goldie_raises_satisfaction_up_to_cap() -> void:
	GameState.satisfaction = 0
	_enter_with({"pet_cooldown_sec": 0.0, "pet_satisfaction_gain": 2, "pet_rewards_per_visit": 5})
	# 不用 watch_signal:營地在 after_each 釋放,訊號監看會在之後才停止。
	var emitted: Array = []
	_camp.goldie_petted.connect(func(rewarded: bool) -> void: emitted.append(rewarded))
	var results: Array[bool] = []
	for i in 7:
		results.append(_camp.pet_goldie())
	assert_eq(results, [true, true, true, true, true, false, false] as Array[bool], "前 5 下有加分")
	assert_eq(GameState.satisfaction, 10, "滿意度 +2 × 5")
	assert_eq(_camp.pet_count, 7, "超過上限照樣可以摸")
	assert_eq(_camp.pet_rewards, 5)
	assert_eq(emitted.size(), 7)
	assert_eq(emitted[0], true)
	assert_eq(emitted[6], false)


func test_pet_cap_resets_on_next_camp_visit() -> void:
	GameState.satisfaction = 0
	_enter_with({"pet_cooldown_sec": 0.0, "pet_rewards_per_visit": 1, "pet_satisfaction_gain": 3})
	assert_true(_camp.pet_goldie())
	assert_false(_camp.pet_goldie())
	_camp.queue_free()
	await wait_frames(1)
	_enter_with({"pet_cooldown_sec": 0.0, "pet_rewards_per_visit": 1, "pet_satisfaction_gain": 3})
	assert_true(_camp.pet_goldie(), "下一次營地又可以加分")
	assert_eq(GameState.satisfaction, 6)


func test_pet_satisfaction_never_exceeds_100() -> void:
	GameState.satisfaction = 99
	_enter_with({"pet_cooldown_sec": 0.0, "pet_satisfaction_gain": 2})
	assert_true(_camp.pet_goldie())
	assert_eq(GameState.satisfaction, 100)
	assert_false(_camp.pet_goldie(), "滿了就不再加")
	assert_eq(GameState.satisfaction, 100)


func test_fast_taps_are_ignored_by_cooldown() -> void:
	_enter_with({"pet_cooldown_sec": 0.3})
	assert_true(_camp.pet_goldie())
	assert_false(_camp.pet_goldie(), "同一瞬間連點不算")
	assert_eq(_camp.pet_count, 1)


func test_goldie_reacts_to_petting() -> void:
	Haptics.reset_for_tests()
	_enter()
	var goldie := _camp.get_goldie()
	assert_false(goldie.is_happy())
	_camp.pet_goldie()
	assert_true(goldie.is_happy(), "開心")
	assert_eq(goldie.current_animation(), _camp.config.goldie_happy_animation, "瞇眼吐舌的動畫")
	assert_eq(Haptics.last_kind, &"light", "輕震")
	goldie.advance(_camp.config.pet_react_sec + 0.01)
	assert_false(goldie.is_happy(), "一會兒後回到平常")
	assert_eq(goldie.current_animation(), _camp.config.goldie_animation)


func test_tapping_goldie_on_screen_pets_her() -> void:
	_enter()
	var zone := _camp.find_child("PetZone", true, false) as Control
	assert_not_null(zone)
	assert_eq(zone.mouse_filter, Control.MOUSE_FILTER_STOP)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	zone.gui_input.emit(tap)
	assert_eq(_camp.pet_count, 1, "點金毛 = 摸頭")


func test_no_petting_during_minigame_or_after_leaving() -> void:
	_enter_with({"pet_cooldown_sec": 0.0})
	_camp.open_minigame()
	assert_false(_camp.pet_goldie(), "小遊戲中不能摸")
	assert_eq(_camp.pet_count, 0)
	var game := _camp.get_minigame()
	game.set_process(false)
	game.close()
	await wait_frames(1)
	_camp.leave_camp()
	assert_false(_camp.pet_goldie(), "離開後不能摸")


func test_bulldog_sits_by_fire_from_second_camp() -> void:
	GameState.level_index = 1
	_enter()
	assert_false(_camp.is_bulldog_visible(), "第一次營地(1-2 之後):鬥牛犬還沒加入")
	_camp.queue_free()
	await wait_frames(1)
	GameState.level_index = 3
	_enter()
	_camp.skip_story()      # 第二次營地先播 camp2(B 線的對白檔存在時)
	for i in 30:
		if not _camp.is_story_playing():
			break
		await wait_frames(1)
	assert_true(_camp.is_bulldog_visible(), "第二次營地(1-4 之後):鬥牛犬坐在火旁")
	Haptics.reset_for_tests()
	_camp.tap_bulldog()
	assert_eq(Haptics.last_kind, &"light", "點鬥牛犬:汪!")


func test_pet_hint_appears_until_first_pet() -> void:
	_enter_with({"pet_hint_delay_sec": 0.0, "pet_cooldown_sec": 0.0})
	await wait_frames(2)
	assert_true(_camp.get_goldie().show_hint, "還沒摸過:金毛頭上有愛心泡泡")
	_camp.pet_goldie()
	await wait_frames(2)
	assert_false(_camp.get_goldie().show_hint, "摸過就不再出現")
