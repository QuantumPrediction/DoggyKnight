extends Node
## C 線圖庫(M1 驗收):每個角色的每個動畫循環播放、全部特效與圖示、三個場地背景。
## 用畫面下方的 ◀ ▶ 換頁(觸控或滑鼠)。這是開發工具,文字不翻譯。
##
## 執行:godot --path . res://tests/line_c/gallery.tscn

const CHARACTERS: Array = [
	["goldie", 2, [&"idle", &"run", &"attack", &"hurt", &"sleep"]],
	["bulldog", 2, [&"idle", &"run", &"attack", &"hurt", &"guard"]],
	["scarecrow", 2, [&"idle", &"run", &"attack", &"hurt"]],
	["crow", 2, [&"idle", &"run", &"attack", &"hurt"]],
	["black_knight", 1, [&"idle", &"run", &"attack", &"hurt", &"charge", &"slam", &"down"]],
]
const FX: Array[String] = ["slash", "hit_spark", "exp_orb", "ultimate_slash", "dizzy_stars", "dust"]
const TRICKS: Array[String] = ["sit", "wag", "fetch", "shake", "spin", "bark"]
const BACKGROUNDS: Array[String] = ["sword_stone", "meadow", "bridge"]

var page: int = 0
var _world: Node2D
var _layer: CanvasLayer
var _page_root: Control
var _title: Label
var _pages: Array[Callable] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = Node2D.new()
	add_child(_world)
	var cam := Camera2D.new()
	cam.position = SafeArea.GAME_CENTER
	_world.add_child(cam)
	cam.make_current()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_page_root = Control.new()
	_page_root.theme = UiKit.THEME
	_page_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_page_root)
	var nav := CanvasLayer.new()
	nav.layer = 5
	add_child(nav)
	var bar := Control.new()
	bar.theme = UiKit.THEME
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(bar)
	_title = UiKit.label("", &"LabelLight")
	bar.add_child(_title)
	var prev := UiKit.button("<", &"ButtonAlt", Vector2(32, 26))
	prev.name = "Prev"
	prev.pressed.connect(func() -> void: show_page(page - 1))
	bar.add_child(prev)
	var next := UiKit.button(">", &"ButtonAlt", Vector2(32, 26))
	next.name = "Next"
	next.pressed.connect(func() -> void: show_page(page + 1))
	bar.add_child(next)
	for c in CHARACTERS:
		_pages.append(_character_page.bind(c))
	_pages.append(_fx_page)
	for bg in BACKGROUNDS:
		_pages.append(_background_page.bind(bg))
	get_viewport().size_changed.connect(_layout_nav.bind(bar, prev, next))
	_layout_nav(bar, prev, next)
	show_page(0)


func page_count() -> int:
	return _pages.size()


func show_page(index: int) -> void:
	page = posmod(index, _pages.size())
	for c in _page_root.get_children():
		c.queue_free()
	for c in _world.get_children():
		if not c is Camera2D:
			c.queue_free()
	_pages[page].call()


func _layout_nav(_bar: Control, prev: Button, next: Button) -> void:
	var safe := SafeArea.get_safe_rect()
	prev.size = prev.custom_minimum_size
	next.size = next.custom_minimum_size
	prev.position = Vector2(safe.position.x + 6, safe.end.y - 34)
	next.position = Vector2(safe.end.x - 6 - next.size.x, safe.end.y - 34)
	_title.position = Vector2(safe.position.x + 4, safe.position.y + 2)
	_title.size = Vector2(safe.size.x - 8, 14)


func _backdrop(color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(r)


func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override(&"h_separation", 4)
	g.add_theme_constant_override(&"v_separation", 2)
	var safe := SafeArea.get_safe_rect()
	g.position = safe.position + Vector2(6, 20)
	_page_root.add_child(g)
	return g


func _cell(content: Control, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	var center := CenterContainer.new()
	center.add_child(content)
	v.add_child(center)
	v.add_child(UiKit.label(caption, &"LabelLight"))
	return v


func _character_page(spec: Array) -> void:
	var code: String = spec[0]
	var scale: int = spec[1]
	_backdrop(PaletteColors.LEAF_D)
	_title.text = "%s(%d/%d)" % [code, page + 1, _pages.size()]
	var g := _grid(3)
	for anim: StringName in spec[2]:
		var box := UiKit.sprite_box("res://assets/sprites/%s/%s_frames.tres" % [code, code], anim, scale)
		g.add_child(_cell(box, String(anim)))


func _fx_page() -> void:
	_backdrop(PaletteColors.FOREST)
	_title.text = "fx + icons(%d/%d)" % [page + 1, _pages.size()]
	var g := _grid(3)
	for fx in FX:
		var box := UiKit.sprite_box("res://assets/fx/%s/%s_frames.tres" % [fx, fx], &"default", 1 if fx == "ultimate_slash" else 2)
		g.add_child(_cell(box, fx))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override(&"separation", 4)
	for t in TRICKS:
		icons.add_child(UiKit.texture_rect(load("res://assets/icons/tricks/%s.png" % t) as Texture2D, 1))
	g.add_child(_cell(icons, "tricks"))


func _background_page(bg: String) -> void:
	_title.text = "%s(%d/%d)" % [bg, page + 1, _pages.size()]
	var scene := load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene
	_world.add_child(scene.instantiate())
	var cast: Array = [["goldie", &"idle", Vector2(90, 232)], ["bulldog", &"guard", Vector2(62, 236)],
			["scarecrow", &"run", Vector2(48, 140)], ["scarecrow", &"attack", Vector2(128, 120)],
			["crow", &"run", Vector2(150, 190)]]
	if bg == "bridge":
		cast.append(["black_knight", &"idle", Vector2(96, 112)])
	for c: Array in cast:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = UiKit.looping_frames(load("res://assets/sprites/%s/%s_frames.tres" % [c[0], c[0]]) as SpriteFrames)
		s.position = c[2]
		s.flip_h = (c[2] as Vector2).x > 100.0
		_world.add_child(s)
		s.play(c[1])
