class_name LevelEvent
extends Resource
## 一個抉擇事件(v2.4 BV3):一個標題、兩個選項(第 0 項梅林的祝福、第 1 項摩根娜的誘惑)。

@export var id: StringName
@export var title: String                   ## 翻譯鍵,例如 "EVENT_SWORD_GLOW_TITLE"
@export var options: Array[EventOption] = []


func offer_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in options:
		if option != null:
			result.append(option.to_offer())
	return result


func get_option(index: int) -> EventOption:
	if index < 0 or index >= options.size():
		return null
	return options[index]
