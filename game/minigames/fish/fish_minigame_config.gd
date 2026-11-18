class_name FishMinigameConfig
extends MinigameConfig
## 「接住跳跳魚」的可調數值(v2.7 DW3)。實際數值在 fish_config.tres。
##
## 玩法:魚從上面的海裡跳出來,落向沙灘;金毛頭上頂著黃金狗碗,玩家左右拖曳讓金毛去接。
## 魚要落下的地方先出現影子(看影子就知道要去哪裡)。金色的魚分數多;舊靴子不要接(接到會「呸!」、連續中斷)。
## 分數 = 得到的點數 ÷ 這一局最多能拿的點數 × 100(0 至 100 分),所以每局魚的數目不同也公平。

@export_group("魚的時間表")
## 第一條魚在開始後幾秒落到碗的高度。
@export var first_land_sec: float = 1.8
## 最後一條魚離時間到至少幾秒(時間到之前全部落地)。
@export var last_land_margin_sec: float = 0.4
## 兩條魚落下的間隔(秒):開始時與結束時,中間慢慢變短;每次再隨機乘上 0.85 至 1.15。
@export var interval_start_sec: float = 0.95
@export var interval_end_sec: float = 0.55
## 魚在空中飛的秒數:開始時與結束時(越後面越快)。
@export var flight_start_sec: float = 1.5
@export var flight_end_sec: float = 1.1
## 金魚的機率。
@export var golden_chance: float = 0.1
## 舊靴子:開始後幾秒才會出現;出現機率從 start 慢慢升到 end。
@export var boot_from_sec: float = 3.0
@export var boot_chance_start: float = 0.08
@export var boot_chance_end: float = 0.22
## 排魚的時候只用金毛速度的這個比例(< 1:每條魚都一定接得到,還有一點餘裕)。
@export var reach_factor: float = 0.8
## 兩條魚的落點盡量至少相差這麼多(邏輯像素),才不會一直站著不動。
@export var min_shift: float = 18.0
## 魚從海裡跳出來的位置,和落點最多相差多少(邏輯像素)。
@export var launch_spread: float = 40.0
## 魚跳出水面的高度(拋物線的弧度,邏輯像素)。
@export var arc_height: float = 50.0
## 隨機種子;0 表示每次不同。
@export var rng_seed: int = 0

@export_group("金毛與判定")
## 金毛左右移動的最快速度(邏輯像素/秒)。
@export var goldie_speed: float = 260.0
## 金毛離安全區左右邊緣至少多遠(碗不會出畫面;也不用把手指拖到系統手勢區)。
@export var edge_margin: float = 22.0
## 魚落到碗的高度時,和碗的中心相差多少以內算接到;更近算「完美!」。
@export var catch_half_width: float = 13.0
@export var perfect_half_width: float = 4.0
@export var fish_points: int = 10
@export var golden_points: int = 20
## 「完美!」多加的點數。
@export var perfect_bonus: int = 2
## 每連續接到幾條,多加 combo_bonus 點。
@export var combo_step: int = 5
@export var combo_bonus: int = 5

@export_group("版面")
## 海佔遊戲區的比例(從計時條下面算起)。
@export var sea_ratio: float = 0.3
## 金毛的腳離安全區底邊多遠(手指不用碰到最底的系統手勢區)。
@export var feet_bottom_margin: float = 40.0
## 可以拖曳的範圍離安全區底邊多遠。
@export var touch_bottom_margin: float = 24.0
@export var goldie_frames: SpriteFrames
@export var goldie_scale: float = 2.0
## 碗相對金毛圖中心的位置(頂在頭上)。
@export var bowl_offset: Vector2 = Vector2(0, -27)

@export_group("演出")
@export var catch_sfx: StringName = &"snack"
@export var perfect_sfx: StringName = &"perfect"
@export var golden_sfx: StringName = &"star"
@export var boot_sfx: StringName = &"ink"
@export var cheer_sfx: StringName = &"bark"
## 接到時的閃光(一次性粒子)。
@export var catch_fx: PackedScene
## 開始後幾秒內還顯示「怎樣玩」的提示文字。
@export var hint_play_sec: float = 2.0
## 碗裡最多畫幾條魚(接越多堆越高)。
@export var bowl_pile_max: int = 6

@export_group("場景(依章)")
## 依章換顏色與裝飾:章 → {欄位: 顏色}。欄位:sky_color、sea_color、sea_light_color、sand_color、
## sand_light_color、foam_color。沒有寫的章用第四章(夏天的海邊)。
@export var chapter_palettes: Dictionary[int, Dictionary] = {}
## 依章的裝飾:章 → 0 海邊(椰子樹、貝殼)、1 雪(飄雪、雪堆)、2 秋天(落葉、楓樹)。沒有寫時用 0。
@export var chapter_decor: Dictionary[int, int] = {}
