class_name ChapterData
extends Resource
## 一章的關卡次序與營地位置(B1、B8)。data/levels/chapter_<N>.tres(v2.6:三章,DEV_PLAN 4.13)。

## v2.6:第幾章(1 至 3)。
@export var number: int = 1
## v2.6:章名的翻譯鍵(CHAPTER_1 至 CHAPTER_3)。結算、HUD 用 tr() 顯示。
@export var display_name: String = "CHAPTER_1"
## 依次序排列的關卡。GameState.level_index 就是這個陣列的索引(0 = 第 1 關)。
@export var levels: Array[LevelData] = []
## 在哪幾關「過關」之後進營地(0 起算的索引)。每章都是第 2 關與第 4 關之後,即 [1, 3]。
@export var camp_after: Array[int] = [1, 3]
## v2.3 故事(docs/STORY.md 第 8 節):新遊戲時、第 1 關之前的開場繪本(第一章 data/story/prologue.tres,
## 第 N 章 cN_prologue.tres)。
@export var prologue: DialogueScript
## v2.3 故事:打完最後一關的結算之後、回標題之前的下一章預告(teaser.tres、cN_teaser.tres)。
## 結局本身是最後一關的 LevelData.story_after。
@export var teaser: DialogueScript
## v2.6 音樂:這一章的一般曲與頭目曲。LevelData.music 空白時用這兩首(一般關 field_music、頭目關
## boss_music);中頭目那一波(稻草人隊長、石像鬼統領、幻影黑騎士)改播 boss_music。
## 音樂檔不存在時 FlowMain 退回 field / boss。
@export var field_music: StringName = &"field"
@export var boss_music: StringName = &"boss"


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
