class_name EndlessWaves
extends RefCounted
## 無盡試煉的波次產生器(v2.4 BV6)。參數在 data/levels/endless.tres(EndlessData)。
##
## make_level():產生一個 LevelData(id &"endless"、隨機背景、同伴),先放第 1 波。
## 之後每一波開始時,FlowMain 呼叫 append_next(level),把下一波加到 level.waves 的最後,
## 所以 WaveSpawner 永遠有下一波可以放(它在一波清空時才看還有沒有下一波)。
## 同一個種子永遠產生同一串波次(測試用)。
## v2.6(BV5):tier = 已打完的章數(GameState.chapters_cleared,至少 1);只用 tier 以內各章的敵人、
## 頭目與背景(EndlessData.enemy_chapter 等)。

var data: EndlessData
var rng: RandomNumberGenerator
var tier: int = 1


func _init(endless: EndlessData, random: RandomNumberGenerator, chapters_cleared: int = 1) -> void:
	data = endless
	rng = random
	tier = maxi(1, chapters_cleared)


func make_level() -> LevelData:
	var level := LevelData.new()
	level.id = data.level_id
	level.display_name = data.display_name
	level.is_boss = false
	level.companions = data.companions.duplicate()
	var backgrounds := data.backgrounds_for(tier)
	if not backgrounds.is_empty():
		level.background = backgrounds[rng.randi_range(0, backgrounds.size() - 1)]
	level.par_time = 0.0
	level.damage_budget = 0
	level.waves.append(make_wave(1))
	return level


## 確保 level.waves 至少有 wave_count 波。
func ensure_waves(level: LevelData, wave_count: int) -> void:
	while level.waves.size() < wave_count:
		level.waves.append(make_wave(level.waves.size() + 1))


func append_next(level: LevelData) -> void:
	level.waves.append(make_wave(level.waves.size() + 1))


## 第 wave 波(1 起算)。
func make_wave(wave: int) -> WaveData:
	var result := WaveData.new()
	var budget := data.budget_for(wave)
	var boss := data.boss_for_wave(wave, tier)
	if boss != &"":
		result.spawns.append(_entry(boss, 1, 0.0, &"edges"))
		var escort := 0.0
		if not data.is_main_boss_wave(wave) or wave >= data.boss_escort_from:
			escort = budget * data.escort_ratio
		_fill(result, wave, escort, 3.0)
		return result
	_fill(result, wave, budget, 0.0)
	return result


## 用 budget 買敵人,分組放進 wave(第一組在 start_delay 秒)。
func _fill(wave_data: WaveData, wave: int, budget: float, start_delay: float) -> void:
	var unlocked := _unlocked(wave)
	if unlocked.is_empty() or budget < 1.0:
		return
	var picks: Array[StringName] = []
	var remaining := budget
	# 這一波新解鎖的敵人一定出現。
	for i in data.enemy_ids.size():
		if i < data.enemy_unlock_wave.size() and data.enemy_unlock_wave[i] == wave and _in_tier(i):
			picks.append(data.enemy_ids[i])
			remaining -= float(_cost(i))
	var guard := 0
	while remaining >= 1.0 and picks.size() < data.max_enemies_per_wave and guard < 200:
		guard += 1
		var index := _weighted_pick(unlocked, remaining)
		if index < 0:
			break
		picks.append(data.enemy_ids[index])
		remaining -= float(_cost(index))
	if picks.is_empty():
		return
	var group_count := clampi(rng.randi_range(data.groups_min, data.groups_max), 1, picks.size())
	# 同一種敵人放在同一組(隊形比較整齊);依抽到的次序分成 group_count 組。
	var by_type: Dictionary = {}
	var type_order: Array[StringName] = []
	for id in picks:
		if not by_type.has(id):
			by_type[id] = 0
			type_order.append(id)
		by_type[id] = int(by_type[id]) + 1
	var groups: Array[Dictionary] = []
	for g in group_count:
		groups.append({})
	var slot := 0
	for id in type_order:
		var count: int = by_type[id]
		# 數目多的種類拆到兩組,讓每組不會太擠。
		var parts := 2 if count >= 6 and group_count > 1 else 1
		@warning_ignore("integer_division")
		var first := count / parts
		var amounts := [count] if parts == 1 else [first, count - first]
		for amount: int in amounts:
			var group: Dictionary = groups[slot % group_count]
			group[id] = int(group.get(id, 0)) + amount
			slot += 1
	for g in group_count:
		var delay := start_delay + float(g) * data.group_gap
		for id: StringName in groups[g]:
			wave_data.spawns.append(_entry(id, groups[g][id], delay, _pattern(wave)))


func _unlocked(wave: int) -> Array[int]:
	var result: Array[int] = []
	for i in data.enemy_ids.size():
		var unlock := data.enemy_unlock_wave[i] if i < data.enemy_unlock_wave.size() else 1
		if wave >= unlock and _in_tier(i):
			result.append(i)
	return result


func _in_tier(index: int) -> bool:
	return data.enemy_chapter_of(index) <= tier


func _cost(index: int) -> int:
	return maxi(1, data.enemy_costs[index] if index < data.enemy_costs.size() else 1)


func _weighted_pick(candidates: Array[int], remaining: float) -> int:
	var total := 0.0
	var affordable: Array[int] = []
	for i in candidates:
		if float(_cost(i)) <= remaining + 0.001:
			affordable.append(i)
			total += _weight(i)
	if affordable.is_empty() or total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in affordable:
		roll -= _weight(i)
		if roll <= 0.0:
			return i
	return affordable[-1]


func _weight(index: int) -> float:
	return maxf(0.0, data.enemy_weights[index] if index < data.enemy_weights.size() else 1.0)


func _pattern(wave: int) -> StringName:
	var options: Array[StringName] = []
	for p in data.patterns:
		if p == &"surround" and wave < data.surround_from_wave:
			continue
		options.append(p)
	if options.is_empty():
		return &"edges"
	return options[rng.randi_range(0, options.size() - 1)]


func _entry(enemy_id: StringName, count: int, delay: float, pattern: StringName) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.enemy_id = enemy_id
	entry.count = count
	entry.delay = delay
	entry.pattern = pattern
	return entry
