class_name CampTraining
extends Control
## 營地訓練介面(DEV_PLAN 4.12、17 DV1):用遊戲內的零食讓金毛永久變強。不涉及真錢,不是商店。
##
## 用法(場景 game/camp/training.tscn,根節點是全螢幕的 Control):
## - 營地:選單的「訓練」打開(Camp.open_training),關掉後回到營地選單。
## - 標題:B 線收到 title 的 training_pressed 後,把這個場景加到自己的 CanvasLayer(第 30 層)之下;
##   收到 closed 訊號後移除它(或設定 free_on_close = true 讓它自己刪除)。
## - 返回鍵(EventBus.back_requested):close_on_back 為 true 時自己關閉。B 線在標題畫面開著訓練時不必處理返回鍵。
##
## 畫面:五項升級(vitality、strength、agility、loyalty、luck),每列顯示圖示、名稱、等級(5 格)、
## 價格牌與效果(現在 → 下一級);最上面是零食數。整列就是購買按鈕(手指好按),買得起才可以按。
## 買了:GameState.snacks -= 價格、GameState.meta_upgrades[id] += 1、發 EventBus.snacks_changed(總數)、
## 升級演出(star_burst、sparkle、level_up 音效、輕震、那一列閃光、「Lv.N!」浮起、零食數遞減)。
## 升級表的來源與規則見 TrainingShop;數值套用到金毛由 B 線負責(新遊戲 reset_run() 之後)。
## 不會暫停遊戲,也不連網;存檔由 B 線負責(snacks_changed、切到背景時)。

const SNACK_FRAMES_PATH: String = "res://assets/fx/snack/snack_frames.tres"
const STAR_BURST_PATH: String = "res://assets/fx/particles/star_burst.tscn"
const SPARKLE_PATH: String = "res://assets/fx/particles/sparkle.tscn"
const DEFAULT_CONFIG_PATH: String = "res://game/camp/training_config.tres"

## 玩家關掉訓練介面(按「返回」或返回鍵)。
signal closed()
## 買了一級。
signal upgraded(id: StringName, new_level: int)

@export var config: TrainingConfig
## 收到 EventBus.back_requested 時自己關閉。
@export var close_on_back: bool = true
## 關閉時自己 queue_free(預設由打開它的一方移除)。
@export var free_on_close: bool = false

## 測試用:讀寫這個物件而不是 GameState(要有 snacks 與 meta_upgrades 欄位)。
var state_override: Object
## 整理過的升級表(TrainingShop.normalize 的格式)。
var entries: Array[Dictionary] = []
var is_closed: bool = false

var _rows: Dictionary = {}          # id → {"row": Control, "name": Label, "effect": Label, "price": Label, "button": Button, "entry": Dictionary}
var _fx: Control
var _backdrop: ColorRect
var _content: Control
var _title: Label
var _hint: Label
var _snack_label: Label
var _snack_icon: TextureRect
var _scroll: ScrollContainer
var _list: VBoxContainer
var _close_button: Button
var _snack_texture: Texture2D
var _star_burst: PackedScene
var _sparkle: PackedScene
var _flash: Dictionary = {}         # id → 剩下的秒數
var _floaters: Array[Dictionary] = []
var _shown_snacks: float = 0.0
var _counter_from: float = 0.0
var _counter_left: float = 0.0
var _open_t: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if config == null:
		config = load(DEFAULT_CONFIG_PATH) as TrainingConfig if ResourceLoader.exists(DEFAULT_CONFIG_PATH) else TrainingConfig.new()
	_load_assets()
	entries = TrainingShop.load_entries(config.upgrade_paths)
	MinigameUi.apply_shared_theme(self)
	_build()
	_shown_snacks = snacks()
	refresh()
	resized.connect(_layout)
	_layout()
	EventBus.snacks_changed.connect(_on_snacks_changed)
	EventBus.back_requested.connect(_on_back_requested)


func _exit_tree() -> void:
	if EventBus.snacks_changed.is_connected(_on_snacks_changed):
		EventBus.snacks_changed.disconnect(_on_snacks_changed)
	if EventBus.back_requested.is_connected(_on_back_requested):
		EventBus.back_requested.disconnect(_on_back_requested)


