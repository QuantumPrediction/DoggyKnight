class_name ChapterData
extends Resource
## 一章的關卡次序與營地位置(B1、B8)。第一章:data/levels/chapter_1.tres。

## 依次序排列的關卡。GameState.level_index 就是這個陣列的索引(0 = 第 1 關)。
@export var levels: Array[LevelData] = []
## 在哪幾關「過關」之後進營地(0 起算的索引)。第一章是 1-2 與 1-4,即 [1, 3]。
@export var camp_after: Array[int] = [1, 3]


func level_count() -> int:
	return levels.size()


func get_level(index: int) -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]


func is_last(index: int) -> bool:
	return index == levels.size() - 1


func has_camp_after(index: int) -> bool:
	return camp_after.has(index)
