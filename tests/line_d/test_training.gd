extends TestCase
## v2.4 DV1、DV2、DV4:營地訓練(規則、介面、營地入口)與小遊戲的零食獎勵。
## 零食與訓練等級不會被 reset_run() 重設,所以每個測試前後都還原。

const TRAINING_SCENE := preload("res://game/camp/training.tscn")
const CAMP_SCENE := preload("res://game/camp/camp.tscn")
const SCROLL_SCENE := preload("res://game/minigames/scroll/scroll_minigame.tscn")
const IDS: Array[StringName] = [&"vitality", &"strength", &"agility", &"loyalty", &"luck"]


class FakeState:
	extends RefCounted
	var snacks: int = 0
	var meta_upgrades: Dictionary = {}


var _training: CampTraining
var _camp: Camp
var _saved_snacks: int = 0
var _saved_meta: Dictionary = {}


func before_each() -> void:
	_saved_snacks = GameState.snacks
	_saved_meta = GameState.meta_upgrades.duplicate()
	GameState.reset_run()
	GameState.snacks = 0
	GameState.meta_upgrades = {}
	Haptics.reset_for_tests()


func after_each() -> void:
	if is_instance_valid(_training):
		_training.queue_free()
	if is_instance_valid(_camp):
		_camp.queue_free()
	_training = null
	_camp = null
	await wait_frames(1)
	GameState.reset_run()
	GameState.snacks = _saved_snacks
	GameState.meta_upgrades = _saved_meta


func _entry(id: StringName = &"strength", costs: Array[int] = [10, 20], max_level: int = 2, per_level: float = 0.1) -> Dictionary:
	return TrainingShop.normalize({"id": id, "max_level": max_level, "costs": costs, "per_level": per_level})


func _open() -> CampTraining:
	_training = TRAINING_SCENE.instantiate() as CampTraining
	add_child(_training)
	return _training


# --- 資料(TrainingShop) ---

func test_fallback_table_has_five_upgrades_in_order() -> void:
	var entries := TrainingShop.load_entries(["res://does/not/exist.tres", TrainingShop.FALLBACK_PATH])
	assert_eq(entries.size(), 5, "五項升級")
	for i in IDS.size():
		var e := entries[i]
		assert_eq(e["id"], IDS[i], "第 %d 項" % i)
		assert_eq(e["max_level"], 5, "%s 有 5 級" % IDS[i])
		assert_eq((e["costs"] as Array).size(), 5, "%s 每級一個價格" % IDS[i])
		for k in 4:
			assert_true(e["costs"][k] < e["costs"][k + 1], "%s 價格越來越貴" % IDS[i])
		assert_true(float(e["per_level"]) > 0.0)
		assert_eq(e["name_key"], "TRAINING_%s_NAME" % String(IDS[i]).to_upper())
		assert_eq(e["desc_key"], "TRAINING_%s_DESC" % String(IDS[i]).to_upper())


func test_reads_any_resource_with_entries_by_field_name() -> void:
	# B 線的 MetaUpgradeTable 在這個分支還不存在:用一個同樣形狀、不同類別的資源代替。
	var upgrade := TrainingUpgrade.new()
	upgrade.id = &"luck"
	upgrade.max_level = 3
	upgrade.costs = [1, 2, 3]
	upgrade.per_level = 2.0
	var table := TrainingUpgradeTable.new()
	table.entries = [upgrade]
	var entries := TrainingShop.entries_from(table)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["id"], &"luck")
	assert_eq(entries[0]["max_level"], 3)
	assert_eq(entries[0]["costs"], [1, 2, 3])
	assert_eq(entries[0]["name_key"], "TRAINING_LUCK_NAME", "沒填翻譯鍵時用 TRAINING_<ID>_NAME")
	# Dictionary 形式也可以;沒有 id 的項目略過
	var from_dict := TrainingShop.entries_from({"entries": [{"id": "agility", "costs": [5]}, {"name_key": "X"}]})
	assert_eq(from_dict.size(), 1)
	assert_eq(from_dict[0]["id"], &"agility")
	assert_eq(from_dict[0]["max_level"], 5, "預設 5 級")
	assert_true(TrainingShop.entries_from(null).is_empty())


