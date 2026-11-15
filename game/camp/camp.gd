class_name Camp
extends Node
## 營地(DEV_PLAN 11 D1、4.9)。
##
## 夜裡的圓桌與營火,卸下盔甲的金毛趴著搖尾巴。三個入口:
## - 小遊戲「拉扯王室卷軸」(玩完回到這裡,獎勵已套用到 GameState)
## - 同伴(預留,按下顯示「即將開放」)
## - 繼續冒險:發出 EventBus.camp_left。營地不會自己消失,由 B 線的流程移除。
##
## 進入時(_ready)發出 EventBus.camp_entered。
## 畫面:放在 CanvasLayer(CampConfig.canvas_layer)內,用 SafeArea 排版,
## 填滿任何大小的畫面(180×320 至 196×426 等),畫面大小改變時重新排版。

const GOLDIE_FRAMES_PATH: String = "res://assets/sprites/goldie/goldie_frames.tres"
const DEFAULT_MINIGAME_PATH: String = "res://game/minigames/scroll/scroll_minigame.tscn"

## 小遊戲開始時發出(給沙盒與測試看)。
signal minigame_opened(minigame: MinigameBase)
signal minigame_closed(score: int, grade: int)

@export var config: CampConfig

var minigame_plays: int = 0
var last_grade: int = -1
var has_left: bool = false

var _layer: CanvasLayer
var _root: Control
var _backdrop: Control
var _front: Control
var _goldie: AnimatedSprite2D
var _fire: AnimatedSprite2D
var _title: Label
var _vigor_label: Label
var _satisfaction_label: Label
var _bonus_label: Label
var _menu: VBoxContainer
var _minigame_button: Button
var _companion_button: Button
var _continue_button: Button
var _toast: Label
var _toast_left: float = 0.0
var _minigame: MinigameBase
var _time: float = 0.0
var _shown_vigor: float = 0.0
var _shown_satisfaction: float = 0.0
var _goldie_spot: Vector2 = Vector2.ZERO
var _fire_spot: Vector2 = Vector2.ZERO
var _table_spot: Vector2 = Vector2.ZERO


func _ready() -> void:
	if config == null:
		config = CampConfig.new()
	if config.goldie_frames == null and ResourceLoader.exists(GOLDIE_FRAMES_PATH):
		config.goldie_frames = load(GOLDIE_FRAMES_PATH) as SpriteFrames
	if config.minigame_scene == null and ResourceLoader.exists(DEFAULT_MINIGAME_PATH):
		config.minigame_scene = load(DEFAULT_MINIGAME_PATH) as PackedScene
	_build()
	_shown_vigor = _vigor_ratio()
	_shown_satisfaction = _satisfaction_ratio()
	_refresh_stats()
	_layout()
	EventBus.camp_entered.emit()


func _process(delta: float) -> void:
	_time += delta
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	_shown_vigor = move_toward(_shown_vigor, _vigor_ratio(), delta * 0.8)
	_shown_satisfaction = move_toward(_shown_satisfaction, _satisfaction_ratio(), delta * 0.8)
	if _backdrop.visible:
		_backdrop.queue_redraw()
		_front.queue_redraw()


## 目前開著的小遊戲(沒有時是 null)。
func get_minigame() -> MinigameBase:
	return _minigame


func is_menu_visible() -> bool:
	return _menu.visible


## 按下「拉扯王室卷軸」。測試與沙盒也可以直接呼叫。
func open_minigame() -> void:
	if has_left or _minigame != null:
		return
	Sfx.play(&"ui_tap")
	if config.minigame_plays_per_visit > 0 and minigame_plays >= config.minigame_plays_per_visit:
		_show_toast(tr("CAMP_MINIGAME_DONE"))
		return
	if config.minigame_scene == null:
		_show_toast(tr("UI_COMING_SOON"))
		return
	_minigame = config.minigame_scene.instantiate() as MinigameBase
	if _minigame == null:
		push_error("CampConfig.minigame_scene 的根節點必須繼承 MinigameBase")
		return
	_minigame.finished.connect(_on_minigame_finished)
	_minigame.closed.connect(_on_minigame_closed)
	_set_camp_visible(false)
	minigame_opened.emit(_minigame)
	_root.add_child(_minigame)


