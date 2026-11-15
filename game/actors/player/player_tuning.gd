class_name PlayerTuning
extends Resource
## 金毛的「手感」數值(A 線)。實際值在 data/player/goldie_tuning.tres。
##
## 基本數值(速度、攻擊力、攻擊間隔、攻擊範圍、拾取範圍)在 StatBlock
## (data/player/goldie_base_stats.tres,經 GameState.player_stats 讀取,把戲會改變它)。
## 這裡放的是不會被把戲改變、只為手感而調的數字。

@export_group("移動")
@export var accel_time: float = 0.06            ## 由靜止到全速的秒數
@export var decel_time: float = 0.04            ## 放手後到完全停下的秒數(不滑行)
@export var body_radius: float = 6.0

@export_group("搖桿")
@export var joystick_radius: float = 18.0       ## 搖桿底座半徑(邏輯像素)
@export var joystick_deadzone: float = 2.5      ## 拖曳少於這個距離不移動
@export var joystick_follow: bool = true        ## 手指拉出底座時,底座跟著手指走

@export_group("攻擊")
@export var attack_windup: float = 0.12         ## 前搖(蓄力)秒數
@export var attack_arc_degrees: float = 150.0   ## 揮劍扇形的總角度
@export var target_search_mult: float = 1.5     ## 找目標的範圍 = attack_range × 這個倍數
@export var close_hit_distance: float = 6.0     ## 貼身時不計角度
@export var hitstop_time: float = 0.05          ## 打中時的停頓
@export var knockback_speed: float = 110.0
@export var attack_anim_time: float = 0.2

@export_group("受擊")
@export var invuln_time: float = 0.7            ## 受擊後無敵秒數
@export var blink_interval: float = 0.07
@export var hurt_anim_time: float = 0.25

@export_group("忠誠度與必殺技")
@export var loyalty_max: float = 100.0
@export var loyalty_per_hit: float = 4.0        ## 每打中一隻敵人
@export var ultimate_radius: float = 80.0
@export var ultimate_damage_mult: float = 6.0
@export var ultimate_invuln_time: float = 0.6
@export var ultimate_hitstop_time: float = 0.12
@export var ultimate_knockback_speed: float = 180.0

@export_group("特效")
@export var footstep_interval: float = 0.22
