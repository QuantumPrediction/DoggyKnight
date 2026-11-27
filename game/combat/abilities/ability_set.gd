class_name AbilitySet
extends RefCounted
## 金毛身上的能力類把戲(A10、v2.4 AV1)。DEV_PLAN 4.7、4.9、4.12。
##
## - 數值類把戲(sit、wag、fetch、dig、sniff)由 B 線改 GameState.player_stats,這裡不處理
##   (例外:sniff 的暴擊率與 dig 的零食機率不在 StatBlock 裡,由金毛與 Loot 直接數 active_tricks)。
## - 金毛進場時用 rebuild(GameState.active_tricks) 重建(同一個 id 出現幾次就是幾層)。
## - 關卡中收到 EventBus.trick_chosen 時用 add_trick() 多疊一層。
## - 進化(v2.4):收到 trick_evolved(或 trick_chosen 是進化 id)時呼叫 evolve():
##   兩個原把戲的能力停用,換成進化把戲(最多一層,重複收到不會疊加)。
##   規則:進化把戲啟用時,它的兩個原把戲一律停用(重建時也一樣,即使 active_tricks 還留著原把戲)。

## 進化 id → 兩個原把戲(DEV_PLAN 4.12,id 固定)。
const EVOLUTION_SOURCES: Dictionary = {
	&"tornado_tail": [&"spin", &"wag"],
	&"lion_roar": [&"bark", &"sit"],
	&"high_five": [&"shake", &"fetch"],
	&"meteor_pounce": [&"pounce", &"zoomies"],
}
const ABILITY_IDS: Array[StringName] = [&"shake", &"spin", &"bark", &"pounce", &"roll", &"play_dead", &"zoomies",
		&"tornado_tail", &"lion_roar", &"high_five", &"meteor_pounce", &"arc_rune", &"starfall", &"gale_disc"]

var shake: ShakeAbility
var spin: SpinAbility
var bark: BarkAbility
var pounce: PounceAbility
var roll: RollAbility
var play_dead: PlayDeadAbility
var zoomies: ZoomiesAbility
var tornado: TornadoTailAbility
var lion_roar: LionRoarAbility
var high_five: HighFiveAbility
var meteor: MeteorPounceAbility
var techniques: Array[TrickAbility] = []
## Per arena player. A revive reuses this instance, a full retry creates a new one.
var landed_pairs: Dictionary[StringName, int] = {}
var _technique_hits := 0
var _all: Array[TrickAbility] = []


func _init(host: Object, tuning: AbilityTuning) -> void:
	shake = ShakeAbility.new(host, tuning)
	spin = SpinAbility.new(host, tuning)
	bark = BarkAbility.new(host, tuning)
	pounce = PounceAbility.new(host, tuning)
	roll = RollAbility.new(host, tuning)
	play_dead = PlayDeadAbility.new(host, tuning)
	zoomies = ZoomiesAbility.new(host, tuning)
	tornado = TornadoTailAbility.new(host, tuning)
	lion_roar = LionRoarAbility.new(host, tuning)
	high_five = HighFiveAbility.new(host, tuning)
	meteor = MeteorPounceAbility.new(host, tuning)
	_all = [shake, spin, bark, pounce, roll, play_dead, zoomies, tornado, lion_roar, high_five, meteor]

	for id in AttackTechniques.IDS:
		var ability := TrickAbility.new(host, tuning)
		ability.id = id
		techniques.append(ability)
		_all.append(ability)


static func is_ability(trick_id: StringName) -> bool:
	return ABILITY_IDS.has(trick_id)


static func is_evolution(trick_id: StringName) -> bool:
	return EVOLUTION_SOURCES.has(trick_id)


## trick_id 是哪一個進化把戲的原把戲(不是時傳回空白)。
static func evolution_of(trick_id: StringName) -> StringName:
	for evo: StringName in EVOLUTION_SOURCES:
		if (EVOLUTION_SOURCES[evo] as Array).has(trick_id):
			return evo
	return &""


## 依照把戲清單重建。清單中不是能力的 id 會被略過;啟用中的進化會停用它的原把戲。
func rebuild(tricks: Array) -> void:
	_technique_hits = 0
	for ability in _all:
		ability.reset()
	for trick_id: Variant in tricks:
		var id := StringName(trick_id)
		if is_evolution(id):
			continue
		var ability := get_ability(id)
		if ability != null:
			ability.add_stack()
	for trick_id: Variant in tricks:
		var id := StringName(trick_id)
		if is_evolution(id):
			evolve(id)


## 多疊一層。傳回 true 表示這是能力類把戲(包括進化,以及已被進化取代的原把戲)。
func add_trick(trick_id: StringName) -> bool:
	if is_evolution(trick_id):
		evolve(trick_id)
		return true
	var ability := get_ability(trick_id)
	if ability == null:
		return false
	var evo := evolution_of(trick_id)
	if evo != &"" and stacks(evo) > 0:
		return true    # 已經進化:原把戲不再單獨生效
	ability.add_stack()
	return true


## 進化:停用兩個原把戲的能力,啟用進化把戲。傳回 true 表示這次真的換了(之前未啟用)。
func evolve(evolution_id: StringName) -> bool:
	var evo := get_ability(evolution_id)
	if evo == null:
		return false
	for source: StringName in EVOLUTION_SOURCES.get(evolution_id, []):
		var ability := get_ability(source)
		if ability != null:
			ability.reset()
	var fresh := not evo.is_active()
	evo.add_stack()
	return fresh


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


## A multi-target swing, a penetrating arrow, or a splashing bolt supplies one beat.
func primary_impact(hero: GoldiePlayer, at: Vector2, primary_id: int, direction: Vector2) -> void:
	var levels := Vector3i(techniques[0].stacks, techniques[1].stacks, techniques[2].stacks)
	if levels == Vector3i.ZERO:
		return
	_technique_hits += 1
	if _technique_hits < 3:
		return
	_technique_hits = 0
	for ability in techniques:
		if ability.is_active():
			ability.triggers += 1
	TechniqueVolley.launch(hero, at, primary_id, direction, levels)


## 場上有敵人倒下。
func on_kill() -> void:
	for ability in _all:
		ability.on_kill()


func speed_mult() -> float:
	var mult := 1.0
	for ability in _all:
		mult *= ability.speed_mult()
	return mult


func damage_taken_mult() -> float:
	var mult := 1.0
	for ability in _all:
		mult *= ability.damage_taken_mult()
	return mult


func is_invulnerable() -> bool:
	for ability in _all:
		if ability.is_invulnerable():
			return true
	return false


## 目前會撲的能力(流星撲擊優先),都沒有時傳回 null。
func active_pounce() -> PounceAbility:
	if meteor.is_active():
		return meteor
	if pounce.is_active():
		return pounce
	return null


## 加速中(暴衝或流星撲擊的暴衝)。
func is_zooming() -> bool:
	return zoomies.is_boosting() or meteor.is_boosting()
