class_name RunProgression
extends Node
## 一輪冒險之中的經驗、升級與把戲(B4、B5;v2.4 BV1、BV3、BV5)。由 FlowMain 擁有,跨關保留。
##
## - 聽 EventBus.exp_collected(原始值),乘上 GameState.player_stats.exp_mult 後累計。
## - 達到門檻:GameState.hero_level +1,發 leveled_up(新等級)、播 Sfx level_up、手機震動 medium。
##   一次升好幾級時,每級各發一次 leveled_up,把戲選擇排隊逐次出現。
## - 要給玩家選把戲時發出本地訊號 choice_opened(FlowMain 據此暫停遊戲),
##   然後發 EventBus.trick_offered(Array[TrickData])。寶箱與抉擇事件也可以排一次選擇(offer_bonus_choice)。
## - 收到 EventBus.trick_chosen:把 id 加進 GameState.active_tricks,數值類把戲修改
##   GameState.player_stats;還有排隊的選擇就再出一次,否則發 choice_closed(繼續遊戲)。
## - 進化(v2.4,TrickDeck):選了進化把戲 → 兩個來源從 active_tricks 全部移除、換成進化把戲,
##   數值重新計算(rebuild_stats),然後發 EventBus.trick_evolved(進化 id)。
##   順序:C 線的介面發 trick_chosen(進化 id)→ 這裡改好 active_tricks → trick_evolved。
## - 抉擇事件的「下一個把戲升兩級」:bonus_trick_levels > 0 時,下一個選的基本把戲多加幾份
##   (不超過 max_level);active_tricks 會出現多份同一個 id。
##
## 數值(rebuild_stats):基準數值 → 營地訓練(MetaUpgradeTable)→ 每個 active_tricks 的 stat_modifiers
## → 這一輪抉擇事件的數值(run_modifiers),都是相加、以基準值計算。新遊戲、每關開始與進化時重算;
## 平常選數值把戲時只把那一個加上去(結果相同)。
##
## 下一次選擇用 call_deferred 發出:介面在發出 trick_chosen 之後通常會把自己藏起來,
## 如果同一刻就送出下一組選擇,介面會在顯示之後立即被自己藏起來。

signal choice_opened()
signal choice_closed()

var difficulty: DifficultyData
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 營地訓練(留空 = 不套用)。
var meta: MetaUpgradeTable
## 只有在關卡進行中才計算經驗(結算、營地、標題時收到的經驗不算)。
var accepting_exp: bool = false
## 這一關新學的把戲 id(依選擇次序,同一個把戲可出現多次;進化把戲也會記)。結算用。
var tricks_this_level: Array[StringName] = []
## 這一輪抉擇事件給的數值加成(每項是 stat_modifiers 格式的 Dictionary)。
var run_modifiers: Array[Dictionary] = []
## 下一個選的基本把戲多加幾級(抉擇事件)。
var bonus_trick_levels: int = 0

var _exp: HeroExperience
var _deck: TrickDeck
var _pending_choices: int = 0
var _choice_open: bool = false
var _current_offer: Array[TrickData] = []


func setup(curve: DifficultyData, rng_seed: int = 0, meta_table: MetaUpgradeTable = null) -> void:
	difficulty = curve
	meta = meta_table
	_deck = TrickDeck.new(difficulty.trick_pool)
	_deck.owned_weight = difficulty.owned_trick_weight
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_exp = HeroExperience.new(difficulty, GameState.hero_level)


func _enter_tree() -> void:
	EventBus.exp_collected.connect(_on_exp_collected)
	EventBus.trick_chosen.connect(_on_trick_chosen)


func _exit_tree() -> void:
	EventBus.exp_collected.disconnect(_on_exp_collected)
	EventBus.trick_chosen.disconnect(_on_trick_chosen)


## 新的一輪(新遊戲或「繼續」):經驗歸零,等級跟隨 GameState.hero_level;事件加成清空。
func reset_run() -> void:
	cancel_choices()
	GameState.run_route = &""
	# Rebuild the offer pool for the selected weapon; pounce is melee-only.
	var pool: Array[StringName] = difficulty.trick_pool.duplicate()
	if GameState.hero_class != &"knight":
		pool.erase(&"pounce")
	_deck = TrickDeck.new(pool)
	_deck.owned_weight = difficulty.owned_trick_weight
	_exp.set_state(GameState.hero_level, 0)
	tricks_this_level.clear()
	run_modifiers.clear()
	bonus_trick_levels = 0


## 關卡開始:清空這一關的把戲記錄,並讓 HUD 拿到經驗的初始值。
func begin_level() -> void:
	cancel_choices()
	tricks_this_level.clear()
	accepting_exp = true
	emit_exp_changed()


## 復活後回到戰鬥(不清空這一關的記錄)。
func resume_level() -> void:
	accepting_exp = true
	emit_exp_changed()


func end_level() -> void:
	accepting_exp = false
	cancel_choices()


