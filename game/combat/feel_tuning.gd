class_name FeelTuning
extends Resource
## 戰鬥「手感與演出」的數值(A 線,DEV_PLAN 第 15 節 AP1 至 AP10)。實際值在 data/player/feel_tuning.tres。
##
## 只放表現用的數字(鏡頭震動、傷害數字、特效上限、連擊、必殺技與頭目演出、震動回饋)。
## 角色數值在 StatBlock 與 goldie_tuning.tres;敵人動作節奏在各敵人場景的屬性欄。

@export_group("鏡頭震動(AP1)")
@export var max_shake_offset: float = 4.0        ## 震動量 = 1 時鏡頭最多偏移幾個邏輯像素
@export var trauma_decay: float = 1.8             ## 震動量每秒減少多少
@export var trauma_power: float = 2.0             ## 偏移 = 震動量的幾次方(2 = 小震很輕、大震很重)
@export var shake_frequency: float = 22.0         ## 晃動的快慢
@export var trauma_player_hit: float = 0.32
@export var trauma_elite_kill: float = 0.35
@export var trauma_ultimate: float = 0.8
@export var trauma_boss_step: float = 0.18        ## 頭目出場的腳步
@export var trauma_boss_roar: float = 0.5
@export var trauma_boss_slam: float = 0.6
@export var trauma_boss_bonk: float = 0.35
@export var trauma_boss_defeat: float = 0.85
@export var swing_nudge: float = 1.5              ## 揮劍時鏡頭推向攻擊方向幾個像素
@export var nudge_return_rate: float = 12.0       ## 推出去後回到中間的速度(越大越快)

@export_group("傷害數字(AP2)")
@export var damage_numbers: bool = true
@export var number_jump_speed: float = 62.0       ## 跳起的初速(像素/秒)
@export var number_gravity: float = 200.0
@export var number_drift: float = 12.0            ## 左右隨機飄的最大速度
@export var number_lifetime: float = 0.7
@export var crit_lifetime: float = 0.8
@export var max_damage_numbers: int = 18          ## 同時最多幾個,超過時移除最舊的
@export var number_color: Color = Color(1.0, 0.97, 0.86)
@export var crit_color: Color = Color(1.0, 0.62, 0.16)
@export var ultimate_number_color: Color = Color(1.0, 0.88, 0.3)
@export var ally_number_color: Color = Color(0.72, 0.88, 1.0)
@export var number_outline: Color = Color(0.16, 0.09, 0.12)

@export_group("命中(AP2、AP3)")
@export var squash_amount: float = 0.3            ## 被打中時壓扁的程度
@export var squash_time: float = 0.16
@export var hit_bursts_per_swing: int = 3         ## 一次揮劍(或必殺技)最多噴幾個 hit_burst
@export var run_lean: float = 0.18                ## 跑步時身體前傾(斜切,弧度)
@export var run_bob: float = 1.0                  ## 跑步時上下彈的像素
@export var trail_time: float = 0.13              ## 揮劍拖尾掃過的秒數
@export var trail_fade_time: float = 0.12

@export_group("特效上限(品質標準 5)")
@export var max_particles: int = 16               ## 同時存在的粒子特效上限(必殺技、頭目重劈等重要特效不受限)
@export var pickup_haptic_interval: float = 0.15  ## 拾取經驗珠的輕震動最短間隔

@export_group("連擊(AP4)")
@export var combo_window: float = 2.0             ## 兩次擊倒相隔不超過這個秒數就算連擊
@export var combo_milestones: PackedInt32Array = PackedInt32Array([5, 10, 20])
@export var combo_milestone_loyalty: PackedFloat32Array = PackedFloat32Array([10.0, 15.0, 25.0])
@export var combo_repeat_every: int = 10          ## 最後一個里程碑之後,每多幾連擊再獎勵一次;0 = 不再獎勵
@export var combo_repeat_loyalty: float = 25.0

@export_group("必殺技演出(AP6)")
@export var ultimate_windup: float = 0.32         ## 舉劍蓄力(畫面變暗、光柱)到斬下的秒數
@export var ultimate_freeze_after: float = 0.22   ## 斬下後敵人再多停頓幾秒
@export var ultimate_dark_alpha: float = 0.5
@export var ultimate_dark_time: float = 0.85      ## 變暗的總秒數(含淡入淡出)
@export var ultimate_pillar_width: float = 14.0

@export_group("頭目演出(AP5)")
@export var boss_defeat_time: float = 0.85        ## 生命歸零到盔甲散開(之後才離開 enemy 群組),要 ≤ 1.5
@export var boss_slowmo_scale: float = 0.3
@export var boss_slowmo_time: float = 1.5
@export var boss_flash_alpha: float = 0.85
@export var boss_flash_time: float = 0.4

@export_group("手機震動(AP9,light / medium / heavy;空白 = 不震)")
@export var haptic_player_hit: StringName = &"medium"
@export var haptic_ultimate: StringName = &"heavy"
@export var haptic_boss_slam: StringName = &"heavy"
@export var haptic_boss_defeat: StringName = &"heavy"
@export var haptic_combo: StringName = &"light"
@export var haptic_pickup: StringName = &"light"
