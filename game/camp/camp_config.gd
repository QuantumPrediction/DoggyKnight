class_name CampConfig
extends Resource
## 營地的可調數值與外觀(DEV_PLAN 11 D1)。實際數值在 game/camp/camp_config.tres。
##
## 美術替換:把正式圖填進 *_texture / *_frames 欄位即可,程式不用改。
## 欄位留空時,營地用程式畫的佔位圖(夜空、圓桌、營火)。

@export_group("流程")
## 營地畫在第幾層 CanvasLayer。比 HUD(10)高,所以會蓋住 HUD;比暫停選單(20)低,所以暫停選單會蓋在營地上面。
@export var canvas_layer: int = 15
## 小遊戲的場景。日後加入大胃王等小遊戲時,換這裡或加入口。
@export var minigame_scene: PackedScene
## 每次進營地可以玩幾次小遊戲(避免無限刷獎勵)。0 表示不限。
@export var minigame_plays_per_visit: int = 1
## 「即將開放」等提示停留的秒數。
@export var toast_sec: float = 1.6

@export_group("版面")
@export var button_size: Vector2 = Vector2(132, 26)
@export var button_gap: int = 6
## 選單底邊離安全區底邊的距離(避開系統手勢區)。
@export var menu_bottom_margin: float = 20.0
@export var title_font_size: int = 14
@export var button_font_size: int = 11
@export var small_font_size: int = 9

@export_group("金毛")
@export var goldie_frames: SpriteFrames
## 卸下盔甲、趴著休息的動畫。
@export var goldie_animation: StringName = &"sleep"
@export var goldie_scale: float = 2.0
## 尾巴每秒搖幾下(來回算一下)。
@export var tail_wags_per_sec: float = 2.5
@export var tail_color: Color = Color("e8b24a")

@export_group("美術(留空 = 程式畫的佔位圖)")
## 整個營地背景。至少 200×440,置中對齊遊戲區(和場地背景相同的約定)。
@export var background_texture: Texture2D
@export var table_texture: Texture2D
@export var fire_frames: SpriteFrames
@export var fire_animation: StringName = &"default"

@export_group("顏色(佔位圖用)")
@export var sky_top_color: Color = Color("141030")
@export var sky_bottom_color: Color = Color("3a2c55")
@export var ground_color: Color = Color("2e3b2a")
@export var ground_light_color: Color = Color("4a4a2e")
@export var table_color: Color = Color("8a5a32")
@export var table_edge_color: Color = Color("5a3418")
@export var fire_colors: Array[Color] = [Color("e8452c"), Color("ff9a2e"), Color("ffe36a")]
@export var glow_color: Color = Color(1.0, 0.6, 0.25, 0.18)
@export var vigor_bar_color: Color = Color("7ed957")
@export var satisfaction_bar_color: Color = Color("ff8fb0")
