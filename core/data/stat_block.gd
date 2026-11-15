class_name StatBlock
extends Resource
## 金毛的數值(DEV_PLAN 4.3)。預設值取自 DEV_PLAN 第 8 節的初始數值表。
## 實際使用的基準數值在 core/data/goldie_base_stats.tres。

@export var max_vigor: int = 100
@export var move_speed: float = 70.0          ## 像素/秒
@export var attack_damage: int = 10
@export var attack_interval: float = 0.5      ## 秒
@export var attack_range: float = 28.0        ## 像素
@export var damage_taken_mult: float = 1.0    ## 1.0 = 正常;0.8 = 受傷害 −20%
@export var pickup_radius: float = 24.0       ## 像素
@export var exp_mult: float = 1.0
