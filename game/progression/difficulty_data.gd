class_name DifficultyData
extends Resource
## 難度參數(B10)。所有可調的流程與成長數字都集中在 game/progression/difficulty.tres,
## M3 調整手感時只改那個檔案,不用改程式。
##
## 敵人的生命、速度、經驗值屬 A 線(data/enemies/);每關有多少敵人、何時出現屬
## B 線的關卡資料(data/levels/)。這裡放的是「所有關卡共用」的節奏與曲線。

@export_group("Experience")
## 從第 1 級升到第 2 級需要的經驗。
@export var exp_first_level_up: int = 5
## 之後每升一級,所需經驗再多這麼多(第 2→3 級要 5+3=8,第 3→4 級要 11……)。
@export var exp_step_per_level: int = 3

@export_group("Tricks")
## 升級時給玩家選的把戲數目。
@export var trick_offer_count: int = 3
## 可以抽到的把戲(id,對應 data/tricks/<id>.tres)。
@export var trick_pool: Array[StringName] = [&"sit", &"wag", &"fetch", &"shake", &"spin", &"bark"]
## 「坐下」疊很多次時,受到的傷害倍率最低只會降到這個值(避免完全無敵)。
@export var min_damage_taken_mult: float = 0.2

@export_group("Waves")
## 關卡開始後,第一波出現前的等待秒數(讓玩家看清場地)。
@export var first_wave_delay: float = 1.5
## 一波清空後,下一波出現前的等待秒數。
@export var inter_wave_delay: float = 2.5
## 同一組敵人之中,每隻之間相隔的秒數(避免一次全部擠出來)。
@export var spawn_spacing: float = 0.5
## 出生位置的隨機偏移(像素),讓同一個出生點出來的敵人不會疊在一起。
@export var spawn_jitter: float = 6.0
## 敵人不會在離金毛這麼近(像素)的出生點出現。
@export var min_spawn_distance: float = 48.0

@export_group("Flow")
## 過關後,停留在場地上多少秒才顯示結算(讓經驗珠飛完、看清勝利的一刻)。
@export var results_delay: float = 1.5
## 金毛倒下(睡著)後,等多少秒才顯示失敗結算。
@export var failure_delay: float = 1.0


## 由 level 級升到 level + 1 級需要的經驗。
func exp_to_next(level: int) -> int:
	return maxi(1, exp_first_level_up + exp_step_per_level * maxi(0, level - 1))
