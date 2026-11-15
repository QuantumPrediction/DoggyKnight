extends Node
## 全域遊戲狀態(Autoload 名稱:GameState)。DEV_PLAN 4.2。
##
## 凍結的合約:四條線可以讀寫這些欄位,但不得修改這個檔案。

const BASE_STATS: StatBlock = preload("res://data/player/goldie_base_stats.tres")

var player_stats: StatBlock       # 金毛目前數值(含把戲加成)
var vigor: int                    # 活力(生命值)
var satisfaction: int             # 滿意度 0 至 100,由小遊戲提高
var snacks: int = 0               # 零食(續關用,原型只做計數)
var chapter: int
var level_index: int              # 0 起算:0 = 第 1 關
var hero_level: int
var active_tricks: Array[StringName] = []
var next_level_bonus: float       # 小遊戲表現換來的下一關加成,0.05 = +5%
var sound_on: bool = true         # 音效開關,隨存檔保存


func _ready() -> void:
	# 原型只有繁體中文(DEV_PLAN 第 10 節);字串在 i18n/strings.csv。
	TranslationServer.set_locale("zh_TW")
	reset_run()


## 開始新的一輪冒險。零食與音效開關屬於存檔與設定,不會被重設。
func reset_run() -> void:
	player_stats = BASE_STATS.duplicate() as StatBlock
	vigor = player_stats.max_vigor
	satisfaction = 0
	chapter = 1
	level_index = 0
	hero_level = 1
	active_tricks.clear()
	next_level_bonus = 0.0
