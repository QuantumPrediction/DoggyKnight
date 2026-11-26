class_name WaveData
extends Resource
## 一波敵人(DEV_PLAN 4.3)。

@export var spawns: Array[SpawnEntry] = []
## First-chapter reinforcements chosen on the class screen. Baseline targets and
## stars read the ordinary spawns, so opt-in groups never retune a normal room.
@export var reinforcements: Array[SpawnEntry] = []


## Presented only when the opening route choice offers the shield echo.
@export var shield_echo_spawns: Array[SpawnEntry] = []


func entries_for(reinforced: bool, borrow_shield: bool = false) -> Array[SpawnEntry]:
	var group := shield_echo_spawns if borrow_shield and not shield_echo_spawns.is_empty() else spawns
	if reinforced and not reinforcements.is_empty():
		return group + reinforcements
	return group
