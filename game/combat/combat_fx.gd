class_name CombatFx
extends RefCounted
## 產生特效的工具。特效圖在 assets/fx/<名稱>/<名稱>_frames.tres(C 線原地替換);
## 一次性粒子在 assets/fx/particles/<名稱>.tscn(DEV_PLAN 4.10,C 線原地替換)。
## 特效放在所屬戰鬥場地的特效層;不在場地內(例如單元測試)時放在呼叫者的上一層。
##
## 品質標準(DEV_PLAN 第 15 節):特效不可以蓋住預警或金毛,同時存在的特效有上限。
## - 粒子:同時最多 FeelTuning.max_particles 個(重要的必殺技、頭目特效不受限)。
##   粒子放在場地的特效層或地面層,z 跟著圖層走(地面層在預警與角色之下)。
## - 傷害數字:同時最多 FeelTuning.max_damage_numbers 個,超過時移除最舊的。
##
## 慢動作:場地在打倒頭目時設定 time_scale(0 至 1);A 線的角色與特效把 delta 乘上它。
## 不改 Engine.time_scale(那會影響流程計時與試玩機器人的倍速)。

const FRAMES_PATH := "res://assets/fx/%s/%s_frames.tres"
const PARTICLES_PATH := "res://assets/fx/particles/%s.tscn"
const DEFAULT_FEEL: FeelTuning = preload("res://data/player/feel_tuning.tres")
const PARTICLE_GROUP: StringName = &"combat_particles"

## 慢動作倍數(1 = 正常)。由場地管理;場地離開場景樹時回到 1。
static var time_scale: float = 1.0

static var _frames_cache: Dictionary = {}
static var _particle_cache: Dictionary = {}
static var _feel: FeelTuning
static var _particles_alive: int = 0
static var _numbers: Array[Node] = []


static func feel() -> FeelTuning:
	return _feel if _feel != null else DEFAULT_FEEL


## 測試或沙盒用:換一份手感數值(null = 回到 data/player/feel_tuning.tres)。
static func set_feel(tuning: FeelTuning) -> void:
	_feel = tuning


static func frames(fx_name: StringName) -> SpriteFrames:
	if not _frames_cache.has(fx_name):
		var path := FRAMES_PATH % [fx_name, fx_name]
		_frames_cache[fx_name] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	return _frames_cache[fx_name]


