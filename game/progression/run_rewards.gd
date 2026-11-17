class_name RunRewards
extends Node
## 零食與寶箱(v2.4 BV2、BV4)。由 FlowMain 擁有;只在關卡進行中(begin_level 到 end_level)才算。
## 數值在 data/progression/economy.tres(EconomyData)。
##
## - snack_collected(amount)(A 線):GameState.snacks += amount;學了「挖寶」時每次另外回復
##   TrickDeck.extra_bonus(&"snack_heal") 活力(呼叫主角的 heal)。
## - enemy_died:每 kills_per_snack 隻 +1 零食。
## - chest_collected(tier)(A 線):普通寶箱 = 回復活力(chest_heal_ratio)或零食(活力已滿一定是零食);
##   精英、頭目寶箱 = 零食 + 一次把戲三選一(RunProgression.offer_bonus_choice,可能出現進化)。
## - 零食每次改變都發 EventBus.snacks_changed(總數);關卡開始時也發一次,讓 HUD 有初始值。
## 存檔由 FlowMain 負責(過關、切到背景等)。

var economy: EconomyData
var progression: RunProgression
## 傳回目前的主角(heal 用);留空或傳回 null 時直接改 GameState.vigor。
var player_getter: Callable = Callable()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 這一關得到的零食(結算用)。
var snacks_this_level: int = 0
## 這一關開過的寶箱數(結算、測試用)。
var chests_this_level: int = 0

var _active: bool = false
var _kills: int = 0


func setup(economy_data: EconomyData, run_progression: RunProgression, rng_seed: int = 0) -> void:
	economy = economy_data
	progression = run_progression
	if rng_seed != 0:
		rng.seed = rng_seed + 7
	else:
		rng.randomize()


func _enter_tree() -> void:
	EventBus.snack_collected.connect(_on_snack_collected)
	EventBus.chest_collected.connect(_on_chest_collected)
	EventBus.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	EventBus.snack_collected.disconnect(_on_snack_collected)
	EventBus.chest_collected.disconnect(_on_chest_collected)
	EventBus.enemy_died.disconnect(_on_enemy_died)


func begin_level() -> void:
	_active = true
	_kills = 0
	snacks_this_level = 0
	chests_this_level = 0
	EventBus.snacks_changed.emit(GameState.snacks)


## 復活後繼續(不清空這一關的紀錄)。
func resume_level() -> void:
	_active = true


func end_level() -> void:
	_active = false


func is_active() -> bool:
	return _active


## 加零食(任何時候都可以,例如過關獎勵);發 snacks_changed。
func add_snacks(amount: int) -> void:
	if amount <= 0:
		return
	GameState.snacks += amount
	snacks_this_level += amount
	EventBus.snacks_changed.emit(GameState.snacks)


## 花零食;不夠時不扣,傳回 false。
func spend(amount: int) -> bool:
	if amount < 0 or GameState.snacks < amount:
		return false
	if amount > 0:
		GameState.snacks -= amount
		EventBus.snacks_changed.emit(GameState.snacks)
	return true


## 回復活力(經由主角的 heal,A 線負責 vigor_changed);沒有主角時直接改 GameState.vigor。
func heal(amount: int) -> void:
	if amount <= 0:
		return
	var player: Object = player_getter.call() if player_getter.is_valid() else null
	if player != null and is_instance_valid(player) and player.has_method(&"heal"):
		player.call(&"heal", amount)
		return
	GameState.vigor = mini(GameState.player_stats.max_vigor, GameState.vigor + amount)
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)


func heal_ratio(ratio: float) -> void:
	heal(ceili(float(GameState.player_stats.max_vigor) * maxf(0.0, ratio)))


func _on_snack_collected(amount: int) -> void:
	if not _active:
		return
	add_snacks(amount)
	var bonus := roundi(TrickDeck.extra_bonus(&"snack_heal"))
	if bonus > 0:
		heal(bonus)


func _on_enemy_died(_enemy_id: StringName, _position: Vector2, _exp_value: int) -> void:
	if not _active or economy == null or economy.kills_per_snack <= 0:
		return
	_kills += 1
	if _kills % economy.kills_per_snack == 0:
		add_snacks(1)


func _on_chest_collected(tier: int) -> void:
	if not _active or economy == null:
		return
	chests_this_level += 1      # 開箱的音效與畫面由 A、C 線負責
	if tier <= 0:
		var hurt := GameState.vigor < GameState.player_stats.max_vigor
		if hurt and rng.randf() < economy.chest_heal_chance:
			heal_ratio(economy.chest_heal_ratio)
		else:
			add_snacks(economy.chest_snack_amount(0))
		return
	add_snacks(economy.chest_snack_amount(tier))
	if progression != null:
		progression.offer_bonus_choice(economy.chest_choice_count(tier))
