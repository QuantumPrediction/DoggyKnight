class_name LevelEvents
extends Node
## 抉擇事件的進行(v2.4 BV3)。由 FlowMain 擁有;事件資料在 data/levels/events.tres。
##
## offer(event):發 EventBus.event_offered(事件 id, 選項),本地訊號 event_opened(FlowMain 暫停遊戲),
## 等 C 線的事件介面(ui/event_choice/event_choice.tscn)發 EventBus.event_chosen(事件 id, 選項索引);
## 套用選項的效果(EventOption.effects)之後發 event_closed(繼續遊戲)。
## 正在選把戲時不會同時出現:等把戲選完(RunProgression.choice_closed)才出現。
## 沒有事件介面(has_ui = false)時,等 auto_pick_delay 秒(真實時間)自動選第一項(梅林的祝福)。
## 效果裡的「立即學把戲」會在事件關閉前排好把戲選擇,所以遊戲一直維持暫停,直到把戲也選完。

signal event_opened()
signal event_closed()

var progression: RunProgression
var rewards: RunRewards
## 有沒有事件介面(FlowMain 設定)。
var has_ui: bool = false
## 沒有介面時自動選第一項之前等的秒數(真實時間)。
var auto_pick_delay: float = 0.5
## 這一關選過的事件:{"id": 事件 id, "option": 索引, "tone": "merlin"|"morgana"}(結算用;沒有時為空)。
var last_choice: Dictionary = {}

var _open: LevelEvent
var _queued: LevelEvent
var _serial: int = 0


func setup(run_progression: RunProgression, run_rewards: RunRewards) -> void:
	progression = run_progression
	rewards = run_rewards
	progression.choice_closed.connect(_on_choice_closed)


func _enter_tree() -> void:
	EventBus.event_chosen.connect(_on_event_chosen)


func _exit_tree() -> void:
	EventBus.event_chosen.disconnect(_on_event_chosen)


func is_open() -> bool:
	return _open != null


func get_open_event() -> LevelEvent:
	return _open


func get_open_id() -> StringName:
	return _open.id if _open != null else &""


## 出一個事件(已經有事件開著時略過)。
func offer(event: LevelEvent) -> void:
	if event == null or event.options.is_empty() or _open != null:
		return
	if progression != null and progression.is_choice_open():
		_queued = event
		return
	_show(event)


## 離開關卡或關卡結束:收起事件(不套用任何效果)。
func cancel() -> void:
	_serial += 1
	_queued = null
	if _open != null:
		_open = null
		event_closed.emit()


## 新的一關:清掉上一關的紀錄。
func reset_level() -> void:
	cancel()
	last_choice = {}


## 選一個選項(測試、沙盒與試玩機器人也可以直接呼叫)。傳回是否有套用。
func choose(index: int) -> bool:
	if _open == null:
		return false
	var option := _open.get_option(index)
	if option == null:
		push_warning("LevelEvents: 事件 %s 沒有第 %d 項,略過" % [_open.id, index])
		return false
	var event := _open
	_open = null
	_serial += 1
	last_choice = {"id": event.id, "option": index, "tone": option.tone}
	apply(option)
	event_closed.emit()
	return true


## 套用一個選項的效果(EventOption 的說明)。
func apply(option: EventOption) -> void:
	var e := option.effects
	if e.has("route"):
		progression.choose_route(StringName(e["route"]))
	if e.get("stats", null) is Dictionary:
		progression.add_run_modifier(e["stats"])
	if e.has("vigor_keep_ratio"):
		var keep := clampf(float(e["vigor_keep_ratio"]), 0.0, 1.0)
		GameState.vigor = maxi(1, roundi(float(GameState.vigor) * keep))
		EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)
	if e.has("heal_ratio"):
		rewards.heal_ratio(float(e["heal_ratio"]))
	if e.has("snacks"):
		rewards.add_snacks(int(e["snacks"]))
	if e.has("bonus_trick_levels"):
		progression.bonus_trick_levels += maxi(0, int(e["bonus_trick_levels"]))
	if e.has("trick_choices"):
		progression.offer_bonus_choice(int(e["trick_choices"]))


func _show(event: LevelEvent) -> void:
	_open = event
	_serial += 1
	var serial := _serial
	event_opened.emit()
	EventBus.event_offered.emit(event.id, event.offer_options())
	if has_ui:
		return
	await get_tree().create_timer(maxf(0.0, auto_pick_delay), true, false, true).timeout
	if serial == _serial and _open == event:
		choose(0)


func _on_choice_closed() -> void:
	if _queued != null and _open == null:
		var event := _queued
		_queued = null
		_show_queued.call_deferred(event, _serial)


func _show_queued(event: LevelEvent, serial: int) -> void:
	# 中途 cancel()(關卡結束、離開畫面)時 _serial 已改變:不再出現。
	if serial == _serial and _open == null and not (progression != null and progression.is_choice_open()):
		_show(event)


func _on_event_chosen(event_id: StringName, option_index: int) -> void:
	if _open == null or event_id != _open.id:
		return
	choose(option_index)
