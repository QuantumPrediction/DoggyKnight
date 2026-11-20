class_name HeroClassData
extends Resource
## A complete starting loadout. Shared resources are never mutated by a run.
@export var id: StringName = &"knight"
@export var display_name: String = "UI_CLASS_KNIGHT"
@export var description: String
@export var tactic: String
@export var ultimate_name: String
@export var stats: StatBlock
@export var windup: float = 0.12
@export var projectile_speed: float = 180.0
@export var projectile_radius: float = 3.0
@export var max_hits: int = 1
@export var splash_radius: float = 0.0
@export var secondary_mult: float = 0.6
@export var focus_time: float = 0.0
@export var focus_mult: float = 1.0
@export var ultimate_radius: float = 80.0
@export var ultimate_mult: float = 6.0
@export var ultimate_projectiles: int = 1
@export var ultimate_spread: float = 0.14
@export var accent: Color = Color("c5a361")
