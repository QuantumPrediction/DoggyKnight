extends Node
## 全域遊戲狀態(Autoload 名稱:GameState)。DEV_PLAN 4.2。
##
## 凍結的合約:四條線可以讀寫這些欄位,但不得修改這個檔案。

const BASE_STATS: StatBlock = preload("res://data/player/goldie_base_stats.tres")
## v2.7:故事模式的總章數(DEV_PLAN 4.14)。選章、存檔、結算一律用這個常數,不要另外寫死。
const CHAPTER_COUNT: int = 6

var player_stats: StatBlock       # 金毛目前數值(含把戲加成)
var vigor: int                    # 活力(生命值)
var satisfaction: int             # 滿意度 0 至 100,由小遊戲提高
var snacks: int = 0               # 零食(續關用,原型只做計數)
var chapter: int = 1               # v2.6:目前這一輪的章(1 至 CHAPTER_COUNT);每章是獨立的一輪(新遊戲由標題畫面選章)
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
var mode: StringName = &"story"   # v2.4:&"story"(第一章)或 &"endless"(無盡試煉)
var meta_upgrades: Dictionary = {}   # v2.4:營地訓練的永久等級 {升級 id: 等級},隨存檔保存
var endless_best: int = 0         # v2.4:無盡試煉最佳波數,隨存檔保存
var chapters_cleared: int = 0     # v2.6:已打完的最高章數(0 至 CHAPTER_COUNT);打完第 N 章解鎖第 N+1 章,隨存檔保存。
                                  # chapter 是這一輪正在玩的章(1 至 3),新遊戲時由標題畫面設定,reset_run() 不會改它


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
	level_index = 0
	hero_level = 1
	active_tricks.clear()
	next_level_bonus = 0.0
