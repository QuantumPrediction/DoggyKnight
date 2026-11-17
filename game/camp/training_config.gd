class_name TrainingConfig
extends Resource
## 營地訓練介面的可調數值與外觀(DEV_PLAN 17 DV1)。實際數值在 game/camp/training_config.tres。
## 升級的價格與效果不在這裡:在 B 線的 data/progression/meta_upgrades.tres(見 TrainingShop)。

@export_group("資料")
## 依序嘗試的升級表(用第一個存在而且有內容的)。B 線的正式資料在前,D 線的替身在後。
@export var upgrade_paths: PackedStringArray = ["res://data/progression/meta_upgrades.tres", "res://game/camp/training_upgrades.tres"]
## 每一列左邊的圖示(升級 id → 圖)。沒有指定的用程式畫的 8×8 像素圖示。
@export var icons: Dictionary[StringName, Texture2D] = {}
## 零食的圖(價格按鈕與零食數旁邊)。留空時用 assets/fx/snack/snack_frames.tres 的第一格。
@export var snack_frames: SpriteFrames

@export_group("版面")
@export var panel_max_width: float = 176.0
@export var row_height: float = 38.0
@export var row_gap: int = 3
## 每一列右上角的價格牌(整列都可以按)。
@export var price_tag_size: Vector2 = Vector2(38, 15)
@export var close_button_size: Vector2 = Vector2(132, 26)
## 「返回」按鈕底邊離安全區底邊的距離(避開系統手勢區)。
@export var bottom_margin: float = 20.0
## 打開時內容從下面滑上來、淡入的秒數。
@export var open_sec: float = 0.3

@export_group("升級演出")
@export var upgrade_sfx: StringName = &"level_up"
## Haptics 的強度(light、medium、heavy)。
@export var upgrade_haptic: StringName = &"light"
@export var star_burst_particles: PackedScene
@export var sparkle_particles: PackedScene
## 升級的那一列閃白光的秒數。
@export var flash_sec: float = 0.45
## 「Lv.N!」與「-N」浮起的秒數。
@export var floater_sec: float = 1.0
## 零食數由舊值數到新值的秒數。
@export var counter_sec: float = 0.4

@export_group("顏色")
@export var backdrop_color: Color = Color(0.06, 0.04, 0.12, 0.9)
@export var row_color: Color = Color("2a2440")
@export var row_border_color: Color = Color("5a4f80")
@export var row_ready_border_color: Color = Color("ffe066")
@export var pip_on_color: Color = Color("ffd34d")
@export var pip_off_color: Color = Color("4a4560")
@export var effect_color: Color = Color("bfe8ff")
@export var buy_fill_color: Color = Color("c0603a")
@export var max_tag_color: Color = Color("8a6a1a")
@export var close_fill_color: Color = Color("3a8a5a")
@export var close_border_color: Color = Color("123a24")
@export var level_up_color: Color = Color("ffe066")
@export var spend_color: Color = Color("ff8fb0")
