class_name AbilitySet
extends RefCounted
## 金毛身上的能力類把戲(A10)。DEV_PLAN 4.7、4.9。
##
## - 數值類把戲(sit、wag、fetch)由 B 線改 GameState.player_stats,這裡不處理。
## - 金毛進場時用 rebuild(GameState.active_tricks) 重建(同一個 id 出現幾次就是幾層)。
## - 關卡中收到 EventBus.trick_chosen 時用 add_trick() 多疊一層。

const ABILITY_IDS: Array[StringName] = [&"shake", &"spin", &"bark"]

var shake: ShakeAbility
var spin: SpinAbility
var bark: BarkAbility
var _all: Array[TrickAbility] = []


func _init(host: Object, tuning: AbilityTuning) -> void:
	shake = ShakeAbility.new(host, tuning)
	spin = SpinAbility.new(host, tuning)
	bark = BarkAbility.new(host, tuning)
	_all = [shake, spin, bark]


static func is_ability(trick_id: StringName) -> bool:
	return ABILITY_IDS.has(trick_id)


## 依照把戲清單重建。清單中不是能力的 id 會被略過。
func rebuild(tricks: Array) -> void:
	for ability in _all:
		ability.reset()
	for trick_id: Variant in tricks:
		add_trick(StringName(trick_id))


## 多疊一層。傳回 true 表示這是能力類把戲。
func add_trick(trick_id: StringName) -> bool:
	var ability := get_ability(trick_id)
	if ability == null:
		return false
	ability.add_stack()
	return true


func get_ability(trick_id: StringName) -> TrickAbility:
	for ability in _all:
		if ability.id == trick_id:
			return ability
	return null


func stacks(trick_id: StringName) -> int:
	var ability := get_ability(trick_id)
	return ability.stacks if ability != null else 0


func triggers(trick_id: StringName) -> int:
	var ability := get_ability(trick_id)
	return ability.triggers if ability != null else 0


func update(delta: float) -> void:
	for ability in _all:
		ability.update(delta)


## 揮劍打中敵人時呼叫,傳回這一下的傷害倍數。
func on_swing_landed() -> float:
	var mult := 1.0
	for ability in _all:
		mult *= ability.on_swing_landed()
	return mult
