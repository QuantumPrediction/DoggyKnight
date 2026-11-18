extends Node
## B 線的量度工具(BP8):跑整合工作階段的試玩機器人(tests/integration/playthrough_bot.tscn,
## 全部正式零件),另外印出每關的星級、受到的傷害、每一波開始與清空的時間,用來設定
## LevelData.par_time 與 damage_budget,以及調整波次節奏。不是自動化測試。
##
## 執行(headless,約 2 分鐘):
##   godot --headless --path . res://tests/line_b/tools/star_bot.tscn -- --seed=7
## 參數與試玩機器人相同(--seed=、--speed=)。另加 --hard:當作已打完第一章,用困難模式玩(v2.3 BS4)。
## v2.6:--chapter=N:當作已打完第 N − 1 章,玩第 N 章(要試玩機器人也能玩完第 N 章)。

const BOT_SCENE: String = "res://tests/integration/playthrough_bot.tscn"

var _flow: FlowMain
var _waves: PackedStringArray = []
var _wave_damage: int = 0
var _hits: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hard := OS.get_cmdline_user_args().has("--hard")
	var bot := (load(BOT_SCENE) as PackedScene).instantiate()
	add_child(bot)
	if hard:
		# 機器人刪掉存檔後才建立流程;標題出現前設定好,FlowMain 的新遊戲就用困難模式。
		GameState.chapter_cleared = true
		GameState.difficulty = &"hard"
		print("STAR 困難模式")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):
			var n := clampi(arg.trim_prefix("--chapter=").to_int(), 1, GameState.CHAPTER_COUNT)
			GameState.chapters_cleared = maxi(GameState.chapters_cleared, n - 1)
			GameState.chapter_cleared = GameState.chapter_cleared or n > 1
			GameState.chapter = n
			print("STAR 第 %d 章" % n)
	_flow = bot.get(&"flow") as FlowMain
	if _flow == null:
		push_error("star_bot: 試玩機器人沒有建立流程")
		return
	_flow.state_changed.connect(_on_state_changed)
	EventBus.level_started.connect(_on_level_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_damaged.connect(_on_player_damaged)


func _time() -> float:
	var session := _flow.get_session()
	return session.time_sec if session != null else 0.0


func _on_level_started(_level_id: StringName) -> void:
	_waves.clear()
	_wave_damage = 0
	_hits = 0


func _on_wave_started(index: int, _total: int) -> void:
	_wave_damage = 0
	_waves.append("w%d %4.1f" % [index, _time()])


func _on_wave_cleared(_index: int) -> void:
	_waves.append("-%4.1f(傷%d)" % [_time(), _wave_damage])


func _on_player_damaged(amount: int) -> void:
	_wave_damage += amount
	_hits += 1


func _on_state_changed(state: FlowMain.State) -> void:
	if state != FlowMain.State.RESULTS and state != FlowMain.State.FAILURE:
		return
	var r := _flow.get_last_result()
	var level := _flow.chapter.get_level(int(r["level_index"]))
	var goals: Array = r["star_goals"]
	var marks := "".join(goals.map(func(g: Dictionary) -> String: return "★" if g["met"] else "☆"))
	print("STAR %s%s %s %s 用時 %5.1f(門檻 %d)傷害 %3d(門檻 %d)被打 %d 次 擊倒 %d 等級 %d | %s" % [
			r["level_id"], "(困難)" if r.get("difficulty", &"normal") == &"hard" else "",
			"過關" if r["victory"] else "失敗", marks, r["time_sec"], int(level.par_time),
			r["damage_taken"], level.damage_budget, _hits, r["kills"], r["hero_level"], " ".join(_waves)])