func _process(delta: float) -> void:
	_time += delta
	_open_t = minf(1.0, _open_t + delta / maxf(config.open_sec, 0.01))
	var ease_t := 1.0 - pow(1.0 - _open_t, 3.0)
	_content.position = Vector2(0, roundf((1.0 - ease_t) * 20.0))
	_content.modulate.a = ease_t
	if _counter_left > 0.0:
		_counter_left = maxf(0.0, _counter_left - delta)
		var t := 1.0 - _counter_left / maxf(config.counter_sec, 0.01)
		_shown_snacks = lerpf(_counter_from, snacks(), t)
	else:
		_shown_snacks = snacks()
	_snack_label.text = str(roundi(_shown_snacks))
	for id: StringName in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
	for f: Dictionary in _floaters:
		f["age"] = float(f["age"]) + delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["age"]) < config.floater_sec)
	for id: StringName in _rows:
		(_rows[id]["row"] as Control).queue_redraw()
	_fx.queue_redraw()


# --- 公開方法(營地、B 線、測試) ---

## 讀寫的狀態:GameState,或測試用的 state_override。
func state() -> Object:
	return state_override if state_override != null else get_node_or_null(^"/root/GameState")


func snacks() -> int:
	var s := state()
	return TrainingShop.snacks_of(s) if s != null else 0


func level_of(id: StringName) -> int:
	var s := state()
	return TrainingShop.level_of(s, id) if s != null else 0


func entry_for(id: StringName) -> Dictionary:
	for e: Dictionary in entries:
		if e["id"] == id:
			return e
	return {}


func can_buy(id: StringName) -> bool:
	var e := entry_for(id)
	var s := state()
	return not e.is_empty() and s != null and TrainingShop.can_buy(s, e)


func get_buy_button(id: StringName) -> Button:
	return _rows[id]["button"] if _rows.has(id) else null


## 價格牌上的文字(價格,或「滿級」)。
func get_price_text(id: StringName) -> String:
	return (_rows[id]["price"] as Label).text if _rows.has(id) else ""


func get_close_button() -> Button:
	return _close_button


## 列的效果文字(給測試看)。
func get_effect_text(id: StringName) -> String:
	return (_rows[id]["effect"] as Label).text if _rows.has(id) else ""


## 買一級(價格按鈕也是呼叫這個)。成功傳回 true。
func buy(id: StringName) -> bool:
	if is_closed:
		return false
	var e := entry_for(id)
	var s := state()
	if e.is_empty() or s == null:
		return false
	var before := TrainingShop.snacks_of(s)
	var new_level := TrainingShop.buy(s, e)
	if new_level < 0:
		Sfx.play(&"ui_tap")
		return false
	var spent := before - TrainingShop.snacks_of(s)
	if s == get_node_or_null(^"/root/GameState"):
		EventBus.snacks_changed.emit(TrainingShop.snacks_of(s))
	_celebrate(id, new_level, spent, float(before))
	refresh()
	upgraded.emit(id, new_level)
	return true


## 跳過打開時的滑入動畫(測試與截圖用)。
func finish_intro() -> void:
	_open_t = 1.0
	_content.position = Vector2.ZERO
	_content.modulate.a = 1.0


## 關閉(「返回」按鈕、返回鍵)。
func close() -> void:
	if is_closed:
		return
	is_closed = true
	Sfx.play(&"ui_tap")
	for id: StringName in _rows:
		(_rows[id]["button"] as Button).disabled = true
	_close_button.disabled = true
	closed.emit()
	if free_on_close:
		queue_free()


## 依目前的零食與等級更新每一列(價格、能不能按、效果)。
func refresh() -> void:
	if _counter_left <= 0.0:
		_shown_snacks = snacks()
		_snack_label.text = str(snacks())
	for id: StringName in _rows:
		var r: Dictionary = _rows[id]
		var e: Dictionary = r["entry"]
		var level := level_of(id)
		var button := r["button"] as Button
		var price := r["price"] as Label
		var cost := TrainingShop.cost_for(e, level)
		if cost < 0:
			price.text = tr("TRAINING_MAX")
			button.disabled = true
		else:
			price.text = str(cost)
			button.disabled = is_closed or not can_buy(id)
		price.add_theme_color_override(&"font_color", MinigameUi.WHITE if not button.disabled or cost < 0 else Color(1, 1, 1, 0.5))
		(r["effect"] as Label).text = _effect_line(e, level)


# --- 內部 ---

func _effect_line(e: Dictionary, level: int) -> String:
	var now := TrainingShop.effect_text(e, level)
	var value := now if TrainingShop.is_maxed(e, level) else "%s→%s" % [now, TrainingShop.effect_text(e, level + 1)]
	var desc := tr(String(e["desc_key"]))
	return desc % value if desc.contains("%s") else "%s %s" % [desc, value]