## 按下「同伴」(預留入口)。
func open_companion() -> void:
	if has_left:
		return
	Sfx.play(&"ui_tap")
	_show_toast(tr("UI_COMING_SOON"))


## 按下「繼續冒險」。
func leave_camp() -> void:
	if has_left or _minigame != null:
		return
	has_left = true
	Sfx.play(&"ui_tap")
	for button: Button in [_minigame_button, _companion_button, _continue_button]:
		button.disabled = true
	EventBus.camp_left.emit()


func _on_minigame_finished(_score: int, grade: int) -> void:
	minigame_plays += 1
	last_grade = grade


func _on_minigame_closed() -> void:
	var finished_score := _minigame.score
	var finished_grade := _minigame.grade
	_minigame.queue_free()
	_minigame = null
	_set_camp_visible(true)
	_refresh_stats()
	_layout()
	minigame_closed.emit(finished_score, finished_grade)


func _set_camp_visible(value: bool) -> void:
	for node: CanvasItem in [_backdrop, _front, _title, _vigor_label, _satisfaction_label, _bonus_label, _menu]:
		node.visible = value
	if not value:
		_toast.visible = false
	_refresh_stats()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_left = config.toast_sec
	_toast.visible = true


func _vigor_ratio() -> float:
	var stats := GameState.player_stats
	if stats == null or stats.max_vigor <= 0:
		return 0.0
	return clampf(float(GameState.vigor) / stats.max_vigor, 0.0, 1.0)


func _satisfaction_ratio() -> float:
	return clampf(GameState.satisfaction / 100.0, 0.0, 1.0)


func _refresh_stats() -> void:
	if _vigor_label == null:
		return
	_bonus_label.visible = _menu.visible and GameState.next_level_bonus > 0.0
	_bonus_label.text = tr("CAMP_BONUS") % roundi(GameState.next_level_bonus * 100.0)


# --- 建立畫面 ---

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Layer"
	_layer.layer = config.canvas_layer
	add_child(_layer)

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MinigameUi.apply_shared_theme(_root)
	_layer.add_child(_root)
	_root.resized.connect(_layout)

	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	_root.add_child(_backdrop)

	if config.fire_frames != null:
		_fire = AnimatedSprite2D.new()
		_fire.name = "Fire"
		_fire.sprite_frames = config.fire_frames
		if config.fire_frames.has_animation(config.fire_animation):
			_fire.play(config.fire_animation)
		_backdrop.add_child(_fire)

	_goldie = AnimatedSprite2D.new()
	_goldie.name = "Goldie"
	_goldie.sprite_frames = config.goldie_frames
	_goldie.scale = Vector2.ONE * config.goldie_scale
	if config.goldie_frames != null:
		if config.goldie_frames.has_animation(config.goldie_animation):
			_goldie.play(config.goldie_animation)
		elif config.goldie_frames.has_animation(&"idle"):
			_goldie.play(&"idle")
	_backdrop.add_child(_goldie)

	_front = Control.new()
	_front.name = "Front"
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	_root.add_child(_front)

	_title = MinigameUi.make_label(tr("UI_CAMP"), config.title_font_size, Color("ffe9a8"))
	_title.name = "Title"
	_root.add_child(_title)
	_vigor_label = MinigameUi.make_label(tr("CAMP_VIGOR"), config.small_font_size)
	_vigor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_vigor_label)
	_satisfaction_label = MinigameUi.make_label(tr("CAMP_SATISFACTION"), config.small_font_size)
	_satisfaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_satisfaction_label)
	_bonus_label = MinigameUi.make_label("", config.small_font_size, Color("ffd34d"))
	_root.add_child(_bonus_label)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", config.button_gap)
	_root.add_child(_menu)
	_minigame_button = MinigameUi.make_button(tr("UI_CAMP_MINIGAME"), config.button_size, config.button_font_size, Color("c0603a"), Color("3a1a10"))
	_minigame_button.name = "MinigameButton"
	_minigame_button.pressed.connect(open_minigame)
	_menu.add_child(_minigame_button)
	_companion_button = MinigameUi.make_button(tr("UI_CAMP_COMPANION"), config.button_size, config.button_font_size, Color("5a5670"), Color("24203a"))
	_companion_button.name = "CompanionButton"
	_companion_button.pressed.connect(open_companion)
	_menu.add_child(_companion_button)
	_continue_button = MinigameUi.make_button(tr("UI_CAMP_CONTINUE"), config.button_size, config.button_font_size, Color("3a8a5a"), Color("123a24"))
	_continue_button.name = "ContinueButton"
	_continue_button.pressed.connect(leave_camp)
	_menu.add_child(_continue_button)

	_toast = MinigameUi.make_label("", config.button_font_size, MinigameUi.WHITE)
	_toast.name = "Toast"
	_toast.visible = false
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Color(0.08, 0.06, 0.14, 0.9)
	toast_box.border_color = Color("ffd34d")
	toast_box.set_border_width_all(1)
	toast_box.content_margin_left = 6
	toast_box.content_margin_right = 6
	toast_box.content_margin_top = 3
	toast_box.content_margin_bottom = 3
	_toast.add_theme_stylebox_override(&"normal", toast_box)
	_root.add_child(_toast)


