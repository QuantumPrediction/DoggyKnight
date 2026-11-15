extends "res://tests/line_a/combat_test_base.gd"
## M1 驗收:連續打 3 分鐘(遊戲時間)小怪,不當機、不卡牆、敵人不出界、不疊成一點。
##
## 為了不讓測試跑 3 分鐘,暫時把物理每秒格數與 time_scale 一起提高 SPEEDUP 倍:
## 每一格仍然是 1/60 秒的遊戲時間,所以行為與正常遊戲相同,只是跑得比較快。

const GAME_SECONDS := 180.0
const SPEEDUP := 10.0
const WAVE_EVERY := 7.0
const MAX_ENEMIES := 40
const SAMPLE_EVERY := 0.5
const COLLAPSE_DISTANCE := 3.0
const BOSS_AT := 95.0

var _saved_ticks: int
var _saved_scale: float
var _saved_max_steps: int


func before_each() -> void:
	_saved_ticks = Engine.physics_ticks_per_second
	_saved_scale = Engine.time_scale
	_saved_max_steps = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = roundi(60.0 * SPEEDUP)
	Engine.time_scale = SPEEDUP
	Engine.max_physics_steps_per_frame = 16


func after_each() -> void:
	Engine.physics_ticks_per_second = _saved_ticks
	Engine.time_scale = _saved_scale
	Engine.max_physics_steps_per_frame = _saved_max_steps
	await super()


