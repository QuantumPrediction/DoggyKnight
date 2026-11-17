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
@export var stone_target_penalty: float = 40.0  ## v2.6:找目標時,變成石頭的敵人當作遠這麼多像素(先打別的)
@export var hitstop_time: float = 0.05          ## 打中時的停頓
@export var knockback_speed: float = 80.0          ## 普通攻擊的擊退(M3:110 → 80,讓單獨的稻草人也打得到金毛)
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

@export_group("營地訓練(v2.4)")
## 「忠誠」訓練每級:忠誠度累積 +10%(讀 GameState.meta_upgrades["loyalty"];StatBlock 沒有這個欄位,所以由 A 線套用)
@export var loyalty_meta_bonus_per_level: float = 0.1

@export_group("復活(v2.4 AV4)")
@export var revive_vigor_ratio: float = 1.0     ## 醒來時活力回到上限的幾成(1 = 全滿)
@export var revive_wake_time: float = 0.5       ## 醒來的演出秒數(伸懶腰、跳起來;這段時間不能動)
@export var revive_invuln_time: float = 2.5     ## 醒來後無敵秒數(含演出)
@export var revive_push_radius: float = 56.0    ## 震開附近敵人的範圍
@export var revive_push_speed: float = 160.0
@export var revive_stun_time: float = 0.8       ## 被震開的敵人暈眩幾秒
