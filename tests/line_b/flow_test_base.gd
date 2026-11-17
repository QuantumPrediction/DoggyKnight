extends TestCase
## B 線測試的共用工具(檔名不是 test_*,所以測試執行器不會把它當成測試)。
## 用法:extends "res://tests/line_b/flow_test_base.gd"

const MAIN_SCENE: String = "res://game/flow/main.tscn"
const SAVE_PATH: String = "user://test_line_b_save.json"
const CHAPTER_1: String = "res://data/levels/chapter_1.tres"
const DIFFICULTY: String = "res://game/progression/difficulty.tres"
const MusicRecorder := preload("res://tests/line_b/music_recorder.gd")

var flow: FlowMain
var quit_calls: int = 0
## make_flow 換上的假音樂播放器(記錄 Music 的呼叫次序;不碰真的 Music Autoload)。
var music_log: MusicRecorder


func after_each() -> void:
	if flow != null and is_instance_valid(flow):
		flow.queue_free()
	flow = null
	get_tree().paused = false
	AppLifecycle.simulate_foreground()
	GameState.reset_run()
	reset_settings()
	SaveStore.new(SAVE_PATH).delete()
	await wait_frames(2)


## 存檔與設定欄位回到預設值(reset_run 不會重設它們)。
static func reset_settings() -> void:
	GameState.snacks = 0
	GameState.sound_on = true
	GameState.music_on = true
	GameState.haptics_on = true
	GameState.tutorial_done = false
	GameState.best_stars = {}
	GameState.difficulty = &"normal"
	GameState.chapter_cleared = false
	GameState.story_seen = {}
	GameState.mode = &"story"
	GameState.meta_upgrades = {}
	GameState.endless_best = 0


## 測試用難度:所有等待都接近 0、不播轉場,測試跑得快。
func fast_difficulty() -> DifficultyData:
	var d := (load(DIFFICULTY) as DifficultyData).duplicate() as DifficultyData
	d.intro_duration = 0.0
	d.transition_cover_time = 0.0
	d.transition_reveal_time = 0.0
	d.surround_telegraph = 0.0
	d.line_spacing = 0.0
	d.first_wave_delay = 0.0
	d.inter_wave_delay = 0.0
	d.spawn_spacing = 0.0
	d.results_delay = 0.02
	d.failure_delay = 0.02
	d.event_delay = 0.0
	d.event_auto_pick_delay = 0.05
	return d


## 第一章的複本,但每組敵人的 delay 都是 0(敵人數目與波次不變)。
## with_story = false(預設):不帶任何對白(舊的流程測試不受故事影響);true:帶上 data/story/ 的全部對白。
func fast_chapter(with_story: bool = false) -> ChapterData:
	var source := load(CHAPTER_1) as ChapterData
	var chapter := ChapterData.new()
	chapter.camp_after = source.camp_after.duplicate()
	if with_story:
		chapter.prologue = source.prologue
		chapter.teaser = source.teaser
	for level in source.levels:
		var copy := LevelData.new()
		copy.id = level.id
		copy.display_name = level.display_name
		copy.is_boss = level.is_boss
		copy.companions = level.companions.duplicate()
		copy.background = level.background
		copy.par_time = level.par_time
		copy.damage_budget = level.damage_budget
		if with_story:
			copy.story_before = level.story_before
			copy.story_after = level.story_after
		for wave in level.waves:
			var wave_copy := WaveData.new()
			for entry in wave.spawns:
				var entry_copy := SpawnEntry.new()
				entry_copy.enemy_id = entry.enemy_id
				entry_copy.count = entry.count
				entry_copy.delay = 0.0
				entry_copy.pattern = entry.pattern
				wave_copy.spawns.append(entry_copy)
			copy.waves.append(wave_copy)
		chapter.levels.append(copy)
	return chapter


## 建立流程(一律用替身、測試存檔、固定種子)並加進場景樹。with_story = true 時帶上全部對白
## (對白框是替身 game/flow/stubs/stub_dialogue_box.tscn)。with_events = true(v2.4)時帶上
## data/levels/events.tres 的抉擇事件(替身事件介面);預設是空的事件表(舊的流程測試不受事件影響)。
func make_flow(keep_save: bool = false, rng_seed: int = 1234, with_story: bool = false,
		with_events: bool = false) -> FlowMain:
	if not keep_save:
		SaveStore.new(SAVE_PATH).delete()
	var f := (load(MAIN_SCENE) as PackedScene).instantiate() as FlowMain
	f.save_path = SAVE_PATH
	f.use_stand_ins = true
	f.rng_seed = rng_seed
	f.difficulty = fast_difficulty()
	f.chapter = fast_chapter(with_story)
	if not with_events:
		f.events = LevelEventTable.new()
	f.platform_name = "Linux"
	quit_calls = 0
	f.quit_handler = func() -> void: quit_calls += 1
	music_log = MusicRecorder.new()
	f.music = music_log
	add_child(f)
	flow = f
	return f


## 等到 condition 成立(最多 timeout_sec 秒)。傳回是否成立。
func wait_until(condition: Callable, timeout_sec: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


## 從標題開始新遊戲,等到第一關開始(已發 level_started)。
func start_new_game() -> bool:
	var title := flow.get_screen()
	title.emit_signal(&"new_game_pressed")
	return await wait_until(flow.is_level_running)


## 關卡已開始(轉場完成、已發 level_started)。
func in_level() -> bool:
	return flow.is_level_running()


## 一直打倒敵人、選第一個把戲,直到這一關結束(結算或失敗畫面出現)。
func play_until_level_ends(timeout_sec: float = 10.0) -> bool:
	return await wait_until(func() -> bool:
		if flow.state == FlowMain.State.LEVEL:
			_auto_step()
		return flow.state == FlowMain.State.RESULTS or flow.state == FlowMain.State.FAILURE, timeout_sec)


func _auto_step() -> void:
	if flow.is_event_open():
		EventBus.event_chosen.emit(flow.get_open_event_id(), 0)
		return
	if flow.is_trick_choice_open():

		var offer := flow.progression.get_current_offer()
		if not offer.is_empty():
			EventBus.trick_chosen.emit(offer[0].id)
		return
	var arena := flow.get_arena()
	if arena != null and arena.has_method(&"debug_kill_all"):
		arena.call(&"debug_kill_all")


## 對白框正在播時按「略過」。傳回略過的段落 id(沒有在播時為 &"")。
func skip_dialogue() -> StringName:
	var box := flow.get_dialogue_box() if flow != null else null
	if box == null or not box.call(&"is_active"):
		return &""
	var id := flow.get_story_id()
	box.call(&"skip")
	return id


## 等到正在播對白(最多 timeout_sec 秒)。
func wait_for_story(timeout_sec: float = 5.0) -> bool:
	return await wait_until(func() -> bool:
		return flow.state == FlowMain.State.STORY and flow.is_story_playing(), timeout_sec)


func save_file_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func read_save() -> Dictionary:
	return SaveStore.new(SAVE_PATH).read()
