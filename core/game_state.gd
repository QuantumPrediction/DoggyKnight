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
var music_on: bool = true         # v2.2:背景音樂開關,隨存檔保存
var haptics_on: bool = true       # v2.2:震動開關,隨存檔保存
var tutorial_done: bool = false   # v2.2:第一關的操作提示已看過,隨存檔保存
var best_stars: Dictionary = {}   # v2.2:每關最佳星數 {關卡 id: 0 至 3},隨存檔保存(困難模式用「關卡 id:hard」)
var difficulty: StringName = &"normal"   # v2.3:&"normal" 或 &"hard";新遊戲時由標題畫面設定,隨存檔保存
var chapter_cleared: bool = false # v2.3:打完第一章(解鎖困難模式),隨存檔保存
var story_seen: Dictionary = {}   # v2.3:看過的對白段落 {段落 id: true},隨存檔保存


func _ready() -> void:
	# 原型只有繁體中文(DEV_PLAN 第 10 節);字串在 i18n/strings.csv。
	TranslationServer.set_locale("zh_TW")
	reset_run()


## 開始新的一輪冒險。零食、設定(音效、音樂、震動)、教學紀錄、最佳星數、難度、通關紀錄與看過的對白
## 屬於存檔與設定,不會被重設。
func reset_run() -> void:
	player_stats = BASE_STATS.duplicate() as StatBlock
	vigor = player_stats.max_vigor
	satisfaction = 0
	chapter = 1
	level_index = 0
	hero_level = 1
	active_tricks.clear()
	next_level_bonus = 0.0
