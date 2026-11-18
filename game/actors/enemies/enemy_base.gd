class_name EnemyBase
extends CharacterBody2D
## 敵人共同基底(A4)。
##
## 合約(DEV_PLAN 4.4、4.9):
## - 在群組 "enemy";setup(data: EnemyData)、take_damage(amount: int)。
## - 由場地的 spawn_enemy() 生成時,先有短暫的塵土預警(SPAWNING),期間已在群組 "enemy" 之內,
##   但不能被瞄準,也不會攻擊。
## - 死亡時「立即」離開群組 "enemy",只發一次 enemy_died,掉落經驗珠,然後才播可愛的「噗」。
## - 被打中:閃白、擊退、短暫停頓(hit stop,只凍結自己,不改 Engine.time_scale)。
## - 群體分離:附近的敵人互相推開,不會疊成一點。
## - M3 打磨:被打中時擠壓變形、跳出傷害數字、噴 hit_burst;倒下時噴 death_particles
##   (稻草人 straw_bits、烏鴉 feathers);從地面冒出時揚起 footstep_dust;精英有光環,
##   倒下時鏡頭震一下。慢動作時(CombatFx.time_scale)動作跟著變慢。
##
## - v2.3 難度(AS6):spawn_enemy() 依 GameState.difficulty 呼叫 apply_difficulty(mods);
##   子類別的預警秒數用 tell()、休息與冷卻用 rest()、不在 EnemyData 的傷害用 scaled_damage()、
##   速度用 scaled_speed()(生命、接觸傷害、移動速度已經在 EnemyData 的複本裡乘好)。
## - v2.3 合作(AS7):同時進攻的敵人有上限(場地的「進攻名額」)。近戰敵人出手前先
##   claim_attack_slot(),收招或被打斷時 release_attack_slot();拿不到名額就在攻擊距離外等。
##
## 子類別覆寫:_ai(delta)、_cancel_attack()、_on_activated()、_on_died()、_uses_separation()、
## attack_role()、is_attacking_target()、join_attack()。
## 子類別設定 desired_velocity(想走的速度)與 anim_state(想播的動畫)。

const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const COMPANION_GROUP: StringName = &"companion"
const FLASH_SHADER: Shader = preload("res://game/actors/enemies/hit_flash.gdshader")
const EXP_ORB_SCENE: PackedScene = preload("res://game/combat/exp_orb.tscn")

enum State { SPAWNING, ACTIVE, DYING }

const POP_TIME := 0.16
const ELITE_AURA := Color(1.0, 0.45, 0.25)
const ELITE_SPARK := Color(1.0, 0.8, 0.4)

@export_group("身體")
@export var body_radius: float = 6.0
@export var visual_scale: float = 1.0
@export var tint: Color = Color.WHITE
@export var elite: bool = false                   ## 精英:腳下有光環,倒下時鏡頭震一下

@export_group("受擊")
@export var knockback_mult: float = 1.0           ## 0 = 不會被擊退(頭目)
@export var knockback_time: float = 0.12
@export var flash_time: float = 0.08
@export var hurt_anim_time: float = 0.15

@export_group("群體")
@export var separation_radius: float = 16.0
@export var separation_speed: float = 34.0

@export_group("出場與倒下")
@export var spawn_time: float = 0.5
@export var death_time: float = 0.3
@export var max_exp_orbs: int = 5
@export var retarget_interval: float = 0.25
@export var death_particles: StringName = &""     ## 倒下時噴的粒子(assets/fx/particles/<名稱>.tscn)
@export var number_height: float = -1.0           ## 傷害數字出現在中心上方幾像素;< 0 = 依圖的高度

@export_group("光暈")
@export var light_fx: StringName = &""           ## C 線的光暈 assets/fx/lights/<名稱>.tscn(眼睛、面罩、羽毛)
@export var light_offset: Vector2 = Vector2.ZERO ## 朝右時光暈的位置(朝左自動鏡像);只在行動中顯示

var data: EnemyData
var hp: int = 1
var max_hp: int = 1
var state: State = State.ACTIVE
var arena: Node                                   ## 由場地的 spawn_enemy() 設定
var target: Node2D                                ## 目前要攻擊的對象(金毛,或正在挑釁的鬥牛犬)
var facing: Vector2 = Vector2.LEFT
var desired_velocity: Vector2 = Vector2.ZERO
var arena_margin: Vector2 = Vector2(6, 6)         ## 中心離場地邊緣至少多遠(整張圖留在場內)
var anim_state: StringName = &"idle"
var sprite: AnimatedSprite2D
var rng := RandomNumberGenerator.new()

