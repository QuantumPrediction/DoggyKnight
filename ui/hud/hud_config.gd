class_name HudConfig
extends Resource
## HUD 演出的可調數值(C 線,CP4)。資料檔:ui/hud/hud_config.tres。

## 關卡標題卡總長(秒)。B 線在 level_started 之後等 intro_duration(約 1.6 秒)才開始第一波。
@export var title_card_time: float = 1.6
## 過關慶祝橫幅停留多久(秒)。B 線約 2 秒後顯示結算。
@export var celebration_time: float = 1.9
## 必殺技切入畫面總長(秒)。
@export var cut_in_time: float = 0.6
## 連擊數達到多少才顯示。
@export var combo_min_show: int = 2
## 連擊里程碑(數字變色、跳更大):[黃, 橘, 粉紅]。
@export var combo_tiers: Array[int] = [5, 10, 20]
## 活力低於這個比例時,愛心跳動、數值條閃爍。
@export var low_vigor_ratio: float = 0.3
## 心跳的速度(每秒幾下)。
@export var heartbeat_rate: float = 1.6
## 「等級 N!」彈出文字停留秒數。
@export var level_pop_time: float = 1.1
