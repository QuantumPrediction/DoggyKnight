class_name CampLancelot
extends Node2D
## 營地裡的蘭斯洛特(v2.6 DV1):柴犬長槍騎士,第二章起站在圓桌右後方(桌面遮住下半身),朝左看著營火。
##
## - 平常:idle 動畫,身體隨呼吸輕輕起伏(和梅林錯開節奏)。
## - 被點(Camp.tap_lancelot):播 lancelot_tap_animation(轉一下長槍)、跳一下、槍尖閃一下;
##   要說的話由 Camp 顯示在對話泡泡裡。
## 圖用 C 線的 assets/sprites/lancelot/lancelot_frames.tres;C 線原地替換,這裡不用改。
## 位置是圖的中心(畫面邏輯像素)。

var config: CampConfig
## 這次「被點」的動作還剩幾秒。
var poke_left: float = 0.0
## 被點的次數(測試用)。
var poke_count: int = 0

var _sprite: AnimatedSprite2D
var _shine: Node2D
var _time: float = 0.0
var _frame_size: Vector2 = Vector2(32, 32)


func _init(p_config: CampConfig = null) -> void:
	config = p_config
	name = "Lancelot"


func _ready() -> void:
	if config == null:
		config = CampConfig.new()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = config.lancelot_frames
	_sprite.scale = Vector2(-config.lancelot_scale if config.lancelot_flip else config.lancelot_scale, config.lancelot_scale)
	add_child(_sprite)
	var idle := _pick(config.lancelot_idle_animation)
	if idle != &"":
		var tex := config.lancelot_frames.get_frame_texture(idle, 0)
		if tex != null:
			_frame_size = tex.get_size()
	_play(config.lancelot_idle_animation)
	_shine = Node2D.new()
	_shine.name = "Shine"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shine.material = mat
	_shine.draw.connect(_draw_shine)
	add_child(_shine)


func _process(delta: float) -> void:
	advance(delta)


## 推進動畫(_process 每格呼叫;測試可以直接呼叫)。
func advance(delta: float) -> void:
	_time += delta
	if poke_left > 0.0:
		poke_left = maxf(0.0, poke_left - delta)
		if poke_left == 0.0:
			_play(config.lancelot_idle_animation)
	# 呼吸:每 2.0 秒上下 1 像素;被點時跳起 3 像素
	var hop := 0.0
	if poke_left > 0.0:
		var t := 1.0 - poke_left / maxf(config.lancelot_tap_sec, 0.05)
		hop = roundf(sin(minf(t * 2.0, 1.0) * PI) * 3.0)
	_sprite.position = Vector2(0, (-1.0 if fmod(_time + 0.7, 2.0) < 1.0 else 0.0) - hop)
	_shine.queue_redraw()


## 被點:轉一下長槍、跳一下、槍尖閃光。音效與震動由 Camp 決定。
func poke() -> void:
	poke_left = maxf(config.lancelot_tap_sec, 0.05)
	poke_count += 1
	_play(config.lancelot_tap_animation)
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.frame = 0


func is_poking() -> bool:
	return poke_left > 0.0


## 目前的動畫名稱(測試用)。
func current_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


## 對話泡泡的尾巴要指向的地方:頭頂上方(畫面邏輯像素)。
func speech_anchor() -> Vector2:
	var head := Vector2(-2.0 if config.lancelot_flip else 2.0, -_frame_size.y * 0.5 + 2.0)
	return (position + head * config.lancelot_scale + Vector2(0, -1)).round()


## 圖的範圍(畫面邏輯像素)。
func sprite_rect() -> Rect2:
	var size := _frame_size * config.lancelot_scale
	return Rect2(position - size * 0.5, size)


func _pick(anim: StringName) -> StringName:
	var frames := config.lancelot_frames
	if frames == null:
		return &""
	if anim != &"" and frames.has_animation(anim):
		return anim
	if frames.has_animation(&"idle"):
		return &"idle"
	return &""


func _play(anim: StringName) -> void:
	var pick := _pick(anim)
	if pick != &"" and _sprite != null:
		_sprite.play(pick)


func _draw_shine() -> void:
	if poke_left <= 0.0:
		return
	var t := 1.0 - poke_left / maxf(config.lancelot_tap_sec, 0.05)
	var strength := sin(t * PI)
	# 槍尖在圖的前上方(朝左時在左上)
	var side := -1.0 if config.lancelot_flip else 1.0
	var c := (Vector2(side * _frame_size.x * 0.42, -_frame_size.y * 0.3) * config.lancelot_scale + _sprite.position).round()
	var arm := roundf(2.0 + 4.0 * strength)
	_shine.draw_circle(c, 3.0 + 2.0 * strength, Color(0.8, 0.9, 1.0, 0.35 * strength))
	_shine.draw_rect(Rect2(c + Vector2(-arm, 0), Vector2(arm * 2.0 + 1.0, 1)), Color(1, 1, 1, strength))
	_shine.draw_rect(Rect2(c + Vector2(0, -arm), Vector2(1, arm * 2.0 + 1.0)), Color(1, 1, 1, strength))