var _hitstop_left: float = 0.0
var _flash_left: float = 0.0
var _hurt_left: float = 0.0
var _knock_left: float = 0.0
var _knock_velocity: Vector2 = Vector2.ZERO
var _stun_left: float = 0.0
var _spawn_left: float = 0.0
var _spawn_total: float = 0.0
var _death_left: float = 0.0
var _retarget_left: float = 0.0
var _dizzy: Node2D
var _spawn_marker: AttackTelegraph
var _telegraph: AttackTelegraph
var _material: ShaderMaterial
var _frame_size: Vector2 = Vector2(24, 24)
var _sprite_base_offset: Vector2 = Vector2.ZERO
var _squash_left: float = 0.0
var _pop_left: float = 0.0
var _glow_color: Color = Color.WHITE
var _glow_amount: float = 0.0
var _age: float = 0.0
var _number_style: DamageNumber.Style = DamageNumber.Style.NORMAL
var _light: Node2D
var mods: EnemyDifficulty                         ## 難度倍數(spawn_enemy 設定;null = 一般模式)

static var _cache_frame: int = -1
static var _cache: Array[Node] = []


func _init() -> void:
	add_to_group(ENEMY_GROUP)


## 合約:由 EnemyData 設定數值。可在加入場景前或後呼叫。
func setup(p_data: EnemyData) -> void:
	data = p_data
	max_hp = maxi(1, data.max_hp)
	hp = max_hp


## 難度(AS6):spawn_enemy() 在加進場景前呼叫。生命、傷害、速度已在 EnemyData 的複本裡乘好。
func apply_difficulty(p_mods: EnemyDifficulty) -> void:
	mods = p_mods


## 預警秒數 × 難度。
func tell(seconds: float) -> float:
	return seconds * (mods.telegraph_mult if mods != null else 1.0)


## 攻擊之間的休息、冷卻秒數 × 難度。
func rest(seconds: float) -> float:
	return seconds * (mods.interval_mult if mods != null else 1.0)


## 不在 EnemyData 裡的傷害(頭目重劈、投射物)× 難度。
func scaled_damage(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(float(base) * (mods.damage_mult if mods != null else 1.0)))


## 不在 EnemyData 裡的速度(衝鋒、衝撞)× 難度。
func scaled_speed(speed: float) -> float:
	return speed * (mods.speed_mult if mods != null else 1.0)


func projectile_speed_mult() -> float:
	return mods.projectile_speed_mult if mods != null else 1.0


func _ready() -> void:
	sprite = get_node_or_null(^"Sprite") as AnimatedSprite2D
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.ENEMY
	collision_mask = Layers.ARENA
	_setup_collision()
	if data == null:
		var fallback := EnemyData.new()
		fallback.id = StringName(name.to_snake_case())
		setup(fallback)
	rng.seed = hash(get_instance_id())
	_retarget_left = rng.randf() * retarget_interval
	if arena == null:
		arena = CombatFx.find_arena(self)
	if sprite != null:
		_frame_size = _idle_size() * visual_scale
		sprite.scale = Vector2.ONE * visual_scale
		sprite.modulate = tint
		_material = ShaderMaterial.new()
		_material.shader = FLASH_SHADER
		sprite.material = _material
	arena_margin = CombatMath.sprite_margin(_frame_size, body_radius)
	global_position = CombatMath.clamp_to_bounds(global_position, arena_margin)
	_attach_light()
	_on_ready()
	_apply_animation()
	queue_redraw()


