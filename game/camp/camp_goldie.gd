class_name CampGoldie
extends Node2D
## 營地裡卸下盔甲、趴在營火旁的金毛(DEV_PLAN 15 DP1)。
##
## - 平常:呼吸(rest 動畫)、偶爾眨眼、慢慢搖尾巴。
## - 被摸頭(pet()):瞇眼吐舌(happy 動畫)、耳朵豎起、尾巴搖得飛快、身體開心地彈一下,
##   一隻手在頭上摸兩下,冒出音符。
## - 進營地一會兒還沒被摸過時,頭上冒出「想被摸」的愛心泡泡(show_hint)。
## 位置是金毛圖的中心(畫面邏輯像素)。圖朝右畫,flip 時朝左。

signal petted()

var config: CampConfig
var happy_left: float = 0.0
var show_hint: bool = false

var _rig: Node2D
var _body: AnimatedSprite2D
var _tail: AnimatedSprite2D
var _overlay: Node2D
var _time: float = 0.0
var _blink_in: float = 3.0
var _blink_left: float = 0.0
var _bounce: float = 0.0
var _rng := RandomNumberGenerator.new()
var _frame_size: Vector2 = Vector2(34, 24)


func _init(p_config: CampConfig = null) -> void:
	config = p_config
	name = "Goldie"


func _ready() -> void:
	if config == null:
		config = CampConfig.new()
	_rng.seed = 11
	scale = Vector2.ONE * config.goldie_scale
	_rig = Node2D.new()
	_rig.name = "Rig"
	_rig.scale = Vector2(-1.0 if config.goldie_flip else 1.0, 1.0)
	add_child(_rig)
	if config.tail_frames != null and config.tail_frames.has_animation(&"wag"):
		_tail = AnimatedSprite2D.new()
		_tail.name = "Tail"
		_tail.sprite_frames = config.tail_frames
		_tail.centered = false
		var tex := config.tail_frames.get_frame_texture(&"wag", 0)
		var tail_size := tex.get_size() if tex != null else Vector2(14, 12)
		# 尾巴的根在每格的右下角附近
		_tail.offset = -Vector2(tail_size.x - 2.0, tail_size.y - 3.0)
		_tail.position = config.tail_offset
		_tail.play(&"wag")
		_rig.add_child(_tail)
	_body = AnimatedSprite2D.new()
	_body.name = "Body"
	_body.sprite_frames = config.goldie_frames
	_rig.add_child(_body)
	if config.goldie_frames != null:
		var anim := _pick(config.goldie_animation)
		if anim != &"":
			var tex := config.goldie_frames.get_frame_texture(anim, 0)
			if tex != null:
				_frame_size = tex.get_size()
	_play(config.goldie_animation)
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_blink_in = _rng.randf_range(config.blink_every_min, config.blink_every_max)
	_update_tail_speed()


func _process(delta: float) -> void:
	advance(delta)


## 推進動畫(_process 每格呼叫;測試可以直接呼叫)。
func advance(delta: float) -> void:
	_time += delta
	if happy_left > 0.0:
		happy_left = maxf(0.0, happy_left - delta)
		if happy_left == 0.0:
			_play(config.goldie_animation)
			_update_tail_speed()
	elif _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_play(config.goldie_animation)
	else:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_in = _rng.randf_range(config.blink_every_min, config.blink_every_max)
			if _has(config.goldie_blink_animation):
				_blink_left = 0.14
				_play(config.goldie_blink_animation)
	# 開心地彈一下:先壓扁再拉長,然後回復
	_bounce = maxf(0.0, _bounce - delta * 3.2)
	var squash := sin(_bounce * PI * 2.0) * _bounce * 0.12
	var sign_x := -1.0 if config.goldie_flip else 1.0
	_rig.scale = Vector2(sign_x * (1.0 + squash), 1.0 - squash)
	_rig.position = Vector2(0, roundf(squash * _frame_size.y * 0.5))
	_overlay.queue_redraw()


## 摸摸頭。只有反應(開心的動畫);滿意度由 Camp 決定。
func pet() -> void:
	happy_left = config.pet_react_sec
	_blink_left = 0.0
	_bounce = 1.0
	show_hint = false
	_play(config.goldie_happy_animation)
	_update_tail_speed()
	petted.emit()


func is_happy() -> bool:
	return happy_left > 0.0


## 目前的動畫名稱(測試用)。
func current_animation() -> StringName:
	return _body.animation if _body != null else &""


