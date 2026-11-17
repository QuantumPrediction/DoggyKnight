extends "res://tests/line_b/flow_test_base.gd"
## v2.6 BV1(DEV_PLAN 第 19 節的關卡表、4.13):第二、三章的 12 關資料。
## 新敵人(A 線同時在做)的 data/enemies/<id>.tres 可能還沒合併:資料檔不存在時只略過「資料檔要對得上」
## 的檢查並印出訊息,其餘(關卡表、教學次序、難度遞增、星級目標)照樣檢查。整合工作階段合併後再確認。

## 每一關:[id, 背景, 同伴, 主要敵人(一定出現), 波數]
const TABLE: Array = [
	["2-1", "castle_town", [&"bulldog"], [&"gargoyle", &"scarecrow", &"crow"], 3],
	["2-2", "castle_courtyard", [&"bulldog"], [&"gargoyle", &"armored_husk", &"scarecrow_archer"], 3],
	["2-3", "royal_library", [&"bulldog", &"lancelot"], [&"spellbook", &"gargoyle"], 3],
	["2-4", "castle_wall", [&"bulldog", &"lancelot"], [&"gargoyle_elite", &"scarecrow_archer"], 3],
	["2-5", "magic_garden", [&"bulldog", &"lancelot"], [&"spellbook", &"gargoyle", &"scarecrow_elite"], 4],
	["2-6", "green_chapel", [&"bulldog", &"lancelot"], [&"green_knight"], 1],
	["3-1", "misty_lake", [&"bulldog", &"lancelot"], [&"foxfire", &"crow"], 3],
	["3-2", "fairy_forest", [&"bulldog", &"lancelot"], [&"shadow_wolf", &"foxfire"], 3],
	["3-3", "stone_circle", [&"bulldog", &"lancelot"], [&"shadow_wolf", &"spellbook", &"gargoyle"], 3],
	["3-4", "crystal_cave", [&"bulldog", &"lancelot"], [&"phantom_knight", &"foxfire"], 3],
	["3-5", "morgana_tower", [&"bulldog", &"lancelot"], [&"gargoyle", &"spellbook", &"foxfire", &"shadow_wolf"], 4],
	["3-6", "tower_top", [&"bulldog", &"lancelot"], [&"morgana"], 1],
]
const CHAPTER_1_ENEMIES: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_elite", &"black_knight",
		&"scarecrow_archer", &"armored_husk", &"scarecrow_captain"]
## 新的小怪:第一次出現的那一波只有它自己(先教學,再混合)。
const NEW_REGULARS: Array[StringName] = [&"gargoyle", &"spellbook", &"foxfire", &"shadow_wolf"]
const MID_BOSSES: Dictionary = {"2-4": &"gargoyle_elite", "3-4": &"phantom_knight"}
const BOSSES: Dictionary = {"2-6": &"green_knight", "3-6": &"morgana"}
const KNOWN_ENEMIES: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_elite", &"black_knight",
		&"scarecrow_archer", &"armored_husk", &"scarecrow_captain", &"gargoyle", &"gargoyle_elite", &"spellbook",
		&"foxfire", &"shadow_wolf", &"phantom_knight", &"green_knight", &"morgana"]

# --- 估算用的假設(同 test_level_data.gd;新敵人用 DEV_PLAN 第 19 節 A 線任務的描述推算,
#     A 線的資料合併後,以 tests/integration/playthrough_bot.tscn 的實際量度校正) ---
## 處理一隻敵人平均要幾秒(第一章的值見 test_level_data.gd)。
## 石像鬼:生命約烏鴉 2.5 倍、會變石頭(要等);魔法書:保持距離、要追;狐火:一下打倒;
## 影狼:成群繞圈、衝鋒;石像鬼統領:中頭目(會召喚 2 隻石像鬼);幻影黑騎士:黑騎士的 60% 生命。
const HANDLE_SEC: Dictionary = {&"scarecrow": 2.5, &"crow": 2.0, &"scarecrow_elite": 6.0, &"black_knight": 70.0,
		&"scarecrow_archer": 3.0, &"armored_husk": 6.0, &"scarecrow_captain": 25.0,
		&"gargoyle": 4.0, &"spellbook": 3.5, &"foxfire": 1.0, &"shadow_wolf": 3.5, &"gargoyle_elite": 28.0,
		&"phantom_knight": 40.0, &"green_knight": 80.0, &"morgana": 90.0}