func _physics_process(delta: float) -> void:
	var ts := CombatFx.time_scale
	delta *= ts
	_age += delta
	match state:
		State.SPAWNING:
			_tick_spawn(delta)
			return
		State.DYING:
			_tick_death(delta)
			return
	_tick_flash(delta)
	if _hitstop_left > 0.0:
		# 打擊停頓:連擠壓變形也停在最扁的那一刻。
		_hitstop_left -= delta
		if _hitstop_left <= 0.0 and sprite != null:
			sprite.speed_scale = ts
		return
	_tick_squash(delta)
	if sprite != null:
		sprite.speed_scale = ts
	if elite:
		queue_redraw()
	if _tick_custom(delta):
		return
	_retarget_left -= delta
	if _retarget_left <= 0.0 or not _is_valid_victim(target):
		_retarget_left = retarget_interval
		target = pick_target()
	if _stun_left > 0.0:
		_stun_left -= delta
		desired_velocity = Vector2.ZERO
		anim_state = &"idle"
		if _stun_left <= 0.0:
			_end_stun()
	elif _knock_left <= 0.0:
		_ai(delta)
	_move(delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_apply_animation()


# --- 合約與受擊 -------------------------------------------------------------------

func take_damage(amount: int) -> void:
	var style := _number_style
	_number_style = DamageNumber.Style.NORMAL
	if state == State.DYING or amount <= 0 or is_invulnerable():
		return
	hp = maxi(0, hp - amount)
	_flash_left = flash_time
	_set_flash(1.0)
	_hurt_left = hurt_anim_time
	_squash_left = CombatFx.feel().squash_time
	if state == State.ACTIVE:
		_tick_squash(0.0)
	CombatFx.damage_number(self, amount, number_anchor(), style)
	_on_damaged(amount)
	if hp <= 0:
		die()


## 金毛與同伴用的攻擊:傷害 + 從 from_position 往外擊退。style 決定傷害數字的樣子(握手雙倍用 CRIT)。
func hit(amount: int, from_position: Vector2, knockback_speed: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL) -> void:
	_number_style = style
	take_damage(amount)
	if state != State.DYING:
		apply_knockback(from_position, knockback_speed)


## v2.7:回復生命(提燈鬼火的回復光)。不超過最大生命;傳回實際回復了多少。倒下中或出場中不回復。
func heal(amount: int) -> int:
	if amount <= 0 or state != State.ACTIVE or hp >= max_hp:
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	_on_healed(hp - before)
	return hp - before


## v2.7:金毛自動攻擊時優先打這隻(提燈鬼火)。
func is_priority_target() -> bool:
	return false


## v2.7:擋下攻擊時的「鏘!」(盾、鉗子、劍鞘護盾):火花與一個小光圈,不跳傷害數字。
func clang_fx(from_position: Vector2, color: Color = Color(0.85, 0.9, 1.0)) -> void:
	var dir := (from_position - global_position).normalized() if from_position.distance_to(global_position) > 0.5 else -facing
	var at := global_position + _sprite_base_offset + dir * (body_radius + 2.0)
	CombatFx.spawn(self, &"hit_spark", at, dir.angle(), Vector2.ONE * 0.8, color)
	CombatFx.ring(self, at, 1.0, 7.0, 0.15, Color(color, 0.9), 1.0)
	CombatFx.sfx(&"clang", &"husk_clank", -6.0)


## 傷害數字出現的位置(頭上)。
func number_anchor() -> Vector2:
	var h := number_height if number_height >= 0.0 else _frame_size.y * 0.55
	return global_position + _sprite_base_offset + Vector2(0, -h)


## 無敵中(出場時;頭目另有出場、怒吼與倒下演出)。這時受到的傷害一律無效。
func is_invulnerable() -> bool:
	return state == State.SPAWNING


## 擊退。正在出招(已經預警)時不會被擊退,讓看得到的預警一定會出手;吠叫的暈眩仍可打斷。
func apply_knockback(from_position: Vector2, speed: float) -> void:
	if knockback_mult <= 0.0 or speed <= 0.0 or state == State.DYING or _is_committed():
		return
	var dir := global_position - from_position
	if dir.length() < 0.01:
		dir = -facing
	_knock_velocity = dir.normalized() * speed * knockback_mult
	_knock_left = knockback_time


func apply_hitstop(duration: float) -> void:
	if state != State.ACTIVE:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	if sprite != null:
		sprite.speed_scale = 0.0


## 暈眩(吠叫):不能動、不能攻擊,頭上冒星星。正在預警的攻擊會被取消。
func stun(duration: float) -> void:
	if state == State.DYING or duration <= 0.0:
		return
	_stun_left = maxf(_stun_left, duration)
	desired_velocity = Vector2.ZERO
	_cancel_attack()
	if _dizzy == null:
		_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55) + _sprite_base_offset)


func is_targetable() -> bool:
	return state == State.ACTIVE


func is_dead() -> bool:
	return state == State.DYING


