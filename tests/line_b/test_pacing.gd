extends "res://tests/line_b/flow_test_base.gd"
## BP1 開場等待、BP2 轉場、BP5 音樂次序。

const FakeArena := preload("res://tests/line_b/fake_arena.gd")
const FakeTransition := preload("res://tests/line_b/fake_transition.gd")

var session: LevelSession


func before_each() -> void:
	if session != null and is_instance_valid(session):
		session.queue_free()
	session = null


func _fake_arena_scene() -> PackedScene:
	var scene := PackedScene.new()
	var node := FakeArena.new()
	scene.pack(node)
	node.free()
	return scene


func _one_wave_level() -> LevelData:
	var level := LevelData.new()
	level.id = &"intro_test"
	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.enemy_id = &"scarecrow"
	entry.count = 1
	wave.spawns.append(entry)
	level.waves.append(wave)
	return level


func test_first_wave_waits_for_the_intro() -> void:
	var d := fast_difficulty()
	d.intro_duration = 1.6
	d.first_wave_delay = 0.0
	session = LevelSession.new()
	session.setup(_one_wave_level(), 0, d, _fake_arena_scene(), RandomNumberGenerator.new())
	add_child(session)
	session.build()
	session.spawner.set_physics_process(false)
	var started := watch_signal(EventBus.level_started)
	var waves := watch_signal(EventBus.wave_started)
	var intro := watch_signal(session.intro_finished)
	session.begin(null)
	assert_eq(started.count, 1, "level_started 立即發出(HUD 播標題卡)")
	assert_true(session.is_playing())
	session.spawner.step(1.0)
	assert_eq(waves.count, 0, "開場中沒有敵人")
	assert_false(session.is_intro_done())
	assert_eq(get_tree().get_node_count_in_group(&"enemy"), 0)
	session.spawner.step(0.7)
	assert_eq(waves.count, 1, "intro_duration 之後第一波")
	assert_eq(intro.count, 1)
	assert_true(session.is_intro_done())


func test_player_can_move_during_the_intro() -> void:
	make_flow()
	var d := flow.difficulty
	d.intro_duration = 30.0
	await wait_frames(1)
	assert_true(await start_new_game())
	assert_false(flow.get_session().is_intro_done())
	assert_false(get_tree().paused, "開場不暫停遊戲")
	var player := flow.get_arena().call(&"get_player") as Node2D
	assert_true(player.can_process(), "金毛在開場時可以走動")
	var before := player.global_position
	player.set(&"direction", Vector2.RIGHT)
	await wait_frames(5)
	player.set(&"direction", Vector2.ZERO)
	assert_true(player.global_position.x > before.x, "金毛移動了")


func test_intro_is_in_difficulty_data() -> void:
	var d := load(DIFFICULTY) as DifficultyData
	assert_almost_eq(d.intro_duration, 1.6, 0.21, "約 1.6 秒")
	assert_almost_eq(d.results_delay, 2.0, 0.31, "約 2 秒(HUD 慶祝)")


# --- 轉場 ---

func _install_fake_transition(hang: bool, seconds: float) -> FakeTransition:
	var fake := FakeTransition.new()
	fake.hang = hang
	flow.transition.use_screen(fake)
	flow.transition.cover_time = seconds
	flow.transition.reveal_time = seconds
	flow.transition.timeout = 0.2
	return fake


func test_new_game_goes_through_cover_and_reveal() -> void:
	make_flow()
	await wait_frames(1)
	var fake := _install_fake_transition(false, 0.05)
	var title := flow.get_screen()
	var started := watch_signal(EventBus.level_started)
	var covered_at_start: Array[bool] = []
	var on_started := func(_id: StringName) -> void: covered_at_start.append(fake.covered)
	EventBus.level_started.connect(on_started)
	title.emit_signal(&"new_game_pressed")
	title.emit_signal(&"new_game_pressed")          # 連按兩下
	assert_eq(flow.state, FlowMain.State.SWITCHING)
	assert_true(flow.is_switching())
	assert_true(is_instance_valid(title) and title.is_inside_tree(), "蓋住之前舊畫面還在")
	assert_true(await wait_until(in_level, 3.0))
	EventBus.level_started.disconnect(on_started)
	assert_eq(fake.calls, PackedStringArray(["cover", "reveal"]))
	assert_eq(started.count, 1, "連按兩下只開始一次")
	assert_eq(covered_at_start, [false] as Array[bool], "畫面完全露出後才發 level_started")
	assert_false(flow.is_switching())


