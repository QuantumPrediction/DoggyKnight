extends "res://tests/line_b/flow_test_base.gd"
## BS2、BS3、BS7:對白的播放次序(docs/STORY.md 第 8 節)。用替身對白框(stub_dialogue_box)。
## 開場繪本 → 1-1 場地 → l1_before → 標題卡(level_started)→ 第一波;過關慶祝 → story_after → 結算;
## 重試不重播;繼續冒險播該關的 story_before;結局 → 結算 → 預告 → 標題;對白期間場地停住。

const FULL_ORDER: Array[StringName] = [&"prologue", &"l1_before", &"l1_after", &"l2_before", &"l2_after",
		&"l3_before", &"l3_after", &"l4_before", &"l4_after", &"l5_before", &"l5_after", &"l6_before",
		&"l6_after", &"teaser"]

var _log: PackedStringArray = []
var _log_hooks: Array[Array] = []


func before_each() -> void:
	_log.clear()


func after_each() -> void:
	for hook in _log_hooks:
		var sig: Signal = hook[0]
		if sig.is_connected(hook[1]):
			sig.disconnect(hook[1])
	_log_hooks.clear()
	await super()


## 依次序記下對白、關卡與波次的訊號,例如 ["story:prologue", "level:1-1", "wave:1"]。
func _start_log() -> void:
	_hook(EventBus.dialogue_started, func(id: StringName) -> void: _log.append("story:%s" % id))
	_hook(EventBus.level_started, func(id: StringName) -> void: _log.append("level:%s" % id))
	_hook(EventBus.wave_started, func(i: int, _t: int) -> void: _log.append("wave:%d" % i))
	_hook(EventBus.level_completed, func(id: StringName) -> void: _log.append("clear:%s" % id))
	_hook(EventBus.level_failed, func(id: StringName) -> void: _log.append("fail:%s" % id))
	_hook(flow.state_changed, func(s: FlowMain.State) -> void:
		if s == FlowMain.State.RESULTS or s == FlowMain.State.TITLE or s == FlowMain.State.CAMP:
			_log.append("state:%s" % FlowMain.State.keys()[s]))


func _hook(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_log_hooks.append([sig, callable])


func _box() -> Node:
	return flow.get_dialogue_box()


func _world() -> Node:
	return flow.get_node(^"World")


## 在關卡中一直打倒敵人,直到對白開始或關卡結束。
func _play_until_story_or_end(timeout_sec: float = 10.0) -> bool:
	return await wait_until(func() -> bool:
		if flow.state == FlowMain.State.LEVEL:
			_auto_step()
		return flow.state in [FlowMain.State.STORY, FlowMain.State.RESULTS, FlowMain.State.FAILURE] \
				and not flow.is_switching(), timeout_sec)


func _wait_story(id: StringName) -> bool:
	return await wait_until(func() -> bool: return flow.is_story_playing() and flow.get_story_id() == id)


func test_new_game_prologue_then_arena_then_l1_before_then_title_card() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	_start_log()
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"prologue"), "新遊戲先播開場繪本")
	assert_eq(flow.state, FlowMain.State.STORY)
	assert_null(flow.get_arena(), "開場繪本時還沒有場地")
	assert_true(flow.get_screen() is StoryBackdrop, "繪本頁的背景")
	assert_eq(music_log.tracks()[-1], "story", "開場繪本播 story 音樂")
	assert_eq(skip_dialogue(), &"prologue")
	assert_true(await _wait_story(&"l1_before"), "然後 l1_before")
	assert_not_null(flow.get_arena(), "l1_before 在 1-1 場地出現之後")
	assert_not_null(flow.get_hud())
	assert_false(flow.get_session().is_playing(), "對白期間關卡還沒開始")
	assert_eq(music_log.tracks()[-1], "field", "關卡前的對白播該關的曲子")
	await wait_frames(2)
	assert_eq(_world().process_mode, Node.PROCESS_MODE_DISABLED, "對白期間場地停止運作")
	var player := flow.get_arena().call(&"get_player") as Node2D
	assert_false(player.can_process(), "金毛不能動")
	assert_eq(flow.get_session().time_sec, 0.0, "對白不計時")
	assert_false(_log.has("level:1-1"), "標題卡(level_started)還沒出現")
	skip_dialogue()
	assert_true(await wait_until(in_level))
	assert_true(await wait_until(func() -> bool: return _log.has("wave:1")))
	await wait_frames(2)
	assert_eq(_world().process_mode, Node.PROCESS_MODE_PAUSABLE, "對白之後場地恢復")
	assert_true(player.can_process())
	assert_eq(_log.slice(0, 4), PackedStringArray(["story:prologue", "story:l1_before", "level:1-1", "wave:1"]),
			"次序:開場繪本 → l1_before → 標題卡 → 第一波")
	assert_eq(read_save()["level_index"], 0)
	assert_true(read_save()["story_seen"].has("prologue"), "看過的段落已存檔")
	assert_true(read_save()["story_seen"].has("l1_before"))


