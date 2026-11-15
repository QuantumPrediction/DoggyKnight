class_name AbilityTuning
extends Resource
## 能力類把戲的數值(A 線,DEV_PLAN 4.7、A10)。實際值在 data/player/ability_tuning.tres。
##
## 同一個把戲重複選擇時的疊加方式(DEV_PLAN 4.9:每多選一次就多疊一層):
## - 握手:每 N 下雙倍,N 每層減 1(4 → 3 → 2);到 2 之後每多一層倍數 +0.5。
## - 轉圈:冷卻時間每層 ×0.8(最短 2.5 秒),半徑每層 +6。
## - 吠叫:冷卻時間每層 ×0.85(最短 4 秒),半徑每層 +8,暈眩每層 +0.5 秒。

@export_group("握手 shake")
@export var shake_every: int = 4
@export var shake_every_min: int = 2
@export var shake_multiplier: float = 2.0
@export var shake_multiplier_per_extra_stack: float = 0.5

@export_group("轉圈 spin")
@export var spin_cooldown: float = 6.0
@export var spin_cooldown_stack_mult: float = 0.8
@export var spin_cooldown_min: float = 2.5
@export var spin_radius: float = 34.0
@export var spin_radius_per_stack: float = 6.0
@export var spin_damage_mult: float = 1.0
@export var spin_knockback_speed: float = 120.0

@export_group("吠叫 bark")
@export var bark_cooldown: float = 8.0
@export var bark_cooldown_stack_mult: float = 0.85
@export var bark_cooldown_min: float = 4.0
@export var bark_radius: float = 48.0
@export var bark_radius_per_stack: float = 8.0
@export var bark_stun_time: float = 1.5
@export var bark_stun_per_stack: float = 0.5
