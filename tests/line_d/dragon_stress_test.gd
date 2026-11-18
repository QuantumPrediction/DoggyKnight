extends "res://tests/line_d/boss_stress_test.gd"
## v2.7 DW4:第五章雙頭目(紅龍 + 白龍)+ 四位同伴 + 投射物的效能量測(DEV_PLAN 20)。
## 沿用 boss_stress_test.gd 的場地、量測與替身類別,只換頭目、小怪與同伴。
##
## 場上一直有(load = 1 時;--load=N 全部乘 N):
## - 紅龍與白龍(64 格的圖,各帶加亮光暈),左右慢慢飄。
##   - 吐息:每 BREATH_EVERY 秒先畫扇形預警 BREATH_WARN 秒,再噴 BREATH_SHOTS 顆(紅龍火球、白龍冰刺,帶光暈)。
##   - 每 FIREBALL_EVERY 秒對準金毛一顆大的;白龍每 ICE_RING_EVERY 秒放一圈 ICE_RING 根冰刺。
##   - 每 ENRAGE_CYCLE 秒的最後 ENRAGE_SEC 秒:紅龍坐下生悶氣(sulk,不出招),白龍 roar 之後招式快一倍。
## - 小怪:火蜥蜴 SALAMANDERS 隻追著金毛、身後每 TRAIL_EVERY 秒留一團小火苗(有碰撞);
##   雪人 SNOWMEN 隻在外圍繞,每 SNOWBALL_EVERY 秒丟雪球(落點先出現影子)。
## - 金毛 + 四位同伴(貝德維爾、蘭斯洛特、崔斯坦、高文)。A 線的同伴資料存在時用正式的(spawn_companion),
##   不存在時用替身:崔斯坦每 NOTE_EVERY 秒朝最近的龍射音符(music_note,我方投射物),
##   高文每 SLAM_EVERY 秒大鐵鎚落地(擴散的衝擊圈 + 震波特效)。
## - 特效同摩根娜的場景(命中、閃光,有同時存在的上限)。
##
## 用法:
##   godot --path . res://tests/line_d/dragon_stress_test.tscn
##   godot --headless --path . res://tests/line_d/dragon_stress_test.tscn -- --bench-seconds=20 --quit-when-done
## 參數同 boss_stress_test:--load=N、--no-glow、--no-minions、--uncapped-fps(--no-clones、--no-beam 沒有作用)。

const RED_FRAMES_PATH: String = "res://assets/sprites/red_dragon/red_dragon_frames.tres"
const WHITE_FRAMES_PATH: String = "res://assets/sprites/white_dragon/white_dragon_frames.tres"
const SALAMANDER_FRAMES_PATH: String = "res://assets/sprites/salamander/salamander_frames.tres"
const SNOWMAN_FRAMES_PATH: String = "res://assets/sprites/snowman/snowman_frames.tres"
const TRISTAN_FRAMES_PATH: String = "res://assets/sprites/tristan/tristan_frames.tres"
const GAWAIN_FRAMES_PATH: String = "res://assets/sprites/gawain/gawain_frames.tres"
const FIREBALL_PATH: String = "res://assets/fx/fireball/fireball_frames.tres"
const ICE_SHARD_PATH: String = "res://assets/fx/ice_shard/ice_shard_frames.tres"
const SNOWBALL_PATH: String = "res://assets/fx/snowball/snowball_frames.tres"
const MUSIC_NOTE_PATH: String = "res://assets/fx/music_note/music_note_frames.tres"
const DRAGON_BACKGROUND_PATH: String = "res://assets/backgrounds/dragon_nest.tscn"
const SHOCKWAVE_PATH: String = "res://assets/fx/particles/shockwave.tscn"

const BREATH_EVERY: float = 3.0
const BREATH_WARN: float = 0.8
const BREATH_SHOTS: int = 7
const BREATH_SPREAD: float = 0.9
const FIREBALL_EVERY: float = 1.2
const ICE_RING: int = 12
const ICE_RING_EVERY: float = 4.0
const SHOT_SPEED: float = 75.0
const ENRAGE_CYCLE: float = 12.0
const ENRAGE_SEC: float = 4.0
const SALAMANDERS: int = 4
const SNOWMEN: int = 3
const TRAIL_EVERY: float = 0.35
const TRAIL_SEC: float = 1.0
const SNOWBALL_EVERY: float = 2.2
const SNOWBALL_WARN: float = 0.8
const NOTE_EVERY: float = 1.5
const NOTE_SPEED: float = 90.0
const SLAM_EVERY: float = 4.0
const SLAM_RADIUS: float = 30.0

