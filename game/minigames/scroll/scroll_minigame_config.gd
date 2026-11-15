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
