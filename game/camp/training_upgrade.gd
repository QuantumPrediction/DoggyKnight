class_name TrainingUpgrade
extends Resource
## 一項營地訓練(DEV_PLAN 4.12、17 DV1)。D 線的替身資料,欄位和 B 線的 MetaUpgrade 相同:
## id、name_key、desc_key、max_level、costs、per_level。
##
## 正式資料在 B 線的 data/progression/meta_upgrades.tres(MetaUpgradeTable,entries 是 MetaUpgrade 的陣列);
## 訓練介面依欄位名稱讀取(duck typing),所以兩邊的類別不必相同。B 線的檔案不存在時才用
## game/camp/training_upgrades.tres(這個類別)。

## 升級 id:vitality、strength、agility、loyalty、luck。GameState.meta_upgrades 的鍵。
@export var id: StringName = &""
## 名稱的翻譯鍵(TRAINING_<ID>_NAME)。
@export var name_key: String = ""
## 效果說明的翻譯鍵(TRAINING_<ID>_DESC)。文字裡的 %s 會換成效果值,例如「+20%」。
@export var desc_key: String = ""
## 最高等級。
@export var max_level: int = 5
## 每一級的價格(零食):costs[0] 是買第 1 級的價格。比 max_level 短時,之後的等級用最後一個價格。
@export var costs: Array[int] = []
## 每一級的效果。小於 1 時當作百分比顯示(0.1 = 每級 +10%),否則當作點數(10 = 每級 +10)。
## 由 B 線套用到 player_stats(新遊戲 reset_run() 之後)。
@export var per_level: float = 0.0
