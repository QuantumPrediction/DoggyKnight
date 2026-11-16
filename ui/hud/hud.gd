extends Control
## 戰鬥 HUD(C8、CP4,DEV_PLAN 4.4、4.9、4.10)。
##
## 只聽 EventBus,不讀任何戰鬥節點。B 線把它放在第 10 層 CanvasLayer。
## - 左上:等級徽章、活力條(愛心;受擊有白色殘影、低活力時心跳)、經驗條、忠誠度條,
##   墊一塊半透明深色底板,在明亮的背景上也看得清楚
## - 右上:暫停按鈕(等同 Android 返回鍵:AppLifecycle.simulate_back())
## - 上方:頭目血條(boss_hp_changed;第二階段變紅)、波次/頭目橫幅、連擊數(combo_changed)
## - 畫面中段:關卡標題卡(level_started)、過關慶祝橫幅與彩紙(level_completed)、
##   必殺技切入畫面(ultimate_used)、「等級 N!」彈出文字(leveled_up)
## - 戰鬥區右下角:必殺技按鈕(忠誠度滿時出現,按下發 ultimate_requested)
## 只有暫停與必殺技兩個按鈕會攔觸控(群組 ui_touch_blocker);其他元件都是 MOUSE_FILTER_IGNORE,
## A 線的搖桿照常運作。位置依 SafeArea 安全區排列。可調數值在 ui/hud/hud_config.tres。

const TOUCH_BLOCKER_GROUP: StringName = &"ui_touch_blocker"
const CONFIG: HudConfig = preload("res://ui/hud/hud_config.tres")
const CONFETTI: PackedScene = preload("res://assets/fx/particles/confetti.tscn")
const SPARKLE: PackedScene = preload("res://assets/fx/particles/sparkle.tscn")
const MARGIN: float = 4.0
const BAR_MAX_WIDTH: float = 96.0
const BANNER_HOLD: float = 1.4
const BOSS_BANNER_HOLD: float = 2.2
## 必殺技按鈕與戰鬥區右下角、安全區底邊的距離(避開系統手勢區)。
const ULTIMATE_INSET: Vector2 = Vector2(6, 6)
const ULTIMATE_BOTTOM_CLEARANCE: float = 14.0
const BOSS_LEVEL_SUFFIX: String = "1-6"

var level_badge: TextureRect
var level_label: Label
var vigor_bar: PixelBar
var exp_bar: PixelBar
var loyalty_bar: PixelBar
var pause_button: Button
var ultimate_button: TextureButton
var ultimate_label: Label
var banner: PanelContainer
var banner_label: Label
var boss_bar: BossBar
var combo: ComboCounter
var title_card: TitleCard
var cut_in: CutIn
var level_pop: Label
var celebration: PanelContainer
var celebration_label: Label

var _plate: NinePatchRect
var _bar_icons: Array[TextureRect] = []
var _banner_queue: Array[Dictionary] = []
var _banner_tween: Tween
var _ultimate_ready: bool = false
var _boss_level: bool = false
var _boss_banner_shown: bool = false
var _last_layout_key: String = ""
var _time: float = 0.0
var _pop_tween: Tween
var _celebration_tween: Tween
var _celebrating: bool = false


