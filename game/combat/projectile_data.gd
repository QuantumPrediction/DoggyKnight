class_name ProjectileData
extends Resource
## 敵方投射物的數值(AS5)。實際值在 data/enemies/projectiles/<id>.tres(A 線):
## arrow(稻草人弓兵的箭)、sword_wave(黑騎士的劍氣)、pitchfork(稻草人隊長的乾草叉)。
##
## 投射物一律先有直線預警(由射出的敵人畫,寬度 = telegraph_width()),然後沿著那條線飛;
## 碰到角色的身體才算打中(看到的線 = 打中的範圍)。鬥牛犬舉盾時擋得住(blockable)。
## 速度與傷害會再乘上難度倍數(EnemyDifficulty.projectile_speed_mult、damage_mult)。

@export var id: StringName
@export var fx: StringName                     ## 圖:assets/fx/<fx>/<fx>_frames.tres 的 default 動畫(朝右畫)
@export var damage: int = 0                    ## 0 = 用射出者的接觸傷害(EnemyData.contact_damage)
@export var speed: float = 120.0               ## 像素/秒
@export var max_range: float = 160.0           ## 最遠飛多遠(撞到場地邊緣也會停)
@export var hit_radius: float = 2.0            ## 投射物的「半徑」:離角色身體這麼近就打中
@export var pierce: bool = false               ## true:打中後繼續飛(每個角色只打一次)
@export var returns: bool = false              ## true:飛到盡頭後飛回射出者手上(乾草叉)
@export var return_speed: float = 140.0
@export var spin_speed: float = 0.0            ## 飛行時旋轉(弧度/秒;0 = 永遠指向前進方向)
@export var blockable: bool = true             ## 鬥牛犬舉盾時擋得住
@export var visual_scale: float = 1.0
@export var trail_color: Color = Color(1.0, 0.9, 0.7, 0.5)   ## 身後的一小段拖尾(讓它在畫面上更顯眼)
@export var end_fade_time: float = 0.3         ## 停下(落地、插在牆上、被擋下)後消失的秒數


## 預警線的寬度(像素)。
func telegraph_width() -> float:
	return hit_radius * 2.0 + 2.0
