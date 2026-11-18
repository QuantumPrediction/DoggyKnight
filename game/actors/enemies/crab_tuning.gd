class_name CrabTuning
extends Resource
## 螃蟹海盜的動作數值(v2.7 AW1)。實際值在 data/enemies/crab_tuning.tres(螃蟹)與
## data/enemies/crab_elite_tuning.tres(中頭目寄居蟹將軍)。生命、夾擊傷害(接觸傷害)、移動速度
## 在 EnemyData(data/enemies/crab.tres)。秒數會再乘難度(預警 tell()、休息 rest())。

@export_group("橫著走")
@export var side_speed_mult: float = 1.5        ## 橫向(左右)的速度 × 移動速度(螃蟹橫著走得很快)
@export var forward_speed_mult: float = 0.45    ## 上下的速度 × 移動速度
@export var side_offset: float = 16.0           ## 走到目標左邊或右邊這麼遠的地方
@export var zigzag: float = 0.35                ## 上下輕輕擺動(看起來像橫著碎步)
@export_group("舉鉗子(guard)")
@export var guard_range: float = 44.0           ## 離目標這麼近、又還不能夾的時候舉起鉗子
@export var guard_damage_mult: float = 0.2      ## 舉鉗子時受到的傷害 ×(幾乎打不痛)
@export var guard_clang_cooldown: float = 0.35  ## 「鏘!」火花的最短間隔
@export_group("夾")
@export var pinch_reach: float = 20.0           ## 扇形預警的半徑 = 打中範圍
@export var pinch_half_angle_deg: float = 60.0
@export var pinch_start: float = 22.0           ## 和目標(中心)這麼近就準備夾
@export var pinch_telegraph: float = 0.6        ## 張開鉗子的預警秒數(× 難度)
@export var pinches_per_turn: int = 1           ## 一輪連續夾幾下(每一下都有完整預警)
@export var pant_time: float = 1.2              ## 夾完喘氣(不舉鉗子,反擊時機)
@export var pinch_cooldown_min: float = 1.4
@export var pinch_cooldown_max: float = 2.2
@export var first_pinch_min: float = 0.6
@export var first_pinch_max: float = 1.2
