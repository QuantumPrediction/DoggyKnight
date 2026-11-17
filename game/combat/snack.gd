class_name Snack
extends ExpOrb
## 零食(AV3,DEV_PLAN 4.12)。敵人倒下時有機率掉(挖寶、luck 提高),像經驗珠一樣彈出來、
## 金毛靠近(拾取範圍)就被吸過去;場上沒有敵人一小段時間後自動飛向金毛。
## 拾取時發 EventBus.snack_collected(value)(B 線累計進 GameState.snacks、發 snacks_changed),
## 播 snack 音效(還沒有音效檔時用 pickup)。學了挖寶(dig)時,每層回復 LootTuning.dig_heal 點活力。
## 圖:assets/fx/snack/snack_frames.tres(C 線原地替換)。

const SNACK_GROUP: StringName = &"snack"
const SNACK_TRAIL := Color(1.0, 0.85, 0.55)


func _ready() -> void:
	# 不呼叫 ExpOrb._ready():零食不在經驗珠群組。
	add_to_group(SNACK_GROUP)
	trail_color = SNACK_TRAIL
	pop_height = 8.0


func collect() -> void:
	if collected:
		return
	collected = true
	remove_from_group(SNACK_GROUP)
	EventBus.snack_collected.emit(value)
	CombatFx.sfx(&"snack", &"pickup")
	CombatFx.spawn(self, &"hit_spark", global_position, 0.0, Vector2.ONE * 0.6, Color(1.0, 0.9, 0.6))
	var dig := Loot.dig_stacks()
	if dig > 0:
		var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
		if player != null and player.has_method(&"heal"):
			player.call(&"heal", Loot.tuning().dig_heal * dig)
			CombatFx.particles(self, &"heart", player.global_position + Vector2(0, -14))
	queue_free()