func test_three_minute_run_stays_stable() -> void:
	make_arena(-1.0)
	var died := watch_signal(EventBus.enemy_died)
	var collected := watch_signal(EventBus.exp_collected)
	var downed := watch_signal(EventBus.player_downed)
	var dog := arena.spawn_companion(&"bulldog") as BulldogCompanion
	for trick: StringName in [&"shake", &"spin", &"bark"]:
		GameState.active_tricks.append(trick)
		EventBus.trick_chosen.emit(trick)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115

	var elapsed := 0.0
	var next_wave := 0.5
	var next_sample := 0.0
	var next_input := 0.0
	var wave := 0
	var boss_spawned := false
	var samples := 0
	var out_of_bounds := 0
	var worst_cluster := 0
	var collapsed_samples := 0
	var max_alive := 0
	var max_fx := 0
	var player_travel := 0.0
	var last_player_pos := player.global_position
	var born: Dictionary = {}
	var oldest := 0.0
	var start_ms := Time.get_ticks_msec()

	while elapsed < GAME_SECONDS:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()     # 已含 time_scale:每格 1/60 秒遊戲時間
		if elapsed >= next_wave:
			next_wave += WAVE_EVERY
			wave += 1
			_spawn_wave(wave, rng)
		if not boss_spawned and elapsed >= BOSS_AT:
			boss_spawned = true
			arena.spawn_enemy(&"black_knight", Vector2(90, 120))
		if elapsed >= next_input:
			# 模擬玩家:一下走、一下停(停下才會攻擊)。
			next_input += rng.randf_range(0.3, 1.1)
			if rng.randf() < 0.45:
				player.set_move_override(Vector2.from_angle(rng.randf() * TAU))
			else:
				player.clear_move_override()
		if GameState.vigor < 40:
			player.heal(GameState.player_stats.max_vigor)
		if player.loyalty >= player.tuning.loyalty_max:
			EventBus.ultimate_requested.emit()
		player_travel += player.global_position.distance_to(last_player_pos)
		last_player_pos = player.global_position
		if elapsed >= next_sample:
			next_sample += SAMPLE_EVERY
			samples += 1
			var enemies := _active_enemies()
			max_alive = maxi(max_alive, get_tree().get_nodes_in_group(&"enemy").size())
			for enemy in enemies:
				if not Layout.ARENA_RECT.has_point(enemy.global_position):
					out_of_bounds += 1
				var id := enemy.get_instance_id()
				if not born.has(id):
					born[id] = elapsed
				if enemy.data.id != &"black_knight":
					oldest = maxf(oldest, elapsed - float(born[id]))
			var cluster := _largest_cluster(enemies)
			worst_cluster = maxi(worst_cluster, cluster)
			if cluster >= 3:
				collapsed_samples += 1
			if not Layout.ARENA_RECT.has_point(player.global_position) or not Layout.ARENA_RECT.has_point(dog.global_position):
				out_of_bounds += 1
			max_fx = maxi(max_fx, arena.fx_layer.get_child_count() + arena.ground_layer.get_child_count())

	var real_seconds := float(Time.get_ticks_msec() - start_ms) / 1000.0
	# 特效不會累積:把剩下的敵人正常打倒,等 2 秒,地上與空中的特效應該幾乎都消失了。
	player.clear_move_override()
	for node in get_tree().get_nodes_in_group(&"enemy"):
		node.call(&"die")
	var settle := 0.0
	while settle < 2.0:
		await get_tree().physics_frame
		settle += get_physics_process_delta_time()
	var lingering := 0
	for layer: Node in [arena.fx_layer, arena.ground_layer]:
		for child in layer.get_children():
			if child.get(&"helmet_settled") == null:
				lingering += 1
	print("          [long run] %.0f s game in %.1f s real, waves %d, kills %d, exp %d, max alive %d, worst cluster %d, oldest enemy %.1f s, max fx %d, lingering fx %d, spin %d, bark %d, shake %d, ult %d, dog dazed %d"
			% [elapsed, real_seconds, wave, died.count, collected.count, max_alive, worst_cluster, oldest, max_fx, lingering,
			player.abilities.triggers(&"spin"), player.abilities.triggers(&"bark"), player.abilities.triggers(&"shake"),
			player.ultimate_count, dog.times_dazed])
	assert_true(samples >= int(GAME_SECONDS / SAMPLE_EVERY) - 1, "跑完 3 分鐘")
	assert_eq(out_of_bounds, 0, "沒有角色跑出場地")
	assert_eq(collapsed_samples, 0, "敵人沒有疊成一點(最多 %d 隻擠在 %.0f 像素內)" % [worst_cluster, COLLAPSE_DISTANCE])
	assert_true(died.count >= 60, "持續有敵人被打倒(%d)" % died.count)
	assert_true(collected.count > 0, "撿到經驗珠")
	assert_eq(downed.count, 0)
	assert_true(player_travel > 300.0, "金毛沒有被卡住(走了 %.0f 像素)" % player_travel)
	assert_true(oldest < 60.0, "沒有敵人卡在某處一直打不到(最久 %.1f 秒)" % oldest)
	assert_true(max_fx < 400, "特效數量合理(最多 %d 個)" % max_fx)
	assert_true(lingering <= 6, "特效會自己消失(剩 %d 個)" % lingering)
	assert_true(player.abilities.triggers(&"spin") >= 10, "轉圈有持續觸發")
	assert_true(player.abilities.triggers(&"bark") >= 5, "吠叫有持續觸發")
	assert_true(player.abilities.triggers(&"shake") >= 5, "握手有持續觸發")


func _spawn_wave(index: int, rng: RandomNumberGenerator) -> void:
	var points := arena.get_spawn_points()
	var plan: Array[StringName] = []
	for i in 3 + index % 4:
		plan.append(&"scarecrow")
	for i in 1 + index % 3:
		plan.append(&"crow")
	if index % 4 == 0:
		plan.append(&"scarecrow_elite")
	for enemy_id in plan:
		if get_tree().get_nodes_in_group(&"enemy").size() >= MAX_ENEMIES:
			return
		arena.spawn_enemy(enemy_id, points[rng.randi() % points.size()])


func _active_enemies() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as EnemyBase
		if enemy != null and enemy.is_targetable():
			result.append(enemy)
	return result


## 最多有幾隻敵人擠在同一點(某隻敵人 COLLAPSE_DISTANCE 以內的數量,含自己)。
func _largest_cluster(enemies: Array[EnemyBase]) -> int:
	var worst := 0
	for a in enemies:
		var count := 0
		for b in enemies:
			if a.global_position.distance_to(b.global_position) <= COLLAPSE_DISTANCE:
				count += 1
		worst = maxi(worst, count)
	return worst
