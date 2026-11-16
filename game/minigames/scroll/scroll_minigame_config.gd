class_name ScrollMinigameConfig
extends MinigameConfig
## 「拉扯王室卷軸」的可調數值(DEV_PLAN 11 D2)。實際數值在 scroll_config.tres。
##
## 長度單位:卷軸被拉出的長度以畫面的邏輯像素計算,px_per_score 像素算 1 分(畫面上顯示為「公分」)。

@export_group("拉卷軸")
## 手指向下滑 1 像素,卷軸拉出多少像素。
@export var pull_ratio: float = 0.6
## 每一次觸控事件最多算多少像素(避免一下子跳太遠)。
@export var max_pull_per_event: float = 24.0
## 多少像素算 1 分(1 公分)。
@export var px_per_score: float = 10.0
## 卷軸每拉出多少像素播一次 scroll 音效。
@export var scroll_sfx_every_px: float = 36.0

@export_group("墨水漬")
## 第一個墨水漬在拉出多少像素時到達咬住的地方。
@export var ink_first_at: float = 260.0
## 之後每個墨水漬之間的距離(像素,隨機取這個範圍)。
@export var ink_gap_min: float = 280.0
@export var ink_gap_max: float = 480.0
## 墨水漬到達咬住的地方時,玩家要停手多少秒,金毛才會換個地方咬。
@export var ink_still_sec: float = 0.45
## 停手期間手指移動少於這個距離(像素)不算滑動,容許手指輕微抖動。
@export var ink_swipe_tolerance_px: float = 4.0
## 停手期間還在滑:扣掉的秒數。
@export var ink_penalty_sec: float = 1.5
## 墨水漬滑過咬住位置的時間(秒)。
@export var ink_pass_sec: float = 0.3
## 墨水漬離咬住的地方還有多少像素時,金毛頭上出現「!」。
@export var ink_warn_px: float = 44.0
## 墨水漬的大小(像素)。
@export var ink_size: float = 10.0
## 被墨水噴到後,金毛臉上的墨點停留多少秒。
@export var ink_face_sec: float = 1.2
## 隨機種子;0 表示每次不同。
@export var rng_seed: int = 0

@export_group("版面與提示")
## 滑動範圍底部離安全區底邊至少多少邏輯像素(避開系統的返回主畫面手勢區)。
@export var swipe_zone_bottom_margin: float = 24.0
## 卷軸紙的寬度(像素)。
@export var paper_width: float = 52.0
## 玩家滑過幾次之後收起提示的手。
@export var hint_swipes_to_hide: int = 2
## 停手多久(秒)後提示的手再出現。
@export var hint_idle_sec: float = 1.5

@export_group("外觀")
@export var goldie_frames: SpriteFrames
@export var goldie_animation: StringName = &"idle"
## 結束時被卷軸纏住所用的動畫。
@export var goldie_tangled_animation: StringName = &"idle"
@export var goldie_scale: float = 2.0
@export var paper_color: Color = Color("f3e6c4")
@export var paper_edge_color: Color = Color("b8323a")
@export var paper_line_color: Color = Color("c9b98f")
@export var ink_color: Color = Color("1b1b2a")
@export var roll_wood_color: Color = Color("7a4a2a")
@export var roll_knob_color: Color = Color("e0b040")
@export var sky_top_color: Color = Color("1d1838")
@export var sky_bottom_color: Color = Color("3a2c55")
@export var table_color: Color = Color("6b4428")
@export var table_edge_color: Color = Color("4a2c18")

@export_group("完美停住(DP2)")
## 墨水漬到達後,玩家在這麼多秒內停手(而且沒有犯錯)就是「完美!」。
@export var perfect_window_sec: float = 0.2
## 每次「完美!」加多少分(公分)。
@export var perfect_bonus_score: int = 5
## 「完美!」時的閃光(一次性粒子)。
@export var perfect_fx: PackedScene

@export_group("王室守則與梅林(DS3)")
## 卷軸開頭的標題(翻譯鍵):開始時就在金毛嘴巴下面。
@export var rules_title_key: String = "MINIGAME_SCROLL_TITLE"
## 每一條的編號(翻譯鍵,%d = 第幾條)。拉得越長,出來的條數越多。
@export var rule_label_key: String = "MINIGAME_SCROLL_RULE"
## 每一條佔幾行(一行 8 像素;其中兩行是編號)。
@export var rule_rows: int = 7
## 條目編號的顏色(淡淡的,不搶墨水漬的眼)。
@export var rule_text_color: Color = Color(0.55, 0.42, 0.28, 0.75)
## 標題的顏色。
@export var rules_title_color: Color = Color(0.72, 0.2, 0.23, 0.85)
## 時間到時走進來的梅林(C 線的 merlin_frames:run、idle)。留空時用 assets/sprites/merlin/merlin_frames.tres。
@export var merlin_frames: SpriteFrames
@export var merlin_scale: float = 2.0
## 梅林問的話(翻譯鍵)。
@export var merlin_ask_key: String = "MINIGAME_MERLIN_ASK"
## 梅林從畫面右邊走到卷軸旁的秒數。
@export var merlin_enter_sec: float = 0.5
## 時間到之後多少秒,梅林開口問。
@export var merlin_ask_delay_sec: float = 0.6
## 梅林站在卷軸右邊多遠(邏輯像素,到梅林的中心)。
@export var merlin_stand_dx: float = 26.0

@export_group("速度線")
## 卷軸每秒被拉出多少像素以上才出現速度線。
@export var speed_lines_min_speed: float = 60.0
## 每秒多少像素時速度線最濃。
@export var speed_lines_full_speed: float = 260.0
## 速度線的數量(每邊)。
@export var speed_line_count: int = 5
