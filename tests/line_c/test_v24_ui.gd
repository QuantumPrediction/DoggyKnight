extends TestCase
## v2.4 玩法深度的 C 線介面與美術(DEV_PLAN 4.12、第 17 節 CV1 至 CV7)。

const EVENT_SCENE := preload("res://ui/event_choice/event_choice.tscn")
const TRICK_SCENE := preload("res://ui/trick_choice/trick_choice.tscn")
const HUD_SCENE := preload("res://ui/hud/hud.tscn")
const NEW_TRICKS: Array[String] = ["pounce", "roll", "dig", "sniff", "play_dead", "zoomies"]
const EVOLUTIONS: Array[String] = ["tornado_tail", "lion_roar", "high_five", "meteor_pounce"]
const OPTIONS: Array = [
	{"title": "UI_EVENT_MERLIN", "desc": "TRICK_SIT_DESC", "icon": "res://assets/ui/icon_heart.png", "tone": "merlin"},
	{"title": "UI_EVENT_MORGANA", "desc": "TRICK_SHAKE_DESC", "icon": "res://assets/ui/icon_snack.png", "tone": "morgana"},
]

var _nodes: Array[Node] = []
var _mode: StringName
var _cleared: bool
var _best: int
var _snacks: int
var _sound: bool


func before_each() -> void:
	_mode = GameState.mode
	_cleared = GameState.chapter_cleared
	_best = GameState.endless_best
	_snacks = GameState.snacks
	_sound = GameState.sound_on
	GameState.sound_on = false


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	GameState.mode = _mode
	GameState.chapter_cleared = _cleared
	GameState.endless_best = _best
	GameState.snacks = _snacks
	GameState.sound_on = _sound
	SafeArea.simulate_notch = false
	# 不等下一格:訊號監看要在節點真正釋放前停止(同 test_screens.gd)。


func _add(c: Node) -> Node:
	add_child(c)
	_nodes.append(c)
	return c


# --------------------------------------------------------------------------
# CV1 / CV4:圖示、寶箱、零食
# --------------------------------------------------------------------------

func test_new_trick_icons_are_16px_and_not_placeholders() -> void:
	for id in NEW_TRICKS + EVOLUTIONS:
		var img := (load("res://assets/icons/tricks/%s.png" % id) as Texture2D).get_image()
		assert_eq(img.get_size(), Vector2i(16, 16), id)
		var colors := {}
		for y in 16:
			for x in 16:
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					colors[c.to_html(false)] = true
		assert_true(colors.size() >= 5, "%s 是正式圖示(%d 色),不是純色佔位方塊" % [id, colors.size()])


func test_evolution_icons_have_a_golden_frame() -> void:
	var gold := PaletteColors.GOLD
	for id in EVOLUTIONS:
		var img := (load("res://assets/icons/tricks/%s.png" % id) as Texture2D).get_image()
		for p: Vector2i in [Vector2i(8, 1), Vector2i(1, 8), Vector2i(8, 14), Vector2i(14, 8)]:
			var c := img.get_pixelv(p)
			assert_true(c.a > 0.9 and (c.r > 0.7 and c.g > 0.45 and c.b < 0.6), "%s 的 %s 是金框(%s)" % [id, p, c])
	for id in NEW_TRICKS:
		var img := (load("res://assets/icons/tricks/%s.png" % id) as Texture2D).get_image()
		var c := img.get_pixel(8, 1)
		assert_false(c.is_equal_approx(gold), "%s 是一般把戲,沒有金框" % id)


func test_chest_and_snack_frames_keep_the_contract() -> void:
	var chest := load("res://assets/sprites/chest/chest_frames.tres") as SpriteFrames
	for anim: StringName in [&"idle", &"open"]:
		assert_true(chest.has_animation(anim), "寶箱有 %s" % anim)
		assert_eq(chest.get_frame_texture(anim, 0).get_size(), Vector2(24, 24))
	assert_true(chest.get_animation_loop(&"idle"))
	assert_false(chest.get_animation_loop(&"open"), "打開只播一次")
	var snack := load("res://assets/fx/snack/snack_frames.tres") as SpriteFrames
	assert_true(snack.has_animation(&"default"))
	assert_eq(snack.get_frame_texture(&"default", 0).get_size(), Vector2(8, 8))


func test_new_strings_render_with_the_pixel_font() -> void:
	var font := load("res://assets/fonts/Cubic_11.ttf") as Font
	for key in ["UI_TRICK_EVOLVE", "UI_EVOLVED", "UI_EVENT_TITLE", "UI_EVENT_HINT", "UI_EVENT_MERLIN",
			"UI_EVENT_MORGANA", "UI_ENDLESS", "UI_TRAINING", "UI_ENDLESS_WAVE", "UI_ENDLESS_BEST",
			"UI_ENDLESS_NEW_BEST", "UI_REVIVE", "UI_REVIVE_HINT"]:
		var text := tr(key)
		assert_ne(text, key, "%s 有翻譯" % key)
		for i in text.length():
			assert_true(font.has_char(text.unicode_at(i)), "%s 的「%s」字型裡有" % [key, text[i]])