func _celebrate(id: StringName, new_level: int, spent: int, before: float) -> void:
	Sfx.play(config.upgrade_sfx)
	Haptics.play(config.upgrade_haptic)
	_flash[id] = config.flash_sec
	var row := _rows[id]["row"] as Control
	var origin := row.global_position - _fx.global_position
	_spawn(_star_burst, origin + _icon_center())
	_spawn(_sparkle, origin + _pip_center(row, new_level - 1))
	_floaters.append({"text": tr("TRAINING_LEVEL_UP") % new_level, "pos": origin + Vector2(52.0, 15.0),
			"age": 0.0, "color": config.level_up_color})
	if spent > 0:
		_floaters.append({"text": "-%d" % spent, "pos": _snack_label.global_position - _fx.global_position + Vector2(_snack_label.size.x + 2.0, 10.0),
				"age": 0.0, "color": config.spend_color})
	_counter_from = before
	_counter_left = config.counter_sec


func _spawn(scene: PackedScene, at: Vector2) -> void:
	if scene == null:
		return
	var fx := scene.instantiate()
	if fx is Node2D:
		(fx as Node2D).position = at.round()
	_fx.add_child(fx)


func _on_snacks_changed(_total: int) -> void:
	refresh()


func _on_back_requested() -> void:
	if close_on_back and is_visible_in_tree():
		close()


