class_name LootTuning
extends Resource
## 寶箱與零食的掉落數值(A 線,DEV_PLAN 4.12、第 17 節 AV2、AV3)。實際值在 data/enemies/loot_tuning.tres。
##
## 寶箱:guaranteed_chests 裡的敵人必掉(值是等級:0 普通、1 精英、2 頭目);其他精英(elite)必掉 1 級、
## 頭目(BossBase)必掉 2 級;一般敵人以 chest_chance 的機率掉 0 級。
## 一般敵人的機率 = chest_chance × (1 + luck 等級 × luck_bonus_per_level)(最多 chest_chance_max)。
## 零食:一般敵人的機率 = snack_chance × (1 + luck 等級 × luck_bonus_per_level) × (1 + 挖寶層數 × dig_snack_bonus),
## 最多 snack_chance_max;guaranteed_snacks 裡的敵人必掉幾個。luck 等級讀 GameState.meta_upgrades["luck"]
## (營地訓練「幸運」每級 +15%,和 D 線訓練畫面的說明一致)。

@export_group("寶箱")
@export var guaranteed_chests: Dictionary = {&"scarecrow_elite": 1, &"scarecrow_captain": 2, &"black_knight": 2}
@export var chest_chance: float = 0.012
@export var chest_chance_max: float = 0.1
@export var max_random_chests: int = 2           ## 場上同時最多幾個「隨機掉落」的寶箱(必掉的不受限)
@export var chest_open_distance: float = 11.0    ## 金毛中心離寶箱多近就打開
@export var chest_pop_time: float = 0.35
@export var chest_pop_height: float = 10.0
@export var chest_auto_collect_delay: float = 1.0   ## 場上沒有敵人多久後寶箱自己滑向金毛;< 0 關閉
@export var chest_magnet_accel: float = 260.0
@export var chest_magnet_max_speed: float = 140.0
@export var chest_open_linger: float = 0.7       ## 打開後停留幾秒才淡出
@export var chest_glow_colors: Array[Color] = [Color(1.0, 0.95, 0.7, 0.55), Color(1.0, 0.6, 0.25, 0.6), Color(0.85, 0.55, 1.0, 0.65)]
@export var chest_tints: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.9, 0.8), Color(1.0, 0.95, 0.75)]

@export_group("零食")
@export var snack_chance: float = 0.12
@export var dig_snack_bonus: float = 0.5         ## 挖寶每層:機率 +50%
@export var snack_chance_max: float = 0.85
@export var guaranteed_snacks: Dictionary = {&"scarecrow_elite": 2, &"scarecrow_captain": 3, &"black_knight": 5}
@export var snack_value: int = 1                 ## 每個零食算幾個(snack_collected 的 amount)
@export var dig_heal: int = 2                    ## 挖寶每層:吃到零食回復幾點活力
@export var max_snacks_on_field: int = 12

@export_group("運氣")
@export var luck_id: StringName = &"luck"
@export var luck_bonus_per_level: float = 0.15   ## 每級:寶箱與零食機率 +15%(相對於原本的機率)