## 每隻敵人給的經驗(假設;A 線的資料檔合併後以資料檔為準)。
const EXP_VALUE: Dictionary = {&"scarecrow": 1, &"crow": 1, &"scarecrow_elite": 3, &"black_knight": 20,
		&"scarecrow_archer": 2, &"armored_husk": 4, &"scarecrow_captain": 12,
		&"gargoyle": 2, &"spellbook": 2, &"foxfire": 1, &"shadow_wolf": 2, &"gargoyle_elite": 12,
		&"phantom_knight": 16, &"green_knight": 22, &"morgana": 25}
## 中頭目與頭目一場大約召喚多少經驗的小怪。
const SUMMON_EXP: Dictionary = {&"scarecrow_captain": 6, &"gargoyle_elite": 4, &"black_knight": 6,
		&"green_knight": 4, &"morgana": 4}
const APPROACH_SEC: float = 3.0
const COMPANION_FACTOR: float = 0.85
## 兩位同伴(貝德維爾 + 蘭斯洛特)。
const TWO_COMPANION_FACTOR: float = 0.75


func _chapter(n: int) -> ChapterData:
	return load(CHAPTER_PATH % n) as ChapterData


func _new_levels() -> Array[LevelData]:
	var result: Array[LevelData] = []
	for n in [2, 3]:
		result.append_array(_chapter(n).levels)
	return result