func _load_assets() -> void:
	var frames := config.snack_frames
	if frames == null and ResourceLoader.exists(SNACK_FRAMES_PATH):
		frames = load(SNACK_FRAMES_PATH) as SpriteFrames
	if frames != null and frames.has_animation(&"default") and frames.get_frame_count(&"default") > 0:
		_snack_texture = frames.get_frame_texture(&"default", 0)
	_star_burst = config.star_burst_particles
	if _star_burst == null and ResourceLoader.exists(STAR_BURST_PATH):
		_star_burst = load(STAR_BURST_PATH) as PackedScene
	_sparkle = config.sparkle_particles
	if _sparkle == null and ResourceLoader.exists(SPARKLE_PATH):
		_sparkle = load(SPARKLE_PATH) as PackedScene


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = config.backdrop_color
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_content = Control.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_title = MinigameUi.make_title(tr("TRAINING_TITLE"))
	_title.name = "Title"
	_content.add_child(_title)
	_snack_icon = TextureRect.new()
	_snack_icon.name = "SnackIcon"
	_snack_icon.texture = StoryArt.ui_icon("icon_snack")
	_snack_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snack_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_snack_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_snack_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_snack_icon)
	_snack_label = MinigameUi.make_label("0", MinigameUi.FONT_S, Color("ffe066"))
	_snack_label.name = "Snacks"
	_snack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(_snack_label)
	_hint = MinigameUi.make_label(tr("TRAINING_HINT"), MinigameUi.FONT_S, Color(1, 1, 1, 0.75))
	_hint.name = "Hint"
	_content.add_child(_hint)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.add_theme_constant_override(&"separation", config.row_gap)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	for e: Dictionary in entries:
		_add_row(e)

	_close_button = MinigameUi.make_button(tr("TRAINING_CLOSE"), config.close_button_size, MinigameUi.FONT_S,
			config.close_fill_color, config.close_border_color)
	_close_button.name = "CloseButton"
	_close_button.pressed.connect(close)
	_content.add_child(_close_button)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _add_row(e: Dictionary) -> void:
	var id: StringName = e["id"]
	var row := Control.new()
	row.name = "Row_%s" % id
	row.custom_minimum_size = Vector2(0, config.row_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(row)
	var name_label := MinigameUi.make_label(tr(String(e["name_key"])), MinigameUi.FONT_S)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var effect := MinigameUi.make_label("", MinigameUi.FONT_S, config.effect_color)
	effect.name = "Effect"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect.clip_text = true
	row.add_child(effect)
	var price := MinigameUi.make_label("", MinigameUi.FONT_S)
	price.name = "Price"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(price)
	# 整列是一個透明的按鈕:外觀(底色、價格牌)由 _draw_row 畫。
	var button := Button.new()
	button.name = "BuyButton"
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(buy.bind(id))
	button.button_down.connect(func() -> void: _squash(row, 0.95))
	button.button_up.connect(func() -> void: _squash(row, 1.0))
	row.add_child(button)
	row.draw.connect(_draw_row.bind(id))
	row.resized.connect(_layout_row.bind(id))
	_rows[id] = {"row": row, "name": name_label, "effect": effect, "price": price, "button": button, "entry": e}


func _squash(target: Control, to: float) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2(to, to), 0.08 if to < 1.0 else 0.18) \
			.set_trans(Tween.TRANS_BACK if to >= 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _layout() -> void:
	if _content == null:
		return
	var safe := SafeArea.get_safe_rect()
	var width := minf(config.panel_max_width, safe.size.x - 8.0)
	var left := roundf(safe.get_center().x - width * 0.5)
	_title.size = Vector2(safe.size.x, 28)
	_title.position = Vector2(safe.position.x, safe.position.y + 2)
	var counter_y := safe.position.y + 30.0
	_snack_label.size = Vector2(40, 16)
	var counter_w := 16.0 + 3.0 + 28.0
	var counter_x := roundf(safe.get_center().x - counter_w * 0.5)
	_snack_icon.size = Vector2(16, 16)
	_snack_icon.position = Vector2(counter_x, counter_y)
	_snack_label.position = Vector2(counter_x + 19.0, counter_y)
	_hint.size = Vector2(safe.size.x, 14)
	_hint.position = Vector2(safe.position.x, counter_y + 18.0)

	var close_y := roundf(safe.end.y - config.bottom_margin - config.close_button_size.y)
	_close_button.size = config.close_button_size
	_close_button.position = Vector2(roundf(safe.get_center().x - config.close_button_size.x * 0.5), close_y)
	var list_top := counter_y + 36.0
	_scroll.position = Vector2(left, list_top)
	_scroll.size = Vector2(width, maxf(config.row_height, close_y - 6.0 - list_top))
	_list.custom_minimum_size = Vector2(width, 0)
	for id: StringName in _rows:
		_layout_row(id)


func _layout_row(id: StringName) -> void:
	var r: Dictionary = _rows[id]
	var row := r["row"] as Control
	var w := row.size.x
	var button := r["button"] as Button
	button.position = Vector2.ZERO
	button.size = row.size
	var text_x := 24.0
	var tag := _price_rect(row)
	var name_label := r["name"] as Label
	name_label.position = Vector2(text_x, 3)
	name_label.size = Vector2(tag.position.x - 3.0 - text_x, 14)
	var price := r["price"] as Label
	price.position = tag.position + Vector2(10, 0)
	price.size = Vector2(tag.size.x - 12.0, tag.size.y)
	var effect := r["effect"] as Label
	effect.position = Vector2(text_x, 20)
	effect.size = Vector2(w - 4.0 - text_x, 14)


## 價格牌的位置(列的本地座標,右上角)。
func _price_rect(row: Control) -> Rect2:
	return Rect2(Vector2(row.size.x - config.price_tag_size.x - 4.0, 3.0), config.price_tag_size)


func _icon_center() -> Vector2:
	return Vector2(12, roundf(config.row_height * 0.5))


func _pip_center(row: Control, index: int) -> Vector2:
	var end_x := _price_rect(row).position.x - 5.0
	return Vector2(end_x - (4 - index) * 7.0 - 2.5, 9.5)


# --- 繪圖 ---

func _draw_row(id: StringName) -> void:
	var r: Dictionary = _rows[id]
	var row := r["row"] as Control
	var e: Dictionary = r["entry"]
	var rect := Rect2(Vector2.ZERO, row.size)
	var level := level_of(id)
	var affordable := not is_closed and can_buy(id)
	row.draw_rect(rect, MinigameUi.INK)
	row.draw_rect(rect.grow(-1), config.row_ready_border_color if affordable else config.row_border_color)
	row.draw_rect(rect.grow(-2), config.row_color)
	if _flash.has(id):
		var a := clampf(float(_flash[id]) / maxf(config.flash_sec, 0.01), 0.0, 1.0)
		row.draw_rect(rect.grow(-2), Color(1, 1, 1, 0.45 * a))
	# 圖示:剛升級時彈一下
	var pop := 0.0
	if _flash.has(id):
		var t := 1.0 - clampf(float(_flash[id]) / maxf(config.flash_sec, 0.01), 0.0, 1.0)
		pop = sin(t * PI)
	_draw_icon(row, id, _icon_center() + Vector2(0, -roundf(pop * 3.0)))
	# 價格牌:買得起是橘色,買不起是灰色,滿級是金色
	var tag := _price_rect(row)
	var maxed := TrainingShop.is_maxed(e, level)
	var fill := config.max_tag_color if maxed else (config.buy_fill_color if affordable else config.pip_off_color)
	row.draw_rect(tag.grow(1), MinigameUi.INK)
	row.draw_rect(tag, fill)
	row.draw_rect(Rect2(tag.position, Vector2(tag.size.x, 1)), fill.lightened(0.3))
	row.draw_rect(Rect2(tag.position + Vector2(0, tag.size.y - 1), Vector2(tag.size.x, 1)), fill.darkened(0.3))
	if not maxed and _snack_texture != null:
		row.draw_texture_rect(StoryArt.ui_icon("icon_snack"), Rect2(tag.position + Vector2(2, (tag.size.y - 8.0) * 0.5), Vector2(8, 8)), false, Color(1, 1, 1, 1.0 if affordable else 0.5))
	# 等級:max_level 格(最多畫 5 格)
	var max_level := mini(int(e["max_level"]), 5)
	for i in max_level:
		var c := _pip_center(row, i + (5 - max_level))
		var on := i < level
		var side := 5.0 + (2.0 if on and _flash.has(id) and i == level - 1 else 0.0)
		var pip := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)).abs()
		row.draw_rect(pip.grow(1), MinigameUi.INK)
		row.draw_rect(pip, config.pip_on_color if on else config.pip_off_color)
		if on:
			row.draw_rect(Rect2(pip.position, Vector2(pip.size.x, 1)), config.pip_on_color.lightened(0.5))


