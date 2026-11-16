extends TestCase
## DP2:「拉扯王室卷軸」的評分門檻(scroll_grading.tres)。
##
## 用真正的小遊戲,逐格(每秒 60 格)模擬幾種玩家,確認門檻合理:
## - 隨便玩(手指慢、反應慢、常在墨水漬上亂滑)→ 1 顆星
## - 普通玩家 → 2 顆星
## - 熟練玩家(滑得快、墨水漬一到就停手)→ 3 顆星
## 速度單位是「邏輯像素 / 秒」:1080 寬的手機上 1 邏輯像素 = 6 實體像素,
## 450 邏輯像素/秒大約是每秒 17 公分的平均手指速度(含抬手換位置的時間)。
## 結果也印在測試輸出,調整門檻時參考。

const SCROLL_SCENE := preload("res://game/minigames/scroll/scroll_minigame.tscn")
const DT: float = 1.0 / 60.0

## name、finger_speed(像素/秒)、stroke(每次滑多長)、lift(抬手換位置的秒數)、
## reaction(墨水漬到了還繼續滑多久)、mistake(每個墨水漬亂滑的機率)
const PROFILES: Array[Dictionary] = [
	{"name": "casual", "finger_speed": 300.0, "stroke": 90.0, "lift": 0.2, "reaction": 0.4, "mistake": 0.3},
	{"name": "average", "finger_speed": 450.0, "stroke": 110.0, "lift": 0.15, "reaction": 0.25, "mistake": 0.12},
	{"name": "skilled", "finger_speed": 650.0, "stroke": 130.0, "lift": 0.1, "reaction": 0.1, "mistake": 0.0},
]

var _game: ScrollMinigame


func before_each() -> void:
	GameState.reset_run()


func after_each() -> void:
	if _game != null and is_instance_valid(_game):
		_game.free()
	_game = null
	GameState.reset_run()


## 模擬一位玩家玩完一場,傳回 [分數, 評價, 完美次數, 犯錯次數]。
func _simulate(profile: Dictionary, run_seed: int) -> Array:
	if _game != null and is_instance_valid(_game):
		_game.free()
	_game = SCROLL_SCENE.instantiate() as ScrollMinigame
	_game.auto_start = false
	var cfg := (_game.config as ScrollMinigameConfig).duplicate() as ScrollMinigameConfig
	cfg.rng_seed = run_seed
	_game.config = cfg
	_game.reward_target = _FakeState.new()
	add_child(_game)
	_game.set_process(false)
	_game.start()
	_game.step(cfg.countdown_sec + 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 31 + 7
	var speed: float = profile["finger_speed"]
	var stroke: float = profile["stroke"]
	var lift: float = profile["lift"]
	var reaction: float = profile["reaction"]
	var mistake_chance: float = profile["mistake"]
	var touching := false
	var stroke_left := 0.0
	var lift_left := 0.0
	var react_left := 0.0
	var in_stop := false
	var frozen := false
	var will_mistake := false
	var mistake_done := false
	var guard := 0
	while _game.state == MinigameBase.State.PLAYING and guard < 60 * 40:
		guard += 1
		if _game.ink_state == ScrollMinigame.Ink.STOP:
			if not in_stop:
				in_stop = true
				react_left = reaction
				will_mistake = rng.randf() < mistake_chance
				mistake_done = false
			if react_left > 0.0 and touching:
				# 還沒反應過來:同一個手勢繼續滑(不罰,但會錯過「完美」)
				react_left -= DT
				_game.pull(speed * DT)
			else:
				react_left = 0.0
				frozen = true
				if will_mistake and not mistake_done:
					# 等不及:抬手又滑一下(扣時間)
					_game.simulate_touch_up()
					_game.simulate_touch_down()
					_game.pull(20.0)
					_game.simulate_touch_up()
					touching = false
					mistake_done = true
		else:
			in_stop = false
			if frozen:
				frozen = false
				if touching:
					_game.simulate_touch_up()
					touching = false
					lift_left = lift
			if touching:
				var step := minf(speed * DT, stroke_left)
				_game.pull(step)
				stroke_left -= step
				if stroke_left <= 0.0:
					_game.simulate_touch_up()
					touching = false
					lift_left = lift
			else:
				lift_left -= DT
				if lift_left <= 0.0:
					_game.simulate_touch_down()
					touching = true
					stroke_left = stroke
		_game.step(DT)
	return [_game.score, _game.grade, _game.perfects, _game.mistakes]


func _grade_counts(profile: Dictionary) -> Array:
	var grades: Array[int] = []
	var scores: Array[int] = []
	for run_seed in [11, 22, 33, 44, 55]:
		var r := _simulate(profile, run_seed)
		scores.append(int(r[0]))
		grades.append(int(r[1]))
	print("    [balance] %s: scores %s grades %s" % [profile["name"], scores, grades])
	return grades


func test_casual_player_gets_about_one_star() -> void:
	var grades := _grade_counts(PROFILES[0])
	for g: int in grades:
		assert_true(g >= 1, "隨便玩也至少 1 顆星(不會挫敗)")
		assert_true(g <= 2, "隨便玩拿不到 3 顆星")


func test_average_player_gets_two_stars() -> void:
	var grades := _grade_counts(PROFILES[1])
	var twos := grades.count(2)
	assert_true(twos >= 3, "普通玩家大多是 2 顆星(%s)" % [grades])
	assert_false(grades.has(0), "普通玩家不會 0 顆星")


func test_skilled_player_gets_three_stars() -> void:
	var grades := _grade_counts(PROFILES[2])
	assert_true(grades.count(3) >= 4, "熟練玩家幾乎都是 3 顆星(%s)" % [grades])


func test_perfect_stops_reward_quick_reactions() -> void:
	var quick := _simulate(PROFILES[2], 11)
	var slow := _simulate(PROFILES[0], 11)
	assert_true(int(quick[2]) > 0, "反應快的玩家有「完美!」")
	assert_true(int(quick[2]) > int(slow[2]), "反應快的完美次數比較多")


## 獎勵套用的替身(不改到真正的 GameState)。
class _FakeState:
	extends RefCounted
	var player_stats: StatBlock = StatBlock.new()
	var vigor: int = 50
	var satisfaction: int = 0
	var next_level_bonus: float = 0.0
