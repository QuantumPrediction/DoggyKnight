extends TestCase
## D3 評分與獎勵:門檻、活力回復(不超過上限)、滿意度(0 至 100)、下一關加成。

const GRADING_PATH := "res://game/minigames/scroll/scroll_grading.tres"


class FakeState:
	extends RefCounted
	var player_stats: StatBlock = StatBlock.new()
	var vigor: int = 0
	var satisfaction: int = 0
	var next_level_bonus: float = 0.0


func _grading() -> MinigameGrading:
	return load(GRADING_PATH) as MinigameGrading


func _state(vigor: int, satisfaction: int, max_vigor: int = 100) -> FakeState:
	var s := FakeState.new()
	s.player_stats.max_vigor = max_vigor
	s.vigor = vigor
	s.satisfaction = satisfaction
	return s


func after_each() -> void:
	GameState.reset_run()


func test_scroll_grading_values_match_dev_plan() -> void:
	var g := _grading()
	assert_not_null(g, "scroll_grading.tres 載入")
	assert_eq(g.max_grade(), 3, "評價 0 至 3")
	assert_eq(g.vigor_restore_ratio.size(), 4)
	for i in 4:
		assert_almost_eq(g.vigor_restore_ratio[i], [0.25, 0.5, 0.75, 1.0][i], 0.0001, "活力回復 %d" % i)
		assert_almost_eq(g.next_level_bonus[i], [0.0, 0.05, 0.10, 0.15][i], 0.0001, "下一關加成 %d" % i)
	for i in g.grade_thresholds.size() - 1:
		assert_true(g.grade_thresholds[i] < g.grade_thresholds[i + 1], "門檻由小到大")


func test_grade_thresholds() -> void:
	var g := MinigameGrading.new()
	g.grade_thresholds = [10, 20, 30]
	assert_eq(g.grade_for(0), 0)
	assert_eq(g.grade_for(9), 0)
	assert_eq(g.grade_for(10), 1, "剛好達到門檻")
	assert_eq(g.grade_for(19), 1)
	assert_eq(g.grade_for(20), 2)
	assert_eq(g.grade_for(29), 2)
	assert_eq(g.grade_for(30), 3)
	assert_eq(g.grade_for(100000), 3, "最多 3 級")
	assert_eq(g.grade_for(-5), 0, "負分是 0 級")


func test_vigor_restore_by_grade() -> void:
	var g := _grading()
	for grade in 4:
		var s := _state(0, 0, 120)
		var changes := g.apply_rewards(grade, s)
		var expected := roundi([0.25, 0.5, 0.75, 1.0][grade] * 120)
		assert_eq(s.vigor, expected, "評價 %d 回復 %d" % [grade, expected])
		assert_eq(changes["vigor"], expected)


func test_vigor_is_clamped_to_max() -> void:
	var g := _grading()
	var s := _state(90, 0, 100)
	var changes := g.apply_rewards(3, s)
	assert_eq(s.vigor, 100, "不會超過上限")
	assert_eq(changes["vigor"], 10, "實際只回復 10")
	var s2 := _state(80, 0, 100)
	g.apply_rewards(1, s2)
	assert_eq(s2.vigor, 100, "80 + 50 → 100")


func test_satisfaction_is_clamped() -> void:
	var g := _grading()
	var s := _state(50, 95)
	var changes := g.apply_rewards(3, s)
	assert_eq(s.satisfaction, 100, "不會超過 100")
	assert_eq(changes["satisfaction"], 5)
	var s2 := _state(50, 0)
	g.apply_rewards(0, s2)
	assert_eq(s2.satisfaction, g.satisfaction_gain[0])
	var g2 := MinigameGrading.new()
	g2.satisfaction_gain = [-50, -50, -50, -50]
	var s3 := _state(50, 10)
	g2.apply_rewards(0, s3)
	assert_eq(s3.satisfaction, 0, "不會低於 0")


func test_next_level_bonus_is_set_not_added() -> void:
	var g := _grading()
	var s := _state(50, 0)
	g.apply_rewards(3, s)
	assert_almost_eq(s.next_level_bonus, 0.15)
	g.apply_rewards(1, s)
	assert_almost_eq(s.next_level_bonus, 0.05, 0.0001, "再玩一次以新的評價為準")
	g.apply_rewards(0, s)
	assert_almost_eq(s.next_level_bonus, 0.0)


func test_out_of_range_grade_is_clamped() -> void:
	var g := _grading()
	var s := _state(0, 0)
	g.apply_rewards(9, s)
	assert_eq(s.vigor, 100, "超出範圍當作 3 級")
	var s2 := _state(0, 0)
	g.apply_rewards(-3, s2)
	assert_eq(s2.vigor, 25, "負數當作 0 級")


func test_rewards_on_real_game_state() -> void:
	GameState.reset_run()
	GameState.vigor = 10
	GameState.satisfaction = 40
	_grading().apply_rewards(2, GameState)
	assert_eq(GameState.vigor, 10 + roundi(0.75 * GameState.player_stats.max_vigor))
	assert_eq(GameState.satisfaction, 60)
	assert_almost_eq(GameState.next_level_bonus, 0.10)
