extends "res://tests/line_a/combat_test_base.gd"
## A10:能力類把戲。用替身宿主與模擬時間計算觸發次數,再確認金毛會重建與監聽把戲。

const FakeHost := preload("res://tests/line_a/fake_ability_host.gd")
const TUNING: AbilityTuning = preload("res://data/player/ability_tuning.tres")
const STEP := 1.0 / 60.0

var host: FakeHost
var abilities: AbilitySet


func before_each() -> void:
	host = FakeHost.new()
	add_child(host)
	var target := Node2D.new()
	host.add_child(target)
	host.targets.append(target)
	abilities = AbilitySet.new(host, TUNING)


func _simulate(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		abilities.update(STEP)


func _swings(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in count:
		result.append(abilities.on_swing_landed())
	return result


func test_shake_does_nothing_until_chosen() -> void:
	assert_eq(_swings(8), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] as Array[float])
	assert_eq(abilities.triggers(&"shake"), 0)


func test_shake_doubles_every_fourth_landed_swing() -> void:
	abilities.add_trick(&"shake")
	var expected: Array[float] = [1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 1.0, 2.0]
	assert_eq(_swings(12), expected)
	assert_eq(abilities.triggers(&"shake"), 3, "12 下中有 3 下雙倍")


func test_shake_stacks_shorten_the_interval() -> void:
	abilities.add_trick(&"shake")
	abilities.add_trick(&"shake")
	assert_eq(abilities.shake.interval(), 3, "兩層:每 3 下")
	assert_eq(_swings(6), [1.0, 1.0, 2.0, 1.0, 1.0, 2.0] as Array[float])
	abilities.add_trick(&"shake")
	assert_eq(abilities.shake.interval(), 2, "三層:每 2 下")
	abilities.add_trick(&"shake")
	assert_eq(abilities.shake.interval(), 2, "最少每 2 下")
	assert_almost_eq(abilities.shake.multiplier(), 2.5, 0.001, "之後每層倍數 +0.5")


func test_spin_triggers_every_six_seconds() -> void:
	abilities.add_trick(&"spin")
	_simulate(5.9)
	assert_eq(abilities.triggers(&"spin"), 0, "6 秒前不轉")
	_simulate(0.2)
	assert_eq(abilities.triggers(&"spin"), 1, "6 秒轉一次")
	_simulate(54.0)
	assert_eq(abilities.triggers(&"spin"), 10, "60 秒轉 10 次")
	assert_eq(host.hits.size(), 10, "每次打中範圍內的目標")
	assert_eq(host.hits[0][1], 10, "迴旋斬傷害 = 攻擊力 × 1")
	assert_eq(host.visuals[0][0], &"spin")


func test_spin_waits_for_a_target_then_fires_at_once() -> void:
	abilities.add_trick(&"spin")
	var saved: Array[Node2D] = host.targets.duplicate()
	host.targets.clear()
	_simulate(10.0)
	assert_eq(abilities.triggers(&"spin"), 0, "附近沒有敵人時不轉")
	host.targets.assign(saved)
	abilities.update(STEP)
	assert_eq(abilities.triggers(&"spin"), 1, "敵人一靠近就轉")


func test_bark_stuns_every_eight_seconds() -> void:
	abilities.add_trick(&"bark")
	_simulate(7.9)
	assert_eq(abilities.triggers(&"bark"), 0)
	_simulate(0.2)
	assert_eq(abilities.triggers(&"bark"), 1)
	_simulate(32.0)
	assert_eq(abilities.triggers(&"bark"), 5, "40 秒吠 5 次")
	assert_eq(host.stuns.size(), 5)
	assert_almost_eq(host.stuns[0][1], 1.5, 0.001, "震懾 1.5 秒")


func test_spin_and_bark_stacking() -> void:
	abilities.add_trick(&"spin")
	abilities.add_trick(&"spin")
	assert_almost_eq(abilities.spin.cooldown(), 4.8, 0.001, "兩層:冷卻 ×0.8")
	assert_almost_eq(abilities.spin.radius(), 40.0, 0.001, "兩層:半徑 +6")
	_simulate(10.0)
	assert_eq(abilities.triggers(&"spin"), 2, "10 秒內轉 2 次")
	abilities.add_trick(&"bark")
	abilities.add_trick(&"bark")
	assert_almost_eq(abilities.bark.cooldown(), 6.8, 0.001)
	assert_almost_eq(abilities.bark.radius(), 56.0, 0.001)
	assert_almost_eq(abilities.bark.stun_time(), 2.0, 0.001)


func test_rebuild_counts_repeats_and_ignores_stat_tricks() -> void:
	abilities.add_trick(&"bark")
	abilities.rebuild([&"shake", &"sit", &"spin", &"shake", &"fetch"])
	assert_eq(abilities.stacks(&"shake"), 2)
	assert_eq(abilities.stacks(&"spin"), 1)
	assert_eq(abilities.stacks(&"bark"), 0, "重建時先清空")
	assert_false(abilities.add_trick(&"wag"), "數值類把戲不歸 A 線")
	assert_true(AbilitySet.is_ability(&"spin"))


func test_player_rebuilds_from_game_state_and_listens_to_trick_chosen() -> void:
	GameState.active_tricks.assign([&"bark", &"wag", &"bark"])
	make_arena()
	assert_eq(player.abilities.stacks(&"bark"), 2, "進場時依 active_tricks 重建")
	EventBus.trick_chosen.emit(&"spin")
	assert_eq(player.abilities.stacks(&"spin"), 1, "trick_chosen 多疊一層")
	EventBus.trick_chosen.emit(&"sit")
	assert_eq(player.abilities.stacks(&"shake"), 0)


func test_player_spin_hits_nearby_enemies_in_game() -> void:
	make_arena()
	player.set_move_override(Vector2.ZERO)
	var enemy := spawn(&"scarecrow_elite", player.global_position + Vector2(0, -26))
	enemy.set_physics_process(false)
	player.abilities.add_trick(&"spin")
	player.abilities.spin.timer = player.abilities.spin.cooldown()
	var hp_before := enemy.hp
	await wait_physics(2)
	assert_eq(player.abilities.triggers(&"spin"), 1)
	assert_true(enemy.hp < hp_before, "迴旋斬打中附近的敵人")
