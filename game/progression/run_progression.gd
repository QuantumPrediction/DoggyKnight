class_name RunProgression
extends Node
## 一輪冒險之中的經驗、升級與把戲(B4、B5)。由 FlowMain 擁有,跨關保留。
##
## - 聽 EventBus.exp_collected(原始值),乘上 GameState.player_stats.exp_mult 後累計。
## - 達到門檻:GameState.hero_level +1,發 leveled_up(新等級)、播 Sfx level_up。
##   一次升好幾級時,每級各發一次 leveled_up,把戲選擇排隊逐次出現。
## - 要給玩家選把戲時發出本地訊號 choice_opened(FlowMain 據此暫停遊戲),
##   然後發 EventBus.trick_offered(Array[TrickData])。
## - 收到 EventBus.trick_chosen:把 id 加進 GameState.active_tricks,數值類把戲修改
##   GameState.player_stats;還有排隊的升級就再出一次選擇,否則發 choice_closed(繼續遊戲)。
##
## 下一次選擇用 call_deferred 發出:介面在發出 trick_chosen 之後通常會把自己藏起來,
## 如果同一刻就送出下一組選擇,介面會在顯示之後立即被自己藏起來。

signal choice_opened()
signal choice_closed()

var difficulty: DifficultyData
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 只有在關卡進行中才計算經驗(結算、營地、標題時收到的經驗不算)。
var accepting_exp: bool = false
## 這一關新學的把戲 id(依選擇次序,同一個把戲可出現多次)。結算用。
var tricks_this_level: Array[StringName] = []

var _exp: HeroExperience
var _deck: TrickDeck
var _pending_choices: int = 0
var _choice_open: bool = false
var _current_offer: Array[TrickData] = []


func setup(curve: DifficultyData, rng_seed: int = 0) -> void:
	difficulty = curve
	_deck = TrickDeck.new(difficulty.trick_pool)
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


## 新的一輪(新遊戲或「繼續」):經驗歸零,等級跟隨 GameState.hero_level。
func reset_run() -> void:
	cancel_choices()
	_exp.set_state(GameState.hero_level, 0)
	tricks_this_level.clear()


## 關卡開始:清空這一關的把戲記錄,並讓 HUD 拿到經驗的初始值。
func begin_level() -> void:
	cancel_choices()
	tricks_this_level.clear()
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


## 關卡開始時的快照,失敗重試時還原(數值、把戲、等級、經驗、下一關加成)。
func take_snapshot() -> Dictionary:
	return {
		"stats": GameState.player_stats.duplicate(),
		"tricks": GameState.active_tricks.duplicate(),
		"hero_level": GameState.hero_level,
		"exp_centi": _exp.get_centi(),
		"next_level_bonus": GameState.next_level_bonus,
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	cancel_choices()
	GameState.player_stats = (snapshot["stats"] as StatBlock).duplicate() as StatBlock
	GameState.active_tricks.assign(snapshot["tricks"] as Array)
	GameState.hero_level = snapshot["hero_level"]
	GameState.next_level_bonus = snapshot["next_level_bonus"]
	_exp.set_state(GameState.hero_level, snapshot["exp_centi"])


## 套用一個把戲(數值類改 player_stats;能力類只記錄,由 A 線執行)。
func apply_trick(trick: TrickData) -> void:
	GameState.active_tricks.append(trick.id)
	if not trick.is_ability and not trick.stat_modifiers.is_empty():
		TrickDeck.apply_modifiers(GameState.player_stats, GameState.BASE_STATS, trick.stat_modifiers,
				difficulty.min_damage_taken_mult)


func cancel_choices() -> void:
	_pending_choices = 0
	_current_offer.clear()
	if _choice_open:
		_choice_open = false
		choice_closed.emit()


func _on_exp_collected(amount: int) -> void:
	if not accepting_exp:
		return
	var mult := GameState.player_stats.exp_mult if GameState.player_stats != null else 1.0
	var gained := _exp.add(amount, mult)
	for i in gained:
		GameState.hero_level += 1
		EventBus.leveled_up.emit(GameState.hero_level)
		Sfx.play(&"level_up")
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
	_current_offer = _deck.draw(difficulty.trick_offer_count, rng)
	if _current_offer.is_empty():
		push_warning("RunProgression: 沒有可抽的把戲,略過這次升級選擇")
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
