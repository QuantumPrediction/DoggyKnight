extends "res://tests/line_b/flow_test_base.gd"
## 替身零件:方法與訊號和正式零件的合約一致(DEV_PLAN 4.4、4.9),以及沙盒用的觸控操作。

const STUBS := "res://game/flow/stubs/"

var arena: Node2D


func before_each() -> void:
	GameState.reset_run()
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = (load(STUBS + "stub_arena.tscn") as PackedScene).instantiate() as Node2D
	add_child(arena)


func test_stand_in_arena_has_the_contract_methods() -> void:
	for method: StringName in [&"spawn_enemy", &"get_spawn_points", &"clear", &"spawn_companion",
			&"set_background", &"get_player"]:
		assert_true(arena.has_method(method), "arena.%s" % method)
	var player := arena.call(&"get_player") as Node2D
	assert_true(player is CharacterBody2D and player.is_in_group(&"player"))
	assert_eq(player.global_position, Layout.PLAYER_START)
	assert_true(player.has_method(&"take_damage") and player.has_method(&"heal"))
	var points: Array = arena.call(&"get_spawn_points")
	assert_true(points.size() >= 4)
	for p: Vector2 in points:
		assert_true(Layout.ARENA_RECT.has_point(p), "出生點在場地內 %s" % p)


func test_spawned_enemy_is_in_group_and_dies_with_signals() -> void:
	var died := watch_signal(EventBus.enemy_died)
	var collected := watch_signal(EventBus.exp_collected)
	var enemy := arena.call(&"spawn_enemy", &"crow", Vector2(60, 100)) as Node2D
	assert_true(enemy.is_in_group(&"enemy"), "生成後立即在 enemy 群組")
	assert_true(enemy.has_method(&"setup") and enemy.has_method(&"take_damage"))
	enemy.call(&"take_damage", 10)
	assert_eq(died.count, 0, "烏鴉 12 生命,10 點不會倒")
	enemy.call(&"take_damage", 10)
	assert_eq(died.count, 1)
	assert_eq(died.last_args()[0], &"crow")
	assert_false(enemy.is_in_group(&"enemy"), "倒下立即離開群組")
	assert_eq(collected.last_args(), [1], "替身直接發 exp_collected")


func test_tap_on_enemy_kills_it() -> void:
	await wait_frames(1)
	var enemy := arena.call(&"spawn_enemy", &"scarecrow", Vector2(60, 100)) as Node2D
	var died := watch_signal(EventBus.enemy_died)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = arena.get_canvas_transform() * enemy.global_position
	arena.call(&"_unhandled_input", touch)
	assert_eq(died.count, 1, "點一下敵人 → 倒下")
	var player := arena.call(&"get_player") as Node2D
	assert_eq(player.get(&"direction"), Vector2.ZERO, "點敵人不會啟動搖桿")


func test_drag_moves_player_and_release_stops() -> void:
	await wait_frames(1)
	var player := arena.call(&"get_player") as Node2D
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(90, 250)
	arena.call(&"_unhandled_input", press)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(110, 250)
	arena.call(&"_unhandled_input", drag)
	assert_eq(player.get(&"direction"), Vector2.RIGHT)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(20, 300)
	arena.call(&"_unhandled_input", second)
	assert_eq(player.get(&"direction"), Vector2.RIGHT, "第二根手指不影響移動")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(110, 250)
	arena.call(&"_unhandled_input", release)
	assert_eq(player.get(&"direction"), Vector2.ZERO, "放手停下")


func test_player_takes_reduced_damage_and_falls_asleep() -> void:
	var player := arena.call(&"get_player") as Node2D
	var downed := watch_signal(EventBus.player_downed)
	var vigor := watch_signal(EventBus.vigor_changed)
	GameState.player_stats.damage_taken_mult = 0.5
	player.call(&"take_damage", 10)
	assert_eq(GameState.vigor, 95, "傷害 × damage_taken_mult")
	assert_eq(vigor.last_args(), [95, 100])
	player.call(&"force_down")
	assert_eq(GameState.vigor, 0)
	assert_eq(downed.count, 1)
	assert_true(player.get(&"downed"))


func test_clear_removes_enemies_from_group_immediately() -> void:
	arena.call(&"spawn_enemy", &"scarecrow", Vector2(60, 100))
	arena.call(&"spawn_enemy", &"scarecrow", Vector2(100, 100))
	arena.call(&"clear")
	assert_eq(get_tree().get_node_count_in_group(&"enemy"), 0)


func test_companion_and_background() -> void:
	var companion := arena.call(&"spawn_companion", &"bulldog") as Node
	assert_true(companion.is_in_group(&"companion"))
	arena.call(&"set_background", load("res://assets/backgrounds/meadow.tscn"))
	assert_eq(arena.get_node("Background").get_child_count(), 1)


func test_stand_in_screens_match_the_ui_contract() -> void:
	var contract := {
		"stub_title.tscn": [[&"setup"], [&"new_game_pressed", &"continue_pressed", &"credits_pressed"]],
		"stub_results.tscn": [[&"setup"], [&"continue_pressed"]],
		"stub_failure.tscn": [[&"setup"], [&"retry_pressed", &"title_pressed"]],
		"stub_credits.tscn": [[], [&"closed"]],
		"stub_hud.tscn": [[], []],
		"stub_trick_choice.tscn": [[], []],
		"stub_pause.tscn": [[], []],
		"stub_camp.tscn": [[], []],
	}
	var entered := watch_signal(EventBus.camp_entered)
	for file: String in contract:
		var node := (load(STUBS + file) as PackedScene).instantiate()
		add_child(node)
		assert_true(node is Control, "%s 的根節點是 Control" % file)
		for method: StringName in contract[file][0]:
			assert_true(node.has_method(method), "%s.%s()" % [file, method])
		for sig: StringName in contract[file][1]:
			assert_true(node.has_signal(sig), "%s 訊號 %s" % [file, sig])
		if file in ["stub_hud.tscn", "stub_trick_choice.tscn", "stub_pause.tscn"]:
			assert_eq(node.process_mode, Node.PROCESS_MODE_ALWAYS, "%s 暫停時仍要運作" % file)
		remove_child(node)
		node.free()
	assert_eq(entered.count, 1, "營地進入時發 camp_entered")


func test_stand_in_pause_and_trick_choice_listen_to_event_bus() -> void:
	var pause := (load(STUBS + "stub_pause.tscn") as PackedScene).instantiate() as Control
	var choice := (load(STUBS + "stub_trick_choice.tscn") as PackedScene).instantiate() as Control
	add_child(pause)
	add_child(choice)
	assert_false(pause.visible)
	EventBus.game_paused.emit(true)
	assert_true(pause.visible)
	EventBus.game_paused.emit(false)
	assert_false(pause.visible)
	var chosen := watch_signal(EventBus.trick_chosen)
	EventBus.trick_offered.emit([TrickDeck.load_trick(&"sit"), TrickDeck.load_trick(&"wag"), TrickDeck.load_trick(&"spin")])
	assert_true(choice.visible)
	choice.call(&"choose", 1)
	assert_false(choice.visible)
	assert_eq(chosen.last_args(), [&"wag"])
	remove_child(pause)
	remove_child(choice)
	pause.free()
	choice.free()
