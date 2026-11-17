class_name EconomyData
extends Resource
## 零食經濟的數值(v2.4 BV2、BV4)。資料在 data/progression/economy.tres。
## 零食只是遊戲內的計數(GameState.snacks),不涉及真錢、不是商店。
##
## 零食從哪裡來:
##   - 敵人掉的零食:A 線發 snack_collected(amount),B 線全數加入。
##   - 擊倒:每打倒 kills_per_snack 隻敵人 +1(即時)。
##   - 寶箱:普通寶箱(tier 0)= 回復活力或零食;精英(1)與頭目(2)寶箱 = 一次把戲三選一,另加零食。
##   - 過關:clear_snacks + 星數 × snacks_per_star(困難模式 × hard_snack_mult)。
##   - 抉擇事件的部分選項。
##   - 無盡試煉:每清一波 endless_snacks_per_wave,頭目波另加 endless_boss_wave_snacks。
## 零食花在哪裡:倒下時復活(每關一次)、營地訓練(data/progression/meta_upgrades.tres)。

@export_group("Earning")
## 每打倒這麼多隻敵人得 1 個零食(0 = 不給)。
@export var kills_per_snack: int = 4
## 過關的基本零食。
@export var clear_snacks: int = 5
## 每顆星多給的零食。
@export var snacks_per_star: int = 4
## 困難模式過關零食的倍數。
@export var hard_snack_mult: float = 1.5

@export_group("Chests")
## 每種寶箱(0 普通、1 精英、2 頭目)給的零食。普通寶箱只在「選中零食」時給。
@export var chest_snacks: Array[int] = [6, 4, 12]
## 普通寶箱回復活力(而不是給零食)的機率;活力已滿時一定給零食。
@export var chest_heal_chance: float = 0.5
## 普通寶箱回復的活力(活力上限的比例)。
@export var chest_heal_ratio: float = 0.3
## 精英與頭目寶箱給幾次把戲三選一。
@export var chest_trick_choices: Array[int] = [0, 1, 1]

@export_group("Revive")
## 故事模式復活的價格 = revive_cost_base + 關卡索引(0 起算)× revive_cost_per_level。
@export var revive_cost_base: int = 15
@export var revive_cost_per_level: int = 8
## 無盡試煉復活的價格 = endless_revive_cost_base + 已清的波數 × endless_revive_cost_per_wave。
@export var endless_revive_cost_base: int = 20
@export var endless_revive_cost_per_wave: int = 2

@export_group("Endless")
@export var endless_snacks_per_wave: int = 1
@export var endless_boss_wave_snacks: int = 8


func revive_cost(level_index: int) -> int:
	return maxi(0, revive_cost_base + maxi(0, level_index) * revive_cost_per_level)


func endless_revive_cost(waves_cleared: int) -> int:
	return maxi(0, endless_revive_cost_base + maxi(0, waves_cleared) * endless_revive_cost_per_wave)


## 過關給的零食(stars 0 至 3)。
func clear_reward(stars: int, hard: bool) -> int:
	var amount := float(clear_snacks + maxi(0, stars) * snacks_per_star)
	if hard:
		amount *= hard_snack_mult
	return maxi(0, roundi(amount))


func chest_snack_amount(tier: int) -> int:
	if chest_snacks.is_empty():
		return 0
	return maxi(0, chest_snacks[clampi(tier, 0, chest_snacks.size() - 1)])


func chest_choice_count(tier: int) -> int:
	if chest_trick_choices.is_empty():
		return 0
	return maxi(0, chest_trick_choices[clampi(tier, 0, chest_trick_choices.size() - 1)])