## 找出 node 所在的戰鬥場地(有 spawn_enemy 方法的祖先)。找不到傳回 null。
static func find_arena(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method(&"spawn_enemy") and current.has_method(&"get_fx_layer"):
			return current
		current = current.get_parent()
	return null


## 特效要放進哪一個節點。ground = true 放在角色之下(塵土、盔甲碎片),否則在角色之上。
static func layer_for(node: Node, ground: bool = false) -> Node:
	var arena := find_arena(node)
	if arena != null:
		return arena.call(&"get_ground_layer") if ground else arena.call(&"get_fx_layer")
	var parent := node.get_parent()
	return parent if parent != null else node


## 在世界座標 at 播一次特效。傳回特效節點(可再調整),特效檔不存在時傳回 null。
static func spawn(host: Node, fx_name: StringName, at: Vector2, rotation: float = 0.0,
		scale: Vector2 = Vector2.ONE, color: Color = Color.WHITE, ground: bool = false,
		lifetime: float = 1.0) -> OneShotFx:
	var sprite_frames := frames(fx_name)
	if sprite_frames == null or not host.is_inside_tree():
		return null
	var fx := OneShotFx.new()
	fx.sprite_frames = sprite_frames
	fx.rotation = rotation
	fx.scale = scale
	fx.modulate = color
	fx.lifetime = lifetime
	layer_for(host, ground).add_child(fx)
	fx.global_position = at
	return fx


## 掛在 parent 身上、一直循環的特效(例如暈眩星星)。由呼叫者負責移除。
static func attach(parent: Node2D, fx_name: StringName, offset: Vector2, color: Color = Color.WHITE) -> OneShotFx:
	var sprite_frames := frames(fx_name)
	if sprite_frames == null:
		return null
	var fx := OneShotFx.new()
	fx.sprite_frames = sprite_frames
	fx.lifetime = -1.0
	fx.position = offset
	fx.modulate = color
	parent.add_child(fx)
	return fx


## 程式畫的擴散圓環。
static func ring(host: Node, at: Vector2, from_radius: float, to_radius: float, duration: float,
		color: Color, width: float = 2.0, ground: bool = false, filled: bool = false) -> RingFx:
	if not host.is_inside_tree():
		return null
	var fx := RingFx.new()
	fx.from_radius = from_radius
	fx.to_radius = to_radius
	fx.duration = duration
	fx.color = color
	fx.width = width
	fx.filled = filled
	layer_for(host, ground).add_child(fx)
	fx.global_position = at
	return fx


# --- 一次性粒子(DEV_PLAN 4.10) -----------------------------------------------------

## 在世界座標 at 噴一次 assets/fx/particles/<名稱>.tscn。
## ground = true 放在地面層(在預警與角色之下,不會蓋住它們);important = true 不受數量上限限制。
## parent 指定時放在那個節點之下(例如必殺技的暗幕)。數量已滿或檔案不存在時傳回 null。
static func particles(host: Node, particle_name: StringName, at: Vector2, ground: bool = false,
		important: bool = false, parent: Node = null) -> Node2D:
	if host == null or not host.is_inside_tree():
		return null
	if not important and _particles_alive >= feel().max_particles:
		return null
	var scene := _particle_scene(particle_name)
	if scene == null:
		return null
	var fx := scene.instantiate() as Node2D
	if fx == null:
		return null
	# z 跟著所屬圖層(地面層在預警與角色之下;特效層在角色之上)。
	fx.z_as_relative = true
	fx.z_index = 0
	if fx is CPUParticles2D and time_scale < 0.999:
		(fx as CPUParticles2D).speed_scale = maxf(0.05, time_scale)
	fx.add_to_group(PARTICLE_GROUP)
	_particles_alive += 1
	fx.tree_exiting.connect(_on_particle_exit, CONNECT_ONE_SHOT)
	var target := parent if parent != null else layer_for(host, ground)
	target.add_child(fx)
	fx.global_position = at
	return fx


## 目前場上有幾個粒子特效(A 線產生的)。
static func particles_alive() -> int:
	return _particles_alive


static func _on_particle_exit() -> void:
	_particles_alive = maxi(0, _particles_alive - 1)


static func _particle_scene(particle_name: StringName) -> PackedScene:
	if not _particle_cache.has(particle_name):
		var path := PARTICLES_PATH % particle_name
		_particle_cache[particle_name] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _particle_cache[particle_name]


# --- 傷害數字(AP2) ---------------------------------------------------------------

## 在 at 上方跳出傷害數字。數量超過上限時移除最舊的。
static func damage_number(host: Node, value: int, at: Vector2, style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> DamageNumber:
	var tuning := feel()
	if not tuning.damage_numbers or host == null or not host.is_inside_tree() or value <= 0:
		return null
	var alive: Array[Node] = []
	for node in _numbers:
		if is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion():
			alive.append(node)
	_numbers = alive
	while _numbers.size() >= maxi(1, tuning.max_damage_numbers):
		var oldest := _numbers.pop_front() as Node
		oldest.queue_free()
	var number := DamageNumber.new()
	number.value = value
	number.style = style
	number.feel = tuning
	layer_for(host).add_child(number)
	number.global_position = at
	_numbers.append(number)
	return number


# --- 鏡頭與畫面(AP1、AP5、AP6) ------------------------------------------------------

## 累積鏡頭震動量(0 至 1)。不在場地內時不做任何事。
static func trauma(host: Node, amount: float) -> void:
	var arena := find_arena(host)
	if arena != null and arena.has_method(&"add_trauma"):
		arena.call(&"add_trauma", amount)


## 讓場地的鏡頭震動(舊的介面,換算成震動量)。
static func shake(host: Node, strength: float, _duration: float = 0.0) -> void:
	trauma(host, clampf(strength * 0.18, 0.0, 1.0))


## 鏡頭輕推向 direction(揮劍)。
static func nudge(host: Node, direction: Vector2, pixels: float) -> void:
	var arena := find_arena(host)
	if arena != null and arena.has_method(&"nudge"):
		arena.call(&"nudge", direction, pixels)


## 蓋住整個戰鬥畫面的一層顏色(必殺技變暗、頭目白光)。傳回 ScreenTint,不在場地內時傳回 null。
static func tint(host: Node, color: Color, duration: float, fade_in: float, fade_out: float, z: int) -> ScreenTint:
	var arena := find_arena(host)
	if arena == null:
		return null
	var overlay := ScreenTint.new()
	overlay.color = color
	overlay.duration = duration
	overlay.fade_in = fade_in
	overlay.fade_out = fade_out
	overlay.z_as_relative = false
	overlay.z_index = z
	arena.add_child(overlay)
	return overlay


## 慢動作(打倒頭目)。不在場地內時不做任何事。
static func slow_motion(host: Node, scale: float, duration: float) -> void:
	var arena := find_arena(host)
	if arena != null and arena.has_method(&"slow_motion"):
		arena.call(&"slow_motion", scale, duration)


# --- 聲音與震動 -------------------------------------------------------------------

## 播放音效;這個 id 還沒有音效檔時改播 fallback(C 線之後補上新音效檔,就會自動用新的)。
static func sfx(id: StringName, fallback: StringName = &"", volume_db: float = 0.0) -> void:
	if fallback != &"" and not Sfx.has_sound(id):
		Sfx.play(fallback, volume_db)
		return
	Sfx.play(id, volume_db)


## 手機震動(kind 空白 = 不震)。
static func haptic(kind: StringName) -> void:
	if kind != &"":
		Haptics.play(kind)
