class_name CrabEnemy
extends EnemyBase
## 螃蟹海盜(v2.7 AW1,第四章 4-1 起,24×24):橫著快速移動;舉鉗子(guard)時幾乎打不痛;
## 張開鉗子(扇形預警)夾一下,夾完喘氣(反擊時機)。動作在 CrabBrain,數值在 data/enemies/crab_tuning.tres,
## 生命與夾擊傷害(接觸傷害)在 data/enemies/crab.tres。
## 倒下:翻過來冒一串泡泡,「啵」地散掉(BitsScatter.BUBBLE),不是受傷。

const DEFAULT_TUNING: CrabTuning = preload("res://data/enemies/crab_tuning.tres")
const BUBBLE_COLORS: Array[Color] = [Color(0.8, 0.95, 1.0, 0.9), Color(0.6, 0.85, 1.0, 0.9)]

@export var tuning: CrabTuning = DEFAULT_TUNING

var brain: CrabBrain
var _hit_from: Vector2 = Vector2.INF


func attack_role() -> StringName:
	return DifficultyScaling.MELEE


func _on_ready() -> void:
	brain = CrabBrain.new(self, tuning)
	brain.on_ready()


func _on_activated() -> void:
	brain.on_activated()


func _ai(delta: float) -> void:
	brain.ai(delta)


func is_guarding() -> bool:
	return brain != null and brain.guarding and state == State.ACTIVE


func hit(amount: int, from_position: Vector2, knockback_speed: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> void:
	_hit_from = from_position
	super(amount, from_position, knockback_speed, style)
	_hit_from = Vector2.INF


func take_damage(amount: int) -> void:
	if brain != null and state == State.ACTIVE:
		amount = brain.filter_damage(amount, _hit_from if _hit_from != Vector2.INF else _attacker_guess())
	super(amount)


## 舉著鉗子時推不動。
func apply_knockback(from_position: Vector2, speed: float) -> void:
	if is_guarding():
		return
	super(from_position, speed)


func _attacker_guess() -> Vector2:
	if not is_inside_tree():
		return global_position - facing
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	return player.global_position if player != null else global_position - facing


func _cancel_attack() -> void:
	super()
	if brain != null:
		brain.cancel()


func is_attacking_target(victim: Node2D) -> bool:
	return target == victim and brain != null and brain.phase == CrabBrain.Phase.TELL


func _is_committed() -> bool:
	return brain != null and brain.is_committed()


func _uses_separation() -> bool:
	return brain == null or brain.uses_separation()


func _draw() -> void:
	super()
	if brain != null and state == State.ACTIVE:
		brain.draw(self, _frame_size)


func _on_died() -> void:
	_poof()
	BitsScatter.burst(self, global_position + Vector2(0, -4), BitsScatter.Kind.BUBBLE, BUBBLE_COLORS, 10)
	CombatFx.particles(self, &"bubble_pop", global_position, false)
