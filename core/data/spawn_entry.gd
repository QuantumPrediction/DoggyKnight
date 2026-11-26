class_name SpawnEntry
extends Resource
## 一波之中的一組敵人(DEV_PLAN 4.3)。

@export var enemy_id: StringName
@export var count: int = 1
@export var delay: float = 0.0                ## 秒
## v2.2 出場隊形:&"edges"(場邊隨機,預設)、&"surround"(圍著金毛一圈)、
## &"line_top"(上方一排)、&"corners"(四個角落)。由 B 線的波次生成器解讀。
@export var pattern: StringName = &"edges"

## Distance from the hero along the shield trial’s front-to-back formation.
@export var formation_distance: float = 0.0