func _ready() -> void:
	UiKit.setup_root(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.vigor_changed.connect(_on_vigor_changed)
	EventBus.exp_changed.connect(_on_exp_changed)
	EventBus.leveled_up.connect(_on_leveled_up)
	EventBus.loyalty_changed.connect(_on_loyalty_changed)
	EventBus.ultimate_used.connect(_on_ultimate_used)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.level_failed.connect(_on_level_failed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.player_damaged.connect(_on_player_damaged)
	get_viewport().size_changed.connect(relayout)
	_set_level(GameState.hero_level)
	_on_vigor_changed(GameState.vigor, GameState.player_stats.max_vigor if GameState.player_stats else 100)
	vigor_bar.snap_to_value()
	exp_bar.set_values(0, 1)
	exp_bar.snap_to_value()
	loyalty_bar.set_values(0, 1)
	loyalty_bar.snap_to_value()
	relayout()


func _process(delta: float) -> void:
	_time += delta
	# 安全區可能在不改變畫面大小的情況下改變(例如沙盒切換模擬瀏海)。
	var key := _layout_key()
	if key != _last_layout_key:
		relayout()
	_update_heartbeat()


# --------------------------------------------------------------------------
# 建立節點
# --------------------------------------------------------------------------

func _build() -> void:
	_plate = NinePatchRect.new()
	_plate.name = "Plate"
	_plate.texture = preload("res://assets/ui/hud_plate.png")
	_plate.patch_margin_left = 4
	_plate.patch_margin_top = 4
	_plate.patch_margin_right = 4
	_plate.patch_margin_bottom = 4
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_plate)

	level_badge = UiKit.texture_rect(preload("res://assets/ui/level_badge.png"))
	level_badge.name = "LevelBadge"
	add_child(level_badge)
	level_label = UiKit.label("1")
	level_label.name = "LevelLabel"
	level_label.size = level_badge.size
	level_badge.add_child(level_label)
	level_label.position = Vector2(0, 0)

	vigor_bar = _make_bar("VigorBar", PaletteColors.RED, PaletteColors.PINK, PaletteColors.RED_D,
			preload("res://assets/ui/icon_heart.png"), 7)
	vigor_bar.low_ratio = CONFIG.low_vigor_ratio
	vigor_bar.segments = 5
	exp_bar = _make_bar("ExpBar", PaletteColors.SKY, PaletteColors.SKY_L, PaletteColors.WATER,
			preload("res://assets/ui/icon_exp.png"), 5)
	loyalty_bar = _make_bar("LoyaltyBar", PaletteColors.GOLD, PaletteColors.GOLD_L, PaletteColors.GOLD_D,
			preload("res://assets/ui/icon_paw.png"), 5)
	loyalty_bar.flash_when_full = true

	pause_button = UiKit.button("", &"ButtonAlt", Vector2(26, 26))
	pause_button.name = "PauseButton"
	pause_button.icon = preload("res://assets/ui/icon_pause.png")
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button.add_to_group(TOUCH_BLOCKER_GROUP)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)

	ultimate_button = TextureButton.new()
	ultimate_button.name = "UltimateButton"
	ultimate_button.texture_normal = preload("res://assets/ui/ultimate_normal.png")
	ultimate_button.texture_pressed = preload("res://assets/ui/ultimate_pressed.png")
	ultimate_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ultimate_button.focus_mode = Control.FOCUS_NONE
	ultimate_button.size = Vector2(32, 32)
	ultimate_button.pivot_offset = Vector2(16, 16)
	ultimate_button.add_to_group(TOUCH_BLOCKER_GROUP)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	ultimate_button.visible = false
	add_child(ultimate_button)
	ultimate_label = UiKit.label(tr("UI_ULTIMATE"), &"LabelLight")
	ultimate_label.name = "UltimateLabel"
	ultimate_label.visible = false
	add_child(ultimate_label)

	boss_bar = BossBar.new()
	boss_bar.name = "BossBar"
	add_child(boss_bar)

	banner = PanelContainer.new()
	banner.name = "Banner"
	banner.theme_type_variation = &"Ribbon"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	banner_label = UiKit.label("", &"LabelLight")
	banner.add_child(banner_label)
	add_child(banner)

	combo = ComboCounter.new()
	combo.name = "Combo"
	combo.min_show = CONFIG.combo_min_show
	combo.tiers = CONFIG.combo_tiers
	add_child(combo)

	level_pop = UiKit.label("", &"LabelPop")
	level_pop.name = "LevelPop"
	level_pop.visible = false
	add_child(level_pop)

	title_card = TitleCard.new()
	title_card.name = "TitleCard"
	add_child(title_card)

	celebration = PanelContainer.new()
	celebration.name = "Celebration"
	celebration.theme_type_variation = &"RibbonBig"
	celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration.visible = false
	celebration_label = UiKit.label(tr("UI_LEVEL_CLEAR"), &"LabelTitle")
	celebration.add_child(celebration_label)
	add_child(celebration)

	cut_in = CutIn.new()
	cut_in.name = "CutIn"
	add_child(cut_in)


func _make_bar(bar_name: String, fill: Color, light: Color, dark: Color, icon: Texture2D, height: int) -> PixelBar:
	var icon_rect := UiKit.texture_rect(icon)
	icon_rect.name = bar_name + "Icon"
	add_child(icon_rect)
	_bar_icons.append(icon_rect)
	var bar := PixelBar.new()
	bar.name = bar_name
	bar.fill_color = fill
	bar.fill_light = light
	bar.fill_dark = dark
	bar.custom_minimum_size = Vector2(40, height)
	bar.size = bar.custom_minimum_size
	add_child(bar)
	return bar


# --------------------------------------------------------------------------
# 版面
# --------------------------------------------------------------------------

func _layout_key() -> String:
	return "%s|%s" % [SafeArea.get_safe_rect(), SafeArea.get_screen_size()]


func relayout() -> void:
	_last_layout_key = _layout_key()
	apply_layout(SafeArea.get_safe_rect(), SafeArea.get_game_rect())


