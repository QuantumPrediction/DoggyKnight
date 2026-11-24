class_name WaveData
extends Resource
## 一波敵人(DEV_PLAN 4.3)。

@export var spawns: Array[SpawnEntry] = []
## First-chapter reinforcements chosen on the class screen. Baseline targets and
## stars read the ordinary spawns, so opt-in groups never retune a normal room.
@export var reinforcements: Array[SpawnEntry] = []


func entries_for(reinforced: bool) -> Array[SpawnEntry]:
	if reinforced and not reinforcements.is_empty():
		return spawns + reinforcements
	return spawns
