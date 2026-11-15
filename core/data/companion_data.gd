class_name CompanionData
extends Resource
## 同伴資料(DEV_PLAN 4.3)。A 線在 data/companions/ 放 .tres。

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var role: StringName                  ## 例如 &"guard"