## 依安全區與遊戲區排列所有元件(畫面座標,邏輯像素)。測試可直接呼叫。
func apply_layout(safe: Rect2, game: Rect2) -> void:
	var top_left := (safe.position + Vector2(MARGIN, MARGIN)).floor()
	level_badge.position = top_left
	level_label.size = level_badge.size

	pause_button.size = pause_button.custom_minimum_size
	pause_button.position = Vector2(floorf(safe.end.x - MARGIN - pause_button.size.x), top_left.y)

	var bar_x := level_badge.position.x + level_badge.size.x + 3.0
	var icon_w := 10.0
	var bar_w := floorf(minf(BAR_MAX_WIDTH, pause_button.position.x - 6.0 - (bar_x + icon_w)))
	var rows := [vigor_bar, exp_bar, loyalty_bar]
	var y := top_left.y + 1.0
	for i in rows.size():
		var bar: PixelBar = rows[i]
		var icon := _bar_icons[i]
		icon.position = Vector2(bar_x, y)
		icon.pivot_offset = icon.size * 0.5
		bar.size = Vector2(bar_w, bar.custom_minimum_size.y)
		bar.position = Vector2(bar_x + icon_w, y + floorf((9.0 - bar.size.y) * 0.5))
		y += 8.0
	_plate.position = Vector2(bar_x - 3, top_left.y - 2)
	_plate.size = Vector2(bar_w + icon_w + 6, 28)

	var boss_w := floorf(minf(160.0, safe.size.x - MARGIN * 2 - 8))
	boss_bar.layout(boss_w)
	boss_bar.position = Vector2(floorf(safe.get_center().x - boss_w * 0.5), top_left.y + 32)

	combo.position = Vector2(floorf(safe.end.x - MARGIN - combo.size.x), top_left.y + (56.0 if boss_bar.visible else 32.0))

	_layout_banner(safe)

	var arena := Rect2(game.position + Layout.ARENA_RECT.position, Layout.ARENA_RECT.size)
	var pos := arena.end - ultimate_button.size - ULTIMATE_INSET
	pos.x = minf(pos.x, safe.end.x - ultimate_button.size.x - MARGIN)
	pos.y = minf(pos.y, safe.end.y - ultimate_button.size.y - ULTIMATE_BOTTOM_CLEARANCE)
	ultimate_button.position = pos.floor()
	ultimate_label.size = ultimate_label.get_minimum_size()
	ultimate_label.position = Vector2(
		floorf(minf(ultimate_button.position.x + 16.0 - ultimate_label.size.x * 0.5, safe.end.x - MARGIN - ultimate_label.size.x)),
		ultimate_button.position.y - ultimate_label.size.y)
	_layout_celebration(safe)


func _layout_banner(safe: Rect2) -> void:
	banner.size = banner.get_minimum_size()
	var cx := safe.position.x + safe.size.x * 0.5
	var y := safe.position.y + (62.0 if boss_bar.visible or _boss_level else 40.0)
	banner.position = Vector2(floorf(cx - banner.size.x * 0.5), floorf(y))


func _layout_celebration(safe: Rect2) -> void:
	celebration.size = celebration.get_minimum_size()
	celebration.pivot_offset = celebration.size * 0.5
	celebration.position = Vector2(floorf(safe.get_center().x - celebration.size.x * 0.5),
			floorf(safe.position.y + safe.size.y * 0.3))


# --------------------------------------------------------------------------
# 訊號
# --------------------------------------------------------------------------

func _on_vigor_changed(current: int, maximum: int) -> void:
	vigor_bar.set_values(current, maximum)


func _on_exp_changed(current: int, needed: int) -> void:
	exp_bar.set_values(current, needed)


func _on_leveled_up(new_level: int) -> void:
	_set_level(new_level)
	level_badge.pivot_offset = level_badge.size * 0.5
	var t := create_tween()
	t.tween_property(level_badge, "scale", Vector2(1.5, 1.5), 0.08)
	t.tween_property(level_badge, "scale", Vector2.ONE, 0.18)
	show_level_pop(new_level)


