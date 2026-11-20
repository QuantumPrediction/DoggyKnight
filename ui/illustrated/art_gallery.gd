extends CanvasLayer
## Read-only gallery, available before chapter unlocks; never writes GameState or a save.
var chapter: int = 1
var level: int = 0
var _root: Control
var _view: Control
var _caption: Label
var _level_buttons: Array[Button] = []
const FONT: Font = preload("res://assets/fonts/StorySans.otf")
const NAMES: Array[String] = ["石中劍", "圓桌騎士", "迷霧之湖", "黃金狗碗", "雙龍之山", "阿瓦隆"]

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	UiKit.setup_root(_root)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.size = SafeArea.GAME_SIZE
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("132a29")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	_view = Control.new()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_scene)
	_root.add_child(_view)
	var previous := UiKit.button("‹", &"ButtonAlt", Vector2(24, 24))
	previous.position = Vector2(8, 8)
	previous.pressed.connect(func() -> void: select_chapter(wrapi(chapter - 1, 1, 7)))
	_root.add_child(previous)
	var next := UiKit.button("›", &"ButtonAlt", Vector2(24, 24))
	next.position = Vector2(148, 8)
	next.pressed.connect(func() -> void: select_chapter(wrapi(chapter + 1, 1, 7)))
	_root.add_child(next)
	_caption = UiKit.label("", &"LabelLight")
	_caption.position = Vector2(35, 8)
	_caption.size = Vector2(110, 24)
	_caption.add_theme_font_size_override(&"font_size", 10)
	_root.add_child(_caption)
	for i in 6:
		var b := UiKit.button(str(i + 1), &"ButtonAlt", Vector2(24, 24))
		b.position = Vector2(8 + i * 28, 259)
		b.pressed.connect(select_level.bind(i))
		_root.add_child(b)
		_level_buttons.append(b)
	var close := UiKit.button("返回", &"", Vector2(90, 24))
	close.position = Vector2(45, 290)
	close.pressed.connect(queue_free)
	_root.add_child(close)
	get_viewport().size_changed.connect(_layout)
	_layout()
	select_chapter(chapter)

func _layout() -> void:
	var safe := SafeArea.get_safe_rect()
	var factor := minf(safe.size.x / 180.0, safe.size.y / 320.0)
	_root.scale = Vector2.ONE * factor
	_root.position = safe.get_center() - SafeArea.GAME_SIZE * factor * 0.5
	_view.queue_redraw()

func select_chapter(value: int) -> void:
	chapter = clampi(value, 1, 6)
	select_level(level)

func select_level(value: int) -> void:
	level = clampi(value, 0, 5)
	_caption.text = "%d-%d  %s" % [chapter, level + 1, NAMES[chapter - 1]]
	for i in _level_buttons.size():
		_level_buttons[i].theme_type_variation = &"" if i == level else &"ButtonAlt"
	_view.queue_redraw()

func _draw_scene() -> void:
	var bg := StoryArt.world(chapter, level)
	if bg != null:
		_view.draw_texture_rect(bg, Rect2(8, 38, 164, 214), false)
	var cast: Array = [["scarecrow", "crow", "black_knight"], ["gargoyle", "spellbook", "green_knight"], ["shadow_wolf", "foxfire", "morgana"], ["crab", "jellyfish", "kraken"], ["snowman", "salamander", "white_dragon"], ["shadow_knight", "lantern_wisp", "mordred"]][chapter - 1]
	for i in cast.size():
		var tex := StoryArt.actor(cast[i])
		if tex != null:
			_view.draw_texture_rect(tex, Rect2(24 + i * 44, 115, 38, 44), false)
	for i in 2:
		var tex := StoryArt.actor("goldie" if i == 0 else "bulldog")
		if tex != null:
			_view.draw_texture_rect(tex, Rect2(49 + i * 44, 180, 39, 44), false)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		get_viewport().set_input_as_handled()
		queue_free()
