class_name FlowParts
extends RefCounted
## 別線的零件在哪裡,以及找不到時用哪個替身(DEV_PLAN 4.4、4.9)。
##
## FlowMain 執行時「按路徑」載入零件:正式零件存在(別線已合併)就用正式的,
## 否則用 game/flow/stubs/ 的替身。替身實作完全相同的方法與訊號,
## 所以別線合併後不需要改 B 線的任何程式。

const ARENA: String = "res://game/combat/arena.tscn"
const HUD: String = "res://ui/hud/hud.tscn"
const TRICK_CHOICE: String = "res://ui/trick_choice/trick_choice.tscn"
const PAUSE: String = "res://ui/pause/pause.tscn"
const TITLE: String = "res://ui/screens/title.tscn"
const RESULTS: String = "res://ui/screens/results.tscn"
const FAILURE: String = "res://ui/screens/failure.tscn"
const CREDITS: String = "res://ui/screens/credits.tscn"
const CAMP: String = "res://game/camp/camp.tscn"
## 可有可無的零件(DEV_PLAN 4.10):不存在時直接略過(正式流程不用替身)。
const TRANSITION: String = "res://ui/transition/transition.tscn"
const TUTORIAL: String = "res://ui/hints/tutorial.tscn"

const STUB_DIR: String = "res://game/flow/stubs"

## 正式零件路徑 → 替身路徑。
const STAND_INS: Dictionary = {
	ARENA: STUB_DIR + "/stub_arena.tscn",
	HUD: STUB_DIR + "/stub_hud.tscn",
	TRICK_CHOICE: STUB_DIR + "/stub_trick_choice.tscn",
	PAUSE: STUB_DIR + "/stub_pause.tscn",
	TITLE: STUB_DIR + "/stub_title.tscn",
	RESULTS: STUB_DIR + "/stub_results.tscn",
	FAILURE: STUB_DIR + "/stub_failure.tscn",
	CREDITS: STUB_DIR + "/stub_credits.tscn",
	CAMP: STUB_DIR + "/stub_camp.tscn",
	TRANSITION: STUB_DIR + "/stub_transition.tscn",
	TUTORIAL: STUB_DIR + "/stub_tutorial.tscn",
}


## 傳回 path 的場景;不存在或載入失敗時傳回替身。force_stand_in = true 時一律用替身。
static func scene_for(path: String, force_stand_in: bool = false) -> PackedScene:
	if not force_stand_in:
		var real := try_load(path)
		if real != null:
			return real
	return try_load(STAND_INS.get(path, ""))


## 可有可無的零件(轉場、教學提示):force_stand_in = true 時用替身;否則只用正式零件,
## 不存在就傳回 null(呼叫的一方略過這個步驟)。
static func optional_scene(path: String, force_stand_in: bool = false) -> PackedScene:
	if force_stand_in:
		return try_load(STAND_INS.get(path, ""))
	return try_load(path)


## 正式零件是否存在(不載入替身)。
static func has_real(path: String) -> bool:
	return ResourceLoader.exists(path)


static func try_load(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## 場地:LevelData.arena_scene 有設定就用它;否則 game/combat/arena.tscn;再不然用替身。
static func arena_for(level: LevelData, force_stand_in: bool = false) -> PackedScene:
	if not force_stand_in and level != null and level.arena_scene != null:
		return level.arena_scene
	return scene_for(ARENA, force_stand_in)


## 安全地連接一個可能不存在的訊號(別線的場景還沒做好某個訊號時,只警告、不當機)。
static func connect_if_present(node: Object, signal_name: StringName, callable: Callable) -> bool:
	if node != null and node.has_signal(signal_name):
		if not node.is_connected(signal_name, callable):
			node.connect(signal_name, callable)
		return true
	push_warning("FlowParts: %s 沒有訊號 %s" % [node, signal_name])
	return false


## 安全地呼叫一個可能不存在的方法。
static func call_if_present(node: Object, method: StringName, args: Array = []) -> Variant:
	if node != null and node.has_method(method):
		return node.callv(method, args)
	push_warning("FlowParts: %s 沒有方法 %s" % [node, method])
	return null
