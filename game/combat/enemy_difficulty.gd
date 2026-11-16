class_name EnemyDifficulty
extends Resource
## 一種難度對敵人的倍數(AS6)。實際值在 data/enemies/difficulty_scaling.tres。
##
## 由場地的 spawn_enemy() 依 GameState.difficulty 套用:
## - 生命、接觸傷害、移動速度:複製一份 EnemyData 再乘上倍數(原本的資料檔不會被改)。
## - 其他(預警秒數、攻擊間隔、投射物速度、頭目重劈等不在 EnemyData 裡的傷害):
##   敵人自己用 EnemyBase.tell()、rest()、scaled_damage()、scaled_speed() 換算。
## 一般模式全部是 1.0,行為與沒有這個檔案時完全相同。

@export var id: StringName = &"normal"

@export_group("數值")
@export var hp_mult: float = 1.0
@export var boss_hp_mult: float = 1.0           ## 頭目與中頭目的生命(頭目戰太長不好玩,所以分開調)
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0             ## 移動、衝鋒、俯衝的速度

@export_group("節奏")
@export var telegraph_mult: float = 1.0         ## 預警秒數(< 1 = 預警比較短)
@export var interval_mult: float = 1.0          ## 攻擊之間的休息與冷卻(< 1 = 攻擊比較頻繁)
@export var projectile_speed_mult: float = 1.0

@export_group("合作")
@export var melee_slot_bonus: int = 0           ## 同時進攻的近戰敵人上限再加幾隻
@export var ranged_slot_bonus: int = 0          ## 同時瞄準的弓兵上限再加幾隻


func is_identity() -> bool:
	return is_equal_approx(hp_mult, 1.0) and is_equal_approx(boss_hp_mult, 1.0) \
			and is_equal_approx(damage_mult, 1.0) and is_equal_approx(speed_mult, 1.0) \
			and is_equal_approx(telegraph_mult, 1.0) and is_equal_approx(interval_mult, 1.0) \
			and is_equal_approx(projectile_speed_mult, 1.0) and melee_slot_bonus == 0 and ranged_slot_bonus == 0


## 依這個難度複製一份敵人資料(生命、接觸傷害、速度)。一般模式直接傳回原本那份。
func scaled_data(data: EnemyData, is_boss: bool) -> EnemyData:
	if data == null:
		return null
	var hp_k := boss_hp_mult if is_boss else hp_mult
	if is_equal_approx(hp_k, 1.0) and is_equal_approx(damage_mult, 1.0) and is_equal_approx(speed_mult, 1.0):
		return data
	var copy := data.duplicate() as EnemyData
	copy.max_hp = maxi(1, roundi(float(data.max_hp) * hp_k))
	copy.contact_damage = maxi(1, roundi(float(data.contact_damage) * damage_mult)) if data.contact_damage > 0 else 0
	copy.move_speed = data.move_speed * speed_mult
	return copy
