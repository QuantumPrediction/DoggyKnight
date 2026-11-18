class_name CampFriend
extends Node2D
## 營地裡的一位同伴(v2.7 DW1):崔斯坦、高文、摩根娜、第六章的湖中仙女。外觀與動作全在 CampFriendData。
##
## - 平常:idle 動畫,身體隨呼吸輕輕起伏;有 ambient_animation 時偶爾自己做(崔斯坦彈琴、飄出音符)。
## - 被點(Camp.tap_friend):播 tap_animation、跳一下、發光、冒特效;要說的話由 Camp 顯示在對話泡泡裡。
## 位置是圖的中心(畫面邏輯像素)。behind_table = true 時畫在夜空與地面之間(圓桌遮住下半身)。

var data: CampFriendData
## 站在圓桌後面(由 Camp 依 cast_layouts 的位置決定)。
var behind_table: bool = true
## 朝左(圖朝右畫)。Camp 排版時依位置設定(CampFriendData.auto_face),見 set_face_left()。
var face_left: bool = false
## 這次動作(被點或平常的動作)還剩幾秒。
var act_left: float = 0.0
## 這次動作是不是被點的(被點才跳、才發光)。
var poked: bool = false
## 被點的次數(測試用)。
var poke_count: int = 0
## 平常的動作做了幾次(測試用)。
var ambient_count: int = 0

var _sprite: AnimatedSprite2D
var _fx: Node2D
var _time: float = 0.0
var _phase: float = 0.0
var _next_ambient: float = 0.0
var _act_total: float = 0.1
var _frame_size: Vector2 = Vector2(32, 32)
var _rng := RandomNumberGenerator.new()
## 飄出的音符:{"pos": Vector2(相對位置), "age": float, "drift": float}
var _notes: Array[Dictionary] = []
var _note_timer: float = 0.0


func _init(p_data: CampFriendData = null) -> void:
	data = p_data
	if data != null and data.id != &"":
		name = String(data.id).to_pascal_case()


func _ready() -> void:
	if data == null:
		data = CampFriendData.new()
	face_left = face_left or data.flip
	_rng.seed = hash(data.id)
	_phase = _rng.randf() * data.breathe_sec
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = data.frames
	_sprite.scale = Vector2(-data.scale if face_left else data.scale, data.scale)
	# 不循環的動畫播完就停在最後一格,直到 act_left 歸零再回到 idle。
	add_child(_sprite)
	var idle := _pick(data.idle_animation)
	if idle != &"":
		var tex := data.frames.get_frame_texture(idle, 0)
		if tex != null:
			_frame_size = tex.get_size()
	_play(data.idle_animation)
	_fx = Node2D.new()
	_fx.name = "Fx"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = mat
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_next_ambient = _rng.randf_range(data.ambient_every_min * 0.4, maxf(data.ambient_every_min * 0.4, data.ambient_every_max * 0.6))


func _process(delta: float) -> void:
	advance(delta)


## 推進動畫(_process 每格呼叫;測試可以直接呼叫)。
func advance(delta: float) -> void:
	_time += delta
	if act_left > 0.0:
		act_left = maxf(0.0, act_left - delta)
		if act_left == 0.0:
			poked = false
			_play(data.idle_animation)
	elif data.ambient_animation != &"" and data.ambient_every_max > 0.0:
		_next_ambient -= delta
		if _next_ambient <= 0.0:
			_start_ambient()
	# 音符:動作中每 0.35 秒飄出一個,慢慢往上飄、左右晃、淡出
	if data.music_notes and act_left > 0.0:
		_note_timer -= delta
		if _note_timer <= 0.0:
			_note_timer = 0.35
			_notes.append({"pos": _note_origin(), "age": 0.0, "drift": _rng.randf_range(-1.0, 1.0)})
	for n: Dictionary in _notes:
		n["age"] = float(n["age"]) + delta
		n["pos"] = (n["pos"] as Vector2) + Vector2(sin(float(n["age"]) * 5.0 + float(n["drift"]) * 3.0) * 6.0 * delta, -12.0 * delta)
	_notes = _notes.filter(func(n: Dictionary) -> bool: return float(n["age"]) < 1.4)
	# 呼吸:整數位移(像素風);被點時跳起 hop_px
	var hop := 0.0
	if poked and act_left > 0.0:
		var t := 1.0 - act_left / maxf(_act_total, 0.05)
		hop = roundf(sin(minf(t * 2.0, 1.0) * PI) * data.hop_px)
	var half := maxf(data.breathe_sec, 0.2) * 0.5
	_sprite.position = Vector2(0, (-1.0 if fmod(_time + _phase, half * 2.0) < half else 0.0) - hop)
	_fx.queue_redraw()