## 「等級 N!」從徽章旁邊彈出、往上飄、淡出;徽章冒出閃光。
func show_level_pop(new_level: int) -> void:
	level_pop.text = tr("UI_LEVEL_POP") % new_level
	level_pop.size = level_pop.get_minimum_size()
	level_pop.visible = true
	level_pop.modulate.a = 1.0
	level_pop.pivot_offset = level_pop.size * 0.5
	var start := level_badge.position + Vector2(level_badge.size.x + 2, level_badge.size.y - 2)
	level_pop.position = start.floor()
	level_pop.scale = Vector2(0.4, 0.4)
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween().set_ignore_time_scale(true)
	_pop_tween.tween_property(level_pop, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(level_pop, "scale", Vector2.ONE, 0.1)
	_pop_tween.parallel().tween_property(level_pop, "position", start + Vector2(0, 8), CONFIG.level_pop_time).set_trans(Tween.TRANS_SINE)
	_pop_tween.parallel().tween_property(level_pop, "modulate:a", 0.0, 0.35).set_delay(CONFIG.level_pop_time - 0.35)
	_pop_tween.tween_callback(func() -> void: level_pop.visible = false)
	_spawn_fx(SPARKLE, level_badge.position + level_badge.size * 0.5)


func _set_level(level: int) -> void:
	level_label.text = str(level)


func _on_loyalty_changed(current: float, maximum: float) -> void:
	loyalty_bar.set_values(current, maximum)
	var ready := maximum > 0.0 and current >= maximum
	if ready and not _ultimate_ready:
		_show_ultimate()
	elif not ready and _ultimate_ready:
		_hide_ultimate()


func _show_ultimate() -> void:
	_ultimate_ready = true
	ultimate_button.disabled = false
	ultimate_button.visible = true
	ultimate_label.visible = true
	ultimate_button.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(ultimate_button, "scale", Vector2(1.15, 1.15), 0.12)
	t.tween_property(ultimate_button, "scale", Vector2.ONE, 0.1)


func _hide_ultimate() -> void:
	_ultimate_ready = false
	ultimate_button.visible = false
	ultimate_label.visible = false


func _on_ultimate_pressed() -> void:
	if not _ultimate_ready or ultimate_button.disabled:
		return
	ultimate_button.disabled = true      # 等 A 線發 ultimate_used,避免連按
	UiKit.tap_sound()
	Haptics.play(&"light")
	EventBus.ultimate_requested.emit()


func _on_ultimate_used() -> void:
	_hide_ultimate()
	cut_in.play(CONFIG.cut_in_time)


func _on_pause_pressed() -> void:
	Haptics.play(&"light")
	AppLifecycle.simulate_back()


func _on_player_damaged(_amount: int) -> void:
	var heart := _bar_icons[0]
	var base := Vector2(heart.position.x, heart.position.y)
	var t := create_tween()
	for dx: float in [-1.0, 1.0, -1.0, 0.0]:
		t.tween_property(heart, "position", base + Vector2(dx, 0), 0.04)


func _update_heartbeat() -> void:
	var heart := _bar_icons[0]
	if vigor_bar.is_low():
		# 「撲通、撲通」:每拍兩下
		var beat := fmod(_time * CONFIG.heartbeat_rate, 1.0)
		var s := 1.0
		if beat < 0.12:
			s = 1.0 + 0.35 * sin(beat / 0.12 * PI)
		elif beat > 0.2 and beat < 0.3:
			s = 1.0 + 0.2 * sin((beat - 0.2) / 0.1 * PI)
		heart.scale = Vector2(s, s)
	elif heart.scale != Vector2.ONE:
		heart.scale = Vector2.ONE


func _on_boss_hp_changed(current: int, maximum: int) -> void:
	var was_visible := boss_bar.visible
	boss_bar.set_hp(current, maximum)
	if boss_bar.visible != was_visible:
		relayout()


func _on_combo_changed(count: int) -> void:
	combo.set_count(count)


func _on_level_started(level_id: StringName) -> void:
	_banner_queue.clear()
	_boss_banner_shown = false
	_celebrating = false
	celebration.visible = false
	boss_bar.reset()
	combo.set_count(0)
	_boss_level = is_boss_level(level_id)
	var id := String(level_id)
	var key := "LEVEL_" + id.replace("-", "_").to_upper()
	var chapter_key := "CHAPTER_" + (id.split("-")[0] if id.contains("-") else "1")
	if tr(chapter_key) == chapter_key:
		chapter_key = "CHAPTER_1"
	var delay := 0.0
	if tr(key) != key:
		title_card.play(tr(chapter_key), tr(key), CONFIG.title_card_time)
		delay = CONFIG.title_card_time
	if _boss_level:
		_boss_banner_shown = true
		queue_banner(tr("UI_BOSS"), BOSS_BANNER_HOLD, true, delay)
	relayout()


func _on_wave_started(index: int, total: int) -> void:
	if _boss_level:
		return      # 頭目關只顯示「頭目來了!」
	var delay := 0.0
	if title_card.is_playing():
		delay = 0.3
	if index >= total and total > 1:
		queue_banner(tr("UI_WAVE_FINAL"), BANNER_HOLD, true, delay)
	else:
		queue_banner(tr("UI_WAVE") % [index, total], BANNER_HOLD, false, delay)


func _on_boss_phase_changed(phase: int) -> void:
	boss_bar.set_phase(phase)
	if not _boss_banner_shown:
		_boss_banner_shown = true
		queue_banner(tr("UI_BOSS"), BOSS_BANNER_HOLD, true)
	elif phase >= 2:
		queue_banner(tr("UI_BOSS_ANGRY"), BOSS_BANNER_HOLD, true)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


func _on_level_failed(_level_id: StringName) -> void:
	combo.set_count(0)
	_banner_queue.clear()


## 過關慶祝:大橫幅彈出、左右兩邊噴彩紙。
func celebrate() -> void:
	if _celebrating:
		return
	_celebrating = true
	combo.set_count(0)
	_hide_ultimate()
	_banner_queue.clear()
	banner.visible = false
	celebration.visible = true
	celebration.modulate.a = 1.0
	_layout_celebration(SafeArea.get_safe_rect())
	celebration.scale = Vector2(0.2, 0.2)
	celebration.rotation = -0.2
	if _celebration_tween != null and _celebration_tween.is_valid():
		_celebration_tween.kill()
	_celebration_tween = create_tween().set_ignore_time_scale(true)
	_celebration_tween.tween_property(celebration, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_celebration_tween.parallel().tween_property(celebration, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_celebration_tween.tween_property(celebration, "scale", Vector2.ONE, 0.12)
	_celebration_tween.tween_interval(maxf(0.2, CONFIG.celebration_time - 0.6))
	_celebration_tween.tween_property(celebration, "modulate:a", 0.0, 0.25)
	_celebration_tween.tween_callback(func() -> void: celebration.visible = false)
	var safe := SafeArea.get_safe_rect()
	var left := _spawn_fx(CONFETTI, Vector2(safe.position.x + 14, safe.position.y + safe.size.y * 0.32))
	var right := _spawn_fx(CONFETTI, Vector2(safe.end.x - 14, safe.position.y + safe.size.y * 0.32))
	if left != null:
		left.direction = Vector2(0.5, -1)
	if right != null:
		right.direction = Vector2(-0.5, -1)


func is_celebrating() -> bool:
	return celebration.visible


func _spawn_fx(scene: PackedScene, at: Vector2) -> CPUParticles2D:
	if scene == null:
		return null
	var fx := scene.instantiate() as CPUParticles2D
	if fx == null:
		return null
	fx.position = at
	fx.z_index = 0
	add_child(fx)
	return fx


static func is_boss_level(level_id: StringName) -> bool:
	var id := String(level_id)
	return id.ends_with(BOSS_LEVEL_SUFFIX) or id.ends_with(BOSS_LEVEL_SUFFIX.replace("-", "_")) or id.contains("boss")


# --------------------------------------------------------------------------
# 橫幅
# --------------------------------------------------------------------------

## 目前顯示中與排隊中的橫幅文字(測試用)。
func banner_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	if banner.visible:
		out.append(banner_label.text)
	for item in _banner_queue:
		out.append(String(item["text"]))
	return out


func queue_banner(text: String, hold: float, boss: bool, delay: float = 0.0) -> void:
	_banner_queue.append({"text": text, "hold": hold, "boss": boss, "delay": delay})
	if _banner_tween == null or not _banner_tween.is_running():
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty():
		banner.visible = false
		return
	var item: Dictionary = _banner_queue[0]
	var delay: float = item.get("delay", 0.0)
	if _banner_tween != null:
		_banner_tween.kill()
	if delay > 0.0:
		item["delay"] = 0.0
		banner.visible = false
		_banner_tween = create_tween()
		_banner_tween.tween_interval(delay)
		_banner_tween.tween_callback(_next_banner)
		return
	_banner_queue.pop_front()
	banner_label.text = item["text"]
	banner.self_modulate = Color(PaletteColors.VIOLET) if item["boss"] else Color.WHITE
	banner.visible = true
	_layout_banner(SafeArea.get_safe_rect())
	var rest := banner.position
	banner.position = rest - Vector2(0, 6)
	banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "position", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.18)
	if item["boss"]:
		for dx: float in [-2.0, 2.0, -2.0, 2.0, 0.0]:
			_banner_tween.tween_property(banner, "position", rest + Vector2(dx, 0), 0.05)
	_banner_tween.tween_interval(item["hold"])
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.25)
	_banner_tween.tween_callback(_next_banner)
