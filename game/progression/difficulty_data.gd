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
## 可以抽到的基本把戲(id,對應 data/tricks/<id>.tres)。進化把戲不放這裡(由 evolves_into 找到)。
@export var trick_pool: Array[StringName] = [&"sit", &"wag", &"fetch", &"shake", &"spin", &"bark",
		&"pounce", &"roll", &"dig", &"sniff", &"play_dead", &"zoomies"]
## 「坐下」疊很多次時,受到的傷害倍率最低只會降到這個值(避免完全無敵)。
@export var min_damage_taken_mult: float = 0.2
## v2.4:已經學過、還沒到上限的把戲,在三選一中出現的機會是其他把戲的這麼多倍
## (讓把戲比較容易練滿、進化;1.0 = 平均)。
@export var owned_trick_weight: float = 1.0

@export_group("Events")
## v2.4 抉擇事件:一波清空後等這麼多秒(遊戲時間)才出現,讓經驗珠先飛完。
@export var event_delay: float = 0.6
## 沒有事件介面(ui/event_choice/event_choice.tscn)時,等這麼多秒(真實時間)自動選第一項。
@export var event_auto_pick_delay: float = 0.5

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

## 這些敵人所在的一波開始時改播頭目音樂(boss)並播 boss_warning(1-4 的稻草人隊長;
## 頭目關本身一開始就播 boss)。
@export var boss_music_enemies: Array[StringName] = [&"scarecrow_captain", &"black_knight"]

@export_group("Hard mode")
## 困難模式(GameState.difficulty == &"hard")每組敵人多加 floor(數目 × 這個比例) 隻
## (例如 0.25:4 至 7 隻的組多 1 隻,8 隻以上多 2 隻;1 至 3 隻的組不變)。敵人本身的生命、傷害、
## 速度與同時進攻的數目由 A 線依難度放大(data/enemies/difficulty_scaling.tres)。
## 目前是 0(不多加):量度時 A 線的放大已經讓困難模式機器人每輪倒下 1 至 8 次;多加 0.25 會變成
## 13 次(1-4 連續失敗 7 次),而且近戰小怪會擠成一團。想讓困難模式「人更多」時再調高。
@export var hard_extra_ratio: float = 0.0
## 困難模式不會多加的敵人(頭目、中頭目)。
@export var hard_extra_exempt: Array[StringName] = [&"black_knight", &"scarecrow_captain"]

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

@export_group("Story")
## 過關後的對白開始時,勝利短曲淡出、換回該關曲子(結局換 story)所用的秒數(讓短曲不會突然被切斷)。
@export var story_music_fade: float = 2.5

@export_group("Transition")
## 換畫面時:畫面被蓋住要多少秒(快一點,按下按鈕立即有反應)。0 = 不播轉場。
@export var transition_cover_time: float = 0.12
## 換好畫面後:畫面露出要多少秒。0 = 不播轉場。
@export var transition_reveal_time: float = 0.3
## 轉場超過「預定秒數 + 這個秒數」仍未完成,流程就不再等它(保證不會卡住)。以真實時間計算。
@export var transition_timeout: float = 1.5


## 困難模式時這一組要多加幾隻。
func hard_extra(enemy_id: StringName, count: int) -> int:
	if count <= 0 or hard_extra_exempt.has(enemy_id):
		return 0
	return maxi(0, floori(float(count) * hard_extra_ratio + 0.0001))


## 由 level 級升到 level + 1 級需要的經驗。
func exp_to_next(level: int) -> int:
	return maxi(1, exp_first_level_up + exp_step_per_level * maxi(0, level - 1))
