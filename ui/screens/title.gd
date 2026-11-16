extends Control
## 標題畫面(C10、CP5,DEV_PLAN 4.9)。B 線把它放在第 30 層 CanvasLayer。
##
## 介面:setup(has_save: bool);訊號 new_game_pressed、continue_pressed、credits_pressed。
## 「繼續冒險」只在有存檔時出現。
## 會動的東西:雲慢慢飄、標誌彈跳進場後輕輕浮動並偶爾閃光、金毛呼吸眨眼搖尾巴、
## 鬥牛犬在旁邊、石中劍閃光、花瓣飄落、按鈕依序滑入。

signal new_game_pressed
signal continue_pressed
signal credits_pressed

const CLOUD_SPEEDS: Array[float] = [3.0, 2.0, 4.5]
const SPARKLE: PackedScene = preload("res://assets/fx/particles/sparkle.tscn")
## 背景圖(304×512)上石中劍劍尖的位置。
const SWORD_TIP_IN_BACKDROP: Vector2 = Vector2(213, 220)

var continue_button: Button
var new_game_button: Button
var credits_button: Button

var _has_save: bool = false
var _backdrop: TextureRect
var _clouds: Array[TextureRect] = []
var _cloud_x: Array[float] = []
var _logo: TextureRect
var _subtitle: Label
var _goldie: Control
var _bulldog: Control
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
	_goldie = UiKit.sprite_box("res://assets/sprites/goldie/goldie_frames.tres", &"idle", 3)
	_goldie.name = "Goldie"
	add_child(_goldie)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", int(UiKit.GAP))
	add_child(_buttons)
	continue_button = UiKit.button(tr("UI_CONTINUE"))
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_buttons.add_child(continue_button)
	new_game_button = UiKit.button(tr("UI_NEW_GAME"))
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(func() -> void: new_game_pressed.emit())
	_buttons.add_child(new_game_button)
	credits_button = UiKit.button(tr("UI_CREDITS"), &"ButtonAlt")
	credits_button.name = "CreditsButton"
	credits_button.pressed.connect(func() -> void: credits_pressed.emit())
	_buttons.add_child(credits_button)

	_version = UiKit.label(tr("UI_VERSION") % ProjectSettings.get_setting("application/config/version", "0.1.0"),
			&"LabelLight", HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_version)

	_apply_save_state()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_play_intro()


## 由 B 線呼叫:有存檔時顯示「繼續冒險」。可在加入場景前或後呼叫。
func setup(has_save: bool) -> void:
	_has_save = has_save
	if is_node_ready():
		_apply_save_state()
		_layout()


func _apply_save_state() -> void:
	continue_button.visible = _has_save
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
	_goldie.position = center + Vector2(-44, -24)
	_goldie.position.y = minf(_goldie.position.y, _buttons.position.y - _goldie.size.y - 2.0)
	_bulldog.position = _goldie.position + Vector2(-38, 22)
	_glint.position = _backdrop.position + SWORD_TIP_IN_BACKDROP - Vector2(4, 4)
	_petals.position = Vector2(cx - 40, safe.position.y + 60)
	_version.size = _version.get_minimum_size()
	_version.position = Vector2(floorf(safe.end.x - _version.size.x - 4), floorf(minf(safe.end.y, screen.y) - _version.size.y - 2))
