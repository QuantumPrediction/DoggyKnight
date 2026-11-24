extends TestCase
## Reach the actual popup and HUD APIs. The compact face supplies its own glyphs in Web builds.

const DISPLAY_FONT: Font = preload("res://assets/fonts/StoryDisplay.tres")
const FIGURES: Font = preload("res://assets/fonts/QuillFigures.ttf")


func test_figure_face_has_distinct_digits_and_semantic_marks() -> void:
	var ts := TextServerManager.get_primary_interface()
	var rid := FIGURES.get_rids()[0]
	var glyphs: Array[int] = []
	for letter: String in "0123456789!−✦":
		var glyph := ts.font_get_glyph_index(rid, 20, letter.unicode_at(0), 0)
		assert_true(glyph != 0 and not glyphs.has(glyph), "缺少或重複字形 " + letter)
		glyphs.append(glyph)
	assert_true(FIGURES.get_string_size("111", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <
			FIGURES.get_string_size("888", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, "數字按筆畫寬度排版")


func test_four_hit_styles_keep_numbers_and_expire_at_original_cutoffs() -> void:
	var host := Node2D.new()
	add_child(host)
	var marks := ["", "!", "✦", ""]
	for i in marks.size():
		var number := CombatFx.damage_number(host, 108, Vector2(35, 70), i as DamageNumber.Style)
		assert_not_null(number)
		if number == null:
			continue
		assert_eq(number.value, 108)
		assert_eq(number._text, "108" + String(marks[i]))
		assert_eq(number.global_position, Vector2(35, 70))
		var big := i == DamageNumber.Style.CRIT or i == DamageNumber.Style.ULTIMATE
		var lifetime := CombatFx.feel().crit_lifetime if big else CombatFx.feel().number_lifetime
		number._process(lifetime - 0.01)
		assert_false(number.is_queued_for_deletion())
		number._process(0.011)
		assert_true(number.is_queued_for_deletion())
	assert_null(CombatFx.damage_number(host, 0, Vector2.ZERO))
	host.free()


func test_display_title_and_combo_fit_their_existing_hud_regions() -> void:
	var hud: Node = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	var card: TitleCard = hud.title_card
	for id in ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6"]:
		EventBus.level_started.emit(StringName(id))
		card._layout()
		var safe := SafeArea.get_safe_rect()
		var bounds := card.name_label.get_global_rect()
		assert_eq(card.name_label.get_theme_font(&"font"), DISPLAY_FONT)
		assert_true(card.name_label.get_theme_font_size(&"font_size") >= 16, id + " 保持標題字級")
		assert_true(bounds.position.x >= safe.position.x + TitleCard.MARGIN_X and
				bounds.end.x <= safe.end.x - TitleCard.MARGIN_X, id + " 兩邊保留呼吸空間")
		assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var combo: ComboCounter = hud.combo
	combo.set_count(20)
	assert_eq(combo.number_label.text, "20")
	assert_eq(combo.number_label.get_theme_font(&"font"), FIGURES)
	assert_true(combo.number_label.size.x <= combo.size.x)
	assert_eq(combo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	hud.free()

func test_player_damage_uses_one_signed_readout_on_the_vigor_bar() -> void:
	var hud: Node = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	var loss: Label = hud.vigor_loss
	EventBus.player_damaged.emit(13)
	assert_eq(loss.text, "−13")
	assert_true(loss.visible)
	assert_eq(loss.get_parent(), hud.vigor_bar)
	assert_eq(loss.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	EventBus.player_damaged.emit(8)
	assert_eq(loss.text, "−8", "快速受擊只保留最新一次")
	EventBus.level_started.emit(&"1-1")
	assert_false(loss.visible)
	EventBus.player_damaged.emit(0)
	assert_false(loss.visible)
	EventBus.player_damaged.emit(13)
	await get_tree().create_timer(0.65).timeout
	assert_false(loss.visible)
	hud.free()

func test_popup_lifts_only_when_real_warning_pressure_is_lower_above_source() -> void:
	var host := Node2D.new()
	add_child(host)
	var source := Vector2(52, 117)
	var arrival := AttackTelegraph.make_arrival_circle(24)
	host.add_child(arrival)
	arrival.global_position = source
	var safe := CombatFx.damage_number(host, 12, source)
	assert_eq(safe._offset, Vector2.ZERO, "無害登場圈保留原位")
	var attack := AttackTelegraph.make_sector(24, Vector2.UP, PI / 3)
	host.add_child(attack)
	attack.global_position = Vector2(52, 132)
	var marked := CombatFx.damage_number(host, 12, source)
	assert_eq(marked.global_position, source, "仍然對應原受擊位置")
	assert_eq(marked._offset, Vector2.UP * DamageNumber.WARNING_LIFT)
	var wide := AttackTelegraph.make_circle(55)
	host.add_child(wide)
	wide.global_position = source
	attack.queue_free()
	var covered := CombatFx.damage_number(host, 12, source)
	assert_eq(covered._offset, Vector2.ZERO, "新位置同樣有預警時不搬動")
	for popup: DamageNumber in [safe, marked, covered]:
		popup.free()
	host.free()
