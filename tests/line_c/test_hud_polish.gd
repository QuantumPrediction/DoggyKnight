extends TestCase
## HUD 打磨(CP4、CP10):頭目血條、連擊數、標題卡、過關慶祝、必殺技切入、等級彈出、心跳與殘影。

const HUD_SCENE := preload("res://ui/hud/hud.tscn")

var hud: Control


func before_each() -> void:
	hud = HUD_SCENE.instantiate() as Control
	add_child(hud)
	await wait_frames(1)


func after_each() -> void:
	hud.queue_free()
	await wait_frames(1)


func test_boss_bar_follows_boss_hp_and_phase() -> void:
	var bar: BossBar = hud.get("boss_bar")
	assert_false(bar.visible, "頭目出場前不顯示")
	EventBus.boss_hp_changed.emit(700, 700)
	assert_true(bar.visible and bar.is_shown(), "boss_hp_changed 後出現")
	assert_eq(bar.name_label.text, tr("ENEMY_BLACK_KNIGHT"))
	EventBus.boss_hp_changed.emit(350, 700)
	assert_almost_eq(bar.bar.ratio(), 0.5)
	var phase1_color := bar.bar.fill_color
	EventBus.boss_phase_changed.emit(2)
	assert_ne(bar.bar.fill_color, phase1_color, "第二階段變色")
	assert_eq(bar.phase, 2)
	EventBus.level_started.emit(&"1-1")
	assert_false(bar.visible, "新的一關重設")


func test_combo_counter_shows_from_two_and_hides_on_break() -> void:
	var combo: ComboCounter = hud.get("combo")
	EventBus.combo_changed.emit(1)
	assert_false(combo.visible, "1 連擊不顯示")
	EventBus.combo_changed.emit(2)
	assert_true(combo.visible)
	assert_eq(combo.number_label.text, "2")
	for c in range(3, 12):
		EventBus.combo_changed.emit(c)
	assert_eq(combo.number_label.text, "11")
	EventBus.combo_changed.emit(0)
	await get_tree().create_timer(0.5).timeout
	assert_false(combo.visible, "連擊中斷後淡出")


func test_title_card_plays_on_level_started_and_ends_in_time() -> void:
	var card: TitleCard = hud.get("title_card")
	EventBus.level_started.emit(&"1-2")
	assert_true(card.visible and card.is_playing(), "level_started 時顯示標題卡")
	assert_eq(card.name_label.text, tr("LEVEL_1_2"))
	assert_eq(card.chapter_label.text, tr("CHAPTER_1"))
	var limit := (load("res://ui/hud/hud_config.tres") as HudConfig).title_card_time + 0.2
	await get_tree().create_timer(limit).timeout
	assert_false(card.visible, "B 線開始第一波時(約 1.6 秒)標題卡已經收起")


func test_final_wave_is_announced() -> void:
	EventBus.wave_started.emit(3, 3)
	var texts: PackedStringArray = hud.call("banner_texts")
	assert_true(texts.has(tr("UI_WAVE_FINAL")), "最後一波有特別提示:%s" % [texts])


func test_celebration_and_cut_in() -> void:
	EventBus.ultimate_used.emit()
	var cut: CutIn = hud.get("cut_in")
	assert_true(cut.is_playing(), "必殺技切入畫面")
	await get_tree().create_timer(0.8).timeout
	assert_false(cut.visible, "約 0.6 秒後消失")
	EventBus.level_completed.emit(&"1-1")
	assert_true(hud.call("is_celebrating"), "過關慶祝橫幅")
	var confetti := 0
	for c in hud.get_children():
		if c is CPUParticles2D:
			confetti += 1
	assert_true(confetti >= 2, "左右兩邊噴彩紙")


func test_level_up_pop_text() -> void:
	EventBus.leveled_up.emit(7)
	var pop: Label = hud.get("level_pop")
	assert_true(pop.visible)
	assert_eq(pop.text, tr("UI_LEVEL_POP") % 7)


func test_vigor_ghost_and_low_vigor_heartbeat() -> void:
	var vigor: PixelBar = hud.get("vigor_bar")
	EventBus.vigor_changed.emit(100, 100)
	vigor.snap_to_value()
	EventBus.vigor_changed.emit(20, 100)
	assert_true(vigor.trail_ratio() > vigor.ratio(), "受擊時留下一段白色殘影")
	assert_true(vigor.is_low(), "活力低於 30% 時心跳")
	await wait_frames(2)
	var heart: TextureRect = hud.get("_bar_icons")[0]
	await get_tree().create_timer(0.05).timeout
	assert_true(heart.scale.x >= 1.0)
	EventBus.vigor_changed.emit(90, 100)
	assert_false(vigor.is_low())


func test_new_elements_never_catch_touches() -> void:
	EventBus.boss_hp_changed.emit(500, 700)
	EventBus.combo_changed.emit(6)
	EventBus.level_started.emit(&"1-3")
	EventBus.ultimate_used.emit()
	EventBus.leveled_up.emit(3)
	EventBus.level_completed.emit(&"1-3")
	EventBus.loyalty_changed.emit(100.0, 100.0)
	await wait_frames(2)
	var catchers: Array[Control] = []
	_touch_catchers(hud, catchers)
	for c in catchers:
		assert_true(c.is_in_group(&"ui_touch_blocker"), "%s 會攔觸控,但不在 ui_touch_blocker" % c.name)


func _touch_catchers(node: Node, out: Array[Control]) -> void:
	for c in node.get_children():
		if c is Control:
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append(ctl)
		_touch_catchers(c, out)