func is_stunned() -> bool:
	return _stun_left > 0.0


func die() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	remove_from_group(ENEMY_GROUP)
	collision_layer = 0
	_cancel_attack()
	release_attack_slot()
	_clear_spawn_marker()
	_clear_dizzy()
	_hitstop_left = 0.0
	if _light != null:
		_light.visible = false
	if sprite != null:
		sprite.speed_scale = 1.0
	EventBus.enemy_died.emit(data.id, global_position, data.exp_value)
	_drop_exp()
	_drop_loot()
	Sfx.play(&"enemy_down")
	_death_left = death_time
	if death_particles != &"":
		CombatFx.particles(self, death_particles, global_position + _sprite_base_offset, true)
	if elite:
		CombatFx.trauma(self, CombatFx.feel().trauma_elite_kill)
		CombatFx.particles(self, &"star_burst", global_position + _sprite_base_offset, false, true)
	_on_died()


## v2.7:撤退(莫德雷德第一戰逃走時,場上的手下跟著跑掉;頭目的幻影時間到了消失):
## 立刻離開 enemy 群組,「噗」地揚起塵土淡出。不是被打倒:不發 enemy_died、不掉經驗與寶箱。
func retreat() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	remove_from_group(ENEMY_GROUP)
	collision_layer = 0
	_cancel_attack()
	release_attack_slot()
	_clear_spawn_marker()
	_clear_dizzy()
	_hitstop_left = 0.0
	if _light != null:
		_light.visible = false
	if sprite != null:
		sprite.speed_scale = 1.0
	_death_left = death_time
	_poof()


# --- 出場 -----------------------------------------------------------------------

## 出場預警:塵土與地上的圓圈,duration 秒後才開始行動。
func begin_spawn(duration: float = -1.0) -> void:
	if state == State.DYING:
		return
	var t := spawn_time if duration < 0.0 else duration
	if t <= 0.0:
		_activate()
		return
	state = State.SPAWNING
	_spawn_left = t
	_spawn_total = t
	_spawn_marker = AttackTelegraph.make_circle(body_radius + 4.0, AttackTelegraph.DUST)
	add_child(_spawn_marker)
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 1.5, Color.WHITE, true)
	CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 2), true)
	_tick_spawn(0.0)


func _tick_spawn(delta: float) -> void:
	_spawn_left -= delta
	var t := 1.0 - clampf(_spawn_left / maxf(_spawn_total, 0.001), 0.0, 1.0)
	if _spawn_marker != null:
		_spawn_marker.progress = t
	if sprite != null:
		# 從地面冒出:前半段只看到地上的塵土,後半段由扁到高、由透明到清楚。
		var rise := clampf((t - 0.35) / 0.65, 0.0, 1.0)
		sprite.modulate = Color(tint, rise)
		sprite.scale = Vector2(visual_scale * (1.0 + 0.25 * (1.0 - rise)), visual_scale * maxf(0.1, rise))
		sprite.position = _sprite_base_offset + Vector2(0, _frame_size.y * 0.5 * (1.0 - rise))
	if _spawn_left <= 0.0:
		_activate()


func _activate() -> void:
	var was_spawning := state == State.SPAWNING
	state = State.ACTIVE
	_clear_spawn_marker()
	if sprite != null:
		sprite.modulate = tint
		sprite.scale = Vector2.ONE * visual_scale
		sprite.position = _sprite_base_offset
	if was_spawning:
		# 冒出地面的一刻:彈一下,再揚起一點塵土。
		_pop_left = POP_TIME
		CombatFx.particles(self, &"footstep_dust", global_position + Vector2(0, 2), true)
	_on_activated()


# --- 移動 -----------------------------------------------------------------------

func _move(delta: float) -> void:
	var v := desired_velocity
	if _knock_left > 0.0:
		_knock_left -= delta
		v = _knock_velocity * clampf(_knock_left / maxf(knockback_time, 0.001), 0.0, 1.0)
	elif _uses_separation():
		v += separation_push() * separation_speed
	velocity = v * CombatFx.time_scale
	move_and_slide()
	global_position = CombatMath.clamp_to_bounds(global_position, arena_margin)


