class_name GargoyleEnemy
extends EnemyBase
## 石像鬼(v2.6 AV1,2-1 起):飛在空中繞著金毛盤旋 → 紅線預警(方向鎖定)→ 沿線俯衝 → 落地喘氣(最好打)。
## 約每 4 秒變成石頭 1.5 秒:落到地上、播 stone,打不動(受擊冒「鏘!」)、推不動、不會被震懾。
## 生命約烏鴉的 2.5 倍(data/enemies/gargoyle.tres),動作數值在 data/enemies/gargoyle_tuning.tres。
## 飛行與石頭的邏輯在 GargoyleFlight(中頭目石像鬼統領共用)。
## 倒下:碎成一小堆石屑(彈一下、淡出),不是受傷。

const DEFAULT_TUNING: GargoyleTuning = preload("res://data/enemies/gargoyle_tuning.tres")

@export var tuning: GargoyleTuning = DEFAULT_TUNING

var flight: GargoyleFlight


func _on_ready() -> void:
	flight = GargoyleFlight.new(self, tuning)
	flight.on_ready()


func _on_activated() -> void:
	flight.on_activated()


func _ai(delta: float) -> void:
	flight.ai(delta)


func is_stone() -> bool:
	return flight != null and flight.is_stone()


## 石頭:打不動,冒「鏘!」。
func take_damage(amount: int) -> void:
	if is_stone() and state == State.ACTIVE and amount > 0:
		_number_style = DamageNumber.Style.NORMAL
		flight.clang()
		return
	super(amount)


func apply_knockback(from_position: Vector2, speed: float) -> void:
	if is_stone():
		return
	super(from_position, speed)


func stun(duration: float) -> void:
	if is_stone():
		return
	super(duration)


func _cancel_attack() -> void:
	super()
	if flight != null:
		flight.cancel()


func _is_committed() -> bool:
	return flight != null and flight.is_committed()


func _uses_separation() -> bool:
	return flight == null or flight.uses_separation()


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + _sprite_base_offset, BitsScatter.Kind.CHIP, GargoyleFlight.CHIP_COLORS, 10, true)
	CombatFx.particles(self, &"stone_bits", global_position, true)