func test_back_and_background_during_a_story() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"prologue"))
	skip_dialogue()
	assert_true(await _wait_story(&"l1_before"))
	var paused := watch_signal(EventBus.game_paused)
	AppLifecycle.simulate_back()
	assert_false(flow.is_pause_open(), "對白中返回鍵無效")
	SaveStore.new(SAVE_PATH).delete()
	AppLifecycle.simulate_background()
	assert_true(save_file_exists(), "對白中切到背景:立即存檔")
	assert_false(flow.is_pause_open(), "不疊暫停選單(對白本身會等玩家)")
	assert_false(get_tree().paused)
	AppLifecycle.simulate_foreground()
	assert_eq(paused.count, 0)
	assert_true(_box().call(&"is_active"), "回來時對白還在")
	skip_dialogue()
	assert_true(await wait_until(in_level))


func test_clear_celebration_then_story_after_then_results() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	_start_log()
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"prologue"))
	skip_dialogue()
	assert_true(await _wait_story(&"l1_before"))
	skip_dialogue()
	assert_true(await wait_until(in_level))
	music_log.clear()
	assert_true(await _play_until_story_or_end())
	assert_eq(flow.get_story_id(), &"l1_after", "過關後的對白")
	assert_eq(flow.state, FlowMain.State.STORY)
	assert_null(flow.get_screen(), "對白播完才出結算")
	assert_eq(music_log.tracks(), PackedStringArray(["victory", "field"]), "過關短曲,然後回到該關曲子")
	await wait_frames(2)
	assert_eq(_world().process_mode, Node.PROCESS_MODE_DISABLED, "過關後的對白期間場地停住")
	skip_dialogue()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.RESULTS))
	var clear_at := _log.find("clear:1-1")
	var story_at := _log.find("story:l1_after")
	var results_at := _log.find("state:RESULTS")
	assert_true(clear_at >= 0 and clear_at < story_at and story_at < results_at,
			"次序:過關 → l1_after → 結算 %s" % [_log])
	assert_eq(flow.get_last_result()["victory"], true)
	assert_eq(flow.get_last_result()["level_id"], &"1-1")


func test_retry_does_not_replay_story_before() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"prologue"))
	skip_dialogue()
	assert_true(await _wait_story(&"l1_before"))
	skip_dialogue()
	assert_true(await wait_until(in_level))
	var stories := watch_signal(EventBus.dialogue_started)
	flow.get_arena().call(&"debug_down_player")
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.FAILURE))
	assert_eq(stories.count, 0, "失敗沒有對白")
	var t0 := Time.get_ticks_msec()
	flow.get_screen().emit_signal(&"retry_pressed")
	assert_true(await wait_until(in_level, 2.0), "重試:直接回到戰鬥")
	assert_true(Time.get_ticks_msec() - t0 < 2000, "2 秒內")
	assert_eq(stories.count, 0, "重試不重播 l1_before")


func test_continue_plays_that_levels_story_before_but_not_the_prologue() -> void:
	SaveStore.new(SAVE_PATH).write(2, 0, true)
	make_flow(true, 1234, true)
	await wait_frames(1)
	var stories := watch_signal(EventBus.dialogue_started)
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await _wait_story(&"l3_before"), "繼續冒險:播 1-3 的開打前對白")
	assert_eq(stories.count, 1, "沒有開場繪本")
	assert_eq(started.count, 0, "對白之後才發 level_started")
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 0, "貝德維爾在對白之後才加入")
	skip_dialogue()
	assert_true(await wait_until(in_level))
	assert_eq(started.last_args(), [&"1-3"])
	await wait_frames(1)
	assert_eq(get_tree().get_node_count_in_group(&"companion"), 1, "鬥牛犬加入")


