extends Control
## 過關結算(C10、CP5,DEV_PLAN 4.9、4.10)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(result: Dictionary);訊號 continue_pressed。
## result 的鍵(B 線提供):level_id、level_name(翻譯鍵)、victory、time_sec、kills、
## tricks(這一關新學的把戲 id)、hero_level、next_is_camp、is_final(打敗黑騎士);
## v2.2 另有 stars(0 至 3)、star_goals(每項 {key, met, text};顯示 text,沒有 text 才用 tr(key))、
## best_stars、new_best、level_index(0 起算)、level_count。缺少新鍵時(舊資料)那幾區自動隱藏。
##
## 演出:面板彈出 → 星星逐顆亮起(star 音效、音高一顆比一顆高、星星爆開)→ 數字遞增 →
## 「新紀錄!」彈出。按「繼續」隨時可以離開。過關短曲(B 線呼叫 Music.play(&"victory"))
## 正在播時不再播 clear 音效,避免兩段音樂疊在一起。
## v2.3(CS7):result.difficulty == &"hard" 時,面板右上角有紅色「困難」標記。

signal continue_pressed

const PANEL_WIDTH: float = 164.0
const STAR_BURST: PackedScene = preload("res://assets/fx/particles/star_burst.tscn")
const CONFETTI: PackedScene = preload("res://assets/fx/particles/confetti.tscn")
const STAR_FULL: Texture2D = preload("res://assets/ui/star_big_full.png")
const STAR_EMPTY: Texture2D = preload("res://assets/ui/star_big_empty.png")
const SMALL_FULL: Texture2D = preload("res://assets/ui/star_small_full.png")
const SMALL_EMPTY: Texture2D = preload("res://assets/ui/star_small_empty.png")
const STAR_DELAY: float = 0.35
const COUNT_TIME: float = 0.6

var continue_button: Button
var title_label: Label
var level_label: Label
var time_value: Label
var kills_value: Label
var level_value: Label
var tricks_row: HBoxContainer
var footer_label: Label
var stars_row: HBoxContainer
var star_rects: Array[TextureRect] = []
var goals_box: VBoxContainer
var new_best_label: Label
var progress: ChapterStrip
var progress_label: Label
var hard_badge: NinePatchRect

var _result: Dictionary = {}
var _panel: PanelContainer
var _ribbon: PanelContainer
var _goldie: Control
var _anim_tween: Tween
var _star_tween: Tween
var _shown_stars: int = 0


