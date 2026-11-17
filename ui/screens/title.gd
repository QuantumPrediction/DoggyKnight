extends Control
## 標題畫面(C10、CP5,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(has_save: bool);訊號 new_game_pressed、continue_pressed、credits_pressed。
## 「繼續冒險」只在有存檔時出現。
## 會動的東西:雲慢慢飄、標誌彈跳進場後輕輕浮動並偶爾閃光、金毛呼吸眨眼搖尾巴、
## 鬥牛犬在旁邊、梅林拄著星星手杖(偶爾施法冒星光,v2.3)、石中劍閃光、花瓣飄落、按鈕依序滑入。
##
## 難度(v2.3,DEV_PLAN 4.11、CS6):GameState.chapter_cleared 為 true(打完第一章)時,
## 按「開始冒險」會先出現難度選擇(一般 / 困難),選好後設定 GameState.difficulty 才發 new_game_pressed;
## 還沒打完第一章時直接設為 &"normal" 再發訊號。
##
## v2.4(CV5,DEV_PLAN 4.12):
## - 「無盡試煉」(紫色)只在 GameState.chapter_cleared 時出現;按下先設 GameState.mode = &"endless"
##   再發 endless_pressed。「開始冒險」「繼續冒險」會把 mode 設回 &"story"。
## - 「訓練」發 training_pressed(B 線打開 D 線的 game/camp/training.tscn)。和「製作名單」並排在最下面。
## - 按鈕最多三行:「繼續冒險」/「開始冒險」+「無盡試煉」/「訓練」+「製作名單」(180×320 加瀏海也放得下)。

signal new_game_pressed
signal continue_pressed
signal credits_pressed
signal endless_pressed
signal training_pressed

const SMALL_BUTTON: Vector2 = Vector2(62, 26)

const CLOUD_SPEEDS: Array[float] = [3.0, 2.0, 4.5]
const SPARKLE: PackedScene = preload("res://assets/fx/particles/sparkle.tscn")
## 背景圖(304×512)上石中劍劍尖的位置。
const SWORD_TIP_IN_BACKDROP: Vector2 = Vector2(213, 220)

var continue_button: Button
var new_game_button: Button
var credits_button: Button
var endless_button: Button
var training_button: Button
var normal_button: Button
var hard_button: Button
var back_button: Button
var difficulty_panel: PanelContainer

var _has_save: bool = false
var _backdrop: TextureRect
var _clouds: Array[TextureRect] = []
var _cloud_x: Array[float] = []
var _logo: TextureRect
var _subtitle: Label
var _goldie: Control
var _bulldog: Control
var _merlin: Control
var _cleared_label: Label
var _next_cast: float = 3.5
var _glint: AnimatedSprite2D
var _petals: CPUParticles2D
var _buttons: VBoxContainer
var _version: Label
var _time: float = 0.0
var _logo_rest: Vector2 = Vector2.ZERO
var _intro_done: bool = false
var _next_sparkle: float = 2.0


func _ready() -> void:
	UiKit.setup_root(self)
	_backdrop = UiKit.backdrop(preload("res://assets/ui/title_bg.png"))
	add_child(_backdrop)
	for i in 3:
		var cloud := UiKit.texture_rect(load("res://assets/ui/cloud_%d.png" % i) as Texture2D)
		cloud.name = "Cloud%d" % i
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_x.append([20.0, 120.0, 70.0][i])
	_glint = AnimatedSprite2D.new()
	_glint.name = "SwordGlint"
	_glint.sprite_frames = load("res://assets/backgrounds/anim/sword_glint_frames.tres")
	_glint.centered = false
	_glint.play(&"default")
	add_child(_glint)
	_petals = _make_petals()
	add_child(_petals)
	_logo = UiKit.texture_rect(preload("res://assets/ui/logo_2x.png"))
	_logo.name = "Logo"
	add_child(_logo)
	_subtitle = UiKit.label(tr("CHAPTER_1"), &"LabelLight")
	add_child(_subtitle)
	_bulldog = UiKit.sprite_box("res://assets/sprites/bulldog/bulldog_frames.tres", &"idle", 2)
	_bulldog.name = "Bulldog"
	add_child(_bulldog)
	_merlin = UiKit.sprite_box("res://assets/sprites/merlin/merlin_frames.tres", &"idle", 2)
	_merlin.name = "Merlin"
	var merlin_sprite := _merlin.get_node_or_null(^"Sprite") as AnimatedSprite2D
	if merlin_sprite != null:
		merlin_sprite.flip_h = true
		merlin_sprite.animation_finished.connect(func() -> void: merlin_sprite.play(&"idle"))
	add_child(_merlin)
	_goldie = UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", &"idle", 2)   # v2.5:32 px 的圖放大 2 倍
	_goldie.name = "Goldie"
	add_child(_goldie)
	_cleared_label = UiKit.label(tr("UI_CHAPTER_CLEARED"), &"LabelPop")
	_cleared_label.name = "ChapterCleared"
	_cleared_label.visible = GameState.chapter_cleared
	add_child(_cleared_label)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", int(UiKit.GAP))
	add_child(_buttons)
	continue_button = UiKit.button(tr("UI_CONTINUE"))
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(func() -> void:
		GameState.mode = &"story"
		continue_pressed.emit())
	_buttons.add_child(continue_button)
	# 「開始冒險」與「無盡試煉」並排(還沒通關時「開始冒險」佔滿整行),小螢幕也放得下
	var mid := HBoxContainer.new()
	mid.name = "PlayButtons"
	mid.add_theme_constant_override(&"separation", int(UiKit.GAP))
	_buttons.add_child(mid)
	new_game_button = UiKit.button(tr("UI_NEW_GAME"), &"", SMALL_BUTTON)
	new_game_button.name = "NewGameButton"
	new_game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_game_button.pressed.connect(_on_new_game)
	mid.add_child(new_game_button)
	endless_button = UiKit.button(tr("UI_ENDLESS"), &"ButtonViolet", SMALL_BUTTON)
	endless_button.name = "EndlessButton"
	endless_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless_button.pressed.connect(_on_endless)
	mid.add_child(endless_button)
	var row := HBoxContainer.new()
	row.name = "SmallButtons"
	row.add_theme_constant_override(&"separation", int(UiKit.GAP))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_child(row)
	training_button = UiKit.button(tr("UI_TRAINING"), &"ButtonAlt", SMALL_BUTTON)
	training_button.name = "TrainingButton"
	training_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training_button.pressed.connect(func() -> void: training_pressed.emit())
	row.add_child(training_button)
	credits_button = UiKit.button(tr("UI_CREDITS"), &"ButtonAlt", SMALL_BUTTON)
	credits_button.name = "CreditsButton"
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.pressed.connect(func() -> void: credits_pressed.emit())
	row.add_child(credits_button)

	_version = UiKit.label(tr("UI_VERSION") % ProjectSettings.get_setting("application/config/version", "0.1.0"),
			&"LabelLight", HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_version)

	_build_difficulty_panel()
	_apply_save_state()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_play_intro()


