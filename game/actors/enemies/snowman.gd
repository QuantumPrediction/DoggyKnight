class_name SnowmanEnemy
extends EnemyBase
## 雪人兵(v2.7 AW3,第五章 5-1 起,24×24):戴黑狼頭帽子的雪人,保持距離拋雪球(落點先出現影子)。
## 動作在 SnowmanBrain,數值在 data/enemies/snowman_tuning.tres;生命在 data/enemies/snowman.tres,
## 雪球在 data/enemies/projectiles/snowball.tres。
## 倒下:碎成一堆雪花(BitsScatter.SNOW 與 snow_burst 粒子),不是受傷。

const DEFAULT_TUNING: SnowmanTuning = preload("res://data/enemies/snowman_tuning.tres")
const SNOW_COLORS: Array[Color] = [Color("ffffff"), Color("dcefff"), Color("b8dcf5")]

@export var tuning: SnowmanTuning = DEFAULT_TUNING

var brain: SnowmanBrain


func attack_role() -> StringName:
	return DifficultyScaling.RANGED


func _on_ready() -> void:
	brain = SnowmanBrain.new(self, tuning)
	brain.on_ready()


func _on_activated() -> void:
	brain.on_activated()


func _ai(delta: float) -> void:
	brain.ai(delta)


func _cancel_attack() -> void:
	super()
	if brain != null:
		brain.cancel()


func _is_committed() -> bool:
	return brain != null and brain.is_committed()


func _uses_separation() -> bool:
	return brain == null or brain.uses_separation()


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + Vector2(0, -6), BitsScatter.Kind.SNOW, SNOW_COLORS, 14)
	CombatFx.particles(self, &"snow_burst", global_position, false)
