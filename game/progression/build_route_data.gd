class_name BuildRouteData
extends Resource
## A run-only starting direction. Tuning is stored in data/routes/*.tres.
@export var id: StringName
@export var hero: StringName
@export var title: String
@export var description: String
@export var starter: StringName
@export var preferred: Array[StringName] = []
@export var modifiers: Dictionary = {}