func _layout() -> void:
	if _root == null:
		return
	var safe := SafeArea.get_safe_rect()
	var game := SafeArea.get_game_rect()
	var cx := roundf(safe.get_center().x)

	_title.size = Vector2(safe.size.x, 16)
	_title.position = Vector2(safe.position.x, safe.position.y + 6)
	var stats_y := safe.position.y + 26.0
	_vigor_label.size = Vector2(40, 10)
	_vigor_label.position = Vector2(cx - 62, stats_y)
	_satisfaction_label.size = Vector2(40, 10)
	_satisfaction_label.position = Vector2(cx - 62, stats_y + 12)
	_bonus_label.size = Vector2(safe.size.x, 10)
	_bonus_label.position = Vector2(safe.position.x, stats_y + 25)

	var menu_size := Vector2(config.button_size.x, config.button_size.y * 3 + config.button_gap * 2)
	var menu_bottom := safe.end.y - config.menu_bottom_margin
	_menu.size = menu_size
	_menu.position = Vector2(cx - roundf(menu_size.x * 0.5), roundf(menu_bottom - menu_size.y))

	# 場景放在標題與選單之間;長螢幕時置中於遊戲區附近。
	var scene_top := maxf(stats_y + 36.0, game.position.y + 70.0)
	var scene_bottom := _menu.position.y - 6.0
	var mid := roundf(lerpf(scene_top, scene_bottom, 0.5))
	_table_spot = Vector2(cx, mid - 22.0)
	_fire_spot = Vector2(cx - 34.0, mid + 26.0)
	_goldie_spot = Vector2(cx + 30.0, mid + 26.0)
	_goldie.position = _goldie_spot
	if _fire != null:
		_fire.position = _fire_spot

	_toast.size = Vector2(minf(150.0, safe.size.x - 16.0), 18)
	_toast.position = Vector2(cx - roundf(_toast.size.x * 0.5), _menu.position.y - 24.0)
	_backdrop.queue_redraw()
	_front.queue_redraw()


# --- 繪圖(佔位美術;CampConfig 有正式圖時改用正式圖) ---

func _draw_backdrop() -> void:
	var screen := SafeArea.get_screen_size()
	var game := SafeArea.get_game_rect()
	if config.background_texture != null:
		var tex_size := config.background_texture.get_size()
		var at := (game.get_center() - tex_size * 0.5).round()
		_backdrop.draw_rect(Rect2(Vector2.ZERO, screen), config.sky_top_color)
		_backdrop.draw_texture(config.background_texture, at)
	else:
		_draw_night(screen)
	if config.table_texture != null:
		var t_size := config.table_texture.get_size()
		_backdrop.draw_texture(config.table_texture, (_table_spot - t_size * 0.5).round())
	else:
		_draw_table()
	if _fire == null:
		_draw_fire()