## 附近敵人互相推開的方向(長度最多 1.5)。
func separation_push() -> Vector2:
	var push := Vector2.ZERO
	for node in _enemies_cached():
		if node == self or not is_instance_valid(node):
			continue
		var other := node as EnemyBase
		if other == null or other.state == State.DYING:
			continue
		var offset := global_position - other.global_position
		var min_dist := maxf(separation_radius, body_radius + other.body_radius + 2.0)
		var dist_sq := offset.length_squared()
		if dist_sq >= min_dist * min_dist:
			continue
		var dist := sqrt(dist_sq)
		if dist < 0.01:
			# 完全重疊:用兩者的 id 決定一個固定方向,一個往前一個往後。
			var a := float(mini(get_instance_id(), other.get_instance_id()) % 628) / 100.0
			offset = Vector2.from_angle(a) * (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
			dist = 0.01
		else:
			offset /= dist
		push += offset * (1.0 - dist / min_dist)
	return push.limit_length(1.5)


func _enemies_cached() -> Array[Node]:
	var frame := Engine.get_physics_frames()
	if frame != _cache_frame:
		_cache_frame = frame
		_cache = get_tree().get_nodes_in_group(ENEMY_GROUP)
	return _cache


# --- 目標與攻擊 -------------------------------------------------------------------

## 目標:挑釁範圍內正在舉盾的同伴優先,否則是金毛(睡著了就沒有目標)。
func pick_target() -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(COMPANION_GROUP):
		var companion := node as Node2D
		if companion == null or not companion.has_method(&"is_taunting") or not bool(companion.call(&"is_taunting")):
			continue
		var taunt: Variant = companion.get(&"taunt_radius")
		var taunt_radius: float = float(taunt) if taunt != null else 40.0
		var d := global_position.distance_to(companion.global_position)
		if d <= taunt_radius and d < best_distance:
			best = companion
			best_distance = d
	if best != null:
		return best
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	return player if _is_valid_victim(player) else null


## 可以被敵人打的對象:金毛(沒睡著)與同伴。
func victims() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if _is_valid_victim(node as Node2D):
			result.append(node as Node2D)
	for node in get_tree().get_nodes_in_group(COMPANION_GROUP):
		if _is_valid_victim(node as Node2D):
			result.append(node as Node2D)
	return result


## 打中扇形範圍內的所有對象。傳回打中幾個。
func hit_victims_in_sector(origin: Vector2, dir: Vector2, radius: float, half_angle: float, damage: int) -> int:
	var count := 0
	for victim in victims():
		var r := radius_of(victim)
		if CombatMath.in_sector(origin, dir, victim.global_position, radius + r, half_angle, r + 4.0):
			victim.call(&"take_damage", damage)
			count += 1
	return count


func hit_victims_in_circle(center: Vector2, radius: float, damage: int) -> int:
	var count := 0
	for victim in victims():
		if center.distance_to(victim.global_position) <= radius + radius_of(victim):
			victim.call(&"take_damage", damage)
			count += 1
	return count


static func radius_of(node: Node) -> float:
	var r: Variant = node.get(&"body_radius")
	return float(r) if r != null else 6.0


## 參數用 Variant:目標可能已被釋放;已釋放的物件傳給有物件型別的參數會出錯。
func _is_valid_victim(victim: Variant) -> bool:
	if not is_instance_valid(victim):
		return false
	var node := victim as Node2D
	if node == null or not node.is_inside_tree():
		return false
	if node.has_method(&"is_downed") and bool(node.call(&"is_downed")):
		return false
	return node.has_method(&"take_damage")


# --- 進攻名額(AS7) ----------------------------------------------------------------

## 這隻敵人用哪一種進攻名額:&"melee"、&"ranged";空白 = 不受限制(烏鴉、頭目)。
func attack_role() -> StringName:
	return &""


func _arena_ok() -> bool:
	return arena != null and is_instance_valid(arena) and arena.has_method(&"claim_attack_slot")


## 拿一個進攻名額(已經拿著就傳回 true)。不在場地裡時一律可以出手。
func claim_attack_slot() -> bool:
	if attack_role() == &"" or not _arena_ok():
		return true
	return bool(arena.call(&"claim_attack_slot", self, attack_role()))


## 現在有沒有空的名額(不拿)。
func attack_slot_free() -> bool:
	if attack_role() == &"" or not _arena_ok():
		return true
	return bool(arena.call(&"attack_slot_free", self, attack_role()))


func release_attack_slot() -> void:
	if _arena_ok():
		arena.call(&"release_attack_slot", self)


## 正在對 victim 出招(預警或揮擊中)。弓兵的交叉火力看這個。
func is_attacking_target(_victim: Node2D) -> bool:
	return false


## 夾擊:同伴開始預警時,場地叫附近等著的近戰敵人一起出手。傳回有沒有答應。
func join_attack(_victim: Node2D) -> bool:
	return false


## 開始預警時呼叫:後段關卡讓附近的同伴一起夾擊(場地決定這一關有沒有夾擊)。
func _call_pincer(victim: Node2D) -> void:
	if _arena_ok() and arena.has_method(&"call_pincer"):
		arena.call(&"call_pincer", self, victim)


func _show_telegraph(telegraph: AttackTelegraph) -> void:
	_clear_telegraph()
	_telegraph = telegraph
	add_child(_telegraph)


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


# --- 掉落與倒下 -------------------------------------------------------------------

## v2.4 寶箱與零食(AV2、AV3):交給場地依 data/enemies/loot_tuning.tres 決定。
func _drop_loot() -> void:
	if arena != null and is_instance_valid(arena) and arena.has_method(&"drop_loot"):
		arena.call(&"drop_loot", self)


func _drop_exp() -> void:
	for value in CombatMath.split_exp(data.exp_value, max_exp_orbs):
		if arena != null and is_instance_valid(arena) and arena.has_method(&"spawn_exp_orb"):
			arena.call(&"spawn_exp_orb", global_position, value)
		elif get_parent() != null:
			var orb := EXP_ORB_SCENE.instantiate() as Node2D
			orb.set(&"value", value)
			get_parent().add_child(orb)
			orb.global_position = global_position


func _tick_death(delta: float) -> void:
	_death_left -= delta
	var t := 1.0 - clampf(_death_left / maxf(death_time, 0.001), 0.0, 1.0)
	if sprite != null:
		# 可愛的「噗」:先壓扁再變白、變透明。
		sprite.scale = Vector2(visual_scale * (1.0 + 0.4 * t), visual_scale * (1.0 - 0.5 * t))
		sprite.modulate = Color(tint, 1.0 - t)
		_set_flash(clampf(1.0 - t * 0.5, 0.0, 1.0))
	if _death_left <= 0.0:
		queue_free()


func _poof() -> void:
	CombatFx.spawn(self, &"dust", global_position, 0.0, Vector2.ONE * 1.6, Color.WHITE, true)
	CombatFx.ring(self, global_position, 2.0, body_radius + 8.0, 0.25, Color(1, 1, 1, 0.8), 1.0)
	for i in 3:
		var dir := Vector2.from_angle(rng.randf() * TAU)
		CombatFx.spawn(self, &"hit_spark", global_position + dir * body_radius, rng.randf() * TAU,
				Vector2.ONE * 0.75, Color(1.0, 0.95, 0.6))


# --- 表現 -----------------------------------------------------------------------

func _tick_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(0.0)
	elif _glow_amount > 0.0 and _material != null:
		_material.set_shader_parameter(&"flash_color", _glow_color)
		_material.set_shader_parameter(&"flash", _glow_amount)


func _set_flash(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"flash_color", Color.WHITE)
		_material.set_shader_parameter(&"flash", amount if amount > 0.0 else _glow_amount)
		if amount <= 0.0 and _glow_amount > 0.0:
			_material.set_shader_parameter(&"flash_color", _glow_color)


## 讓整隻敵人帶一層顏色(頭目第二階段的紅光)。amount 0 = 沒有。
func set_glow(color: Color, amount: float) -> void:
	_glow_color = color
	_glow_amount = clampf(amount, 0.0, 1.0)
	if _flash_left <= 0.0:
		_set_flash(0.0)


## 被打中的擠壓變形與出場的彈跳(只在 ACTIVE 時)。
func _tick_squash(delta: float) -> void:
	if sprite == null:
		return
	var feel := CombatFx.feel()
	var sx := 1.0
	var sy := 1.0
	if _squash_left > 0.0:
		_squash_left = maxf(0.0, _squash_left - delta)
		var k := _squash_left / maxf(feel.squash_time, 0.001)
		sx += feel.squash_amount * k
		sy -= feel.squash_amount * k * 0.8
	if _pop_left > 0.0:
		_pop_left = maxf(0.0, _pop_left - delta)
		var p := sin(PI * (1.0 - _pop_left / POP_TIME))
		sx -= 0.15 * p
		sy += 0.2 * p
	sprite.scale = Vector2(visual_scale * sx, visual_scale * sy)


func _apply_animation() -> void:
	if sprite == null:
		return
	if absf(facing.x) > 0.05:
		sprite.flip_h = facing.x < 0.0
	if _light != null:
		_light.visible = state == State.ACTIVE and sprite.visible
		_light.position = sprite.position + Vector2(-light_offset.x if sprite.flip_h else light_offset.x, light_offset.y)
	_play(&"hurt" if _hurt_left > 0.0 else anim_state)


func _play(anim: StringName, restart: bool = false) -> void:
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if sprite.animation != anim or restart:
		sprite.play(anim)
		if restart:
			sprite.set_frame_and_progress(0, 0.0)
	elif not sprite.is_playing() and frames.get_animation_loop(anim):
		sprite.play(anim)


func _idle_size() -> Vector2:
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		return frames.get_frame_texture(&"idle", 0).get_size()
	return Vector2(24, 24)


## 加上 C 線的光暈圖(加亮混合的 Sprite2D,不用 Light2D)。檔案不存在就略過。
func _attach_light() -> void:
	if light_fx == &"":
		return
	var path := "res://assets/fx/lights/%s.tscn" % light_fx
	if not ResourceLoader.exists(path):
		return
	_light = (load(path) as PackedScene).instantiate() as Node2D
	if _light == null:
		return
	_light.name = "Light"
	_light.position = light_offset
	_light.visible = false
	add_child(_light)


func _setup_collision() -> void:
	var collision := get_node_or_null(^"Collision") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "Collision"
		add_child(collision)
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	collision.shape = circle


func _clear_spawn_marker() -> void:
	if _spawn_marker != null and is_instance_valid(_spawn_marker):
		_spawn_marker.queue_free()
	_spawn_marker = null


func _end_stun() -> void:
	_stun_left = 0.0
	_clear_dizzy()


func _clear_dizzy() -> void:
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null


func _draw() -> void:
	var w := _frame_size.x * 0.3
	var aura := elite and state == State.ACTIVE
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	if aura:
		# 精英的光環:身體後面一團脈動的橘紅色光(在角色圖之下,看起來像輪廓發光)。
		var body := Vector2(0, -_frame_size.y * 0.02) + _sprite_base_offset
		draw_set_transform(body, 0.0, Vector2(0.78, 1.0))
		draw_circle(Vector2.ZERO, _frame_size.y * 0.44 + pulse, Color(ELITE_AURA, 0.12 + 0.12 * pulse))
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	if aura:
		# 腳下一圈光,外面有一圈轉動的虛線。
		draw_circle(Vector2.ZERO, w + 4.0 + pulse, Color(ELITE_AURA, 0.3 + 0.15 * pulse))
		var dashes := 10
		for i in dashes:
			var a := _age * 1.6 + TAU * float(i) / float(dashes)
			draw_arc(Vector2.ZERO, w + 7.0 + pulse, a, a + 0.32, 3, Color(ELITE_SPARK, 0.7 + 0.3 * pulse), 2.0)
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	if aura:
		# 往上飄的火星。
		for i in 3:
			var phase := fmod(_age * 0.9 + float(i) / 3.0, 1.0)
			var x := sin(float(i) * 2.3 + _age * 2.0) * w * 0.9
			var y := _frame_size.y * 0.4 - phase * _frame_size.y * 0.9
			draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE), Color(ELITE_SPARK, 1.0 - phase))


# --- 給子類別覆寫 -----------------------------------------------------------------

func _on_ready() -> void:
	pass


## 子類別自己的計時(頭目的倒下演出)。傳回 true 表示這一格不跑一般的 AI 與移動。
func _tick_custom(_delta: float) -> bool:
	return false


func _on_activated() -> void:
	pass


func _ai(_delta: float) -> void:
	desired_velocity = Vector2.ZERO
	anim_state = &"idle"


func _cancel_attack() -> void:
	_clear_telegraph()


func _on_damaged(_amount: int) -> void:
	pass


func _on_healed(_amount: int) -> void:
	pass


func _on_died() -> void:
	_poof()


func _uses_separation() -> bool:
	return true


## 正在出招(預警中或揮擊中)。這時不會被擊退。
func _is_committed() -> bool:
	return false