func test_a_stuck_transition_never_blocks_the_flow() -> void:
	make_flow()
	await wait_frames(1)
	var fake := _install_fake_transition(true, 0.05)
	var t0 := Time.get_ticks_msec()
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await wait_until(in_level, 3.0), "轉場卡住也會在逾時後繼續")
	assert_true(Time.get_ticks_msec() - t0 < 2000)
	assert_eq(fake.calls, PackedStringArray(["cover", "reveal"]))
	# 失敗 → 再試一次:同樣不會卡住,而且 2 秒內回到戰鬥
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	t0 = Time.get_ticks_msec()
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level, 2.0))
	assert_true(Time.get_ticks_msec() - t0 < 2000, "2 秒內回到戰鬥")


func test_backgrounding_during_a_transition_pauses_the_new_level() -> void:
	make_flow()
	await wait_frames(1)
	_install_fake_transition(false, 0.1)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_eq(flow.state, FlowMain.State.SWITCHING)
	AppLifecycle.simulate_background()
	assert_true(save_file_exists(), "轉場中切到背景也立即存檔")
	AppLifecycle.simulate_foreground()
	assert_true(await wait_until(in_level, 3.0))
	assert_true(flow.is_pause_open(), "回來時新的一關已暫停")
	assert_true(get_tree().paused)


func test_no_transition_scene_switches_directly() -> void:
	assert_null(FlowParts.optional_scene("res://ui/does_not_exist.tscn"), "檔案不存在 → 不播轉場")
	make_flow()
	await wait_frames(1)
	flow.transition.use_screen(null)
	flow.transition.cover_time = 0.3
	flow.transition.reveal_time = 0.3
	assert_false(flow.transition.is_active())
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await wait_until(in_level, 1.0))


func test_quitting_during_a_transition_does_not_start_the_old_level() -> void:
	make_flow()
	await wait_frames(1)
	_install_fake_transition(false, 0.1)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.LEVEL))
	assert_true(flow.is_switching(), "畫面還在露出中")
	EventBus.back_requested.emit()                  # 打開暫停選單
	EventBus.quit_to_title_requested.emit()         # 立即回標題
	assert_true(await wait_until(func() -> bool:
		return flow.state == FlowMain.State.TITLE and not flow.is_switching(), 3.0))
	await wait_frames(5)
	assert_eq(started.count, 0, "被打斷的那一關不會開始")
	assert_null(flow.get_session())
	assert_false(get_tree().paused)


func test_real_transition_scene_has_the_contract_methods() -> void:
	var scene := FlowParts.optional_scene(FlowParts.TRANSITION)
	if scene == null:
		return          # C 線還沒有轉場:流程直接切換
	var node := scene.instantiate()
	assert_true(node is CanvasLayer)
	assert_true(node.has_method(&"cover") and node.has_method(&"reveal"))
	node.free()


# --- 音樂(BP5) ---

func test_music_follows_the_flow() -> void:
	make_flow()
	await wait_frames(1)
	assert_eq(music_log.tracks(), PackedStringArray(["title"]), "標題")
	assert_true(await start_new_game())
	assert_eq(music_log.tracks(), PackedStringArray(["title", "field"]), "一般關卡")
	music_log.clear()
	AppLifecycle.simulate_back()
	assert_eq(music_log.calls, PackedStringArray(["duck:true"]), "暫停:壓低音量")
	AppLifecycle.simulate_back()
	assert_eq(music_log.calls, PackedStringArray(["duck:true", "duck:false"]), "繼續:回復音量")
	music_log.clear()
	assert_true(await play_until_level_ends())
	assert_eq(music_log.tracks(), PackedStringArray(["victory"]), "過關")
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	music_log.clear()
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	assert_eq(music_log.tracks(), PackedStringArray(["fail"]), "失敗")
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(music_log.tracks(), PackedStringArray(["fail", "field"]), "再試一次")
	music_log.clear()
	AppLifecycle.simulate_back()
	EventBus.quit_to_title_requested.emit()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	assert_eq(music_log.calls, PackedStringArray(["duck:true", "duck:false", "play:title"]), "回標題")


func test_boss_and_chapter_clear_music() -> void:
	SaveStore.new(SAVE_PATH).write(5, 0, true)
	make_flow(true)
	await wait_frames(1)
	music_log.clear()
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	assert_eq(music_log.tracks(), PackedStringArray(["boss"]), "頭目關")
	assert_true(await play_until_level_ends())
	assert_eq(music_log.tracks(), PackedStringArray(["boss", "chapter_clear"]), "打完第一章")
	assert_true(flow.get_last_result()["is_final"])
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	assert_eq(music_log.tracks(), PackedStringArray(["boss", "chapter_clear", "title"]))
