extends TestCase
## 核對 EventBus 與 DEV_PLAN 4.1(v2.3)的合約完全一致(名稱、參數名稱、參數型別,不多不少)。
## 這個測試失敗,代表有人改了凍結的合約。

const CONTRACT: Dictionary = {
	"companion_guard_coverage": [["protected", TYPE_BOOL]],
	"player_combat_status_requested": [],
	"player_combat_readiness": [["state", TYPE_STRING_NAME], ["charge_left", TYPE_FLOAT], ["charge_bonus", TYPE_FLOAT]],
	"companion_counter_resolved": [["result", TYPE_STRING_NAME]],
	"guard_lesson_requested": [],
	"guard_lesson_completed": [],
	"guard_lesson_dismissed": [],
	"equipment_requested": [],
	"companion_blocked": [["at", TYPE_VECTOR2]],
	"companion_guard_requested": [],
	"companion_guard_status_requested": [],
	"companion_guard_state": [["state", TYPE_STRING_NAME], ["cooldown_left", TYPE_FLOAT], ["duration_left", TYPE_FLOAT]],
	"companion_counter_granted": [["bonus", TYPE_FLOAT]],
	"boss_intent_changed": [["enemy_id", TYPE_STRING_NAME], ["intent", TYPE_STRING_NAME], ["remaining", TYPE_FLOAT]],
	"enemy_died": [["enemy_id", TYPE_STRING_NAME], ["position", TYPE_VECTOR2], ["exp_value", TYPE_INT]],
	"player_damaged": [["amount", TYPE_INT]],
	"vigor_changed": [["current", TYPE_INT], ["maximum", TYPE_INT]],
	"loyalty_changed": [["current", TYPE_FLOAT], ["maximum", TYPE_FLOAT]],
	"ultimate_used": [],
	"player_downed": [],
	"boss_phase_changed": [["phase", TYPE_INT]],
	"exp_collected": [["amount", TYPE_INT]],
	"boss_hp_changed": [["current", TYPE_INT], ["maximum", TYPE_INT]],
	"combo_changed": [["count", TYPE_INT]],
	"boss_appeared": [["enemy_id", TYPE_STRING_NAME]],
	"chest_collected": [["tier", TYPE_INT]],
	"snack_collected": [["amount", TYPE_INT]],
	"level_started": [["level_id", TYPE_STRING_NAME]],
	"wave_started": [["index", TYPE_INT], ["total", TYPE_INT]],
	"wave_cleared": [["index", TYPE_INT]],
	"level_completed": [["level_id", TYPE_STRING_NAME]],
	"level_failed": [["level_id", TYPE_STRING_NAME]],
	"exp_changed": [["current", TYPE_INT], ["needed", TYPE_INT]],
	"leveled_up": [["new_level", TYPE_INT]],
	"trick_offered": [["options", TYPE_ARRAY]],
	"trick_chosen": [["trick_id", TYPE_STRING_NAME]],
	"game_paused": [["paused", TYPE_BOOL]],
	"trick_evolved": [["evolution_id", TYPE_STRING_NAME]],
	"event_offered": [["event_id", TYPE_STRING_NAME], ["options", TYPE_ARRAY]],
	"snacks_changed": [["total", TYPE_INT]],
	"ultimate_requested": [],
	"resume_requested": [],
	"quit_to_title_requested": [],
	"event_chosen": [["event_id", TYPE_STRING_NAME], ["option_index", TYPE_INT]],
	"camp_entered": [],
	"minigame_finished": [["minigame_id", TYPE_STRING_NAME], ["score", TYPE_INT], ["grade", TYPE_INT]],
	"camp_left": [],
	"dialogue_started": [["script_id", TYPE_STRING_NAME]],
	"dialogue_finished": [["script_id", TYPE_STRING_NAME]],
	"app_backgrounded": [],
	"app_foregrounded": [],
	"back_requested": [],
}


func _script_signals() -> Dictionary:
	var result := {}
	for info: Dictionary in (EventBus.get_script() as Script).get_script_signal_list():
		result[info["name"]] = info["args"]
	return result


func test_every_contract_signal_exists_with_exact_arguments() -> void:
	var actual := _script_signals()
	for signal_name: String in CONTRACT:
		if not actual.has(signal_name):
			assert_true(false, "缺少訊號 %s" % signal_name)
			continue
		var expected_args: Array = CONTRACT[signal_name]
		var actual_args: Array = actual[signal_name]
		assert_eq(actual_args.size(), expected_args.size(), "%s 的參數數目" % signal_name)
		for i in mini(actual_args.size(), expected_args.size()):
			assert_eq(actual_args[i]["name"], expected_args[i][0], "%s 第 %d 個參數名稱" % [signal_name, i + 1])
			assert_eq(actual_args[i]["type"], expected_args[i][1], "%s 第 %d 個參數型別" % [signal_name, i + 1])


func test_no_signals_outside_the_contract() -> void:
	for signal_name: String in _script_signals():
		assert_true(CONTRACT.has(signal_name), "合約以外的訊號:%s(請走 docs/requests/ 申請)" % signal_name)
