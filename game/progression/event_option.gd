class_name EventOption
extends Resource
## 抉擇事件的一個選項(v2.4 BV3)。資料在 data/levels/events.tres。
##
## effects 的鍵(全部可以省略,依下列次序套用):
##   "stats": Dictionary         這一輪冒險的數值加成(和把戲一樣相加、以基準值計算),例如
##                                {"attack_damage": 0.3, "max_vigor": -0.2};失敗重試時還原。
##   "vigor_keep_ratio": float    活力變成目前的這個比例(至少剩 1),例如 0.5 = 只剩一半。
##   "heal_ratio": float          回復活力上限的這個比例(1.0 = 回滿)。
##   "snacks": int                得到零食。
##   "bonus_trick_levels": int    下一個選的把戲多升這麼多級(不超過上限)。
##   "trick_choices": int         立即給這麼多次把戲三選一(可能出現進化)。

const KEYS: Array[String] = ["stats", "vigor_keep_ratio", "heal_ratio", "snacks", "bonus_trick_levels",
		"trick_choices", "route"]

@export var title: String                   ## 翻譯鍵
@export var desc: String                    ## 翻譯鍵
@export var icon: String                    ## 圖檔路徑(梅林或摩根娜的頭像)
@export var tone: String = "merlin"         ## "merlin"(梅林的祝福)或 "morgana"(摩根娜的誘惑)
@export var effects: Dictionary = {}


## event_offered 的一項(DEV_PLAN 4.12)。
func to_offer() -> Dictionary:
	return {"title": title, "desc": desc, "icon": icon, "tone": tone}
