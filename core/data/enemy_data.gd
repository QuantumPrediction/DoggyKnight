class_name EnemyData
extends Resource
## 敵人資料(DEV_PLAN 4.3)。A 線在 data/enemies/ 放 .tres。

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_hp: int = 10
@export var contact_damage: int = 5
@export var move_speed: float = 30.0          ## 像素/秒
@export var exp_value: int = 1