# --------------------------------------------------------------------------
# CV1:進化卡片
# --------------------------------------------------------------------------

func _trick(id: String, evolution: bool) -> TrickData:
	var t := TrickData.new()
	t.id = StringName(id)
	t.display_name = "TRICK_%s_NAME" % id.to_upper()
	t.description = "TRICK_%s_DESC" % id.to_upper()
	t.is_evolution = evolution
	return t


func test_evolution_card_has_the_evolve_style() -> void:
	var ui := _add(TRICK_SCENE.instantiate()) as Control
	await wait_frames(1)
	EventBus.trick_offered.emit([_trick("tornado_tail", true), _trick("sit", false)])
	var cards: Array = ui.get("cards")
	var evo: Button = cards[0]
	var plain: Button = cards[1]
	assert_eq(evo.theme_type_variation, &"CardEvolve")
	assert_eq(plain.theme_type_variation, &"CardButton")
	assert_eq(((evo.get_node("Badge") as Control).get_node("Text") as Label).text, tr("UI_TRICK_EVOLVE"))
	assert_ne(((plain.get_node("Badge") as Control).get_node("Text") as Label).text, tr("UI_TRICK_EVOLVE"))
	var parents := evo.get_node_or_null("Parents") as Control
	assert_not_null(parents, "進化卡片顯示「甲 + 乙」")
	var icons := 0
	for c in parents.get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			icons += 1
	assert_eq(icons, 2, "兩個原把戲的小圖示")
	assert_eq(ui.call("badge_text_for", _trick("lion_roar", true)), tr("UI_TRICK_EVOLVE"))


func test_evolution_parents() -> void:
	EvolutionInfo.reset()
	assert_eq(EvolutionInfo.parents_of(&"meteor_pounce").size(), 2)
	for id in EVOLUTIONS:
		var p := EvolutionInfo.parents_of(StringName(id))
		assert_eq(p.size(), 2, id)
		for parent in p:
			assert_not_null(EvolutionInfo.icon_of(parent), "%s 的原把戲 %s 有圖示" % [id, parent])
	assert_eq(EvolutionInfo.parents_of(&"not_a_trick").size(), 0)


# --------------------------------------------------------------------------
# CV2:進化演出
# --------------------------------------------------------------------------

