extends "res://tests/line_a/combat_test_base.gd"
## v2.7 A 線測試的共同工具(不是測試檔本身:檔名不以 test_ 開頭)。
## 為了讓全部測試留在 tools/run_tests.sh 的時間上限之內,這裡的測試用「快轉」:
## 場地建好後把 CombatFx.time_scale 設成 FAST(A 線的角色、投射物、預警都照這個倍數前進),
## 頭目的倒下演出也縮短(feel.boss_defeat_time)。預警「夠長」一律用資料裡的秒數檢查,不用格數。
## 用法:extends "res://tests/line_a/fast_combat_test_base.gd"

const FAST := 4.0

var feel: FeelTuning


func before_each() -> void:
	Haptics.reset_for_tests()
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.mode = &"story"
	GameState.chapter = 1
	GameState.level_index = 0
	feel = (load("res://data/player/feel_tuning.tres") as FeelTuning).duplicate() as FeelTuning
	feel.boss_defeat_time = 0.15
	feel.boss_slowmo_time = 0.0
	CombatFx.set_feel(feel)


func after_each() -> void:
	CombatFx.time_scale = 1.0
	CombatFx.set_feel(null)
	DifficultyScaling.override = null
	GameState.difficulty = &"normal"
	GameState.mode = &"story"
	GameState.chapter = 1
	await super()


## 建立場地(敵人立刻行動)、金毛不動不攻擊,然後快轉。
func make_fast_arena() -> CombatArena:
	make_arena()
	player.set_physics_process(false)
	CombatFx.time_scale = FAST
	return arena


func projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group(EnemyProjectile.GROUP)


func count_in(layer: Node, script_class: Variant) -> int:
	var n := 0
	for child in layer.get_children():
		if is_instance_of(child, script_class) and not child.is_queued_for_deletion():
			n += 1
	return n


func first_in(layer: Node, script_class: Variant) -> Node:
	for child in layer.get_children():
		if is_instance_of(child, script_class) and not child.is_queued_for_deletion():
			return child
	return null


## 金毛又可以被打中(測試裡金毛的 _physics_process 關著,無敵時間不會自己倒數)。
func reset_player_hit() -> void:
	player.invuln_left = 0.0
