class_name DialogueLine
extends Resource
## 一句對白(DEV_PLAN 4.11,v2.3)。文字是翻譯鍵,內容在 i18n/story.csv;說話者與表情見 docs/STORY.md。

@export var speaker: StringName = &"narrator"   ## goldie、bulldog、merlin、black_knight、morgana、scarecrow_captain、crow、narrator
@export var expression: StringName = &"normal"  ## 頭像表情:assets/portraits/<speaker>/<expression>.png
@export var text_key: String                    ## 例如 "STORY_L1_BEFORE_01"
@export var illustration: Texture2D             ## 繪本插畫(assets/story/<id>.png);旁白一定有,其他可空白