func test_evolution_show_plays_on_trick_evolved_without_catching_touches() -> void:
	var hud := _add(HUD_SCENE.instantiate()) as Control
	await wait_frames(1)
	var show: EvolutionShow = hud.get("evolution")
	assert_not_null(show)
	assert_false(show.is_playing())
	EventBus.trick_evolved.emit(&"lion_roar")
	assert_true(show.is_playing())
	assert_eq(show.evolution_id, &"lion_roar")
	assert_not_null(show.left_icon.texture, "原把戲圖示(吠叫)")
	assert_not_null(show.right_icon.texture, "原把戲圖示(坐下)")
	assert_not_null(show.result_icon.texture, "進化後的圖示")
	EventBus.trick_evolved.emit(&"high_five")      # 排隊,不會打斷
	assert_eq(show.evolution_id, &"lion_roar")
	assert_eq(show.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for c in show.get_children():
		if c is Control:
			assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 不攔觸控" % c.name)


# --------------------------------------------------------------------------
# CV3:抉擇事件
# --------------------------------------------------------------------------

func test_event_choice_root_contract() -> void:
	var ui := _add(EVENT_SCENE.instantiate()) as Control
	await wait_frames(1)
	assert_eq(ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(ui.anchor_right, 1.0)
	assert_eq(ui.anchor_bottom, 1.0)
	assert_eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "隱藏時不擋 A 線搖桿")
	assert_false(ui.visible)
	var groups: Array[StringName] = []
	for g in ui.get_groups():
		if not String(g).begins_with("_"):     # Godot 內部群組不算
			groups.append(g)
	assert_eq(groups.size(), 0, "不加入任何群組:%s" % [groups])


func test_event_offered_shows_two_toned_cards_and_choice_emits() -> void:
	var ui := _add(EVENT_SCENE.instantiate()) as Control
	await wait_frames(1)
	var chosen := watch_signal(EventBus.event_chosen)
	EventBus.event_offered.emit(&"l3_event", OPTIONS)
	assert_true(ui.visible)
	var cards: Array = ui.get("cards")
	assert_eq(cards.size(), 2)
	assert_eq((cards[0] as Button).theme_type_variation, &"CardMerlin", "梅林:藍色")
	assert_eq((cards[1] as Button).theme_type_variation, &"CardMorgana", "摩根娜:紫色")
	assert_eq(((cards[1] as Button).get_node("Name") as Label).text, tr("UI_EVENT_MORGANA"))
	assert_eq(((cards[0] as Button).get_node("Description") as Label).text, tr("TRICK_SIT_DESC"))
	assert_not_null((cards[0] as Button).get_node_or_null("Icon"), "選項的小圖示")
	(cards[1] as Button).pressed.emit()          # 剛出現時不接受點擊(避免誤選)
	assert_eq(chosen.count, 0)
	ui.set("_accept_at", 0.0)
	(cards[1] as Button).pressed.emit()
	assert_eq(chosen.count, 1)
	assert_eq(chosen.last_args(), [&"l3_event", 1])
	assert_false(ui.visible, "選了就隱藏")
	ui.call("choose", 0)
	assert_eq(chosen.count, 1, "隱藏後不會再發")


func test_event_cards_are_touch_sized_and_inside_the_safe_area() -> void:
	SafeArea.simulate_notch = true
	var ui := _add(EVENT_SCENE.instantiate()) as Control
	await wait_frames(1)
	EventBus.event_offered.emit(&"e", OPTIONS)
	await get_tree().create_timer(0.7).timeout      # 卡片從兩邊滑進來
	var safe := SafeArea.get_safe_rect()
	for card: Button in ui.get("cards"):
		var r := Rect2(card.position, card.size)
		assert_true(card.size.x >= 24 and card.size.y >= 24)
		assert_true(safe.encloses(r), "卡片 %s 在安全區 %s 內" % [r, safe])


func test_event_choice_works_while_paused() -> void:
	var ui := _add(EVENT_SCENE.instantiate()) as Control
	await wait_frames(1)
	get_tree().paused = true
	EventBus.event_offered.emit(&"e", OPTIONS)
	assert_true(ui.can_process(), "暫停時照常運作")
	get_tree().paused = false


# --------------------------------------------------------------------------
# CV5:HUD 零食與無盡試煉
# --------------------------------------------------------------------------

func test_hud_snack_counter() -> void:
	GameState.snacks = 4
	var hud := _add(HUD_SCENE.instantiate()) as Control
	await wait_frames(1)
	var label: Label = hud.get("snack_label")
	assert_eq(label.text, "4", "一開始顯示 GameState.snacks")
	EventBus.snacks_changed.emit(11)
	assert_eq(label.text, "11")
	assert_true((hud.get("snack_icon") as TextureRect).visible)


func test_hud_endless_wave_and_best() -> void:
	GameState.mode = &"story"
	GameState.endless_best = 7
	var hud := _add(HUD_SCENE.instantiate()) as Control
	await wait_frames(1)
	assert_false((hud.get("wave_label") as Label).visible, "故事模式不顯示無盡波數")
	EventBus.wave_started.emit(2, 3)
	assert_true(Array(hud.call("banner_texts")).has(tr("UI_WAVE") % [2, 3]))
	GameState.mode = &"endless"
	EventBus.level_started.emit(&"endless")
	EventBus.wave_started.emit(5, 0)
	assert_true((hud.get("wave_label") as Label).visible)
	assert_eq((hud.get("wave_label") as Label).text, "5")
	assert_eq((hud.get("best_label") as Label).text, "7")
	assert_true(Array(hud.call("banner_texts")).has(tr("UI_ENDLESS_WAVE") % 5), "無盡試煉的橫幅是「第 N 波」")
	EventBus.wave_started.emit(8, 0)
	assert_eq((hud.get("best_label") as Label).text, "8", "超過最佳紀錄時跟著跑")
	assert_true(Array(hud.call("banner_texts")).has(tr("UI_ENDLESS_NEW_BEST") % 8))


func test_hud_still_only_has_two_touch_catchers() -> void:
	GameState.mode = &"endless"
	var hud := _add(HUD_SCENE.instantiate()) as Control
	await wait_frames(1)
	EventBus.snacks_changed.emit(3)
	EventBus.wave_started.emit(1, 0)
	EventBus.trick_evolved.emit(&"tornado_tail")
	EventBus.loyalty_changed.emit(100.0, 100.0)
	var catchers: Array[Control] = []
	_catchers(hud, catchers)
	assert_eq(catchers.size(), 2, "只有暫停與必殺技:%s" % [catchers])


func _catchers(node: Node, out: Array[Control]) -> void:
	for c in node.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(c)
		_catchers(c, out)


func test_hud_info_row_stays_inside_the_safe_area() -> void:
	GameState.mode = &"endless"
	GameState.endless_best = 120
	var hud := _add(HUD_SCENE.instantiate()) as Control
	await wait_frames(1)
	EventBus.snacks_changed.emit(999)
	EventBus.wave_started.emit(121, 0)
	for c: Array in [[Vector2(180, 320), Rect2(0, 24, 180, 286)], [Vector2(196, 426), Rect2(0, 34, 196, 382)]]:
		var screen: Vector2 = c[0]
		var safe: Rect2 = c[1]
		var game := Rect2(((screen - SafeArea.GAME_SIZE) * 0.5).floor(), SafeArea.GAME_SIZE)
		hud.call("apply_layout", safe, game)
		var snack: Label = hud.get("snack_label")
		var wave_icon: Control = hud.get("wave_icon")
		var best: Label = hud.get("best_label")
		for n: Control in [hud.get("snack_icon"), snack, wave_icon, hud.get("wave_label"), best]:
			assert_true(safe.encloses(Rect2(n.position, n.size)), "%s 在安全區內" % n.name)
		assert_true(snack.position.x + snack.size.x + 2 <= wave_icon.position.x, "零食數與波數不重疊")
		assert_true(best.position.x + best.size.x <= (hud.get("pause_button") as Control).position.x - 4, "不碰暫停按鈕")


# --------------------------------------------------------------------------
# CV5:失敗畫面的復活、標題的無盡試煉與訓練
# --------------------------------------------------------------------------

func _failure(result: Dictionary) -> Control:
	var f := (load("res://ui/screens/failure.tscn") as PackedScene).instantiate() as Control
	_add(f)
	f.call("setup", result)
	return f


func test_failure_revive_button_only_when_allowed() -> void:
	var f := _failure({"time_sec": 10.0, "kills": 3})
	assert_false((f.get("revive_button") as Button).visible, "沒有 can_revive 就不顯示")
	var g := _failure({"time_sec": 10.0, "kills": 3, "can_revive": false, "revive_cost": 5})
	assert_false((g.get("revive_button") as Button).visible)


func test_failure_revive_button_shows_cost_and_emits_once() -> void:
	var f := _failure({"time_sec": 10.0, "kills": 3, "can_revive": true, "revive_cost": 6})
	await wait_frames(1)
	var b: Button = f.get("revive_button")
	assert_true(b.visible)
	assert_eq(b.text, tr("UI_REVIVE") % 6)
	assert_true(b.size.x >= 24 and b.size.y >= 24)
	var w := watch_signal(Signal(f, "revive_pressed"))
	b.pressed.emit()
	b.pressed.emit()
	assert_eq(w.count, 1, "連按只發一次")
	var safe := SafeArea.get_safe_rect()
	var panel_rect := Rect2(b.global_position, b.size)
	assert_true(safe.encloses(panel_rect), "復活按鈕在畫面內")


func _title() -> Control:
	var t := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	_add(t)
	t.call("setup", true)
	return t


func test_title_endless_only_after_clearing_and_sets_mode() -> void:
	GameState.chapter_cleared = false
	var t := _title()
	assert_false((t.get("endless_button") as Button).visible, "還沒通關不顯示無盡試煉")
	t.queue_free()
	GameState.chapter_cleared = true
	GameState.mode = &"story"
	var u := _title()
	var b: Button = u.get("endless_button")
	assert_true(b.visible)
	var seen: Array[StringName] = []
	u.connect("endless_pressed", func() -> void: seen.append(GameState.mode))
	b.pressed.emit()
	u.get_class_select().confirm_button.pressed.emit()
	assert_eq(seen, [&"endless"] as Array[StringName], "發 endless_pressed 前已設定 mode")


func test_title_training_and_story_mode() -> void:
	GameState.chapter_cleared = false
	GameState.mode = &"endless"
	var t := _title()
	var w := watch_signal(Signal(t, "training_pressed"))
	(t.get("training_button") as Button).pressed.emit()
	assert_eq(w.count, 1)
	var n := watch_signal(Signal(t, "new_game_pressed"))
	(t.get("new_game_button") as Button).pressed.emit()
	t.get_class_select().confirm_button.pressed.emit()
	assert_eq(n.count, 1)
	assert_eq(GameState.mode, &"story", "開始冒險回到故事模式")


func test_title_buttons_fit_small_screen_with_notch() -> void:
	GameState.chapter_cleared = true
	SafeArea.simulate_notch = true
	var t := _title()
	await wait_frames(2)
	var safe := SafeArea.get_safe_rect()
	for name in ["continue_button", "new_game_button", "endless_button", "training_button", "_equipment_button"]:
		var b: Button = t.get(name)
		var r := Rect2(b.global_position, b.size)
		assert_true(b.size.x >= 24 and b.size.y >= 24, name)
		assert_true(safe.encloses(r), "%s 在安全區內(%s)" % [name, r])