func _draw_icon(ci: CanvasItem, id: StringName, center: Vector2) -> void:
	var index: int = {&"vitality": 0, &"strength": 7, &"agility": 2, &"loyalty": 1, &"luck": 14}.get(id, 5)
	ci.draw_texture_rect(StoryArt.cell("ui_icons", index % 4, index / 4), Rect2(center - Vector2(8, 8), Vector2(16, 16)), false)


const SWORD: Array[String] = ["...o....", "..obo...", "..oao...", "..oao...", "..oao...", "occccco.", "..odo...", "..oco..."]
const FEATHER: Array[String] = ["......oo", ".....obo", "....oabo", "...oabo.", "..oaao..", ".oaao...", ".ooo....", "o......."]
const CLOVER: Array[String] = [".oo.oo..", "oabobao.", "oaaaaao.", ".oaaao..", "oaaaaao.", "oaaoaao.", ".oo.odo.", "......do"]


## 狗掌印(16×16):四顆趾頭和一個肉墊。
static func _draw_paw(ci: CanvasItem, center: Vector2, color: Color) -> void:
	var o := (center - Vector2(8, 8)).round()
	var parts: Array[Rect2] = [Rect2(0, 5, 3, 3), Rect2(4, 1, 3, 4), Rect2(9, 1, 3, 4), Rect2(13, 5, 3, 3),
		Rect2(4, 8, 8, 6), Rect2(3, 10, 10, 3)]
	for r in parts:
		ci.draw_rect(Rect2(o + r.position, r.size).grow(1), MinigameUi.INK)
	for r in parts:
		ci.draw_rect(Rect2(o + r.position, r.size), color)
	ci.draw_rect(Rect2(o + Vector2(5, 9), Vector2(2, 1)), color.lightened(0.5))


## 8×8 的像素圖示,放大 2 倍。字元對應 palette 的顏色,「.」是透明。
static func _draw_glyph(ci: CanvasItem, center: Vector2, rows: Array[String], palette: Dictionary) -> void:
	var origin := (center - Vector2(8, 8)).round()
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ch == "." or not palette.has(ch):
				continue
			ci.draw_rect(Rect2(origin + Vector2(x, y) * 2.0, Vector2(2, 2)), palette[ch])


func _draw_fx() -> void:
	var font := _title.get_theme_font(&"font")
	for f: Dictionary in _floaters:
		var age := float(f["age"])
		var t := age / maxf(config.floater_sec, 0.01)
		var alpha := clampf(1.0 - (t - 0.6) / 0.4, 0.0, 1.0)
		var pos := ((f["pos"] as Vector2) + Vector2(0, -roundf(minf(t, 0.5) * 2.0 * 12.0))).round()
		_fx.draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, 4, Color(MinigameUi.INK, alpha))
		_fx.draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, Color(f["color"] as Color, alpha))
