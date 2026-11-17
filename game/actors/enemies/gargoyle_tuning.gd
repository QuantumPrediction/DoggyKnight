class_name GargoyleTuning
extends Resource
## 石像鬼的動作數值(v2.6 AV1、AV5)。實際值在 data/enemies/gargoyle_tuning.tres(石像鬼)與
## data/enemies/gargoyle_elite_tuning.tres(中頭目石像鬼統領)。生命、俯衝傷害(接觸傷害)、
## 盤旋速度在 EnemyData(data/enemies/gargoyle.tres)。秒數會再乘難度(預警 tell()、休息 rest())。

@export_group("飛行")
@export var fly_height: float = 9.0             ## 飛的時候圖往上提幾像素(地上的影子不動)
@export var hover_distance: float = 62.0        ## 盤旋時離目標多遠
@export var orbit_speed: float = 0.7            ## 繞著目標轉的角速度(弧度/秒)
@export_group("俯衝")
@export var swoop_telegraph: float = 0.7        ## 紅線預警秒數(方向在預警開始時就鎖定)
@export var swoop_speed: float = 130.0
@export var swoop_overshoot: float = 26.0       ## 衝過目標多遠
@export var swoop_max_distance: float = 170.0
@export var hit_radius: float = 7.0             ## 預警線寬度 = 2 × 這個;身體碰到紅線就算打中
@export var recover_time: float = 0.8           ## 俯衝後停在地上喘氣(反擊好時機)
@export var swoop_cooldown_min: float = 1.6
@export var swoop_cooldown_max: float = 2.6
@export var first_swoop_min: float = 0.8
@export var first_swoop_max: float = 1.6
@export_group("變成石頭")
@export var stone_interval: float = 4.0         ## 大約每幾秒變成石頭一次(盤旋或喘氣時計時)
@export var stone_jitter: float = 0.2           ## 每次 ± 這個比例,幾隻石像鬼不會同時變
@export var stone_time: float = 1.5             ## 石頭維持幾秒:打不動、推不動、受擊「鏘」
@export var clang_cooldown: float = 0.4         ## 頭上「鏘!」泡泡的最短間隔