func test_ending_order_and_chapter_cleared() -> void:
	SaveStore.new(SAVE_PATH).write(5, 0, true)
	make_flow(true, 1234, true)
	await wait_frames(1)
	assert_false(GameState.chapter_cleared)
	_start_log()
	music_log.clear()
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await _wait_story(&"l6_before"))
	skip_dialogue()
	assert_true(await wait_until(in_level))
	assert_true(await _play_until_story_or_end())
	assert_eq(flow.get_story_id(), &"l6_after", "打敗黑騎士 → 結局")
	assert_true(GameState.chapter_cleared, "打敗黑騎士時就解鎖困難模式")
	assert_true(read_save()["chapter_cleared"], "並且立即存檔(結局播到一半被關掉也不會遺失)")
	assert_eq(music_log.tracks()[-1], "story", "結局播 story 音樂")
	skip_dialogue()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.RESULTS))
	assert_true(flow.get_last_result()["is_final"], "結算(第一章完)")
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await _wait_story(&"teaser"), "結算之後:第二章預告")
	assert_true(flow.get_screen() is StoryBackdrop)
	assert_null(flow.get_arena(), "預告時場地已移除")
	skip_dialogue()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.TITLE))
	var order: PackedStringArray = []
	for entry in _log:
		if entry.begins_with("story:") or entry.begins_with("clear:") or entry.begins_with("state:"):
			order.append(entry)
	assert_eq(order, PackedStringArray(["story:l6_before", "clear:1-6", "story:l6_after", "state:RESULTS",
			"story:teaser", "state:TITLE"]), "結局次序")
	assert_eq(music_log.tracks(), PackedStringArray(["boss", "chapter_clear", "story", "story", "title"]))
	assert_true(read_save()["chapter_cleared"])
	assert_false(flow.has_save(), "整章完成:沒有要繼續的關卡")


func test_whole_chapter_plays_every_level_story_in_order() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	var started := watch_signal(EventBus.level_started)
	var camps := watch_signal(EventBus.camp_entered)
	var results_seen: Array[StringName] = []
	var camp_seen: Array[int] = []
	flow.get_screen().emit_signal(&"new_game_pressed")
	var finished := await wait_until(func() -> bool:
		if flow.is_switching():
			return false
		match flow.state:
			FlowMain.State.STORY:
				skip_dialogue()
			FlowMain.State.LEVEL:
				_auto_step()
			FlowMain.State.RESULTS:
				var id: StringName = flow.get_last_result()["level_id"]
				if not results_seen.has(id):
					results_seen.append(id)
					flow.get_screen().emit_signal(&"continue_pressed")
			FlowMain.State.CAMP:
				if not camp_seen.has(flow.get_level_index()):
					camp_seen.append(flow.get_level_index())
					EventBus.camp_left.emit()
			FlowMain.State.TITLE:
				return started.count > 0
		return false, 60.0)
	assert_true(finished, "在時限內玩完")
	assert_eq(started.count, 6)
	assert_eq(camps.count, 2)
	assert_eq(_box().get(&"played"), FULL_ORDER, "每段對白依 docs/STORY.md 第 8 節的次序各播一次")
	for id in FULL_ORDER:
		assert_true(GameState.story_seen.has(id), "story_seen 有 %s" % id)
	assert_true(GameState.chapter_cleared)


func test_without_a_dialogue_box_the_story_is_skipped() -> void:
	make_flow(false, 1234, true)
	await wait_frames(1)
	_box().free()
	assert_false(flow.can_play_story(flow.chapter.prologue))
	var started := watch_signal(EventBus.level_started)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await wait_until(in_level), "沒有對白框:直接開始 1-1")
	assert_eq(started.last_args(), [&"1-1"])
	assert_true(await play_until_level_ends())
	assert_eq(flow.state, FlowMain.State.RESULTS, "過關直接出結算")


func test_captain_wave_switches_to_boss_music() -> void:
	SaveStore.new(SAVE_PATH).write(3, 0, true)
	make_flow(true)
	await wait_frames(1)
	flow.get_screen().emit_signal(&"continue_pressed")
	assert_true(await wait_until(in_level))
	var level := flow.get_session().level
	var captain_wave := -1
	for i in level.waves.size():
		if flow.get_session().spawner.has_boss_music(level.waves[i]):
			captain_wave = i + 1
	assert_eq(captain_wave, level.waves.size(), "1-4 的最後一波有稻草人隊長")
	var waves := watch_signal(EventBus.wave_started)
	music_log.clear()
	assert_true(await wait_until(func() -> bool:
		_auto_step()
		return waves.count > 0 and waves.last_args()[0] == captain_wave))
	assert_eq(music_log.tracks(), PackedStringArray(["boss"]), "隊長那一波開始時改播頭目音樂")