## 紅龍正在生悶氣(白龍暴怒中)。
var sulking: bool = false
var notes_fired: int = 0
var slams: int = 0
var breaths: int = 0

var _red: AnimatedSprite2D
var _white: AnimatedSprite2D
var _pattern_time: float = 0.0
var _clock: Dictionary = {}
## 預警結束後才噴的吐息:{"left": 秒, "dragon": AnimatedSprite2D, "frames": String, "glow": Color, "aim": Vector2}
var _pending_breaths: Array[Dictionary] = []
var _salamanders: Array[Node2D] = []
var _snowmen: Array[Node2D] = []


func _init() -> void:
	tag = "dragon-stress"
	companion_ids = [&"bulldog", &"lancelot", &"tristan", &"gawain"]


func _ready() -> void:
	super()
	if ResourceLoader.exists(SHOCKWAVE_PATH):
		_fx_scenes[&"shockwave"] = load(SHOCKWAVE_PATH)
	for key: String in ["red_breath", "white_breath", "red_ball", "white_ball", "ring", "trail", "snowball", "note", "slam"]:
		_clock[key] = 0.3
	_clock["white_breath"] = BREATH_EVERY * 0.5
	print("[%s] dragons=%d companions=%d (stand-ins: %s)" % [tag, dragon_count(), companions().size(), stand_in_ids()])


func _frame_paths() -> Dictionary:
	var paths := super()
	paths.merge({"red": RED_FRAMES_PATH, "white": WHITE_FRAMES_PATH, "salamander": SALAMANDER_FRAMES_PATH,
		"snowman": SNOWMAN_FRAMES_PATH, "tristan": TRISTAN_FRAMES_PATH, "gawain": GAWAIN_FRAMES_PATH,
		"fireball": FIREBALL_PATH, "ice_shard": ICE_SHARD_PATH, "snowball": SNOWBALL_PATH, "music_note": MUSIC_NOTE_PATH})
	return paths


func _background_path() -> String:
	return DRAGON_BACKGROUND_PATH


func dragon_count() -> int:
	var count := 0
	for d: AnimatedSprite2D in [_red, _white]:
		if d != null and is_instance_valid(d):
			count += 1
	return count


## 用替身的同伴(A 線的同伴資料還沒有時)。
func stand_in_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for c in companions():
		if c != null and String(c.name).begins_with("StandIn_"):
			ids.append(String(c.name).trim_prefix("StandIn_"))
	return ids


# --- 雙龍 ---

func _build_boss() -> void:
	var r := Layout.ARENA_RECT
	var top := r.position.y + 52.0
	_red = _stand_in_sprite("red", Vector2(r.get_center().x - 40.0, top))
	_red.name = "RedDragon"
	_white = _stand_in_sprite("white", Vector2(r.get_center().x + 40.0, top))
	_white.name = "WhiteDragon"
	for d: AnimatedSprite2D in [_red, _white]:
		d.z_index = 3
		if d.sprite_frames != null and d.sprite_frames.has_animation(&"idle"):
			d.play(&"idle")
	_add_glow(_red, 3.0, Color(1.0, 0.5, 0.25, 0.35))
	_add_glow(_white, 3.0, Color(0.6, 0.85, 1.0, 0.35))
	# 摩根娜場景的特效與「頭目」指向紅龍
	_boss = _red


func _build_minions() -> void:
	var r := Layout.ARENA_RECT.grow(-14)
	var index := 0
	for i in SALAMANDERS * load_mult:
		var m := BossMinion.new()
		m.setup(_frames.get("salamander"), BossMinion.Mode.CHASE, _player, 55.0, 5.0, index)
		m.position = r.position + Vector2(fmod(index * 37.0, r.size.x), r.size.y * 0.6 + fmod(index * 23.0, r.size.y * 0.3))
		add_child(m)
		_salamanders.append(m)
		index += 1
	for i in SNOWMEN * load_mult:
		var m := BossMinion.new()
		m.setup(_frames.get("snowman"), BossMinion.Mode.ORBIT, _player, 18.0, 7.0, index)
		m.position = r.position + Vector2(fmod(index * 41.0, r.size.x), fmod(index * 29.0, r.size.y * 0.5))
		add_child(m)
		_snowmen.append(m)
		index += 1