func _ready() -> void:
	UiKit.setup_root(self)
	add_child(UiKit.dim(Color(PaletteColors.INK, 0.55)))
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	_panel.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)

	level_label = UiKit.label("", &"LabelSoft")
	box.add_child(level_label)

	# Goldie cheering beside the three stars
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override(&"separation", 2)
	box.add_child(hero_row)
	var frames := load("res://assets/sprites/goldie/goldie_frames.tres") as SpriteFrames
	var anim := &"victory" if frames != null and frames.has_animation(&"victory") else &"idle"
	_goldie = UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", anim, 2)
	hero_row.add_child(_goldie)
	stars_row = HBoxContainer.new()
	stars_row.name = "Stars"
	stars_row.add_theme_constant_override(&"separation", 3)
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_child(stars_row)
	for i in 3:
		var star := UiKit.texture_rect(STAR_EMPTY)
		star.name = "Star%d" % i
		star.pivot_offset = star.size * 0.5
		stars_row.add_child(star)
		star_rects.append(star)

	goals_box = VBoxContainer.new()
	goals_box.name = "Goals"
	goals_box.add_theme_constant_override(&"separation", 0)
	box.add_child(goals_box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", -2)
	box.add_child(grid)
	time_value = _stat_row(grid, tr("UI_TIME"))
	kills_value = _stat_row(grid, tr("UI_KILLS"))
	level_value = _stat_row(grid, tr("UI_LEVEL"))

	box.add_child(UiKit.label(tr("UI_TRICKS"), &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	tricks_row = HBoxContainer.new()
	tricks_row.add_theme_constant_override(&"separation", 4)
	tricks_row.custom_minimum_size = Vector2(0, 16)
	box.add_child(tricks_row)

	progress_label = UiKit.label("", &"LabelSoft")
	box.add_child(progress_label)
	progress = ChapterStrip.new()
	progress.name = "Progress"
	box.add_child(progress)

	footer_label = UiKit.wrapped_label("", PANEL_WIDTH - 16, &"", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(footer_label)

	continue_button = UiKit.button(tr("UI_NEXT"))
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	var button_row := CenterContainer.new()
	button_row.add_child(continue_button)
	box.add_child(button_row)

	_ribbon = PanelContainer.new()
	_ribbon.theme_type_variation = &"Ribbon"
	title_label = UiKit.label("", &"LabelLight")
	_ribbon.add_child(title_label)
	add_child(_ribbon)

	hard_badge = NinePatchRect.new()
	hard_badge.name = "HardBadge"
	hard_badge.texture = preload("res://assets/ui/badge_hard.png")
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		hard_badge.set_patch_margin(side, 5)
	hard_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hard_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_text := UiKit.label(tr("UI_HARD_BADGE"), &"LabelLight")
	badge_text.name = "Text"
	hard_badge.add_child(badge_text)
	hard_badge.visible = false
	add_child(hard_badge)

	new_best_label = UiKit.label(tr("UI_NEW_BEST"), &"LabelPop")
	new_best_label.name = "NewBest"
	new_best_label.visible = false
	add_child(new_best_label)

	_apply()
	get_viewport().size_changed.connect(_layout)


## 由 B 線呼叫,傳入這一關的結算資料。
func setup(result: Dictionary) -> void:
	_result = result
	if is_node_ready():
		_apply()
	if not _jingle_playing():
		UiKit.play_sfx(&"clear")


func _jingle_playing() -> bool:
	var music := get_node_or_null("/root/Music")
	if music == null or not music.has_method(&"playing_track"):
		return false
	var track: StringName = music.call(&"playing_track")
	return track == &"victory" or track == &"chapter_clear"


func _stat_row(grid: GridContainer, title: String) -> Label:
	grid.add_child(UiKit.label(title, &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	var v := UiKit.label("-", &"", HORIZONTAL_ALIGNMENT_RIGHT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
	return v


func stars() -> int:
	return clampi(int(_result.get("stars", 0)), 0, 3)


func has_stars() -> bool:
	return _result.has("stars")


func _apply() -> void:
	var is_final: bool = _result.get("is_final", false)
	hard_badge.visible = StringName(str(_result.get("difficulty", "normal"))) == &"hard"
	title_label.text = tr("UI_THE_END") if is_final else tr("UI_LEVEL_CLEAR")
	var level_name := String(_result.get("level_name", ""))
	level_label.text = tr(level_name) if not level_name.is_empty() else ""
	time_value.text = UiKit.format_time(float(_result.get("time_sec", 0.0)))
	kills_value.text = str(int(_result.get("kills", 0)))
	level_value.text = "%s %d" % [tr("UI_LEVEL_SHORT"), int(_result.get("hero_level", GameState.hero_level))]
	for c in tricks_row.get_children():
		c.queue_free()
	var tricks: Array = _result.get("tricks", [])
	if tricks.is_empty():
		tricks_row.add_child(UiKit.label(tr("UI_NONE"), &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT))
	for id: Variant in tricks:
		tricks_row.add_child(_trick_chip(StringName(str(id))))
	if is_final:
		footer_label.text = tr("UI_THANKS")
	elif _result.get("next_is_camp", false):
		footer_label.text = tr("UI_NEXT_CAMP")
	else:
		footer_label.text = ""
	footer_label.visible = not footer_label.text.is_empty()
	# stars and goals (v2.2)
	stars_row.visible = has_stars()
	for star in star_rects:
		star.texture = STAR_EMPTY
		star.scale = Vector2.ONE
	_shown_stars = 0
	for c in goals_box.get_children():
		c.queue_free()
	var goals: Array = _result.get("star_goals", [])
	for goal: Variant in goals:
		if goal is Dictionary:
			goals_box.add_child(_goal_row(goal))
	goals_box.visible = not goals.is_empty()
	new_best_label.visible = false
	# chapter progress (v2.2)
	var has_progress := _result.has("level_index") and _result.has("level_count") and int(_result["level_count"]) > 0
	progress.visible = has_progress
	progress_label.visible = has_progress
	if has_progress:
		var idx := int(_result["level_index"])
		var total := int(_result["level_count"])
		progress.set_progress(idx, total)
		progress_label.text = tr("UI_CHAPTER_PROGRESS") % [mini(idx + 1, total), total]
	_layout()
	_start_show.call_deferred()


func _goal_row(goal: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	var met: bool = goal.get("met", false)
	var icon := UiKit.texture_rect(SMALL_FULL if met else SMALL_EMPTY)
	var icon_box := CenterContainer.new()
	icon_box.add_child(icon)
	row.add_child(icon_box)
	var text := String(goal.get("text", ""))
	if text.is_empty():
		text = tr(String(goal.get("key", "")))
	var l := UiKit.label(text, &"" if met else &"LabelSoft", HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(l)
	return row


## 星星、數字、新紀錄的演出(setup 之後下一格開始;測試可以先讀到最終數值)。
func _start_show() -> void:
	if not is_inside_tree():
		return
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	if _star_tween != null and _star_tween.is_valid():
		_star_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_anim_tween = create_tween()
	_anim_tween.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var time_sec := float(_result.get("time_sec", 0.0))
	var kills := int(_result.get("kills", 0))
	_anim_tween.parallel().tween_method(func(v: float) -> void: time_value.text = UiKit.format_time(v),
			0.0, time_sec, COUNT_TIME).set_delay(0.1)
	_anim_tween.parallel().tween_method(func(v: float) -> void: kills_value.text = str(int(round(v))),
			0.0, float(kills), COUNT_TIME).set_delay(0.1)
	# 星星與新紀錄另用一條時間線,和數字遞增同時進行
	var seq := create_tween()
	seq.tween_interval(0.3)
	if has_stars():
		for i in stars():
			if i > 0:
				seq.tween_interval(STAR_DELAY)
			seq.tween_callback(_light_star.bind(i))
	if _result.get("new_best", false):
		seq.tween_interval(0.3)
		seq.tween_callback(_show_new_best)
	if _result.get("is_final", false):
		seq.tween_callback(_final_confetti)
	_star_tween = seq


func _light_star(i: int) -> void:
	if i >= star_rects.size():
		return
	var star := star_rects[i]
	star.texture = STAR_FULL
	star.pivot_offset = star.size * 0.5
	star.scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(star, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "scale", Vector2.ONE, 0.12)
	_shown_stars = i + 1
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.call(&"play", &"star", 0.0, 1.0 + 0.12 * i)
	Haptics.play(&"light")
	var fx := STAR_BURST.instantiate() as Node2D
	fx.position = star.get_global_rect().get_center() - get_global_rect().position
	add_child(fx)


## 目前已經亮起的星星數(測試用)。
func shown_stars() -> int:
	return _shown_stars


func _show_new_best() -> void:
	new_best_label.visible = true
	_layout()
	new_best_label.pivot_offset = new_best_label.size * 0.5
	new_best_label.scale = Vector2(0.2, 0.2)
	new_best_label.rotation = -0.15
	var t := create_tween()
	t.tween_property(new_best_label, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(new_best_label, "scale", Vector2.ONE, 0.1)
	t.tween_property(new_best_label, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(new_best_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
	UiKit.play_sfx(&"perfect")


func _final_confetti() -> void:
	var safe := SafeArea.get_safe_rect()
	for x: float in [safe.position.x + 12, safe.end.x - 12]:
		var fx := CONFETTI.instantiate() as CPUParticles2D
		fx.position = Vector2(x, safe.position.y + safe.size.y * 0.25)
		fx.direction = Vector2(0.5 if x < safe.get_center().x else -0.5, -1)
		add_child(fx)


func _trick_chip(id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var path := "res://assets/icons/tricks/%s.png" % id
	if ResourceLoader.exists(path):
		row.add_child(UiKit.texture_rect(load(path) as Texture2D))
	var key := "TRICK_%s_NAME" % String(id).to_upper()
	row.add_child(UiKit.label(tr(key) if tr(key) != key else String(id), &"", HORIZONTAL_ALIGNMENT_LEFT))
	return row


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	_panel.size = _panel.get_minimum_size()
	_ribbon.size = _ribbon.get_minimum_size()
	var total := Vector2(_panel.size.x, _panel.size.y + _ribbon.size.y * 0.5)
	var pos := UiKit.center_in(safe, total)
	_ribbon.position = Vector2(floorf(safe.get_center().x - _ribbon.size.x * 0.5), pos.y)
	_panel.position = Vector2(pos.x, pos.y + floorf(_ribbon.size.y * 0.5))
	_panel.pivot_offset = _panel.size * 0.5
	if hard_badge.visible:
		var text := hard_badge.get_node(^"Text") as Label
		text.size = text.get_minimum_size()
		hard_badge.size = Vector2(text.size.x + 10.0, 16.0)
		text.position = Vector2(5, 1)
		hard_badge.position = Vector2(floorf(_panel.position.x + _panel.size.x - hard_badge.size.x + 4.0),
				floorf(_panel.position.y - 6.0))
	if new_best_label.visible:
		new_best_label.size = new_best_label.get_minimum_size()
		var anchor := stars_row.get_global_rect()
		new_best_label.position = Vector2(floorf(minf(anchor.end.x - new_best_label.size.x * 0.4,
				safe.end.x - new_best_label.size.x - 2)), floorf(anchor.position.y - new_best_label.size.y * 0.6))