## 被點:播 tap_animation、跳一下、發光、冒特效。音效、震動與說話由 Camp 決定。
func poke() -> void:
	_act_total = maxf(data.tap_sec, 0.05)
	act_left = _act_total
	poked = true
	poke_count += 1
	_note_timer = 0.0
	_play(data.tap_animation)
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.frame = 0
	if data.tap_particles != null and is_inside_tree():
		var fx := data.tap_particles.instantiate()
		if fx is Node2D:
			(fx as Node2D).position = glow_point().round()
		add_child(fx)


## 轉向(圖朝右畫;true = 朝左)。
func set_face_left(value: bool) -> void:
	face_left = value
	if _sprite != null:
		_sprite.scale.x = -data.scale if face_left else data.scale


func is_poking() -> bool:
	return poked and act_left > 0.0


## 正在做動作(被點或平常的動作)。
func is_acting() -> bool:
	return act_left > 0.0


## 目前的動畫名稱(測試用)。
func current_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


## 畫面上飄著的音符數(測試用)。
func note_count() -> int:
	return _notes.size()


## 對話泡泡的尾巴要指向的地方:頭頂上方(畫面邏輯像素)。
func speech_anchor() -> Vector2:
	var head := Vector2(-2.0 if face_left else 2.0, -_frame_size.y * 0.5 + data.head_inset)
	return (position + head * data.scale + Vector2(0, -1)).round()


## 圖的範圍(畫面邏輯像素)。
func sprite_rect() -> Rect2:
	var size := _frame_size * data.scale
	return Rect2(position - size * 0.5, size)


## 發光的位置(相對這個節點,畫面邏輯像素)。
func glow_point() -> Vector2:
	var local := data.glow_offset
	if face_left:
		local.x = -local.x
	return local * data.scale + (_sprite.position if _sprite != null else Vector2.ZERO)


func _start_ambient() -> void:
	_next_ambient = _rng.randf_range(data.ambient_every_min, maxf(data.ambient_every_min, data.ambient_every_max))
	_act_total = maxf(data.ambient_sec, 0.05)
	act_left = _act_total
	poked = false
	ambient_count += 1
	_note_timer = 0.1
	_play(data.ambient_animation)


func _note_origin() -> Vector2:
	var side := -1.0 if face_left else 1.0
	return Vector2(side * (_frame_size.x * 0.25 + _rng.randf_range(-2.0, 2.0)) * data.scale, -_frame_size.y * 0.25 * data.scale)


func _pick(anim: StringName) -> StringName:
	var frames := data.frames
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


func _draw_fx() -> void:
	# 被點時的光
	if poked and act_left > 0.0 and data.glow_color.a > 0.0:
		var t := 1.0 - act_left / maxf(_act_total, 0.05)
		var strength := sin(t * PI)
		var c := glow_point().round()
		for i in 3:
			var r := roundf((4.0 + i * 3.0) * (0.7 + 0.3 * strength))
			_fx.draw_circle(c, r, Color(data.glow_color, data.glow_color.a * strength * (1.0 - i * 0.3)))
		var arm := roundf(2.0 + 3.0 * strength)
		_fx.draw_rect(Rect2(c + Vector2(-arm, 0), Vector2(arm * 2.0 + 1.0, 1)), Color(1, 1, 0.9, strength))
		_fx.draw_rect(Rect2(c + Vector2(0, -arm), Vector2(1, arm * 2.0 + 1.0)), Color(1, 1, 0.9, strength))
	# 音符(八分音符的像素圖:符頭 2×2、符桿、符尾)
	for n: Dictionary in _notes:
		var age := float(n["age"])
		var alpha := clampf(minf(age / 0.15, (1.4 - age) / 0.5), 0.0, 1.0)
		var p := (n["pos"] as Vector2).round()
		var col := Color(data.note_color, alpha)
		_fx.draw_rect(Rect2(p + Vector2(0, 3), Vector2(3, 2)), col)
		_fx.draw_rect(Rect2(p + Vector2(2, -2), Vector2(1, 5)), col)
		_fx.draw_rect(Rect2(p + Vector2(3, -2), Vector2(2, 1)), col)
		_fx.draw_rect(Rect2(p + Vector2(4, -1), Vector2(1, 1)), col)