func is_choice_open() -> bool:
	return _choice_open


func get_current_offer() -> Array[TrickData]:
	return _current_offer.duplicate()


func get_exp() -> int:
	return _exp.current()


func get_exp_needed() -> int:
	return _exp.needed()


func get_deck() -> TrickDeck:
	return _deck


func emit_exp_changed() -> void:
	EventBus.exp_changed.emit(_exp.current(), _exp.needed())


## 關卡開始時的快照,失敗重試時還原(數值、把戲、等級、經驗、事件加成)。
## next_level_bonus 不在快照內:重試時保持原值(DEV_PLAN 4.9:失敗重試時保留)。零食也不還原。
func take_snapshot() -> Dictionary:
	return {
		"route": GameState.run_route,
		"stats": GameState.player_stats.duplicate(),
		"tricks": GameState.active_tricks.duplicate(),
		"hero_level": GameState.hero_level,
		"exp_centi": _exp.get_centi(),
		"run_modifiers": run_modifiers.duplicate(true),
		"bonus_trick_levels": bonus_trick_levels,
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	cancel_choices()
	GameState.run_route = BuildRoutes.valid_id(snapshot.get("route", ""), GameState.hero_class)
	GameState.player_stats = (snapshot["stats"] as StatBlock).duplicate() as StatBlock
	GameState.active_tricks.assign(snapshot["tricks"] as Array)
	GameState.hero_level = snapshot["hero_level"]
	_exp.set_state(GameState.hero_level, snapshot["exp_centi"])
	run_modifiers.assign(snapshot.get("run_modifiers", []) as Array)
	bonus_trick_levels = int(snapshot.get("bonus_trick_levels", 0))


## 由頭計算金毛的數值:基準 → 營地訓練 → 把戲 → 事件加成。寫回現有的 GameState.player_stats
## (同一個物件,別線拿著它也看得到新數值);活力超過新的上限時降到上限。
func rebuild_stats() -> void:
	var base := GameState.base_stats()
	var stats := base.duplicate() as StatBlock
	if meta != null:
		meta.apply_to(stats, base)
	TrickDeck.apply_modifiers(stats, base, EquipmentInventory.bonuses(GameState.run_equipment, String(GameState.hero_class)).mods, difficulty.min_damage_taken_mult)
	var route := BuildRoutes.get_route(GameState.run_route)
	if route != null and route.hero == GameState.hero_class:
		TrickDeck.apply_modifiers(stats, base, route.modifiers, difficulty.min_damage_taken_mult)
	for id in GameState.active_tricks:
		var trick := _find_trick(id)
		if trick != null and not trick.stat_modifiers.is_empty():
			TrickDeck.apply_modifiers(stats, base, trick.stat_modifiers, difficulty.min_damage_taken_mult)
	for mods in run_modifiers:
		TrickDeck.apply_modifiers(stats, base, mods, difficulty.min_damage_taken_mult)
	if GameState.player_stats == null:
		GameState.player_stats = stats
	else:
		for prop in stats.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				GameState.player_stats.set(prop["name"], stats.get(prop["name"]))
	clamp_vigor()


## 活力不超過上限(上限變小時);有改變就發 vigor_changed 讓 HUD 更新。
func clamp_vigor() -> void:
	var maximum := GameState.player_stats.max_vigor
	if GameState.vigor > maximum:
		GameState.vigor = maximum
		EventBus.vigor_changed.emit(GameState.vigor, maximum)


## 抉擇事件:這一輪的數值加成(stat_modifiers 格式)。
func add_run_modifier(mods: Dictionary) -> void:
	if mods.is_empty():
		return
	run_modifiers.append(mods.duplicate(true))
	TrickDeck.apply_modifiers(GameState.player_stats, GameState.base_stats(), mods, difficulty.min_damage_taken_mult)
	GameState.vigor = mini(GameState.vigor, GameState.player_stats.max_vigor)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)   # 上限可能改了


func choose_route(id: StringName) -> bool:
	if not accepting_exp or _choice_open or GameState.run_route != &"":
		return false
	var route := BuildRoutes.get_route(BuildRoutes.valid_id(id, GameState.hero_class))
	if route == null:
		return false
	GameState.run_route = route.id
	# This grant is exactly one level and does not spend a queued event bonus.
	if _deck.available(GameState.active_tricks).has(route.starter):
		var saved_bonus := bonus_trick_levels
		bonus_trick_levels = 0
		apply_trick(_deck.get_trick(route.starter))
		bonus_trick_levels = saved_bonus
		tricks_this_level.append(route.starter)
		EventBus.trick_chosen.emit(route.starter)
	rebuild_stats()
	return true

