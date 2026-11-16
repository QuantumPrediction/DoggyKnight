extends "res://tests/integration/playthrough_bot.gd"
## A 線的難度量度工具(AS7;不是測試)。用整合工作階段的試玩機器人(全部正式零件、同一套操作),
## 另外可以:
##   --hard        用困難模式(GameState.difficulty = &"hard")玩整章
##   --approx      B 線的新波次還沒合併時,用「近似 v2.3 設計」的波次(1-3 加弓兵、1-4 最後一波是
##                 稻草人隊長、1-5 混合空盔甲兵、精英、烏鴉、弓兵);正式關卡已經有新敵人時自動不用
## 最後多印「每關倒下幾次」與「每關受到的傷害」。
##
## 執行(headless,約 2 至 4 分鐘):
##   godot --headless --path . res://tests/line_a/tools/difficulty_bot.tscn -- --seed=7 --hard

const CHAPTER_PATH := "res://data/levels/chapter_1.tres"

var hard: bool = false
var approx: bool = false
var _downs_by_level: Dictionary = {}
var _damage_by_level: Dictionary = {}
var _fails_by_level: Dictionary = {}


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--hard":
			hard = true
		elif arg == "--approx":
			approx = true
	GameState.difficulty = &"hard" if hard else &"normal"
	SaveStore.new(SAVE_PATH).delete()
	flow = (load("res://game/flow/main.tscn") as PackedScene).instantiate() as FlowMain
	flow.save_path = SAVE_PATH
	flow.use_stand_ins = false
	flow.rng_seed = rng_seed
	var chapter := load(CHAPTER_PATH) as ChapterData
	if approx and not _has_new_enemies(chapter):
		flow.chapter = _approx_chapter(chapter)
		print("(使用近似 v2.3 的波次:B 線的新波次還沒合併)")
	add_child(flow)
	EventBus.player_downed.connect(_on_downed)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.ultimate_used.connect(func() -> void: _ultimates += 1)
	EventBus.level_started.connect(func(_id: StringName) -> void: _level_clock = 0.0)
	await _frames(10)
	GameState.difficulty = &"hard" if hard else &"normal"
	flow.get_screen().emit_signal(&"new_game_pressed")
	GameState.difficulty = &"hard" if hard else &"normal"
	Engine.time_scale = speed
	var started := Time.get_ticks_msec()
	var finished := false
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame
		if _skip_dialogues():
			continue
		match flow.state:
			FlowMain.State.LEVEL:
				_level_clock += get_process_delta_time()
				await _play_level()
			FlowMain.State.RESULTS:
				await _on_results()
			FlowMain.State.FAILURE:
				var r := flow.get_last_result()
				_level_lines.append("%s  失敗 %5.1f 秒  擊倒 %2d" % [r["level_id"], r["time_sec"], r["kills"]])
				_fails_by_level[r["level_id"]] = int(_fails_by_level.get(r["level_id"], 0)) + 1
				flow.get_screen().emit_signal(&"retry_pressed")
				await _frames(5)
			FlowMain.State.CAMP:
				await _play_camp()
			FlowMain.State.TITLE:
				finished = true
				break
	Engine.time_scale = 1.0
	print("\n== 難度量度(%s,seed %d) ==" % ["困難" if hard else "一般", rng_seed])
	for line in _level_lines:
		print(line)
	var summary: PackedStringArray = []
	for id: String in ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6"]:
		summary.append("%s 倒%d 傷%d" % [id, int(_downs_by_level.get(StringName(id), 0)), int(_damage_by_level.get(StringName(id), 0))])
	print("每關:", " | ".join(summary))
	print("DOWNS %d;必殺技 %d 次;最後活力 %d" % [_downs, _ultimates, GameState.vigor])
	print("PLAYTHROUGH %s" % ("COMPLETE" if finished else "TIMEOUT"))
	SaveStore.new(SAVE_PATH).delete()
	get_tree().quit(0 if finished else 1)


func _current_level() -> StringName:
	var session := flow.get_session() if flow != null else null
	return session.level.id if session != null and session.level != null else &"?"


func _on_downed() -> void:
	_downs += 1
	var id := _current_level()
	_downs_by_level[id] = int(_downs_by_level.get(id, 0)) + 1


func _on_damaged(amount: int) -> void:
	var id := _current_level()
	_damage_by_level[id] = int(_damage_by_level.get(id, 0)) + amount


func _has_new_enemies(chapter: ChapterData) -> bool:
	for level in chapter.levels:
		for wave in level.waves:
			for entry in wave.spawns:
				if entry.enemy_id in [&"scarecrow_archer", &"armored_husk", &"scarecrow_captain"]:
					return true
	return false


static func _entry(id: StringName, count: int, delay: float, pattern: StringName) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = id
	e.count = count
	e.delay = delay
	e.pattern = pattern
	return e


## 近似 B 線 v2.3 的關卡設計(只用來量度 A 線的數值;正式波次以 B 線為準)。
func _approx_chapter(source: ChapterData) -> ChapterData:
	var chapter := ChapterData.new()
	chapter.camp_after = source.camp_after.duplicate()
	var levels: Array[LevelData] = []
	for level in source.levels:
		var copy := level.duplicate(true) as LevelData
		var waves: Array[WaveData] = []
		for wave in level.waves:
			var w := WaveData.new()
			var spawns: Array[SpawnEntry] = []
			for e in wave.spawns:
				spawns.append(_entry(e.enemy_id, e.count, e.delay, e.pattern))
			w.spawns = spawns
			waves.append(w)
		copy.waves = waves
		levels.append(copy)
	# 1-3:弓兵登場(第 2、3 波的一組烏鴉換成弓兵)。
	var l3 := levels[2].waves
	l3[1].spawns[2] = _entry(&"scarecrow_archer", 2, 11.0, &"corners")
	l3[2].spawns[1] = _entry(&"scarecrow_archer", 2, 6.0, &"corners")
	# 1-4:最後一波的最後一組換成稻草人隊長。
	var l4 := levels[3].waves
	l4[l4.size() - 1].spawns[l4[l4.size() - 1].spawns.size() - 1] = _entry(&"scarecrow_captain", 1, 7.0, &"line_top")
	# 1-5:空盔甲兵、精英、烏鴉、弓兵混合。
	var l5 := levels[4].waves
	l5[0].spawns.append(_entry(&"armored_husk", 1, 5.0, &"edges"))
	l5[1].spawns[1] = _entry(&"scarecrow_archer", 2, 6.0, &"corners")
	l5[1].spawns.append(_entry(&"armored_husk", 1, 2.0, &"edges"))
	l5[2].spawns.append(_entry(&"armored_husk", 2, 8.0, &"edges"))
	var last := l5[l5.size() - 1].spawns
	last.append(_entry(&"scarecrow_archer", 2, 7.0, &"corners"))
	last.append(_entry(&"armored_husk", 1, 10.0, &"edges"))
	chapter.levels = levels
	return chapter
