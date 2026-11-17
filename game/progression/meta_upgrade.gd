class_name MetaUpgrade
extends Resource
## 營地訓練的一項永久升級(v2.4 BV5,DEV_PLAN 4.12)。資料在 data/progression/meta_upgrades.tres。
## 等級存在 GameState.meta_upgrades[id](0 = 還沒練),隨存檔保存,reset_run() 不重設。
## 介面(game/camp/training.tscn)由 D 線製作,名稱與說明的文字(TRAINING_*)也由 D 線撰寫。

@export var id: StringName
@export var name_key: String                  ## 翻譯鍵,例如 "TRAINING_VITALITY_NAME"(D 線撰寫文字)
@export var desc_key: String                  ## 翻譯鍵,例如 "TRAINING_VITALITY_DESC"
@export var max_level: int = 5
## 每一級的價格(零食):costs[0] = 由 0 級升到 1 級。
@export var costs: Array[int] = []
## 每一級的效果,例如 0.05 = 每級 +5%。
@export var per_level: float = 0.05
## 直接加到金毛數值的 StatBlock 欄位(相加,以基準值計算,和把戲一樣)。
## 空白 = 不是金毛的數值,由別線讀 MetaUpgradeTable.current_bonus(id)(loyalty:A 線的忠誠度累積;
## luck:A 線的寶箱與零食掉落機率)。
@export var stat: StringName


## 由 level 級升到 level + 1 級的價格;已到上限時傳回 -1。
func cost_for(level: int) -> int:
	if level < 0 or level >= max_level or costs.is_empty():
		return -1
	return costs[mini(level, costs.size() - 1)]