## 套用一個把戲(數值類改 player_stats;能力類只記錄,由 A 線執行;進化把戲換掉兩個來源)。
func apply_trick(trick: TrickData) -> void:
	if trick.is_evolution:
		_evolve(trick)
		return
	var copies := 1 + maxi(0, bonus_trick_levels)
	bonus_trick_levels = 0
	for i in copies:
		if i > 0 and trick.max_level > 0 and TrickDeck.count_in(GameState.active_tricks, trick.id) >= trick.max_level:
			break
		GameState.active_tricks.append(trick.id)
		if not trick.stat_modifiers.is_empty():
			TrickDeck.apply_modifiers(GameState.player_stats, GameState.base_stats(), trick.stat_modifiers,
					difficulty.min_damage_taken_mult)


## 寶箱或抉擇事件:排 count 次把戲三選一(只在關卡進行中)。傳回是否排上。
func offer_bonus_choice(count: int = 1) -> bool:
	if not accepting_exp or count <= 0:
		return false
	_pending_choices += count
	if not _choice_open:
		_choice_open = true
		choice_opened.emit()
		_offer_next.call_deferred()
	return true


func cancel_choices() -> void:
	_pending_choices = 0
	_current_offer.clear()
	if _choice_open:
		_choice_open = false
		choice_closed.emit()


func _evolve(evolution: TrickData) -> void:
	var sources := _deck.sources_of(evolution.id)
	var kept: Array[StringName] = []
	for id in GameState.active_tricks:
		if not sources.has(id):
			kept.append(id)
	kept.append(evolution.id)
	GameState.active_tricks.assign(kept)
	rebuild_stats()
	EventBus.trick_evolved.emit(evolution.id)


func _find_trick(id: StringName) -> TrickData:
	var trick := _deck.get_trick(id) if _deck != null else null
	return trick if trick != null else TrickDeck.load_trick(id)


func _on_exp_collected(amount: int) -> void:
	if not accepting_exp:
		return
	var mult := GameState.player_stats.exp_mult if GameState.player_stats != null else 1.0
	var gained := _exp.add(amount, mult)
	for i in gained:
		GameState.hero_level += 1
		EventBus.leveled_up.emit(GameState.hero_level)
		Sfx.play(&"level_up")
		Haptics.play(&"medium")
	emit_exp_changed()
	if gained > 0:
		_pending_choices += gained
		if not _choice_open:
			_choice_open = true
			choice_opened.emit()
			_offer_next.call_deferred()


func _offer_next() -> void:
	if not _choice_open or _pending_choices <= 0:
		return
	_current_offer = _deck.draw(difficulty.trick_offer_count, rng, GameState.active_tricks)
	_current_offer = BuildRoutes.guide_offer(_current_offer, _deck, GameState.active_tricks, GameState.run_route)
	_current_offer = AttackTechniques.guide_offer(_current_offer, _deck, GameState.active_tricks,
			GameState.hero_class, GameState.hero_level, GameState.run_route)
	if _current_offer.is_empty():
		push_warning("RunProgression: 沒有可抽的把戲,略過這次選擇")
		cancel_choices()
		return
	EventBus.trick_offered.emit(_current_offer.duplicate())


func _on_trick_chosen(trick_id: StringName) -> void:
	if not _choice_open or _current_offer.is_empty():
		return
	var chosen: TrickData = null
	for trick in _current_offer:
		if trick.id == trick_id:
			chosen = trick
			break
	if chosen == null:
		push_warning("RunProgression: 選了不在選項內的把戲 %s,略過" % trick_id)
		return
	_current_offer.clear()
	apply_trick(chosen)
	tricks_this_level.append(chosen.id)
	_pending_choices -= 1
	if _pending_choices > 0:
		_offer_next.call_deferred()
	else:
		_choice_open = false
		choice_closed.emit()


## JSON-safe checkpoint of an adventure at a level boundary.
func export_checkpoint() -> Dictionary:
	return {"route": String(GameState.run_route), "hero_level": GameState.hero_level, "tricks": Array(GameState.active_tricks),
		"exp_centi": _exp.get_centi(), "run_modifiers": run_modifiers.duplicate(true),
		"bonus_trick_levels": bonus_trick_levels, "vigor": GameState.vigor,
		"satisfaction": GameState.satisfaction, "next_level_bonus": GameState.next_level_bonus,
		"rng": str(rng.state), "equipment": GameState.run_equipment.duplicate(true)}

func import_checkpoint(data: Dictionary) -> void:
	cancel_choices()
	GameState.run_route = BuildRoutes.valid_id(data.get("route", ""), GameState.hero_class)
	GameState.hero_level = int(data.hero_level)
	GameState.active_tricks.assign(data.tricks)
	_exp.set_state(GameState.hero_level, int(data.exp_centi))
	run_modifiers.assign(data.run_modifiers)
	bonus_trick_levels = int(data.bonus_trick_levels)
	GameState.next_level_bonus = float(data.next_level_bonus)
	GameState.satisfaction = int(data.satisfaction)
	GameState.run_equipment = data.equipment.duplicate(true)
	rng.state = int(data.rng)
	rebuild_stats()
	GameState.vigor = clampi(int(data.vigor), 1, GameState.player_stats.max_vigor)
