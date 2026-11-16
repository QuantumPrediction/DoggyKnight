class_name DialogueScript
extends Resource
## 一段對白(DEV_PLAN 4.11,v2.3)。B 線依 docs/STORY.md 在 data/story/<id>.tres 建立;
## C 線的對白框用 play(script) 播放;D 線的營地也用它。

@export var id: StringName                      ## 例如 &"l1_before"、&"camp1"、&"prologue"
@export var lines: Array[DialogueLine] = []
@export var skippable: bool = true
