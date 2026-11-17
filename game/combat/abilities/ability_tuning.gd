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

# --- v2.4 新把戲(DEV_PLAN 4.12、AV1) --------------------------------------------------
## 疊加:撲擊每層範圍 +8、冷卻 ×0.85;打滾每層冷卻 ×0.8、無敵 +0.05 秒;
## 裝死每層多一次機會(每關);暴衝每層速度 +10%、時間 +0.5 秒。進化把戲不疊加(最多一層)。

@export_group("撲擊 pounce")
@export var pounce_range: float = 60.0           ## 停下時敵人在這個距離內(扣掉敵人身體半徑)就撲過去
@export var pounce_range_per_stack: float = 8.0
@export var pounce_min_distance: float = 22.0    ## 比這個近就不必撲,直接揮劍
@export var pounce_time: float = 0.16            ## 撲過去的秒數
@export var pounce_stop_distance: float = 12.0   ## 撲到離敵人中心多遠停下
@export var pounce_cooldown: float = 1.6
@export var pounce_cooldown_stack_mult: float = 0.85
@export var pounce_cooldown_min: float = 0.8
@export var pounce_hop_height: float = 6.0

@export_group("打滾 roll")
@export var roll_time: float = 0.3               ## 翻滾(無敵)秒數
@export var roll_time_per_stack: float = 0.05
@export var roll_cooldown: float = 3.0
@export var roll_cooldown_stack_mult: float = 0.8
@export var roll_cooldown_min: float = 1.5
@export var roll_speed_mult: float = 1.5         ## 翻滾時的移動速度倍數

@export_group("裝死 play_dead")
@export var play_dead_invuln: float = 2.0        ## 改為剩 1 活力後無敵幾秒
@export var play_dead_flop_time: float = 0.45    ## 先「裝死」倒下幾秒(不能動,無敵)
@export var play_dead_push_radius: float = 40.0  ## 起身時震開附近敵人
@export var play_dead_push_speed: float = 130.0

@export_group("暴衝 zoomies")
@export var zoomies_time: float = 2.0            ## 打倒敵人後持續幾秒
@export var zoomies_time_per_stack: float = 0.5
@export var zoomies_speed_bonus: float = 0.3     ## 移動速度 +30%(乘在目前速度上,不改 player_stats)
@export var zoomies_speed_per_stack: float = 0.1

@export_group("進化:旋風尾 tornado_tail(spin + wag)")
@export var tornado_radius: float = 30.0         ## 旋風繞身的範圍
@export var tornado_tick: float = 0.45           ## 每幾秒打一次範圍內的敵人
@export var tornado_damage_mult: float = 0.55
@export var tornado_knockback_speed: float = 60.0
@export var tornado_spin_speed: float = 7.0      ## 旋風繞身的角速度(弧度/秒)
@export var tornado_move_speed_bonus: float = 0.0    ## 額外速度加成(乘在目前速度上;搖尾巴的數值由 B 線決定保留與否)

@export_group("進化:獅王吼 lion_roar(bark + sit)")
@export var roar_cooldown: float = 8.0
@export var roar_radius_mult: float = 2.0        ## 範圍 = 吠叫半徑 × 這個倍數
@export var roar_damage_mult: float = 1.5
@export var roar_stun_time: float = 1.5
@export var roar_guard_mult: float = 0.5         ## 震懾期間金毛受到的傷害 × 這個倍數
@export var roar_knockback_speed: float = 90.0

@export_group("進化:擊掌連打 high_five(shake + fetch)")
@export var high_five_every: int = 3             ## 每第幾下打中的攻擊放出掌印
@export var high_five_swing_mult: float = 1.5    ## 那一下本身的傷害倍數
@export var high_five_paw_damage_mult: float = 1.5
@export var high_five_paw_speed: float = 150.0
@export var high_five_paw_range: float = 120.0   ## 找目標的範圍
@export var high_five_paw_lifetime: float = 1.2

@export_group("進化:流星撲擊 meteor_pounce(pounce + zoomies)")
@export var meteor_range: float = 76.0
@export var meteor_cooldown: float = 1.2
@export var meteor_time: float = 0.22
@export var meteor_hop_height: float = 14.0
@export var meteor_impact_radius: float = 26.0
@export var meteor_damage_mult: float = 1.2
@export var meteor_knockback_speed: float = 120.0
@export var meteor_zoomies_time: float = 2.5     ## 保留暴衝:打倒敵人後加速
@export var meteor_zoomies_speed_bonus: float = 0.35

@export_group("嗅嗅 sniff(暴擊;拾取範圍由 B 線套用)")
@export var sniff_crit_chance: float = 0.08      ## 每層暴擊率
@export var crit_multiplier: float = 1.5
