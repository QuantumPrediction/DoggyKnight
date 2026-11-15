class_name LevelData
extends Resource
## 關卡資料(DEV_PLAN 4.3)。B 線在 data/levels/ 放 .tres。

@export var id: StringName
@export var display_name: String
@export var waves: Array[WaveData] = []
@export var is_boss: bool = false
@export var arena_scene: PackedScene
