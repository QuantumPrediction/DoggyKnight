class_name UiKit
extends RefCounted
## 介面共用的小工具(C 線)。所有介面場景都用這裡建立按鈕與文字,外觀因此一致。
##
## 規則(DEV_PLAN 第 10 節):觸控目標至少 24×24 邏輯像素、按鈕之間至少 4 像素;
## 文字一律用 tr() 取翻譯鍵;按鈕按下時播放 ui_tap。

const THEME: Theme = preload("res://ui/theme/main_theme.tres")
const MIN_TOUCH: float = 24.0
const GAP: float = 6.0
const BUTTON_SIZE: Vector2 = Vector2(116, 26)


## 一般按鈕。variation:&"" 金色主要按鈕、&"ButtonAlt" 藍色次要按鈕。
static func button(text: String, variation: StringName = &"", min_size: Vector2 = BUTTON_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(maxf(min_size.x, MIN_TOUCH), maxf(min_size.y, MIN_TOUCH))
	b.focus_mode = Control.FOCUS_ALL
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.pressed.connect(tap_feedback)
	add_squash(b)
	return b


## 按下時擠扁、放開時彈回(CP5)。任何 Control 按鈕都可以用。
static func add_squash(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _squash(b, Vector2.ONE * 0.98, 0.1))
	b.button_up.connect(func() -> void: _squash(b, Vector2.ONE, 0.14))


static func _squash(b: Control, to: Vector2, time: float) -> void:
	if not b.is_inside_tree():
		return
	b.pivot_offset = (b.size * 0.5).floor()
	var t := b.create_tween()
	t.tween_property(b, "scale", to, time)


## 按鈕回饋:按鍵音 + 手機輕震(遵守 GameState.haptics_on)。
static func tap_feedback() -> void:
	tap_sound()
	Haptics.play(&"light")


static func label(text: String, variation: StringName = &"", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


static func wrapped_label(text: String, width: float, variation: StringName = &"",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, variation, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


static func texture_rect(tex: Texture2D, scale: int = 1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		t.custom_minimum_size = tex.get_size() * scale
		t.size = t.custom_minimum_size
	return t


## 全螢幕半透明底色,擋住後面的點擊。
static func dim(color: Color = Color(PaletteColors.INK, 0.6)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## 介面場景根節點的共同設定:全螢幕錨點、主題、暫停時照常運作。
static func setup_root(root: Control, always_process: bool = true) -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = THEME
	if always_process:
		root.process_mode = Node.PROCESS_MODE_ALWAYS


static func tap_sound() -> void:
	play_sfx(&"ui_tap")


## 播放音效(經 Sfx Autoload;節點還沒加入場景時也可以呼叫)。
static func play_sfx(id: StringName) -> void:
	var sfx := _autoload(&"Sfx")
	if sfx != null:
		sfx.call(&"play", id)


## 遊戲區在畫面上的位置(邏輯像素);介面依安全區排列,但不超出這個寬度太多。
static func safe_rect() -> Rect2:
	return SafeArea.get_safe_rect()


static func game_rect() -> Rect2:
	return SafeArea.get_game_rect()


## 把位置取整數,像素字與像素圖才會清楚。
static func snap(v: Vector2) -> Vector2:
	return v.floor()


static func center_in(rect: Rect2, item_size: Vector2) -> Vector2:
	return (rect.position + (rect.size - item_size) * 0.5).floor()


## 給動畫精靈用:把 SpriteFrames 裡不循環的動畫複製成循環版(圖庫、畫面裝飾用)。
static func looping_frames(frames: SpriteFrames) -> SpriteFrames:
	var copy := frames.duplicate() as SpriteFrames
	for anim in copy.get_animation_names():
		copy.set_animation_loop(anim, true)
	return copy


static func _autoload(name: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(name)))


## 放在 Control 版面裡的動畫角色(整數倍放大)。
static func sprite_box(frames_path: String, anim: StringName, scale: int = 2) -> Control:
	var frames := load(frames_path) as SpriteFrames
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frames == null:
		return holder
	var tex := frames.get_frame_texture(anim, 0)
	var frame_size := tex.get_size() if tex != null else Vector2(24, 24)
	holder.custom_minimum_size = frame_size * scale
	holder.size = holder.custom_minimum_size
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = looping_frames(frames)
	spr.centered = false
	spr.scale = Vector2(scale, scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(spr)
	spr.play(anim)
	return holder


## 置中鋪滿畫面的背景圖(比畫面大的像素圖,裁掉外圍)。
static func backdrop(tex: Texture2D) -> TextureRect:
	var t := texture_rect(tex)
	t.name = "Backdrop"
	return t


static func place_backdrop(t: TextureRect) -> void:
	if t.texture == null:
		return
	var screen := SafeArea.get_screen_size()
	t.size = screen if t.texture.resource_path.begins_with("res://assets/ui/title_bg") else t.texture.get_size()
	t.position = ((screen - t.size) * 0.5).floor()


## 時間格式:分:秒。
static func format_time(seconds: float) -> String:
	var total := int(round(maxf(seconds, 0.0)))
	return "%d:%02d" % [floori(total / 60.0), total % 60]