func _draw_night(screen: Vector2) -> void:
	var horizon := _table_spot.y + 4.0
	var bands := 10
	for i in bands:
		var c := config.sky_top_color.lerp(config.sky_bottom_color, float(i) / (bands - 1))
		_backdrop.draw_rect(Rect2(0, horizon * i / bands, screen.x, horizon / bands + 1), c)
	for i in 22:
		var star := Vector2(fmod(i * 47.0 + 13.0, screen.x), fmod(i * 29.0 + 7.0, maxf(horizon - 8.0, 20.0)))
		var twinkle := 0.5 + 0.5 * sin(_time * 1.7 + i * 1.3)
		var size := 2.0 if i % 7 == 0 else 1.0
		_backdrop.draw_rect(Rect2(star.round(), Vector2(size, size)), Color(1, 1, 0.85, 0.3 + 0.6 * twinkle))
	# 月亮
	var moon := Vector2(screen.x - 28.0, 22.0 + SafeArea.get_safe_rect().position.y + 24.0)
	_backdrop.draw_circle(moon, 9.0, Color("fff3c4"))
	_backdrop.draw_circle(moon + Vector2(4, -2), 8.0, config.sky_top_color.lerp(config.sky_bottom_color, 0.3))
	# 遠山與地面
	var hills := PackedVector2Array([Vector2(0, horizon), Vector2(0, horizon - 14), Vector2(screen.x * 0.25, horizon - 26),
		Vector2(screen.x * 0.5, horizon - 12), Vector2(screen.x * 0.75, horizon - 30), Vector2(screen.x, horizon - 16), Vector2(screen.x, horizon)])
	_backdrop.draw_colored_polygon(hills, config.sky_bottom_color.darkened(0.35))
	_backdrop.draw_rect(Rect2(0, horizon, screen.x, screen.y - horizon), config.ground_color)
	for i in 30:
		var tuft := Vector2(fmod(i * 53.0 + 5.0, screen.x), horizon + 6.0 + fmod(i * 31.0, maxf(screen.y - horizon - 8.0, 8.0)))
		_backdrop.draw_rect(Rect2(tuft.round(), Vector2(2, 1)), config.ground_light_color)
	# 營火照亮的地面
	for i in 4:
		_backdrop.draw_circle(_fire_spot + Vector2(0, 4), 44.0 - i * 9.0, config.glow_color)


func _draw_table() -> void:
	var c := _table_spot
	# 圓桌:從正面看是一個扁扁的橢圓,加上桌腳
	_backdrop.draw_rect(Rect2(c + Vector2(-40, 6), Vector2(4, 18)), config.table_edge_color)
	_backdrop.draw_rect(Rect2(c + Vector2(36, 6), Vector2(4, 18)), config.table_edge_color)
	_backdrop.draw_rect(Rect2(c + Vector2(-2, 8), Vector2(4, 18)), config.table_edge_color)
	_draw_ellipse(c + Vector2(0, 4), Vector2(56, 14), config.table_edge_color)
	_draw_ellipse(c, Vector2(56, 14), config.table_color)
	_draw_ellipse(c + Vector2(0, -2), Vector2(44, 9), config.table_color.lightened(0.12))
	# 桌上的王室卷軸與杯子(暗示小遊戲)
	_backdrop.draw_rect(Rect2(c + Vector2(-26, -5), Vector2(22, 6)), Color("f3e6c4"))
	_backdrop.draw_rect(Rect2(c + Vector2(-28, -6), Vector2(3, 8)), Color("e0b040"))
	_backdrop.draw_rect(Rect2(c + Vector2(-5, -6), Vector2(3, 8)), Color("e0b040"))
	_backdrop.draw_rect(Rect2(c + Vector2(-18, -5), Vector2(2, 6)), Color("b8323a"))
	_backdrop.draw_rect(Rect2(c + Vector2(12, -10), Vector2(7, 9)), Color("c9c9d9"))
	_backdrop.draw_rect(Rect2(c + Vector2(19, -8), Vector2(2, 4)), Color("c9c9d9"))