func _enemy_set(waves: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for wave: WaveData in waves:
		for entry in wave.spawns:
			if not result.has(entry.enemy_id):
				result.append(entry.enemy_id)
	return result


func test_chapter_files() -> void:
	for n in [1, 2, 3]:
		var chapter := _chapter(n)
		assert_not_null(chapter, "chapter_%d.tres" % n)
		if chapter == null:
			continue
		assert_eq(chapter.number, n)
		assert_eq(chapter.display_name, "CHAPTER_%d" % n)
		assert_ne(tr(chapter.display_name), chapter.display_name, "章名有翻譯")
		# BV6:結算與章節進度不寫死「第一章」(C 線可以用 tr("UI_CHAPTER_PROGRESS_ANY") % [tr("CHAPTER_SHORT_N"), …])
		assert_ne(tr("CHAPTER_SHORT_%d" % n), "CHAPTER_SHORT_%d" % n, "短章名")
		assert_eq(chapter.level_count(), 6, "每章 6 關")
		assert_eq(chapter.camp_after, [1, 3] as Array[int], "每章 2 次營地(第 2、4 關之後)")
		for m in 6:
			var level := chapter.get_level(m)
			assert_eq(level.resource_path, "res://data/levels/level_%d_%d.tres" % [n, m + 1])
			assert_eq(level.id, StringName("%d-%d" % [n, m + 1]))
		assert_true(chapter.is_last(5))
		assert_true(chapter.get_level(5).is_boss, "頭目在 -6")
	assert_eq(_chapter(1).field_music, &"field")
	assert_eq(_chapter(1).boss_music, &"boss")
	assert_eq(_chapter(2).field_music, &"field_2")
	assert_eq(_chapter(2).boss_music, &"boss_2")
	assert_eq(_chapter(3).field_music, &"field_3")
	assert_eq(_chapter(3).boss_music, &"boss_3")
	for key: String in ["UI_CHAPTER_PROGRESS_ANY", "UI_CHAPTER_CLEARED_ANY", "UI_CHAPTER_UNLOCKED"]:
		assert_ne(tr(key), key, "%s 有翻譯" % key)
	assert_eq(tr("UI_CHAPTER_PROGRESS_ANY") % [tr("CHAPTER_SHORT_2"), 3, 6], "第二章 3/6")


func test_levels_follow_the_table() -> void:
	var levels := _new_levels()
	assert_eq(levels.size(), TABLE.size())
	for i in levels.size():
		var level := levels[i]
		var row: Array = TABLE[i]
		var id := String(row[0])
		var parts := id.split("-")
		assert_eq(level.id, StringName(id))
		assert_eq(level.display_name, "LEVEL_%s_%s" % [parts[0], parts[1]])
		assert_ne(tr(level.display_name), level.display_name, "i18n 有 %s" % level.display_name)
		assert_eq(level.background.resource_path, "res://assets/backgrounds/%s.tscn" % row[1], "%s 的背景" % id)
		assert_null(level.arena_scene, "arena_scene 留空(用 game/combat/arena.tscn)")
		var companions: Array[StringName] = []
		companions.assign(row[2])
		assert_eq(level.companions, companions, "%s 的同伴" % id)
		assert_eq(level.waves.size(), int(row[4]), "%s 的波數" % id)
		assert_eq(level.is_boss, parts[1] == "6", "%s 頭目關" % id)
		var music := ("boss_%s" if level.is_boss else "field_%s") % parts[0]
		assert_eq(level.music, StringName(music), "%s 的音樂" % id)
		var enemies := _enemy_set(level.waves)
		for kind: StringName in row[3]:
			assert_true(enemies.has(kind), "%s 有 %s" % [id, kind])
		for wave in level.waves:
			assert_false(wave.spawns.is_empty())
			for entry in wave.spawns:
				assert_true(KNOWN_ENEMIES.has(entry.enemy_id), "%s:未知的敵人 %s" % [id, entry.enemy_id])
				assert_true(entry.count > 0 and entry.delay >= 0.0)
				assert_true(WaveSpawner.PATTERNS.has(entry.pattern), "%s 的隊形 %s" % [id, entry.pattern])


func test_bosses_and_mid_bosses_are_where_the_contract_says() -> void:
	for level in _new_levels():
		var id := String(level.id)
		for wave_index in level.waves.size():
			var wave := level.waves[wave_index]
			for entry in wave.spawns:
				var kind := entry.enemy_id
				if MID_BOSSES.values().has(kind):
					assert_eq(MID_BOSSES.get(id, &""), kind, "%s 只在 %s" % [kind, MID_BOSSES.find_key(kind)])
					assert_eq(wave_index, level.waves.size() - 1, "%s 的中頭目在最後一波" % id)
					assert_eq(entry.count, 1)
				if BOSSES.values().has(kind) or kind == &"black_knight":
					assert_eq(BOSSES.get(id, &""), kind, "%s 只在 %s" % [kind, BOSSES.find_key(kind)])
	for id: String in BOSSES:
		var level := _find(id)
		assert_eq(level.waves.size(), 1, "%s 只有頭目那一波" % id)
		assert_eq(level.waves[0].spawns.size(), 1)
		assert_eq(level.waves[0].spawns[0].enemy_id, BOSSES[id])
		assert_eq(level.waves[0].spawns[0].count, 1)
	var difficulty := load(DIFFICULTY) as DifficultyData
	for kind: StringName in MID_BOSSES.values() + BOSSES.values():
		assert_true(difficulty.boss_music_enemies.has(kind), "%s 那一波播頭目曲" % kind)
		assert_true(difficulty.hard_extra_exempt.has(kind), "困難模式不會多出 %s" % kind)


func test_each_new_enemy_is_taught_alone_before_mixing() -> void:
	var seen: Array[StringName] = CHAPTER_1_ENEMIES.duplicate()
	for level in _new_levels():
		for wave_index in level.waves.size():
			var kinds := _enemy_set([level.waves[wave_index]])
			var fresh: Array[StringName] = []
			for kind in kinds:
				if not seen.has(kind) and NEW_REGULARS.has(kind):
					fresh.append(kind)
			for kind in fresh:
				assert_eq(kinds, [kind] as Array[StringName],
						"%s 第一次出現(%s 第 %d 波)時只有它自己" % [kind, level.id, wave_index + 1])
				assert_eq(wave_index, 0, "%s 在 %s 的第 1 波教學" % [kind, level.id])
			for kind in kinds:
				if not seen.has(kind):
					seen.append(kind)
	for kind in NEW_REGULARS:
		assert_true(seen.has(kind), "會出現 %s" % kind)
	# 教學那一關之後的關卡才混合(主要敵人表):2-1 石像鬼、2-3 魔法書、3-1 狐火、3-2 影狼
	var teach: Dictionary = {&"gargoyle": &"2-1", &"spellbook": &"2-3", &"foxfire": &"3-1", &"shadow_wolf": &"3-2"}
	for kind: StringName in teach:
		var level := _find(String(teach[kind]))
		assert_eq(_enemy_set([level.waves[0]]), [kind] as Array[StringName], "%s 在 %s 教學" % [kind, level.id])
		assert_true(_enemy_set(level.waves.slice(1)).size() > 1, "%s 之後的波混合" % level.id)


func test_chapters_ramp_and_3_5_is_the_hardest_normal_level() -> void:
	var hardest_id := &""
	var hardest := 0.0
	for n in [1, 2, 3]:
		var previous := -1.0
		for level in _chapter(n).levels:
			var work := _work(level)
			print("    %s  工作量 %.0f 秒  敵人 %d 隻" % [level.id, work, _count(level)])
			if level.is_boss:
				continue
			if not level.id.ends_with("-1"):
				assert_true(work >= previous * 0.9, "%s 不比上一關容易太多(%.0f / %.0f)" % [level.id, work, previous])
			previous = work
			if work > hardest:
				hardest = work
				hardest_id = level.id
	assert_eq(hardest_id, &"3-5", "3-5 是最難的一般關")
	for n in [2, 3]:
		var first := _work(_chapter(n).get_level(0))
		var fifth := _work(_chapter(n).get_level(4))
		assert_true(fifth > first * 1.3, "第 %d 章逐關變難(%.0f → %.0f)" % [n, first, fifth])


func test_star_goals_are_sensible() -> void:
	# par_time 與估計時間的比例,要落在第一章(已經用試玩機器人校正過)的範圍之內。
	var low := INF
	var high := 0.0
	for level in _chapter(1).levels:
		if not level.is_boss:
			var ratio := level.par_time / _estimated_seconds(level)
			low = minf(low, ratio)
			high = maxf(high, ratio)
	for n in [2, 3]:
		var chapter := _chapter(n)
		var reference := _chapter(1)
		var previous_budget := 0
		for m in 6:
			var level := chapter.get_level(m)
			assert_true(level.par_time >= 55.0 and level.par_time <= 100.0, "%s 的 par_time %.0f 在 55 至 100 秒" % [
					level.id, level.par_time])
			assert_true(level.damage_budget >= 16 and level.damage_budget <= 60, "%s 的 damage_budget %d" % [
					level.id, level.damage_budget])
			# 每章的敵人傷害較高(A 線 chapter_damage_mult 1.2、1.4):預算不比第一章同一關少。
			assert_true(level.damage_budget >= reference.get_level(m).damage_budget,
					"%s 的 damage_budget 不少於 1-%d" % [level.id, m + 1])
			if not level.is_boss:
				assert_true(level.damage_budget >= previous_budget, "%s 的 damage_budget 逐關不減" % level.id)
				previous_budget = level.damage_budget
				var ratio := level.par_time / _estimated_seconds(level)
				assert_true(ratio >= low * 0.9 and ratio <= high * 1.1,
						"%s 的 par_time %.0f ÷ 估計 %.0f 秒 = %.2f,第一章是 %.2f 至 %.2f" % [
						level.id, level.par_time, _estimated_seconds(level), ratio, low, high])


func test_estimated_level_ups_per_chapter() -> void:
	var curve := load(DIFFICULTY) as DifficultyData
	for n in [2, 3]:
		var hero := 1          # 每章是獨立的一輪:等級 1 開始
		var progress := 0
		for level in _chapter(n).levels:
			var exp_gained := 0
			for wave in level.waves:
				for entry in wave.spawns:
					exp_gained += entry.count * int(EXP_VALUE[entry.enemy_id])
					exp_gained += int(SUMMON_EXP.get(entry.enemy_id, 0))
			progress += exp_gained
			var ups := 0
			while progress >= curve.exp_to_next(hero):
				progress -= curve.exp_to_next(hero)
				hero += 1
				ups += 1
			print("    %s  經驗 %d  升 %d 級 → 第 %d 級" % [level.id, exp_gained, ups, hero])
			var fewest := 0 if level.is_boss else 1
			assert_true(ups >= fewest and ups <= 2, "%s 估計升 %d 級,目標 %d 至 2 級" % [level.id, ups, fewest])


## A 線的敵人資料檔:存在就要對得上 id;不存在(A 線還在做)就略過並印出訊息。
func test_enemy_data_files_match_when_present() -> void:
	var missing: Array[StringName] = []
	for level in _new_levels():
		for kind in _enemy_set(level.waves):
			var path := "res://data/enemies/%s.tres" % kind
			if not ResourceLoader.exists(path):
				if not missing.has(kind):
					missing.append(kind)
				continue
			var data := load(path) as EnemyData
			assert_not_null(data, "%s 是 EnemyData" % path)
			if data != null:
				assert_eq(data.id, kind, "%s 的 id" % path)
				assert_true(data.max_hp > 0, "%s 有生命" % path)
	if not missing.is_empty():
		print("    略過(A 線的資料檔還沒合併,整合後再確認):%s" % ", ".join(missing))
	var lancelot := "res://data/companions/lancelot.tres"
	if ResourceLoader.exists(lancelot):
		assert_not_null(load(lancelot) as CompanionData, "lancelot 是 CompanionData")
	else:
		print("    略過:data/companions/lancelot.tres 還沒合併(A 線)")


func _find(id: String) -> LevelData:
	for level in _new_levels():
		if level.id == StringName(id):
			return level
	return null


func _count(level: LevelData) -> int:
	var total := 0
	for wave in level.waves:
		for entry in wave.spawns:
			total += entry.count
	return total


## 估計的過關秒數(含開場標題卡與波間休息)。
func _estimated_seconds(level: LevelData) -> float:
	var curve := load(DIFFICULTY) as DifficultyData
	return curve.intro_duration + curve.inter_wave_delay * (level.waves.size() - 1) + _work(level)


## 估計的戰鬥秒數:每波 max(出場完的時間, 處理所有敵人的時間) + 走近的時間;有同伴時快一點。
func _work(level: LevelData) -> float:
	var curve := load(DIFFICULTY) as DifficultyData
	var factor := 1.0
	if level.companions.size() >= 2:
		factor = TWO_COMPANION_FACTOR
	elif level.companions.size() == 1:
		factor = COMPANION_FACTOR
	var seconds := 0.0
	for wave in level.waves:
		var spawn_end := 0.0
		var work := 0.0
		for entry in wave.spawns:
			spawn_end = maxf(spawn_end, entry.delay + (entry.count - 1) * curve.spawn_spacing)
			work += entry.count * float(HANDLE_SEC[entry.enemy_id])
		seconds += maxf(spawn_end, work * factor) + APPROACH_SEC
	return seconds
