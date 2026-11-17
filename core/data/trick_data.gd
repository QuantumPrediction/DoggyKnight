class_name TrickData
extends Resource
## 把戲資料(DEV_PLAN 4.3、4.7)。B 線在 data/tricks/ 放 .tres。
##
## stat_modifiers 的鍵是 StatBlock 的欄位名稱,例如 {"move_speed": 0.15}。
## 數值怎樣套用(相加還是相乘)由 B 線決定並寫進 B 線的測試。

@export var id: StringName
@export var display_name: String              ## 翻譯鍵,例如 "TRICK_SIT_NAME";介面用 tr() 顯示
@export var description: String               ## 翻譯鍵,例如 "TRICK_SIT_DESC"
@export var icon: Texture2D
@export var stat_modifiers: Dictionary = {}
@export var is_ability: bool = false
## v2.4 進化(DEV_PLAN 4.12)
@export var max_level: int = 5                ## 最多可以選幾次
@export var evolution_partner: StringName     ## 與這個把戲搭配可以進化(空白 = 不會進化)
@export var evolves_into: StringName          ## 進化後的把戲 id
@export var is_evolution: bool = false        ## 本身是進化把戲(不會出現在一般三選一)
