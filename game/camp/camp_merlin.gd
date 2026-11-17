class_name CampMerlin
extends Node2D
## 營地裡的梅林(DEV_PLAN 16 DS2):年邁的西施犬魔法師,坐在圓桌後面(桌面遮住下半身)。
##
## - 平常:idle 動畫,身體隨呼吸輕輕起伏。
## - 偶爾施法:cast 動畫,手杖頂端的星星發亮、冒出 sparkle 閃光(merlin_cast_every_min 至 max 秒一次)。
## - 被點(Camp.tap_merlin):立刻施法一次;要說的話由 Camp 顯示在對話泡泡裡。
## 圖用 C 線的 assets/sprites/merlin/merlin_frames.tres(idle、run、cast);C 線原地替換,這裡不用改。
## 位置是梅林圖的中心(畫面邏輯像素)。圖朝右畫,merlin_flip 時朝左。
## v2.6 DV1:第三章由湖中仙女坐在同一個位置(Camp 建立時換 frames、glow_color、tip;其他數值沿用梅林的)。

signal cast_started()

var config: CampConfig
## 用哪一套圖(梅林或湖中仙女)。
var frames: SpriteFrames
## 施法時的光的顏色。
var glow_color: Color = Color(0.55, 0.75, 1.0, 0.35)
## 施法時光的位置(相對圖中心,圖的像素;朝右時)。
var tip: Vector2 = Vector2(9, -7)
## 這次施法還剩幾秒(> 0 = 正在施法)。
var casting_left: float = 0.0
## 施法次數(測試用)。
var cast_count: int = 0

var _sprite: AnimatedSprite2D
var _glow: Node2D
var _time: float = 0.0
var _next_cast: float = 0.0
var _rng := RandomNumberGenerator.new()
var _frame_size: Vector2 = Vector2(24, 24)


func _init(p_config: CampConfig = null, p_frames: SpriteFrames = null) -> void:
	config = p_config
	name = "Merlin"
	if config != null:
		frames = p_frames if p_frames != null else config.merlin_frames
		glow_color = config.merlin_glow_color
		tip = config.merlin_staff_tip


func _ready() -> void:
	if config == null:
		config = CampConfig.new()
		frames = config.merlin_frames
	_rng.seed = 23
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(-config.merlin_scale if config.merlin_flip else config.merlin_scale, config.merlin_scale)
	add_child(_sprite)
	if frames != null:
		var anim := _pick(config.merlin_idle_animation)
		if anim != &"":
			var tex := frames.get_frame_texture(anim, 0)
			if tex != null:
				_frame_size = tex.get_size()
	_play(config.merlin_idle_animation)
	# 手杖頂端的光暈(加亮混合,施法時才亮)
	_glow = Node2D.new()
	_glow.name = "Glow"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_next_cast = _rng.randf_range(config.merlin_cast_every_min * 0.5, config.merlin_cast_every_max * 0.6)


func _process(delta: float) -> void:
	advance(delta)


## 推進動畫(_process 每格呼叫;測試可以直接呼叫)。
func advance(delta: float) -> void:
	_time += delta
	if casting_left > 0.0:
		casting_left = maxf(0.0, casting_left - delta)
		if casting_left == 0.0:
			_play(config.merlin_idle_animation)
	elif config.merlin_cast_every_max > 0.0:
		_next_cast -= delta
		if _next_cast <= 0.0:
			cast()
	# 呼吸:每 2.4 秒上下 1 像素(像素風:整數位移)
	_sprite.position = Vector2(0, -1.0 if fmod(_time, 2.4) < 1.2 else 0.0)
	_glow.queue_redraw()


## 施法一次:cast 動畫、手杖發光、冒閃光。音效與震動由呼叫的一方決定(點梅林時才有)。
func cast() -> void:
	casting_left = maxf(config.merlin_cast_sec, 0.05)
	_next_cast = _rng.randf_range(config.merlin_cast_every_min, maxf(config.merlin_cast_every_min, config.merlin_cast_every_max))
	cast_count += 1
	_play(config.merlin_cast_animation)
	if config.merlin_sparkle_particles != null and is_inside_tree():
		var fx := config.merlin_sparkle_particles.instantiate()
		if fx is Node2D:
			(fx as Node2D).position = (staff_tip() - position).round()
		add_child(fx)
	cast_started.emit()


func is_casting() -> bool:
	return casting_left > 0.0


## 目前的動畫名稱(測試用)。
func current_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


## 手杖頂端的位置(畫面邏輯像素)。
func staff_tip() -> Vector2:
	var local := tip
	if config.merlin_flip:
		local.x = -local.x
	return position + local * config.merlin_scale


## 對話泡泡的尾巴要指向的地方:頭頂上方(畫面邏輯像素)。
func speech_anchor() -> Vector2:
	var head := Vector2(2.0 if not config.merlin_flip else -2.0, -_frame_size.y * 0.5)
	return (position + head * config.merlin_scale + Vector2(0, -1)).round()


## 圖的範圍(畫面邏輯像素)。
func sprite_rect() -> Rect2:
	var size := _frame_size * config.merlin_scale
	return Rect2(position - size * 0.5, size)


func _pick(anim: StringName) -> StringName:
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


func _draw_glow() -> void:
	if casting_left <= 0.0:
		return
	var t := 1.0 - casting_left / maxf(config.merlin_cast_sec, 0.05)
	var strength := sin(t * PI)
	var c := (staff_tip() - position).round()
	var color := glow_color
	for i in 3:
		var r := roundf((4.0 + i * 3.0) * (0.7 + 0.3 * strength))
		_glow.draw_circle(c, r, Color(color, color.a * strength * (1.0 - i * 0.3)))
	# 十字星光
	var arm := roundf(2.0 + 3.0 * strength)
	_glow.draw_rect(Rect2(c + Vector2(-arm, 0), Vector2(arm * 2.0 + 1.0, 1)), Color(1, 1, 0.9, strength))
	_glow.draw_rect(Rect2(c + Vector2(0, -arm), Vector2(1, arm * 2.0 + 1.0)), Color(1, 1, 0.9, strength))
