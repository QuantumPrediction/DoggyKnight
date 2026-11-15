extends "res://tests/line_b/flow_test_base.gd"
## B3 六個關卡資料與第一章的次序;以及一個粗略的「一關多久、升幾級」估算,
## 讓日後調整數字時不會不小心偏離目標(一關 60 至 90 秒、一關升 1 至 2 級)。

const LEVEL_FILES: Array[String] = [
	"res://data/levels/level_1_1.tres", "res://data/levels/level_1_2.tres", "res://data/levels/level_1_3.tres",
	"res://data/levels/level_1_4.tres", "res://data/levels/level_1_5.tres", "res://data/levels/level_1_6.tres",
]
const KNOWN_ENEMIES: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_elite", &"black_knight"]

# --- 估算用的假設(不是遊戲數值;A 線的戰鬥完成後,M3 以實際試玩時間校正) ---
## 一個普通玩家處理一隻敵人平均要幾秒(走位 + 攻擊)。金毛每 0.5 秒 10 點傷害:
## 稻草人兵 25 生命 = 3 下;烏鴉 12 生命 = 2 下但會俯衝;精英 75 生命 = 8 下;黑騎士 450 生命。
const HANDLE_SEC: Dictionary = {&"scarecrow": 2.5, &"crow": 2.0, &"scarecrow_elite": 6.0, &"black_knight": 70.0}
## 每隻敵人給的經驗(A 線的資料檔;精英暫定 3)。
const EXP_VALUE: Dictionary = {&"scarecrow": 1, &"crow": 1, &"scarecrow_elite": 3, &"black_knight": 20}
## 敵人從出生點走到金毛身邊的時間。
const APPROACH_SEC: float = 3.0
## 有同伴幫忙時處理速度的倍數。
const COMPANION_FACTOR: float = 0.85
## 黑騎士一場大約召喚幾隻小怪(每隻 1 經驗)。
const BOSS_SUMMON_EXP: int = 6


func _levels() -> Array[LevelData]:
	var result: Array[LevelData] = []
	for path in LEVEL_FILES:
		result.append(load(path) as LevelData)
	return result


func test_six_level_files_follow_the_table() -> void:
	var levels := _levels()
	var ids: Array[StringName] = [&"1-1", &"1-2", &"1-3", &"1-4", &"1-5", &"1-6"]
	var wave_counts: Array[int] = [2, 3, 3, 3, 4, 1]
	var backgrounds: Array[String] = ["sword_stone", "meadow", "meadow", "meadow", "meadow", "bridge"]
	for i in levels.size():
		var level := levels[i]
		assert_not_null(level, LEVEL_FILES[i])
		if level == null:
			continue
		assert_eq(level.id, ids[i])
		assert_eq(level.display_name, "LEVEL_1_%d" % (i + 1))
		assert_ne(tr(level.display_name), level.display_name, "i18n 有 %s" % level.display_name)
		assert_eq(level.waves.size(), wave_counts[i], "%s 的波數" % level.id)
		assert_eq(level.is_boss, i == 5)
		assert_null(level.arena_scene, "arena_scene 留空(用 game/combat/arena.tscn)")
		assert_eq(level.background.resource_path, "res://assets/backgrounds/%s.tscn" % backgrounds[i])
		var expected_companions: Array[StringName] = []
		if i >= 2:
			expected_companions.append(&"bulldog")
		assert_eq(level.companions, expected_companions, "%s 的同伴" % level.id)
		for wave in level.waves:
			assert_false(wave.spawns.is_empty())
			for entry in wave.spawns:
				assert_true(KNOWN_ENEMIES.has(entry.enemy_id), "未知的敵人 %s" % entry.enemy_id)
				assert_true(entry.count > 0 and entry.delay >= 0.0)


func test_level_contents() -> void:
	var levels := _levels()
	assert_eq(_enemy_set(levels[0]), [&"scarecrow"] as Array[StringName], "1-1 只有稻草人兵")
	assert_true(_enemy_set(levels[1]).has(&"crow"), "1-2 認識烏鴉")
	assert_eq(_enemy_set(levels[1].waves[1]), [&"crow"] as Array[StringName], "1-2 第 2 波只有烏鴉")
	assert_true(_enemy_set(levels[4]).has(&"scarecrow_elite"), "1-5 有精英稻草人兵")
	assert_false(_enemy_set(levels[4]).has(&"scarecrow"), "1-5 用精英,不用普通稻草人兵")
	var boss_wave := levels[5].waves[0]
	assert_eq(boss_wave.spawns.size(), 1)
	assert_eq(boss_wave.spawns[0].enemy_id, &"black_knight")
	assert_eq(boss_wave.spawns[0].count, 1)


func test_chapter_1_order_and_camps() -> void:
	var chapter := load(CHAPTER_1) as ChapterData
	assert_eq(chapter.level_count(), 6)
	for i in 6:
		assert_eq(chapter.get_level(i).resource_path, LEVEL_FILES[i])
	assert_eq(chapter.camp_after, [1, 3] as Array[int], "1-2 與 1-4 之後進營地")
	assert_true(chapter.is_last(5))


func test_estimated_length_and_level_ups_are_on_target() -> void:
	var curve := load(DIFFICULTY) as DifficultyData
	var hero := 1
	var progress := 0
	for level in _levels():
		var seconds := curve.first_wave_delay + curve.inter_wave_delay * (level.waves.size() - 1)
		var exp_gained := BOSS_SUMMON_EXP if level.is_boss else 0
		var factor := COMPANION_FACTOR if not level.companions.is_empty() else 1.0
		for wave in level.waves:
			var spawn_end := 0.0
			var work := 0.0
			for entry in wave.spawns:
				spawn_end = maxf(spawn_end, entry.delay + (entry.count - 1) * curve.spawn_spacing)
				work += entry.count * float(HANDLE_SEC[entry.enemy_id])
				exp_gained += entry.count * int(EXP_VALUE[entry.enemy_id])
			seconds += maxf(spawn_end, work * factor) + APPROACH_SEC
		progress += exp_gained
		var ups := 0
		while progress >= curve.exp_to_next(hero):
			progress -= curve.exp_to_next(hero)
			hero += 1
			ups += 1
		print("    %s  估計 %.0f 秒  經驗 %d  升 %d 級 → 第 %d 級" % [level.id, seconds, exp_gained, ups, hero])
		# 關卡長度改由 tests/integration/playthrough_bot.tscn 以正式戰鬥量度(這個估算沒有真實戰鬥,M2 時比實際短約三成),這裡只印出參考。
		assert_true(ups >= 1 and ups <= 2, "%s 估計升 %d 級,目標 1 至 2 級" % [level.id, ups])


func _enemy_set(source: Resource) -> Array[StringName]:
	var result: Array[StringName] = []
	var waves: Array = (source as LevelData).waves if source is LevelData else [source]
	for wave: WaveData in waves:
		for entry in wave.spawns:
			if not result.has(entry.enemy_id):
				result.append(entry.enemy_id)
	return result
