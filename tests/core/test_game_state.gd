extends TestCase
## GameState(DEV_PLAN 4.2)與資料類別(4.3)。


func after_each() -> void:
	GameState.reset_run()
	GameState.snacks = 0
	GameState.sound_on = true


func test_reset_run_starts_a_fresh_run() -> void:
	GameState.vigor = 3
	GameState.hero_level = 5
	GameState.level_index = 4
	GameState.active_tricks.append(&"sit")
	GameState.next_level_bonus = 0.1
	GameState.satisfaction = 80
	GameState.reset_run()
	assert_eq(GameState.vigor, GameState.player_stats.max_vigor)
	assert_eq(GameState.hero_level, 1)
	assert_eq(GameState.chapter, 1)
	assert_eq(GameState.level_index, 0)
	assert_eq(GameState.active_tricks.size(), 0)
	assert_eq(GameState.next_level_bonus, 0.0)
	assert_eq(GameState.satisfaction, 0)


func test_reset_run_keeps_save_data_and_settings() -> void:
	GameState.snacks = 7
	GameState.sound_on = false
	GameState.reset_run()
	assert_eq(GameState.snacks, 7, "零食屬於存檔")
	assert_false(GameState.sound_on, "音效開關屬於設定")


func test_player_stats_is_a_copy_of_the_base() -> void:
	GameState.player_stats.move_speed = 999.0
	assert_almost_eq(GameState.BASE_STATS.move_speed, 70.0, 0.001, "基準數值不可被改")
	GameState.reset_run()
	assert_almost_eq(GameState.player_stats.move_speed, 70.0)


func test_base_stats_match_dev_plan_table() -> void:
	var stats: StatBlock = GameState.BASE_STATS
	assert_eq(stats.max_vigor, 100)
	assert_eq(stats.attack_damage, 10)
	assert_almost_eq(stats.move_speed, 70.0)
	assert_almost_eq(stats.attack_interval, 0.5)
	assert_almost_eq(stats.attack_range, 28.0)
	assert_almost_eq(stats.damage_taken_mult, 1.0)
	assert_almost_eq(stats.exp_mult, 1.0)


func test_data_classes_have_contract_fields() -> void:
	var contract := {
		StatBlock: ["max_vigor", "move_speed", "attack_damage", "attack_interval", "attack_range",
				"damage_taken_mult", "pickup_radius", "exp_mult"],
		EnemyData: ["id", "display_name", "scene", "max_hp", "contact_damage", "move_speed", "exp_value"],
		CompanionData: ["id", "display_name", "scene", "role"],
		TrickData: ["id", "display_name", "description", "icon", "stat_modifiers", "is_ability"],
		LevelData: ["id", "display_name", "waves", "is_boss", "arena_scene", "companions", "background"],
		WaveData: ["spawns"],
		SpawnEntry: ["enemy_id", "count", "delay"],
	}
	for data_class: GDScript in contract:
		var instance: Resource = data_class.new()
		var names: Array = instance.get_property_list().map(func(p: Dictionary) -> String: return p["name"])
		for field: String in contract[data_class]:
			assert_true(names.has(field), "%s.%s" % [data_class.get_global_name(), field])


func test_level_data_holds_typed_waves() -> void:
	var entry := SpawnEntry.new()
	entry.enemy_id = &"scarecrow"
	entry.count = 3
	var wave := WaveData.new()
	wave.spawns.append(entry)
	var level := LevelData.new()
	level.id = &"1-1"
	level.waves.append(wave)
	assert_eq(level.waves[0].spawns[0].enemy_id, &"scarecrow")
	assert_eq(level.waves[0].spawns[0].count, 3)