func test_primary_path_is_b_lines_meta_upgrades() -> void:
	var cfg := load("res://game/camp/training_config.tres") as TrainingConfig
	assert_eq(cfg.upgrade_paths[0], "res://data/progression/meta_upgrades.tres", "先讀 B 線的正式資料")
	assert_eq(cfg.upgrade_paths[1], TrainingShop.FALLBACK_PATH)
	assert_eq(TrainingShop.PRIMARY_PATH, "res://data/progression/meta_upgrades.tres")


func test_cost_uses_last_price_when_list_is_short() -> void:
	var e := _entry(&"strength", [10, 20], 4)
	assert_eq(TrainingShop.cost_for(e, 0), 10)
	assert_eq(TrainingShop.cost_for(e, 1), 20)
	assert_eq(TrainingShop.cost_for(e, 3), 20, "比 max_level 短時用最後一個價格")
	assert_eq(TrainingShop.cost_for(e, 4), -1, "滿級")


func test_buy_only_when_affordable() -> void:
	var s := FakeState.new()
	var e := _entry(&"strength", [10, 20], 2)
	s.snacks = 9
	assert_false(TrainingShop.can_buy(s, e), "9 個買不起 10 個的")
	assert_eq(TrainingShop.buy(s, e), -1)
	assert_eq(s.snacks, 9, "買不起時零食不變")
	assert_eq(TrainingShop.level_of(s, &"strength"), 0)
	s.snacks = 30
	assert_eq(TrainingShop.buy(s, e), 1, "升到 1 級")
	assert_eq(s.snacks, 20)
	assert_eq(s.meta_upgrades[&"strength"], 1)
	assert_eq(TrainingShop.buy(s, e), 2, "升到 2 級")
	assert_eq(s.snacks, 0, "剛好買得起")
	s.snacks = 100
	assert_eq(TrainingShop.buy(s, e), -1, "滿級不能再買")
	assert_eq(s.snacks, 100)
	assert_eq(s.meta_upgrades[&"strength"], 2)


func test_level_reads_string_or_stringname_keys() -> void:
	var s := FakeState.new()
	s.meta_upgrades = {"luck": 3}
	assert_eq(TrainingShop.level_of(s, &"luck"), 3, "從存檔讀回的字串鍵也算")


func test_effect_text_percent_or_points() -> void:
	assert_eq(TrainingShop.effect_text(_entry(&"a", [1], 5, 0.1), 2), "+20%")
	assert_eq(TrainingShop.effect_text(_entry(&"a", [1], 5, 0.08), 0), "+0%")
	assert_eq(TrainingShop.effect_text(_entry(&"a", [1], 5, 10.0), 3), "+30", "1 以上當作點數")


# --- 介面(training.tscn) ---

func test_lists_five_upgrades_with_prices_and_snacks() -> void:
	GameState.snacks = 12
	GameState.meta_upgrades = {&"luck": 5}
	_open()
	assert_eq(_training.entries.size(), 5)
	for id in IDS:
		assert_not_null(_training.get_buy_button(id), "%s 有購買按鈕" % id)
	assert_eq(_training.get_price_text(&"vitality"), "10", "價格")
	assert_eq(_training.get_price_text(&"luck"), tr("TRAINING_MAX"), "滿級")
	assert_true(_training.get_buy_button(&"luck").disabled, "滿級不能按")
	assert_false(_training.get_buy_button(&"vitality").disabled, "12 個買得起 10 個的")
	assert_true(_training.get_buy_button(&"luck").disabled)
	var snack_label := _training.find_child("Snacks", true, false) as Label
	assert_eq(snack_label.text, "12", "顯示零食數")
	var effect := _training.get_effect_text(&"vitality")
	assert_true(effect.begins_with(tr("TRAINING_VITALITY_DESC").replace("%s", "").strip_edges()), "效果文字:%s" % effect)
	assert_true(effect.contains("+0%") and effect.contains("+10%"), "現在 → 下一級:%s" % effect)


func test_unaffordable_buttons_are_disabled() -> void:
	GameState.snacks = 5
	_open()
	for id in IDS:
		assert_true(_training.get_buy_button(id).disabled, "5 個零食什麼都買不起:%s" % id)
	assert_false(_training.buy(&"vitality"), "直接呼叫也買不了")
	assert_eq(GameState.snacks, 5)
	assert_eq(GameState.meta_upgrades.get(&"vitality", 0), 0)