## 頭頂的位置(畫面邏輯像素):愛心、泡泡、摸頭的手都放這裡。
func head_position() -> Vector2:
	var local := Vector2(_frame_size.x * 0.5 - 10.0, -_frame_size.y * 0.5 + 4.0)
	if config.goldie_flip:
		local.x = -local.x
	return position + local * scale


## 可以點的範圍(畫面邏輯像素),比圖稍大一些。
func touch_rect() -> Rect2:
	var size := _frame_size * scale
	return Rect2(position - size * 0.5, size).grow(config.pet_touch_margin)


func _update_tail_speed() -> void:
	if _tail == null:
		return
	# wag 動畫一來一回 4 格、每秒 8 格 = 每秒搖 2 下。
	var wags := config.tail_wags_per_sec * (config.pet_wag_mult if happy_left > 0.0 else 1.0)
	_tail.speed_scale = maxf(0.05, wags / 2.0)


func _pick(anim: StringName) -> StringName:
	if _has(anim):
		return anim
	if _has(&"idle"):
		return &"idle"
	return &""


func _has(anim: StringName) -> bool:
	return config.goldie_frames != null and anim != &"" and config.goldie_frames.has_animation(anim)


func _play(anim: StringName) -> void:
	var pick := _pick(anim)
	if pick != &"" and _body != null:
		_body.play(pick)


# --- 疊在上面的圖(手、音符、泡泡);座標是金毛的本地座標(已乘 scale) ---

func _draw_overlay() -> void:
	var inv := 1.0 / maxf(scale.x, 0.01)
	var head := (head_position() - position) * inv
	if happy_left > 0.0:
		var t := 1.0 - happy_left / maxf(config.pet_react_sec, 0.01)
		# 摸頭的手:在頭上左右揉兩下
		if t < 0.8:
			var rub := sin(t / 0.8 * PI * 4.0)
			var hand_at := head + Vector2(roundf(rub * 1.5), -4.0 + roundf(absf(rub)))
			_draw_pat_hand(hand_at, 1.0 - maxf(0.0, (t - 0.6) / 0.2))
		# 音符往上飄
		var note_t := fmod(t * 1.6, 1.0)
		var note := head + Vector2(-6.0 * (1.0 if config.goldie_flip else -1.0) * (1.0 + note_t), -8.0 - note_t * 8.0)
		_draw_note(note, 1.0 - note_t)
	elif show_hint:
		# 「想被摸」:頭上的對話泡泡,裡面一顆會跳的愛心
		var bob := roundf(sin(_time * 4.0) * 1.0)
		var bubble := head + Vector2(0, -11.0 + bob)
		var box := Rect2(bubble - Vector2(6, 5), Vector2(13, 10))
		_overlay.draw_rect(box.grow(1), MinigameUi.INK)
		_overlay.draw_rect(box, MinigameUi.WHITE)
		_overlay.draw_rect(Rect2(bubble + Vector2(-1, 5), Vector2(3, 2)), MinigameUi.INK)
		_overlay.draw_rect(Rect2(bubble + Vector2(0, 5), Vector2(1, 1)), MinigameUi.WHITE)
		var beat := 1.0 if fmod(_time, 0.8) < 0.15 else 0.0
		MinigameUi.draw_heart(_overlay, bubble + Vector2(0.5, -0.5 - beat * 0.5), 1.0)


## 張開的手掌(從上面看),9×7 格。
func _draw_pat_hand(center: Vector2, alpha: float) -> void:
	const ROWS: Array[String] = [".x.x.x...", "xoxoxox..", "xoooooxx.", "xooooooox", ".xoooooox", "..xoooox.", "...xxxx.."]
	var fill := Color(MinigameUi.WHITE, alpha)
	var edge := Color(MinigameUi.INK, alpha)
	var origin := center - Vector2(4, 4)
	for y in ROWS.size():
		for x in ROWS[y].length():
			var ch := ROWS[y][x]
			if ch != ".":
				_overlay.draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), edge if ch == "x" else fill)


func _draw_note(at: Vector2, alpha: float) -> void:
	var c := Color(MinigameUi.WHITE, alpha)
	var p := at.round()
	_overlay.draw_rect(Rect2(p + Vector2(0, 2), Vector2(2, 2)), c)
	_overlay.draw_rect(Rect2(p + Vector2(1, -2), Vector2(1, 4)), c)
	_overlay.draw_rect(Rect2(p + Vector2(2, -2), Vector2(2, 1)), c)
