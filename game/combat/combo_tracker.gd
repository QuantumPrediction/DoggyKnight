class_name ComboTracker
extends Node
## 連擊(AP4)。戰鬥場地的子節點。
##
## - 每次有敵人倒下(EventBus.enemy_died),連擊 +1,並重新開始計時;
##   超過 FeelTuning.combo_window 秒(預設 2 秒)沒有再打倒敵人,連擊中斷。
## - 每次改變都發 EventBus.combo_changed(count);中斷時發 combo_changed(0)。
## - 達到里程碑(預設 5、10、20,之後每 10)時:金毛加忠誠度、播 combo 音效、輕震動、
##   金毛身邊閃一下,並發本地訊號 milestone_reached。
## - 計時用 _physics_process:遊戲暫停(選把戲、暫停選單)時不會中斷連擊。
## - 場地離開場景樹時,如果還有連擊,發 combo_changed(0),讓 HUD 歸零。

signal milestone_reached(count: int, loyalty: float)

var count: int = 0
var best: int = 0
var milestones_hit: int = 0
var feel: FeelTuning

var _left: float = 0.0


func _ready() -> void:
	if feel == null:
		feel = CombatFx.feel()


func _enter_tree() -> void:
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if count > 0:
		count = 0
		EventBus.combo_changed.emit(0)


func _physics_process(delta: float) -> void:
	step(delta)


## 讓時間前進 delta 秒(測試可以關掉物理處理後自己呼叫)。
func step(delta: float) -> void:
	if count <= 0:
		return
	_left -= delta
	if _left <= 0.0:
		reset()


## 剩下幾秒連擊就會中斷。
func time_left() -> float:
	return maxf(0.0, _left) if count > 0 else 0.0


## 中斷連擊(有連擊時發 combo_changed(0))。
func reset() -> void:
	_left = 0.0
	if count == 0:
		return
	count = 0
	EventBus.combo_changed.emit(0)


## 記一次擊倒。
func add_kill() -> void:
	if feel == null:
		feel = CombatFx.feel()
	count += 1
	best = maxi(best, count)
	_left = feel.combo_window
	EventBus.combo_changed.emit(count)
	var reward := loyalty_for(count)
	if reward > 0.0:
		_celebrate(reward)


## count 連擊時是不是里程碑;是的話傳回要加的忠誠度,否則 0。
func loyalty_for(combo: int) -> float:
	var marks := feel.combo_milestones
	for i in marks.size():
		if marks[i] == combo:
			return feel.combo_milestone_loyalty[i] if i < feel.combo_milestone_loyalty.size() else 0.0
	if marks.is_empty() or feel.combo_repeat_every <= 0:
		return 0.0
	var last := marks[marks.size() - 1]
	if combo > last and (combo - last) % feel.combo_repeat_every == 0:
		return feel.combo_repeat_loyalty
	return 0.0


func _celebrate(reward: float) -> void:
	milestones_hit += 1
	var arena := get_parent()
	var player: Node2D = arena.call(&"get_player") if arena != null and arena.has_method(&"get_player") else null
	if player != null and is_instance_valid(player):
		if player.has_method(&"add_loyalty"):
			player.call(&"add_loyalty", reward)
		if player.has_method(&"celebrate_combo"):
			player.call(&"celebrate_combo", count)
	CombatFx.sfx(&"combo", &"pickup")
	CombatFx.haptic(feel.haptic_combo)
	milestone_reached.emit(count, reward)


func _on_enemy_died(_enemy_id: StringName, _position: Vector2, _exp_value: int) -> void:
	if is_inside_tree():
		add_kill()