func test_buying_spends_snacks_and_emits() -> void:
	GameState.snacks = 25
	_open()
	var changed := watch_signal(EventBus.snacks_changed)
	var upgraded: Array = []
	_training.upgraded.connect(func(id: StringName, level: int) -> void: upgraded.append([id, level]))
	_training.get_buy_button(&"vitality").pressed.emit()
	assert_eq(GameState.snacks, 15, "扣 10 個零食")
	assert_eq(GameState.meta_upgrades.get(&"vitality"), 1, "活力 1 級")
	assert_eq(changed.count, 1, "發 snacks_changed")
	assert_eq(changed.last_args(), [15], "傳零食總數")
	assert_eq(upgraded, [[&"vitality", 1]])
	assert_eq(Haptics.last_kind, &"light", "輕震")
	assert_eq(_training.get_price_text(&"vitality"), "20", "下一級的價格")
	assert_true(_training.get_buy_button(&"vitality").disabled, "15 個買不起 20 個的")
	assert_false(_training.get_buy_button(&"agility").disabled, "8 個的還買得起")
	assert_true(_training.get_effect_text(&"vitality").contains("+10%"))


func test_upgrade_effect_spawns_particles() -> void:
	GameState.snacks = 10
	_open()
	var fx := _training.find_child("Fx", true, false) as Control
	var before := fx.get_child_count()
	_training.buy(&"agility")
	assert_true(fx.get_child_count() >= before + 2, "star_burst 與 sparkle")


func test_refreshes_when_snacks_change_elsewhere() -> void:
	GameState.snacks = 0
	_open()
	assert_true(_training.get_buy_button(&"strength").disabled)
	GameState.snacks = 50
	EventBus.snacks_changed.emit(50)
	assert_false(_training.get_buy_button(&"strength").disabled, "零食變多時按鈕亮起")


func test_close_button_and_back_key_emit_closed_once() -> void:
	_open()
	var closed := [0]
	_training.closed.connect(func() -> void: closed[0] += 1)
	_training.get_close_button().pressed.emit()
	EventBus.back_requested.emit()
	assert_eq(closed[0], 1, "只發一次 closed")
	assert_true(is_instance_valid(_training), "預設不自己刪除(由打開的一方移除)")


func test_back_key_closes_and_free_on_close() -> void:
	_training = TRAINING_SCENE.instantiate() as CampTraining
	_training.free_on_close = true
	add_child(_training)
	var closed := [0]
	_training.closed.connect(func() -> void: closed[0] += 1)
	EventBus.back_requested.emit()
	assert_eq(closed[0], 1, "返回鍵關閉")
	await wait_frames(1)
	assert_false(is_instance_valid(_training), "free_on_close:自己刪除")


func test_fits_safe_area_on_phones() -> void:
	_open()
	var root := get_tree().root
	var original := root.size
	for phone: Vector2i in [Vector2i(1080, 1920), Vector2i(1179, 2556), Vector2i(1080, 2400), Vector2i(750, 1334)]:
		for notch: bool in [false, true]:
			SafeArea.simulate_notch = notch
			root.size = phone
			ScreenFit.call(&"_refit")
			await wait_frames(2)
			_training.call(&"_layout")
			_training.finish_intro()
			await wait_frames(1)
			var safe := SafeArea.get_safe_rect()
			var label := "%s notch=%s" % [phone, notch]
			var close := _training.get_close_button()
			var close_rect := Rect2(close.global_position, close.size)
			assert_true(safe.encloses(close_rect), "%s:返回按鈕在安全區內" % label)
			assert_true(close_rect.end.y <= safe.end.y - 16.0, "%s:避開底部手勢區" % label)
			var scroll := _training.find_child("Scroll", true, false) as ScrollContainer
			var scroll_rect := Rect2(scroll.global_position, scroll.size)
			assert_true(safe.encloses(scroll_rect), "%s:列表在安全區內" % label)
			assert_false(scroll_rect.intersects(close_rect), "%s:列表不蓋住返回按鈕" % label)
			for id in IDS:
				var b := _training.get_buy_button(id)
				assert_true(b.size.x >= 24.0 and b.size.y >= 24.0, "%s:%s 夠大好按" % [label, id])
	SafeArea.simulate_notch = false
	root.size = original
	ScreenFit.call(&"_refit")
	await wait_frames(1)