## 推進雙龍、小怪與同伴的招式(_process 每格呼叫;測試可以直接呼叫)。
func run_patterns(delta: float) -> void:
	_pattern_time += delta
	var was_sulking := sulking
	sulking = fmod(_pattern_time, ENRAGE_CYCLE) >= ENRAGE_CYCLE - ENRAGE_SEC
	if sulking != was_sulking:
		_play(_red, &"sulk" if sulking else &"idle")
		_play(_white, &"roar" if sulking else &"idle")
	var center_x := Layout.ARENA_RECT.get_center().x
	if _red != null:
		_red.position.x = center_x - 40.0 + sin(_pattern_time * 0.7) * 16.0
	if _white != null:
		_white.position.x = center_x + 40.0 + sin(_pattern_time * 0.8 + 2.0) * 16.0
	var white_rate := 2.0 if sulking else 1.0
	if not sulking:
		_dragon_attacks("red", _red, "fireball", Color(1.0, 0.55, 0.25, 0.45), delta, 1.0)
	_dragon_attacks("white", _white, "ice_shard", Color(0.6, 0.85, 1.0, 0.45), delta, white_rate)
	if _tick("ring", delta * white_rate, ICE_RING_EVERY) and _white != null:
		for i in ICE_RING * load_mult:
			var dir := Vector2.RIGHT.rotated(TAU * i / (ICE_RING * load_mult) + _pattern_time)
			_fire_shot("ice_shard", _white.position, dir * SHOT_SPEED * 0.8, 2.4, 0.0, 3.0)
	for i in range(_pending_breaths.size() - 1, -1, -1):
		var b := _pending_breaths[i]
		b["left"] = float(b["left"]) - delta
		if float(b["left"]) <= 0.0:
			_pending_breaths.remove_at(i)
			var dragon := b["dragon"] as AnimatedSprite2D
			var glow_color: Color = b["glow"]
			if dragon != null and is_instance_valid(dragon):
				breaths += 1
				for k in load_mult:
					_fire_fan(dragon.position, BREATH_SHOTS, BREATH_SPREAD, String(b["frames"]), SHOT_SPEED, 1.0, glow_color)
	_run_minion_attacks(delta)
	_run_companion_attacks(delta)


func _dragon_attacks(key: String, dragon: AnimatedSprite2D, frames_key: String, glow: Color, delta: float, rate: float) -> void:
	if dragon == null:
		return
	if _tick(key + "_breath", delta * rate, BREATH_EVERY):
		var aim := (_player.global_position - dragon.position).normalized() if _player != null else Vector2.DOWN
		var cone := WarningCone.new()
		cone.position = dragon.position
		cone.direction = aim
		cone.spread = BREATH_SPREAD
		cone.length = 90.0
		cone.life = BREATH_WARN
		cone.color = Color(glow, 0.6)
		_warnings.add_child(cone)
		_pending_breaths.append({"left": BREATH_WARN, "dragon": dragon, "frames": frames_key, "glow": glow})
		_play(dragon, &"breath")
	if _tick(key + "_ball", delta * rate, FIREBALL_EVERY):
		var aim := (_player.global_position - dragon.position).normalized() if _player != null else Vector2.DOWN
		for k in load_mult:
			var shot := _fire_shot(frames_key, dragon.position, aim.rotated((k - (load_mult - 1) * 0.5) * 0.25) * SHOT_SPEED * 1.2, 3.0, 0.0, 5.0)
			_add_glow(shot, 1.4, glow)


