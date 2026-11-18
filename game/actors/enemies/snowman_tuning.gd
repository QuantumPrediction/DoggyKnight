class_name SnowmanTuning
extends Resource
## 雪人兵的動作數值(v2.7 AW3)。實際值在 data/enemies/snowman_tuning.tres(雪人兵)與
## data/enemies/snowman_elite_tuning.tres(中頭目雪人隊長)。生命與移動速度在 EnemyData,
## 雪球在 data/enemies/projectiles/snowball.tres(傷害、飛行速度、落點圈半徑)。秒數會再乘難度。

@export_group("距離")
@export var keep_min: float = 60.0              ## 和目標保持這個距離以上(太近就往後退)
@export var keep_max: float = 100.0
@export var retreat_distance: float = 44.0
@export var retreat_speed_mult: float = 1.15
@export var strafe_speed_mult: float = 0.5
@export var strafe_switch_min: float = 1.2
@export var strafe_switch_max: float = 2.4
@export_group("拋雪球")
@export var throw_range: float = 140.0
@export var throw_telegraph: float = 0.45       ## 落點的影子出現到雪球丟出去的秒數(× 難度)
@export var min_flight: float = 0.6             ## 雪球最少飛這麼久(影子一共亮 throw_telegraph + 飛行時間)
@export var arc_height: float = 40.0
@export var balls_per_throw: int = 1
@export var ball_spread: float = 28.0           ## 一次丟幾顆時,落點之間的距離
@export var throw_interval: float = 2.8
@export var throw_interval_jitter: float = 0.15
@export var first_throw_min: float = 0.8
@export var first_throw_max: float = 1.6
@export var release_time: float = 0.35