func test_strings_exist() -> void:
	for key in ["TRAINING_TITLE", "TRAINING_HINT", "TRAINING_CLOSE", "TRAINING_MAX", "TRAINING_LEVEL_UP",
			"CAMP_TRAINING", "MINIGAME_REWARD_SNACKS"]:
		assert_ne(tr(key), key, "%s 有文字" % key)
	for id in IDS:
		var upper := String(id).to_upper()
		assert_ne(tr("TRAINING_%s_NAME" % upper), "TRAINING_%s_NAME" % upper)
		var desc := tr("TRAINING_%s_DESC" % upper)
		assert_true(desc.contains("%s"), "TRAINING_%s_DESC 有 %%s" % upper)
	assert_true(tr("TRAINING_HINT").contains("，"), "全形逗號")


# --- 營地入口 ---

func test_camp_menu_has_training_entry() -> void:
	_camp = CAMP_SCENE.instantiate() as Camp
	add_child(_camp)
	var button := _camp.find_child("TrainingButton", true, false) as Button
	assert_not_null(button, "營地選單有「訓練」")
	assert_eq(button.text, tr("CAMP_TRAINING"))
	var opened := [0]
	_camp.training_opened.connect(func(_t: CampTraining) -> void: opened[0] += 1)
	button.pressed.emit()
	assert_eq(opened[0], 1)
	var training := _camp.get_training()
	assert_not_null(training, "打開訓練介面")
	assert_true(training.is_inside_tree())
	# 開著訓練時,其他入口不動作
	var left := watch_signal(EventBus.camp_left)
	_camp.leave_camp()
	_camp.open_minigame()
	assert_eq(left.count, 0, "訓練中不能離開營地")
	assert_null(_camp.get_minigame(), "訓練中不能開小遊戲")
	assert_false(_camp.pet_goldie(), "訓練中不能摸頭")
	var closed := [0]
	_camp.training_closed.connect(func() -> void: closed[0] += 1)
	training.close()
	assert_eq(closed[0], 1)
	assert_null(_camp.get_training(), "關掉後回到營地")
	assert_true(_camp.is_menu_visible())
	_camp.leave_camp()
	assert_eq(left.count, 1, "關掉訓練後可以繼續冒險")


func test_camp_forwards_upgrades() -> void:
	GameState.snacks = 10
	_camp = CAMP_SCENE.instantiate() as Camp
	add_child(_camp)
	_camp.open_training()
	var upgraded: Array = []
	_camp.training_upgraded.connect(func(id: StringName, level: int) -> void: upgraded.append([id, level]))
	_camp.get_training().buy(&"loyalty")
	assert_eq(upgraded, [[&"loyalty", 1]])
	assert_eq(GameState.snacks, 2)


# --- 小遊戲的零食獎勵(DV2) ---

func test_scroll_grading_snack_rewards() -> void:
	var g := load("res://game/minigames/scroll/scroll_grading.tres") as MinigameGrading
	assert_eq(g.snack_reward, [0, 3, 6, 10], "評價 0 至 3 給 0、3、6、10 個零食")
	GameState.snacks = 4
	var rewards := g.apply_rewards(2, GameState)
	assert_eq(rewards["snacks"], 6)
	assert_eq(GameState.snacks, 10)


func test_minigame_end_adds_snacks_and_emits() -> void:
	GameState.snacks = 5
	var changed := watch_signal(EventBus.snacks_changed)
	var game := SCROLL_SCENE.instantiate() as ScrollMinigame
	game.auto_start = false
	add_child(game)
	game.set_process(false)
	game.start()
	game.step(game.config.countdown_sec + 0.01)
	game.pulled_px = 245.0 * (game.config as ScrollMinigameConfig).px_per_score
	game.step(game.config.duration_sec + 0.1)
	assert_eq(game.grade, 3)
	assert_eq(GameState.snacks, 15, "3 級給 10 個零食")
	assert_eq(changed.count, 1, "發 snacks_changed")
	assert_eq(changed.last_args(), [15])
	assert_eq(game.rewards["snacks"], 10)
	game.free()


func test_grade_zero_gives_no_snacks_and_no_signal() -> void:
	GameState.snacks = 5
	var changed := watch_signal(EventBus.snacks_changed)
	var game := SCROLL_SCENE.instantiate() as ScrollMinigame
	game.auto_start = false
	add_child(game)
	game.set_process(false)
	game.start()
	game.step(game.config.countdown_sec + 0.01)
	game.step(game.config.duration_sec + 0.1)
	assert_eq(game.grade, 0)
	assert_eq(GameState.snacks, 5)
	assert_eq(changed.count, 0, "沒有零食時不發")
	game.free()
