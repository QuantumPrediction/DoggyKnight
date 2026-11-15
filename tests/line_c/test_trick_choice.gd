extends TestCase
## 把戲選擇介面(C9):聽 trick_offered,點卡片發 trick_chosen 並隱藏。

const SCENE := preload("res://ui/trick_choice/trick_choice.tscn")

var ui: Control


func before_each() -> void:
	ui = SCENE.instantiate() as Control
	add_child(ui)
	await wait_frames(1)


func after_each() -> void:
	ui.queue_free()
	SafeArea.simulate_notch = false
	await wait_frames(1)


func _options(ids: Array[String]) -> Array:
	var out: Array = []
	for id in ids:
		var t := TrickData.new()
		t.id = StringName(id)
		t.display_name = "TRICK_%s_NAME" % id.to_upper()
		t.description = "TRICK_%s_DESC" % id.to_upper()
		out.append(t)     # icon 留空:介面會用 assets/icons/tricks/<id>.png
	return out


func test_root_contract() -> void:
	assert_eq(ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(ui.anchor_right, 1.0)
	assert_eq(ui.anchor_bottom, 1.0)
	assert_eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "根節點不攔觸控(隱藏時不擋 A 線搖桿)")
	assert_false(ui.visible, "一開始隱藏")


func test_shows_three_cards_with_names_and_icons() -> void:
	EventBus.trick_offered.emit(_options(["sit", "spin", "bark"]))
	assert_true(ui.visible)
	var cards: Array = ui.get("cards")
	assert_eq(cards.size(), 3)
	var first: Button = cards[0]
	assert_eq((first.get_node("Name") as Label).text, tr("TRICK_SIT_NAME"))
	assert_eq((first.get_node("Description") as Label).text, tr("TRICK_SIT_DESC"))
	var icon: TextureRect = null
	for c in first.get_children():
		if c is TextureRect:
			icon = c
	assert_not_null(icon, "卡片有圖示")
	if icon != null:
		assert_not_null(icon.texture, "沒有 icon 時改用 assets/icons/tricks/sit.png")


func test_tapping_a_card_emits_trick_chosen_and_hides() -> void:
	var chosen := watch_signal(EventBus.trick_chosen)
	EventBus.trick_offered.emit(_options(["wag", "fetch", "shake"]))
	var cards: Array = ui.get("cards")
	(cards[1] as Button).pressed.emit()
	assert_eq(chosen.count, 0, "剛出現時的誤觸不算")
	await get_tree().create_timer(0.45).timeout
	(cards[1] as Button).pressed.emit()
	assert_eq(chosen.count, 1)
	assert_eq(chosen.last_args()[0], &"fetch", "發出被點的把戲 id")
	assert_false(ui.visible, "選完就隱藏")
	(cards[2] as Button).pressed.emit()
	assert_eq(chosen.count, 1, "隱藏後不再發出")


func test_choose_directly() -> void:
	var chosen := watch_signal(EventBus.trick_chosen)
	EventBus.trick_offered.emit(_options(["sit", "wag", "spin"]))
	ui.call("choose", 2)
	assert_eq(chosen.last_args()[0], &"spin")


func test_cards_fit_inside_the_safe_area() -> void:
	for notch in [false, true]:
		SafeArea.simulate_notch = notch
		EventBus.trick_offered.emit(_options(["sit", "fetch", "spin"]))
		var safe := SafeArea.get_safe_rect()
		var prev_bottom := -INF
		for card: Button in ui.get("cards"):
			var r := Rect2(card.position, card.size)
			assert_true(safe.encloses(r), "卡片 %s 在安全區 %s 內" % [r, safe])
			assert_true(card.size.y >= 24.0 and card.size.x >= 24.0)
			assert_true(r.position.y - prev_bottom >= 4.0, "卡片之間至少 4 像素")
			prev_bottom = r.end.y
		ui.call("choose", 0)
