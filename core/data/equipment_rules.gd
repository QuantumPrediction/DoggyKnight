class_name EquipmentRules
extends Resource
## All balance values live in the catalog resource; levels start at 1.
@export var gem_packs: Array[Dictionary] = []
@export var synergy_radius: float = 64.0
@export var hard_coin_mult: float = 1.25
@export var items: Array[Dictionary] = []
@export var elements: Dictionary = {}
@export var effect_caps: Dictionary = {}
@export var common_costs: Array[int] = [50, 100, 180, 300]
@export var epic_costs: Array[int] = [100, 160, 240, 340, 460, 600, 760, 940]
@export var epic_shards: Array[int] = [0, 0, 1, 2, 3, 4, 5, 7]
@export var boss_drop_chance: float = 0.2
@export var boss_pity: int = 5
@export var boss_shards: int = 2
@export var duplicate_shards: int = 8
@export var first_clear_gems: int = 20
@export var level_coins: int = 40
@export var boss_coins: int = 160
@export var starting_coins: int = 250
@export var common_growth: float = 0.25
@export var epic_growth: float = 0.125
@export var effect_steps: Array[float] = [1.0, 1.15, 1.3, 1.5]
@export var effect_levels: Array[int] = [1, 3, 6, 9]
@export var synergy_window: float = 3.0
@export var synergy_cooldown: float = 6.0
@export var movement_charge_time: float = 1.5
@export var guard_cooldown: float = 12.0
@export var control_cooldown: float = 8.0
@export var control_radius: float = 32.0
@export var control_time: float = 0.35
@export var set_bonuses: Dictionary = {
    "guardian": {"max_vigor": 0.08},
    "ranger": {"move_speed": 0.06},
    "scholar": {"exp_mult": 0.08}
}
