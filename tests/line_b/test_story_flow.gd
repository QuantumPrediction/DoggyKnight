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


# --- BW4(v2.7,DEV_PLAN 第 20 節) ---

const FADING_BOX: String = "res://tests/line_b/fading_dialogue_box.tscn"


## 對白框在畫面上嗎(播放中,或播完之後還在淡出)。測試自己判斷,不用 FlowMain 的 is_dialogue_showing()。
func _box_visible(box: Node) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	if box.has_method(&"is_fading"):
		return bool(box.call(&"is_active")) or bool(box.call(&"is_fading"))
	var root := box.get_node_or_null(^"DialogueRoot") as CanvasItem      # C 線的正式對白框
	return root != null and root.visible and root.modulate.a > 0.0


## BW4:試玩截圖裡,3-1 過關後的對白(蘭斯洛特)蓋在結算畫面上。原因:對白框(第 40 層)播完之後
## 還要淡出一下(正式對白框約 0.18 秒),但結算畫面(第 30 層)在播完的同一格就加上去了,所以淡出的
## 那幾格對白框疊在結算之上。docs/STORY.md 第 8 節:過關慶祝 → story_after → 結算;現在等對白框
## 完全看不見才出結算。開打前的對白也一樣:淡出之後才發 level_started(標題卡)。
## 用會淡出的測試替身與 C 線的正式對白框(存在的話)各驗一次,重現的是 3-1。
func test_results_wait_until_the_story_after_dialogue_has_faded() -> void:
	var scenes: Array[PackedScene] = [load(FADING_BOX) as PackedScene]
	if FlowParts.has_real(FlowParts.DIALOGUE):
		scenes.append(FlowParts.try_load(FlowParts.DIALOGUE))
	else:
		print("    略過正式對白框(ui/dialogue/dialogue_box.tscn 不存在),只用測試替身")
	for scene in scenes:
		await _check_story_after_then_results(scene)


func _check_story_after_then_results(scene: PackedScene) -> void:
	var where := scene.resource_path.get_file()
	reset_settings()
	GameState.chapters_cleared = 2
	GameState.chapter_cleared = true
	GameState.chapter = 3
	make_flow(false, 1234, true, false, scene)
	await wait_frames(1)
	var box := flow.get_dialogue_box()
	assert_not_null(box, where)
	if box == null:
		return
	var seen := {"overlap_frames": 0, "results_with_box": false, "title_card_with_box": false}
	var watch := func() -> void:
		if flow != null and is_instance_valid(flow) and flow.state == FlowMain.State.RESULTS \
				and flow.get_screen() != null and _box_visible(box):
			seen["overlap_frames"] = int(seen["overlap_frames"]) + 1
	var on_state := func(s: FlowMain.State) -> void:
		if s == FlowMain.State.RESULTS:
			seen["results_with_box"] = _box_visible(box)
	var on_level := func(_id: StringName) -> void:
		seen["title_card_with_box"] = bool(seen["title_card_with_box"]) or _box_visible(box)
	_hook(get_tree().process_frame, watch)
	_hook(flow.state_changed, on_state)
	_hook(EventBus.level_started, on_level)
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"c3_prologue"), where)
	skip_dialogue()
	assert_true(await _wait_story(&"c3l1_before"), where)
	skip_dialogue()
	assert_true(await wait_until(in_level), where)
	assert_false(seen["title_card_with_box"], "%s:開打前的對白淡出之後才出標題卡" % where)
	assert_true(await _play_until_story_or_end(), where)
	assert_eq(flow.get_story_id(), &"c3l1_after", "%s:3-1 過關後的對白" % where)
	assert_eq(flow.chapter.get_level(0).story_after.lines[0].speaker, &"lancelot", "第一句是蘭斯洛特")
	skip_dialogue()
	await wait_frames(1)
	assert_true(_box_visible(box), "%s:對白框還在淡出" % where)
	assert_eq(flow.state, FlowMain.State.STORY, "%s:淡出期間還不出結算" % where)
	assert_null(flow.get_screen(), "%s:結算畫面還沒加上" % where)
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.RESULTS, 3.0), where)
	assert_false(seen["results_with_box"], "%s:結算出現時對白框已經看不見" % where)
	await wait_frames(3)
	assert_eq(seen["overlap_frames"], 0, "%s:沒有任何一格同時看到結算與對白框" % where)
	assert_not_null(flow.get_screen(), where)
	assert_eq(flow.get_last_result()["level_id"], &"3-1")
	flow.queue_free()
	flow = null
	await wait_frames(2)


## BW4:對白框一直不隱藏(淡出很久或壞掉)也不會卡住:最多等 story_fade_wait 秒。
func test_a_box_that_never_hides_does_not_block_the_results() -> void:
	make_flow(false, 1234, true, false, load(FADING_BOX) as PackedScene)
	await wait_frames(1)
	flow.get_dialogue_box().set(&"fade_sec", 30.0)
	flow.difficulty.story_fade_wait = 0.25
	flow.get_screen().emit_signal(&"new_game_pressed")
	assert_true(await _wait_story(&"prologue"))
	skip_dialogue()
	assert_true(await _wait_story(&"l1_before"))
	skip_dialogue()
	assert_true(await wait_until(in_level, 2.0), "最多等 story_fade_wait 秒就開始")
	assert_true(await _play_until_story_or_end())
	assert_eq(flow.get_story_id(), &"l1_after")
	var started := Time.get_ticks_msec()
	skip_dialogue()
	assert_true(await wait_until(func() -> bool: return flow.state == FlowMain.State.RESULTS, 2.0),
			"最多等 story_fade_wait 秒就出結算")
	assert_true(Time.get_ticks_msec() - started >= 200, "有等對白框")
