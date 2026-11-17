class_name WakeMinigameConfig
extends MinigameConfig
## 「叫醒騎士」的可調數值(v2.6 DV3)。實際數值在 wake_config.tres。
##
## 玩法:圓桌旁三位騎士被午睡咒弄得一直打瞌睡。跟著節拍,圈圈縮到某位騎士頭上時點他那一欄,把他叫醒。
## 分數 = 得到的點數 ÷ 這一局最多能拿的點數 × 100(0 至 100 分),所以譜面長短不同也公平。

@export_group("節拍與譜面")
## 騎士(欄)的數目。
@export var lane_count: int = 3
## 開始與結束時的速度(每分鐘拍數);中間慢慢加快。
@export var bpm_start: float = 88.0
@export var bpm_end: float = 116.0
## 第一拍在開始後幾秒(要比圈圈出現的時間長,第一個圈圈才不會一出來就到)。
@export var first_beat_sec: float = 1.6
## 最後一個音符離時間到至少幾秒。
@export var last_note_margin_sec: float = 0.5
## 某一拍不叫任何人的機率(不會連續兩拍都休息)。
@export var rest_chance: float = 0.22
## 連續兩下叫同一位騎士的機率(不會連續三下)。
@export var same_lane_chance: float = 0.15
## 過了全部時間的這個比例之後,兩拍之間偶爾多一個「半拍」。
@export var offbeat_from_ratio: float = 0.55
@export var offbeat_chance: float = 0.18
## 圈圈在音符前幾拍出現。
@export var approach_beats: float = 2.0
## 隨機種子;0 表示每次不同。
@export var rng_seed: int = 0

@export_group("判定與分數")
## 和節拍相差多少秒以內算「完美!」、「好!」。
@export var perfect_window_sec: float = 0.07
@export var good_window_sec: float = 0.15
## 太早點(早於「好!」但在這個秒數以內)算「沒叫醒」:防止亂點。
@export var early_miss_window_sec: float = 0.3
@export var perfect_points: int = 10
@export var good_points: int = 6
## 每連續叫醒幾位,多加 combo_bonus 點。
@export var combo_step: int = 5
@export var combo_bonus: int = 5

@export_group("演出")
## 叫醒後騎士保持清醒的秒數(然後又打起瞌睡)。
@export var wake_sec: float = 0.6
## 每拍的節拍音效(很小聲);空白 = 不播。
@export var beat_sfx: StringName = &"countdown"
@export var beat_volume_db: float = -14.0
@export var perfect_sfx: StringName = &"perfect"
@export var good_sfx: StringName = &"pet"
## 結束時騎士們全醒過來歡呼的音效。
@export var cheer_sfx: StringName = &"bark"
## 叫醒時的閃光(一次性粒子)。
@export var wake_fx: PackedScene
## 開始後幾秒內還顯示「怎樣玩」的提示文字。
@export var hint_play_sec: float = 2.0
## 圈圈的半徑:出現時與縮到騎士頭上時。
@export var ring_start_radius: float = 36.0
@export var ring_end_radius: float = 20.0
## 騎士畫幾倍大(整數,像素保持方正)。
@export var knight_scale: float = 2.0
## 下面的按鈕墊離安全區底邊多遠(避開系統手勢區)。
@export var pad_bottom_margin: float = 28.0
@export var pad_height: float = 30.0

@export_group("顏色")
@export var wall_color: Color = Color("4a3550")
@export var wall_dark_color: Color = Color("2e2038")
@export var floor_color: Color = Color("3a2a2e")
@export var window_color: Color = Color("27325e")
@export var table_color: Color = Color("8a5a32")
@export var table_edge_color: Color = Color("5a3418")
@export var armor_color: Color = Color("aab3c9")
## 每位騎士的毛色(柯基、黑柴、白貴賓……)。
@export var fur_colors: Array[Color] = [Color("e0a050"), Color("6a4a3a"), Color("f0ece0")]
## 每位騎士的羽飾與按鈕墊的顏色。
@export var plume_colors: Array[Color] = [Color("e8434f"), Color("4a8ae8"), Color("6ad06a")]
