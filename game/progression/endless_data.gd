class_name EndlessData
extends Resource
## 無盡試煉的參數(v2.4 BV6)。資料在 data/levels/endless.tres;波次由 EndlessWaves 依這些參數產生。
##
## 一波接一波,沒有盡頭;每波的「敵人預算」= budget_base + (波數 − 1) × budget_per_wave,
## 用 enemy_costs 買敵人(新解鎖的敵人在解鎖那一波一定出現),分成幾組陸續出場,隊形隨機。
## 每 boss_every 波是頭目波:boss_every × 2 的倍數是黑騎士,其他是稻草人隊長,另加少量護衛。
## 每 event_every 波清空之後有一次抉擇事件(data/levels/events.tres 的 endless_pool)。
## 從第 hard_from_wave 波起,敵人改用困難模式的倍數(A 線依 GameState.difficulty 放大)。
##
## v2.6(BV5):「章的等級」tier = GameState.chapters_cleared(至少 1)。enemy_chapter、background_chapter
## 標明每種敵人、每張背景屬於第幾章;只用 tier 以內的。打完第二章(tier 2)起加入第二章的敵人
## (石像鬼、魔法書)與背景,打完第三章(tier 3)起加入第三章的(狐火、影狼)。頭目波也輪流換人:
## 中頭目 mini_boss_id → extra_mini_bosses(石像鬼統領、幻影黑騎士);頭目 boss_id → extra_bosses
## (綠騎士、摩根娜),同樣只用 tier 以內的。
##
## v2.7(BW5):tier 最高到 GameState.CHAPTER_COUNT(6)。打完第四章起加入螃蟹、水母、寄居蟹將軍、章魚王與
## 第四章的背景;第五章起雪人、火蜥蜴、雪人隊長、紅龍、白龍(雙龍在無盡試煉各自單獨出場,一次只有一條);
## 第六章起影子騎士、提燈鬼火、莫德雷德(第一戰,半血逃走)與莫德雷德。

@export var level_id: StringName = &"endless"
@export var display_name: String = "LEVEL_ENDLESS"
## 每次開始隨機選一個背景。
@export var backgrounds: Array[PackedScene] = []
## v2.6:每張背景屬於第幾章(與 backgrounds 同次序;沒寫 = 1)。
@export var background_chapter: Array[int] = []
@export var companions: Array[StringName] = [&"bulldog"]

@export_group("Enemies")
@export var enemy_ids: Array[StringName] = [&"scarecrow", &"crow", &"scarecrow_archer", &"scarecrow_elite",
		&"armored_husk"]
## 每種敵人花多少預算(與 enemy_ids 同次序)。
@export var enemy_costs: Array[int] = [1, 1, 2, 3, 3]
## 每種敵人從第幾波開始出現(與 enemy_ids 同次序)。
@export var enemy_unlock_wave: Array[int] = [1, 2, 3, 4, 6]
## 抽中機會的權重(與 enemy_ids 同次序)。
@export var enemy_weights: Array[float] = [3.0, 2.0, 1.5, 1.0, 1.0]
## v2.6:每種敵人屬於第幾章(與 enemy_ids 同次序;沒寫 = 1)。
@export var enemy_chapter: Array[int] = []

@export_group("Budget")
@export var budget_base: float = 6.0
@export var budget_per_wave: float = 1.6
## 每波最多幾隻(不含頭目)。
@export var max_enemies_per_wave: int = 24
## 每波分成幾組(隨機,含兩端)。
@export var groups_min: int = 2
@export var groups_max: int = 4
## 每組相隔的秒數。
@export var group_gap: float = 4.5
## 隊形(SpawnEntry.pattern)。surround 從 surround_from_wave 起才會出現。
@export var patterns: Array[StringName] = [&"edges", &"line_top", &"corners", &"surround"]
@export var surround_from_wave: int = 3

@export_group("Bosses")
@export var boss_every: int = 5
@export var mini_boss_id: StringName = &"scarecrow_captain"
@export var boss_id: StringName = &"black_knight"
## v2.6:之後各章的中頭目與頭目(與 *_chapter 同次序)。輪流:第 k 次中頭目波用
## [mini_boss_id] + 已解鎖的 extra_mini_bosses 的第 k % 數目 個(頭目同理)。
@export var extra_mini_bosses: Array[StringName] = []
@export var extra_mini_boss_chapter: Array[int] = []
@export var extra_bosses: Array[StringName] = []
@export var extra_boss_chapter: Array[int] = []
## 頭目波的護衛 = 該波預算 × 這個比例(黑騎士波從第 boss_escort_from 波起才有護衛)。
@export var escort_ratio: float = 0.35
@export var boss_escort_from: int = 20

@export_group("Flow")
@export var event_every: int = 10
## 從這一波起敵人用困難模式的倍數(0 = 不切換)。
@export var hard_from_wave: int = 16


func is_boss_wave(wave: int) -> bool:
	return boss_every > 0 and wave > 0 and wave % boss_every == 0


## 第 wave 波的頭目(不是頭目波時 &"")。tier = 已打完的章數(v2.6;1 = 只有第一章的頭目)。
func boss_for_wave(wave: int, tier: int = 1) -> StringName:
	if not is_boss_wave(wave):
		return &""
	@warning_ignore("integer_division")
	var turn := wave / (boss_every * 2) - 1 if is_main_boss_wave(wave) else wave / (boss_every * 2)
	var pool: Array[StringName] = []
	if is_main_boss_wave(wave):
		pool.append(boss_id)
		pool.append_array(_unlocked_ids(extra_bosses, extra_boss_chapter, tier))
	else:
		pool.append(mini_boss_id)
		pool.append_array(_unlocked_ids(extra_mini_bosses, extra_mini_boss_chapter, tier))
	return pool[maxi(0, turn) % pool.size()]


## 頭目波之中,是「頭目」(每 boss_every × 2 波)而不是中頭目。
func is_main_boss_wave(wave: int) -> bool:
	return is_boss_wave(wave) and wave % (boss_every * 2) == 0


## 第 index 種敵人屬於第幾章。
func enemy_chapter_of(index: int) -> int:
	return enemy_chapter[index] if index >= 0 and index < enemy_chapter.size() else 1


## tier 以內的背景。
func backgrounds_for(tier: int) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for i in backgrounds.size():
		var chapter := background_chapter[i] if i < background_chapter.size() else 1
		if chapter <= maxi(1, tier) and backgrounds[i] != null:
			result.append(backgrounds[i])
	return result


static func _unlocked_ids(ids: Array[StringName], chapters: Array[int], tier: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for i in ids.size():
		var chapter := chapters[i] if i < chapters.size() else 1
		if chapter <= maxi(1, tier):
			result.append(ids[i])
	return result


func is_event_wave(wave: int) -> bool:
	return event_every > 0 and wave > 0 and wave % event_every == 0


func budget_for(wave: int) -> float:
	return budget_base + float(maxi(0, wave - 1)) * budget_per_wave