func _run_minion_attacks(delta: float) -> void:
	if _tick("trail", delta, TRAIL_EVERY):
		for m in _salamanders:
			if m != null and is_instance_valid(m):
				_fire_shot("fox_flame", m.global_position, Vector2.ZERO, TRAIL_SEC, 0.0, 4.0)
	if _tick("snowball", delta, SNOWBALL_EVERY) and _player != null:
		for i in _snowmen.size():
			var at := _player.global_position + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-24.0, 24.0))
			_add_warning(at, 7.0, SNOWBALL_WARN, Color(0.2, 0.25, 0.45, 0.5))
			_fire_shot("snowball", at, Vector2.ZERO, 0.35, SNOWBALL_WARN, 6.0)


## 替身的崔斯坦與高文(A 線的同伴還沒合併時):音符與大鐵鎚。正式的同伴自己會攻擊。
func _run_companion_attacks(delta: float) -> void:
	var stand_ins := stand_in_ids()
	if stand_ins.has("tristan") and _tick("note", delta, NOTE_EVERY):
		var tristan := _find_companion("tristan")
		var target := _nearest_dragon(tristan.global_position)
		if target != null:
			var dir := (target.position - tristan.global_position).normalized()
			for k in load_mult:
				_fire_shot("music_note", tristan.global_position, dir.rotated(k * 0.2) * NOTE_SPEED, 2.0, 0.0, 4.0, true)
				notes_fired += 1
	if stand_ins.has("gawain") and _tick("slam", delta, SLAM_EVERY):
		var gawain := _find_companion("gawain")
		for k in load_mult:
			var ring := SlamRing.new()
			ring.position = gawain.global_position
			ring.radius = SLAM_RADIUS
			_shots.add_child(ring)
			slams += 1
		_spawn_fx(&"shockwave", gawain.global_position)
		_spawn_fx(&"star_burst", gawain.global_position)


func _find_companion(id: String) -> Node2D:
	for c in companions():
		if c != null and is_instance_valid(c) and String(c.name) == "StandIn_" + id:
			return c
	return _player


func _nearest_dragon(from: Vector2) -> AnimatedSprite2D:
	var best: AnimatedSprite2D = null
	for d: AnimatedSprite2D in [_red, _white]:
		if d != null and is_instance_valid(d) and (best == null or from.distance_to(d.position) < from.distance_to(best.position)):
			best = d
	return best


## 倒數計時:到了傳回 true 並重設為 every。
func _tick(key: String, delta: float, every: float) -> bool:
	_clock[key] = float(_clock.get(key, every)) - delta
	if float(_clock[key]) <= 0.0:
		_clock[key] = every
		return true
	return false


static func _play(sprite: AnimatedSprite2D, anim: StringName) -> void:
	if sprite != null and sprite.sprite_frames != null:
		sprite.play(anim if sprite.sprite_frames.has_animation(anim) else &"idle")


## 吐息的扇形預警:慢慢變亮,時間到就消失。
class WarningCone:
	extends Node2D
	var direction: Vector2 = Vector2.DOWN
	var spread: float = 0.9
	var length: float = 90.0
	var life: float = 0.8
	var color: Color = Color.RED
	var _age: float = 0.0

	func _process(dt: float) -> void:
		_age += dt
		if _age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 9:
			pts.append(direction.rotated(-spread * 0.5 + spread * i / 8.0) * length)
		draw_colored_polygon(pts, Color(color, color.a * 0.35 * t))
		draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), color, 1.0)


## 高文的大鐵鎚落地:擴散的衝擊圈(我方攻擊判定),0.3 秒後消失。
class SlamRing:
	extends Area2D
	var radius: float = 30.0
	var _age: float = 0.0
	var _shape: CircleShape2D

	func _ready() -> void:
		collision_layer = Layers.PLAYER_ATTACK
		collision_mask = Layers.ENEMY
		monitorable = false
		var shape := CollisionShape2D.new()
		_shape = CircleShape2D.new()
		_shape.radius = 4.0
		shape.shape = _shape
		add_child(shape)

	func _physics_process(dt: float) -> void:
		_age += dt
		_shape.radius = lerpf(4.0, radius, clampf(_age / 0.3, 0.0, 1.0))
		queue_redraw()
		if _age >= 0.3:
			queue_free()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, _shape.radius if _shape != null else 4.0, 0, TAU, 24, Color(1, 0.9, 0.6, 1.0 - _age / 0.3), 2.0)
