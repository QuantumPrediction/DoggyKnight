class_name LevelData
extends Resource
## 關卡資料(DEV_PLAN 4.3、4.9)。B 線在 data/levels/ 放 .tres。
## display_name 存翻譯鍵(例如 "LEVEL_1_1"),介面用 tr() 顯示。

@export var id: StringName
@export var display_name: String
@export var waves: Array[WaveData] = []
@export var is_boss: bool = false
@export var arena_scene: PackedScene
@export var companions: Array[StringName] = []   ## 這一關開始時加入的同伴,例如 [&"bulldog"]
@export var background: PackedScene              ## 場地背景(assets/backgrounds/*.tscn)
@export var par_time: float = 75.0               ## v2.2 星級:在這個秒數內過關得第 2 顆星
@export var damage_budget: int = 30              ## v2.2 星級:這一關受到的傷害不超過這個數得第 3 顆星
@export var story_before: DialogueScript         ## v2.3:開打前的對白(docs/STORY.md)
@export var story_after: DialogueScript          ## v2.3:過關後的對白
@export var music: StringName = &""               ## v2.6:背景音樂 id(Music.play);空白 = 一般關 &"field"、頭目關 &"boss"
