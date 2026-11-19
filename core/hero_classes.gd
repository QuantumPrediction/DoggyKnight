class_name HeroClasses
extends RefCounted

const IDS: Array[StringName] = [&"knight", &"mage", &"archer"]

static func valid_id(value: Variant) -> StringName:
	if (value is String or value is StringName) and IDS.has(StringName(value)):
		return StringName(value)
	return &"knight"

static func get_data(id: StringName) -> HeroClassData:
	return load("res://data/player/classes/%s.tres" % valid_id(id)) as HeroClassData
