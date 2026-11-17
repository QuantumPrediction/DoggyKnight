extends TestCase
## GameState(DEV_PLAN 4.2)與資料類別(4.3)。


func after_each() -> void:
	GameState.reset_run()
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
	Haptics.reset_for_tests()


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
		TrickData: ["id", "display_name", "description", "icon", "stat_modifiers", "is_ability", "max_level",
				"evolution_partner", "evolves_into", "is_evolution"],
		LevelData: ["id", "display_name", "waves", "is_boss", "arena_scene", "companions", "background", "par_time", "damage_budget",
				"story_before", "story_after"],
		DialogueLine: ["speaker", "expression", "text_key", "illustration"],
		DialogueScript: ["id", "lines", "skippable"],
		WaveData: ["spawns"],
		SpawnEntry: ["enemy_id", "count", "delay", "pattern"],
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


func test_reset_run_keeps_v22_settings_and_records() -> void:
	GameState.music_on = false
	GameState.haptics_on = false
	GameState.tutorial_done = true
	GameState.best_stars = {&"1-1": 3}
	GameState.reset_run()
	assert_false(GameState.music_on, "音樂開關屬於設定")
	assert_false(GameState.haptics_on, "震動開關屬於設定")
	assert_true(GameState.tutorial_done, "教學紀錄屬於存檔")
	assert_eq(GameState.best_stars.get(&"1-1"), 3, "最佳星數屬於存檔")


func test_spawn_entry_default_pattern() -> void:
	assert_eq(SpawnEntry.new().pattern, &"edges")


func test_haptics_respects_setting_and_merges_bursts() -> void:
	Haptics.reset_for_tests()
	Haptics.play(&"medium")
	assert_eq(Haptics.play_count, 1)
	assert_eq(Haptics.last_kind, &"medium")
	Haptics.play(&"heavy")
	assert_eq(Haptics.play_count, 1, "60 毫秒內的連續震動會被合併")
	Haptics.reset_for_tests()
	GameState.haptics_on = false
	Haptics.play(&"heavy")
	assert_eq(Haptics.play_count, 0, "關掉震動就不震")


func test_reset_run_keeps_v23_progress() -> void:
	GameState.difficulty = &"hard"
	GameState.chapter_cleared = true
	GameState.story_seen = {&"prologue": true}
	GameState.reset_run()
	assert_eq(GameState.difficulty, &"hard", "難度屬於存檔")
	assert_true(GameState.chapter_cleared, "通關紀錄屬於存檔")
	assert_true(GameState.story_seen.has(&"prologue"), "看過的對白屬於存檔")


func test_reset_run_keeps_v24_meta_progress() -> void:
	GameState.meta_upgrades = {&"strength": 2}
	GameState.endless_best = 12
	GameState.reset_run()
	assert_eq(GameState.meta_upgrades.get(&"strength"), 2, "營地訓練屬於存檔")
	assert_eq(GameState.endless_best, 12, "無盡試煉紀錄屬於存檔")
