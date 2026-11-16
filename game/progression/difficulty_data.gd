class_name DifficultyData
extends Resource
## 難度參數(B10)。所有可調的流程與成長數字都集中在 game/progression/difficulty.tres,
## M3 調整手感時只改那個檔案,不用改程式。
##
## 敵人的生命、速度、經驗值屬 A 線(data/enemies/);每關有多少敵人、何時出現、星級門檻屬
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
## 開場(intro_duration)結束後,第一波出現前再等的秒數。
@export var first_wave_delay: float = 0.0
## 一波清空後,下一波出現前的等待秒數(喘息時間;HUD 在這段時間顯示「第 N 波」)。
@export var inter_wave_delay: float = 2.5
## 同一組敵人之中,每隻之間相隔的秒數(避免一次全部擠出來)。隊形 edges、corners 使用。
@export var spawn_spacing: float = 0.5
## 出生位置的隨機偏移(像素),讓同一個出生點出來的敵人不會疊在一起。隊形 edges 使用。
@export var spawn_jitter: float = 6.0
## 敵人不會在離金毛這麼近(像素)的地方出現(surround 另有自己的距離)。
@export var min_spawn_distance: float = 48.0

@export_group("Patterns")
## 隊形(SpawnEntry.pattern)的出生點離戰鬥區(Layout.ARENA_RECT)邊緣的距離(像素)。
@export var pattern_inset: float = 12.0
## surround:圍著金毛的圓圈半徑(像素)。
@export var surround_radius: float = 64.0
## surround:圓圈貼牆被壓扁時,出生點離金毛至少這麼遠(像素);太近的點會移到別的角度。
@export var surround_min_distance: float = 46.0
## surround:地上先出現預警記號,過這麼多秒敵人才冒出來(讓玩家有時間走出包圍)。
@export var surround_telegraph: float = 0.9
## line_top:一排敵人由左到右逐隻出現,每隻相隔的秒數。
@export var line_spacing: float = 0.12
## line_top:金毛在戰鬥區上方這個比例之內時,改從下方排一排(不在她身邊冒出來)。
@export var line_flip_ratio: float = 0.35

@export_group("Flow")
## 發出 level_started 之後,等這麼多秒才開始第一波(HUD 播關卡標題卡;金毛可以走動)。
@export var intro_duration: float = 1.6
## 過關後,停留在場地上多少秒才顯示結算(HUD 播慶祝、經驗珠飛完、金毛歡呼)。
@export var results_delay: float = 2.0
## 金毛倒下(睡著)後,等多少秒才顯示失敗結算。
@export var failure_delay: float = 1.0

@export_group("Transition")
## 換畫面時:畫面被蓋住要多少秒(快一點,按下按鈕立即有反應)。0 = 不播轉場。
@export var transition_cover_time: float = 0.12
## 換好畫面後:畫面露出要多少秒。0 = 不播轉場。
@export var transition_reveal_time: float = 0.3
## 轉場超過「預定秒數 + 這個秒數」仍未完成,流程就不再等它(保證不會卡住)。以真實時間計算。
@export var transition_timeout: float = 1.5


## 由 level 級升到 level + 1 級需要的經驗。
func exp_to_next(level: int) -> int:
	return maxi(1, exp_first_level_up + exp_step_per_level * maxi(0, level - 1))
