class_name CombatFx
extends RefCounted
## 產生特效的工具。特效圖在 assets/fx/<名稱>/<名稱>_frames.tres(C 線原地替換)。
## 特效放在所屬戰鬥場地的特效層;不在場地內(例如單元測試)時放在呼叫者的上一層。

const FRAMES_PATH := "res://assets/fx/%s/%s_frames.tres"

static var _frames_cache: Dictionary = {}


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


## 讓場地的鏡頭震動(必殺技、頭目重劈)。不在場地內時不做任何事。
static func shake(host: Node, strength: float, duration: float) -> void:
	var arena := find_arena(host)
	if arena != null and arena.has_method(&"shake"):
		arena.call(&"shake", strength, duration)