func _build_difficulty_panel() -> void:
	difficulty_panel = PanelContainer.new()
	difficulty_panel.name = "DifficultyPanel"
	difficulty_panel.visible = false
	add_child(difficulty_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	difficulty_panel.add_child(box)
	box.add_child(UiKit.label(tr("UI_DIFFICULTY"), &""))
	normal_button = UiKit.button(tr("UI_DIFFICULTY_NORMAL"), &"", Vector2(124, 28))
	normal_button.name = "NormalButton"
	normal_button.pressed.connect(func() -> void: _start(&"normal"))
	box.add_child(_centered(normal_button))
	box.add_child(UiKit.label(tr("UI_DIFFICULTY_NORMAL_DESC"), &"LabelSoft"))
	hard_button = UiKit.button(tr("UI_DIFFICULTY_HARD"), &"ButtonAlt", Vector2(124, 28))
	hard_button.name = "HardButton"
	hard_button.pressed.connect(func() -> void: _start(&"hard"))
	box.add_child(_centered(hard_button))
	box.add_child(UiKit.label(tr("UI_DIFFICULTY_HARD_DESC"), &"LabelSoft"))
	back_button = UiKit.button(tr("UI_BACK"), &"ButtonAlt", Vector2(64, 24))
	back_button.name = "BackButton"
	back_button.pressed.connect(func() -> void: show_difficulty(false))
	box.add_child(_centered(back_button))


func _centered(c: Control) -> CenterContainer:
	var row := CenterContainer.new()
	row.add_child(c)
	return row


## 「開始冒險」:打完第一章才問難度,否則直接用一般難度。
func _on_new_game() -> void:
	if GameState.chapter_cleared:
		show_difficulty(true)
	else:
		_start(&"normal")


func show_difficulty(on: bool) -> void:
	difficulty_panel.visible = on
	_buttons.visible = not on
	if on:
		difficulty_panel.pivot_offset = difficulty_panel.size * 0.5
		difficulty_panel.scale = Vector2(0.9, 0.9)
		var t := create_tween()
		t.tween_property(difficulty_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_layout()


func is_difficulty_open() -> bool:
	return difficulty_panel.visible


## 「無盡試煉」:先設定模式再發訊號(B 線收到後開始無盡試煉)。
func _on_endless() -> void:
	if not GameState.chapter_cleared:
		return
	GameState.mode = &"endless"
	endless_pressed.emit()


func _start(difficulty: StringName) -> void:
	GameState.difficulty = difficulty
	GameState.mode = &"story"
	difficulty_panel.visible = false
	_buttons.visible = true
	new_game_pressed.emit()


## 由 B 線呼叫:有存檔時顯示「繼續冒險」。可在加入場景前或後呼叫。
func setup(has_save: bool) -> void:
	_has_save = has_save
	if is_node_ready():
		_apply_save_state()
		_layout()


func _apply_save_state() -> void:
	continue_button.visible = _has_save
	endless_button.visible = GameState.chapter_cleared
	_cleared_label.visible = GameState.chapter_cleared
	# 有存檔時「繼續」是主要按鈕(金色),「開始冒險」改為次要(藍色)。
	new_game_button.theme_type_variation = &"ButtonAlt" if _has_save else &""


func _make_petals() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Petals"
	p.texture = load("res://assets/backgrounds/anim/p_petal.png")
	p.amount = 10
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(110, 4)
	p.direction = Vector2(1, 0.5)
	p.spread = 20.0
	p.gravity = Vector2(0, 3)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	return p


func _play_intro() -> void:
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2(0.2, 0.2)
	_logo.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.15)
	t.tween_property(_logo, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(_logo, "scale", Vector2(1.12, 1.12), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_logo, "scale", Vector2.ONE, 0.14)
	t.tween_property(_subtitle, "modulate:a", 1.0, 0.25)
	t.tween_callback(func() -> void: _intro_done = true)
	for i in _buttons.get_child_count():
		var b := _buttons.get_child(i) as Control
		b.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(0.2 + 0.08 * i)
		bt.tween_property(b, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_time += delta
	for i in _clouds.size():
		_cloud_x[i] += CLOUD_SPEEDS[i] * delta
		var screen_w := SafeArea.get_screen_size().x
		if _cloud_x[i] > screen_w + 4:
			_cloud_x[i] = -_clouds[i].size.x - 4
		_clouds[i].position.x = floorf(_cloud_x[i])
	_next_cast -= delta
	if _next_cast <= 0.0:
		_next_cast = 5.0
		_merlin_cast()
	if _intro_done:
		# 標誌輕輕浮動
		_logo.position.y = _logo_rest.y + roundf(sin(_time * 1.6) * 1.0)
		_next_sparkle -= delta
		if _next_sparkle <= 0.0:
			_next_sparkle = 2.4
			var fx := SPARKLE.instantiate() as Node2D
			fx.position = _logo.position + Vector2(randf_range(8, _logo.size.x - 8), randf_range(4, _logo.size.y - 4))
			add_child(fx)
	_layout()


## 梅林偶爾舉起手杖,星星冒出星光。
func _merlin_cast() -> void:
	var spr := _merlin.get_node_or_null(^"Sprite") as AnimatedSprite2D
	if spr == null or not spr.sprite_frames.has_animation(&"cast"):
		return
	spr.sprite_frames.set_animation_loop(&"cast", false)
	spr.play(&"cast")
	var fx := SPARKLE.instantiate() as Node2D
	fx.position = _merlin.position + Vector2(6, 2)
	add_child(fx)


func _layout() -> void:
	if not is_inside_tree():
		return
	var safe := SafeArea.get_safe_rect()
	var screen := SafeArea.get_screen_size()
	UiKit.place_backdrop(_backdrop)
	var cx := safe.get_center().x
	_logo_rest = Vector2(floorf(cx - _logo.size.x * 0.5), floorf(safe.position.y + 44.0))
	_logo.position.x = _logo_rest.x
	if not _intro_done:
		_logo.position.y = _logo_rest.y
	_subtitle.size = _subtitle.get_minimum_size()
	_subtitle.position = Vector2(floorf(cx - _subtitle.size.x * 0.5), _logo_rest.y + _logo.size.y + 4.0)
	for i in _clouds.size():
		_clouds[i].position.y = floorf(safe.position.y + [14.0, 92.0, 30.0][i])
	_buttons.size = _buttons.get_minimum_size()
	var bottom := minf(safe.end.y, screen.y) - 24.0
	_buttons.position = Vector2(floorf(cx - _buttons.size.x * 0.5), floorf(bottom - _buttons.size.y))
	# 金毛站在小丘上(背景圖中心 = 畫面中心),鬥牛犬在她左後方;石中劍在右邊的小坡上
	var center := (screen * 0.5).floor()
	_goldie.position = center + Vector2(-34, -14)
	_goldie.position.y = minf(_goldie.position.y, _buttons.position.y - _goldie.size.y - 2.0)
	_bulldog.position = _goldie.position + Vector2(-40, 8)
	_merlin.position = _goldie.position + Vector2(44, 6)
	_cleared_label.size = _cleared_label.get_minimum_size()
	_cleared_label.position = Vector2(floorf(cx - _cleared_label.size.x * 0.5), _subtitle.position.y + _subtitle.size.y + 1.0)
	difficulty_panel.size = difficulty_panel.get_combined_minimum_size()
	difficulty_panel.position = Vector2(floorf(cx - difficulty_panel.size.x * 0.5),
			floorf(bottom - difficulty_panel.size.y + 4.0))
	_glint.position = _backdrop.position + SWORD_TIP_IN_BACKDROP - Vector2(4, 4)
	_petals.position = Vector2(cx - 40, safe.position.y + 60)
	_version.size = _version.get_minimum_size()
	_version.position = Vector2(floorf(safe.end.x - _version.size.x - 4), floorf(minf(safe.end.y, screen.y) - _version.size.y - 2))
