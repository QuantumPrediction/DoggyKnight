extends TestCase
## A 線測試的共同工具(不是測試檔本身:檔名不以 test_ 開頭)。
## 用法:extends "res://tests/line_a/combat_test_base.gd"

const ARENA_SCENE: PackedScene = preload("res://game/combat/arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://game/actors/player/player.tscn")

var arena: CombatArena
var player: GoldiePlayer


## 建立一個戰鬥場地。spawn_telegraph = 0 表示敵人生成後立刻行動(測試用)。
func make_arena(spawn_telegraph: float = 0.0) -> CombatArena:
	arena = ARENA_SCENE.instantiate() as CombatArena
	arena.spawn_telegraph_time = spawn_telegraph
	add_child(arena)
	player = arena.get_player() as GoldiePlayer
	return arena


func spawn(enemy_id: StringName, at: Vector2) -> EnemyBase:
	return arena.spawn_enemy(enemy_id, at) as EnemyBase


func wait_physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## 每個物理格檢查一次 condition,成立就傳回 true;超過 max_frames 傳回 false。
func wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return bool(condition.call())


func after_each() -> void:
	if arena != null and is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = null
	player = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	GameState.reset_run()
	await get_tree().process_frame