func _draw_fire() -> void:
	var c := _fire_spot
	# 木柴
	_backdrop.draw_set_transform(c + Vector2(0, 8), 0.35)
	_backdrop.draw_rect(Rect2(-12, -2, 24, 4), Color("6b4428"))
	_backdrop.draw_set_transform(c + Vector2(0, 8), -0.35)
	_backdrop.draw_rect(Rect2(-12, -2, 24, 4), Color("5a3418"))
	_backdrop.draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in 5:
		var stone := c + Vector2(-16 + i * 8, 11)
		_backdrop.draw_rect(Rect2(stone, Vector2(6, 4)), Color("6a6a78"))
	# 火焰:三層,高度隨時間跳動
	for layer in config.fire_colors.size():
		var scale := 1.0 - layer * 0.28
		var flick := 1.0 + 0.18 * sin(_time * (9.0 + layer * 3.0)) + 0.1 * sin(_time * 23.0 + layer)
		var h := 22.0 * scale * flick
		var w := 11.0 * scale
		var sway := sin(_time * 4.0 + layer) * 2.0
		var pts := PackedVector2Array([
			c + Vector2(-w, 6), c + Vector2(-w * 0.7, -h * 0.35), c + Vector2(sway * 0.5 - w * 0.25, -h * 0.7),
			c + Vector2(sway, -h), c + Vector2(sway * 0.5 + w * 0.3, -h * 0.6), c + Vector2(w * 0.75, -h * 0.3), c + Vector2(w, 6),
		])
		_backdrop.draw_colored_polygon(pts, config.fire_colors[layer])
	# 火星
	for i in 4:
		var life := fmod(_time * 0.8 + i * 0.27, 1.0)
		var spark := c + Vector2(sin(i * 2.1 + _time) * 6.0, -18.0 - life * 26.0)
		_backdrop.draw_rect(Rect2(spark.round(), Vector2.ONE), Color(1, 0.85, 0.4, 1.0 - life))


func _draw_front() -> void:
	# 金毛的尾巴(搖來搖去);正式的搖尾巴動畫由 C 線提供時,可以把 tail_wags_per_sec 設為 0 關掉。
	if config.tail_wags_per_sec > 0.0:
		var base := _goldie.position + Vector2(-10, 4) * config.goldie_scale
		var angle := sin(_time * TAU * config.tail_wags_per_sec) * 0.6 - 0.4
		_front.draw_set_transform(base, angle)
		_front.draw_rect(Rect2(-12, -2, 12, 4), MinigameUi.INK)
		_front.draw_rect(Rect2(-11, -1, 10, 2), config.tail_color)
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	# 金毛睡得很舒服:Z 字
	var z_t := fmod(_time * 0.6, 1.0)
	var font := ThemeDB.fallback_font
	var z_pos := (_goldie.position + Vector2(10, -18 - z_t * 10.0)).round()
	_front.draw_string(font, z_pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 1.0 - z_t))
	# 活力與滿意度的條
	_draw_bar(_vigor_label.position + Vector2(42, 2), _shown_vigor, config.vigor_bar_color)
	_draw_bar(_satisfaction_label.position + Vector2(42, 2), _shown_satisfaction, config.satisfaction_bar_color)
	# 玩過小遊戲後,在按鈕旁邊顯示拿到的星星
	if last_grade >= 0 and _menu.visible:
		var button_rect := Rect2(_menu.position + _minigame_button.position, _minigame_button.size)
		for i in 3:
			var star_at := Vector2(button_rect.end.x + 8.0, button_rect.position.y + 5.0 + i * 8.0)
			MinigameUi.draw_star(_front, star_at, 3.5, i < last_grade)


func _draw_bar(at: Vector2, ratio: float, color: Color) -> void:
	var rect := Rect2(at.round(), Vector2(80, 6))
	_front.draw_rect(rect.grow(1), MinigameUi.INK)
	_front.draw_rect(rect, Color("2a2440"))
	_front.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * ratio), rect.size.y)), color)
	_front.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * ratio), 1)), color.lightened(0.3))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_backdrop.draw_colored_polygon(pts, color)
