class_name GoldiePlayer
extends CharacterBody2D
## 金毛騎士:A1 移動、A2 停下自動攻擊、A3 活力與受擊、A9 忠誠度與必殺技、A10 能力把戲。
##
## 合約(DEV_PLAN 4.4、4.9):
## - 根節點 CharacterBody2D,在群組 "player";take_damage(amount)、heal(amount)。
## - 數值每次都從 GameState.player_stats 讀(把戲會在關卡中改變它)。
## - 傷害 = attack_damage × (1 + GameState.next_level_bonus);受到的傷害 × damage_taken_mult。
## - 活力存在 GameState.vigor,每次改變發 vigor_changed;進場時也發一次。
## - 活力歸零:趴下睡覺(sleep 動畫 + 暈眩星星),只發一次 player_downed,之後不能操作。
## - 忠誠度:打中敵人累積,發 loyalty_changed;滿了且收到 ultimate_requested → 必殺技,發 ultimate_used。
## - 能力類把戲:進場時依 GameState.active_tricks 重建;關卡中聽 trick_chosen 多疊一層。
##
## M3 打磨(DEV_PLAN 第 15 節,數值在 data/player/feel_tuning.tres):
## - AP1 揮劍時鏡頭輕推向攻擊方向;受擊、必殺技時鏡頭震動(震動量累積)。
## - AP2 傷害數字(握手雙倍用大字 + crit 音效)、hit_burst 粒子。
## - AP3 跑步時 footstep_dust、身體前傾與上下彈;揮劍有拖尾,上下交替揮。
## - AP6 必殺技:畫面變暗、金毛舉劍、光柱、所有敵人停頓 → 斬下(ultimate_burst、大震動、heavy 震動)。
## - AP9 受擊 medium、必殺技 heavy 震動(Haptics)。
## - AP10 收到 level_completed 後停止攻擊,停下時歡呼(有 victory 動畫就用)。
## - 慢動作(打倒頭目時):動作跟著 CombatFx.time_scale 變慢。

const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"
const DEFAULT_TUNING: PlayerTuning = preload("res://data/player/goldie_tuning.tres")
const DEFAULT_ABILITY_TUNING: AbilityTuning = preload("res://data/player/ability_tuning.tres")
const SPIN_VISUAL_TIME := 0.3
const HOP_TIME := 0.18
const CHEER_HOP_TIME := 0.38
const POWER_TINT := Color(1.0, 0.85, 0.4)
const TRAIL_TINT := Color(1.0, 0.97, 0.85, 0.9)
const ULT_Z := 9                          ## 必殺技時金毛升到暗幕(8)之上

@export var tuning: PlayerTuning = DEFAULT_TUNING
@export var ability_tuning: AbilityTuning = DEFAULT_ABILITY_TUNING

var abilities: AbilitySet
var loyalty: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var invuln_left: float = 0.0             ## 剩餘無敵秒數(測試可直接設為 0)
var swing_count: int = 0                 ## 揮劍次數(含揮空)
var last_swing_damage: int = 0
var last_swing_hits: int = 0
var ultimate_count: int = 0
var celebrating: bool = false            ## 過關後歡呼中(不再攻擊)
var feel: FeelTuning

var sprite: AnimatedSprite2D
var joystick: TouchJoystick

var _downed: bool = false
var _override_active: bool = false
var _override_vector: Vector2 = Vector2.ZERO
var _attack_cooldown: float = 0.0
var _windup_left: float = -1.0
var _attack_target: Node2D
var _hitstop_left: float = 0.0
var _blink_left: float = 0.0
var _hurt_anim_left: float = 0.0
var _attack_anim_left: float = 0.0
var _footstep_timer: float = 0.0
var _spin_left: float = 0.0
var _hop_left: float = 0.0
var _dizzy: Node2D
var _frame_size: Vector2 = Vector2(24, 24)
var _arena_margin: Vector2 = Vector2(6, 6)
var _swing_down: bool = true
var _ult_left: float = -1.0
var _ult_overlay: ScreenTint
var _cheer_left: float = 0.0
var _cheer_count: int = 0
var _run_time: float = 0.0
var _last_pickup_haptic: float = -10.0


func _ready() -> void:
	sprite = $Sprite as AnimatedSprite2D
	joystick = get_node_or_null(^"JoystickLayer/Joystick") as TouchJoystick
	if feel == null:
		feel = CombatFx.feel()
	add_to_group(PLAYER_GROUP)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Layers.PLAYER
	collision_mask = Layers.ARENA
	_frame_size = _sprite_size()
	_arena_margin = CombatMath.sprite_margin(_frame_size, tuning.body_radius)
	if joystick != null:
		joystick.configure(tuning)
	abilities = AbilitySet.new(self, ability_tuning)
	abilities.rebuild(GameState.active_tricks)
	EventBus.trick_chosen.connect(_on_trick_chosen)
	EventBus.ultimate_requested.connect(_on_ultimate_requested)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.leveled_up.connect(_on_leveled_up)
	EventBus.exp_collected.connect(_on_exp_collected)
	_play(&"idle")
	if GameState.vigor > GameState.player_stats.max_vigor:
		GameState.vigor = GameState.player_stats.max_vigor
	_emit_vigor()
	_emit_loyalty()


func _physics_process(delta: float) -> void:
	if _downed:
		velocity = Vector2.ZERO
		return
	var ts := CombatFx.time_scale
	delta *= ts
	_tick_feedback(delta)
	if _ult_left >= 0.0:
		_tick_ultimate(delta)
		return
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		if _hitstop_left <= 0.0:
			sprite.speed_scale = ts
		return
	sprite.speed_scale = ts
	var stats := GameState.player_stats
	var input := get_move_input()
	var target_velocity := input * stats.move_speed
	var ramp_time := tuning.accel_time if input != Vector2.ZERO else tuning.decel_time
	var rate := stats.move_speed / maxf(ramp_time, 0.001)
	velocity = velocity.move_toward(target_velocity, rate * delta)
	var real_velocity := velocity
	velocity *= ts
	move_and_slide()
	velocity = real_velocity
	global_position = CombatMath.clamp_to_bounds(global_position, _arena_margin)
	var moving := input != Vector2.ZERO
	if moving:
		facing = input
	_update_attack(delta, moving)
	abilities.update(delta)
	_update_visuals(delta)


# --- 合約方法 ------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if _downed or amount <= 0 or invuln_left > 0.0:
		return
	var final := CombatMath.damage_taken(amount, GameState.player_stats)
	GameState.vigor = maxi(0, GameState.vigor - final)
	EventBus.player_damaged.emit(final)
	_emit_vigor()
	Sfx.play(&"hurt")
	CombatFx.spawn(self, &"hit_spark", global_position + Vector2(0, -_frame_size.y * 0.4), 0.0,
			Vector2.ONE, Color(1.0, 0.95, 0.55))
	# 可愛的受擊:頭上冒小星星、鏡頭震一下、手機 medium 震動(狗不會受傷)。
	CombatFx.particles(self, &"star_burst", global_position + Vector2(0, -_frame_size.y * 0.5))
	CombatFx.trauma(self, feel.trauma_player_hit)
	CombatFx.haptic(feel.haptic_player_hit)
	if GameState.vigor <= 0:
		_go_down()
		return
	invuln_left = tuning.invuln_time
	_blink_left = tuning.invuln_time
	_hurt_anim_left = tuning.hurt_anim_time
	_cancel_windup()


func heal(amount: int) -> void:
	if amount <= 0 or _downed:
		return
	GameState.vigor = mini(GameState.player_stats.max_vigor, GameState.vigor + amount)
	_emit_vigor()


func is_downed() -> bool:
	return _downed


## 叫醒睡著的金毛(給流程或沙盒用;一般重試是重新建立場地)。活力為 0 時回到上限。
func revive() -> void:
	if not _downed:
		return
	_downed = false
	if _dizzy != null and is_instance_valid(_dizzy):
		_dizzy.queue_free()
	_dizzy = null
	if joystick != null:
		joystick.enabled = true
	if GameState.vigor <= 0:
		GameState.vigor = GameState.player_stats.max_vigor
	invuln_left = tuning.invuln_time
	_blink_left = tuning.invuln_time
	_play(&"idle")
	_emit_vigor()


# --- 移動輸入 ------------------------------------------------------------------

## 目前的移動方向(長度 0 或 1)。
func get_move_input() -> Vector2:
	if _override_active:
		return _override_vector
	return joystick.get_vector() if joystick != null else Vector2.ZERO


## 測試與自動試玩用:用程式代替搖桿。
func set_move_override(direction: Vector2) -> void:
	_override_active = true
	_override_vector = direction.normalized() if direction.length() > 0.001 else Vector2.ZERO


func clear_move_override() -> void:
	_override_active = false
	_override_vector = Vector2.ZERO


# --- 自動攻擊(A2) --------------------------------------------------------------

func _update_attack(delta: float, moving: bool) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if moving:
		if _windup_left >= 0.0:
			_cancel_windup()
		return
	if _windup_left >= 0.0:
		_windup_left -= delta
		if _is_valid_target(_attack_target):
			_face_toward(_attack_target.global_position)
		if _windup_left <= 0.0:
			_swing()
		return
	if _attack_cooldown <= 0.0 and not celebrating and _has_enemies():
		_start_windup()


func _start_windup() -> void:
	var stats := GameState.player_stats
	_attack_target = _nearest_enemy(stats.attack_range * tuning.target_search_mult)
	if _attack_target != null:
		_face_toward(_attack_target.global_position)
	_windup_left = tuning.attack_windup
	_play(&"attack", true)
	sprite.pause()
	# 蓄力:身體壓扁、往後縮一點。
	sprite.scale = Vector2(1.12, 0.88)
	sprite.position = -facing.normalized()


func _cancel_windup() -> void:
	if _windup_left < 0.0:
		return
	_windup_left = -1.0
	_attack_target = null
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	_play(&"idle")


func _swing() -> void:
	_windup_left = -1.0
	var stats := GameState.player_stats
	if _is_valid_target(_attack_target):
		_face_toward(_attack_target.global_position)
	_attack_target = null
	var half_angle := deg_to_rad(tuning.attack_arc_degrees) * 0.5
	var hits := _enemies_in_sector(stats.attack_range, half_angle)
	var mult := abilities.on_swing_landed() if not hits.is_empty() else 1.0
	var damage := CombatMath.player_damage(stats, GameState.next_level_bonus, mult)
	swing_count += 1
	last_swing_hits = hits.size()
	last_swing_damage = damage if not hits.is_empty() else 0
	_attack_cooldown = maxf(0.0, stats.attack_interval - tuning.attack_windup)

	# 揮劍:身體拉長、往前衝一點,弧光朝目標;上下交替揮,有拖尾;鏡頭輕推向攻擊方向。
	sprite.scale = Vector2(0.9, 1.1)
	sprite.position = facing.normalized() * 2.0
	sprite.play(&"attack")
	_attack_anim_left = tuning.attack_anim_time
	var power := mult > 1.0
	_swing_down = not _swing_down
	var slash := CombatFx.spawn(self, &"slash", global_position + facing.normalized() * 10.0, facing.angle(),
			Vector2.ONE * (1.35 if power else 1.0), POWER_TINT if power else Color.WHITE)
	if slash != null:
		# 預設圖是一個方向的弧光(朝左時鏡像);每一下反過來一次,看起來是上下交替揮。
		slash.flip_v = (facing.x < 0.0) != _swing_down
	_spawn_trail(stats.attack_range, power)
	CombatFx.nudge(self, facing, feel.swing_nudge * (1.6 if power else 1.0))
	if power:
		CombatFx.sfx(&"whoosh", &"swing")
	else:
		Sfx.play(&"swing")
	if hits.is_empty():
		return
	if power:
		CombatFx.sfx(&"crit", &"hit")
	else:
		Sfx.play(&"hit")
	var style := DamageNumber.Style.CRIT if power else DamageNumber.Style.NORMAL
	var stop := tuning.hitstop_time * (1.6 if power else 1.0)
	var bursts := 0
	for enemy in hits:
		_strike(enemy, damage, tuning.knockback_speed, style, bursts < feel.hit_bursts_per_swing)
		bursts += 1
		if enemy.has_method(&"apply_hitstop"):
			enemy.call(&"apply_hitstop", stop)
	add_loyalty(tuning.loyalty_per_hit * hits.size())
	_hitstop_left = stop
	sprite.speed_scale = 0.0
	if power:
		CombatFx.trauma(self, feel.trauma_player_hit * 0.6)


func _spawn_trail(attack_range: float, power: bool) -> void:
	if not is_inside_tree():
		return
	var trail := SwingTrail.new()
	trail.facing_angle = facing.angle()
	trail.arc = deg_to_rad(tuning.attack_arc_degrees)
	trail.inner_radius = 6.0
	trail.outer_radius = attack_range * (1.05 if power else 0.92)
	# 畫面上「由上往下」:朝右時角度增加(順時針),朝左時鏡像。
	trail.clockwise = _swing_down == (facing.x >= 0.0)
	trail.color = POWER_TINT if power else TRAIL_TINT
	trail.sweep_time = feel.trail_time
	trail.fade_time = feel.trail_fade_time
	CombatFx.layer_for(self).add_child(trail)
	trail.global_position = global_position + Vector2(0, -2)


func _strike(enemy: Node2D, damage: int, knockback: float,
		style: DamageNumber.Style = DamageNumber.Style.NORMAL, burst: bool = true) -> void:
	var spark_at := enemy.global_position.lerp(global_position, 0.35)
	if enemy.has_method(&"hit"):
		enemy.call(&"hit", damage, global_position, knockback, style)
	else:
		enemy.call(&"take_damage", damage)
	CombatFx.spawn(self, &"hit_spark", spark_at, randf() * TAU)
	if burst:
		CombatFx.particles(self, &"hit_burst", spark_at)
		if style == DamageNumber.Style.CRIT:
			CombatFx.particles(self, &"star_burst", spark_at)


# --- 忠誠度與必殺技(A9、AP6) ----------------------------------------------------

func add_loyalty(amount: float) -> void:
	if _downed or amount <= 0.0:
		return
	var before := loyalty
	loyalty = minf(tuning.loyalty_max, loyalty + amount)
	if loyalty != before:
		_emit_loyalty()


func can_use_ultimate() -> bool:
	return not _downed and _ult_left < 0.0 and loyalty >= tuning.loyalty_max


## 王者之劍:以金毛為中心的大範圍斬擊。忠誠度未滿時不做任何事,傳回 false。
## 演出(AP6):按下的一刻忠誠度歸零、發 ultimate_used;畫面變暗、金毛舉劍、天上降下光柱,
## 所有敵人停住;ultimate_windup 秒後斬下(ultimate_burst、大震動、heavy 震動),
## 範圍內的敵人受到攻擊力 × ultimate_damage_mult 的傷害。整段時間金毛無敵、不能移動。
func use_ultimate() -> bool:
	if not can_use_ultimate():
		return false
	loyalty = 0.0
	ultimate_count += 1
	_cancel_windup()
	_hitstop_left = 0.0
	velocity = Vector2.ZERO
	var windup := maxf(0.0, feel.ultimate_windup)
	invuln_left = maxf(invuln_left, windup + tuning.ultimate_invuln_time)
	# 所有敵人停頓(包括範圍外的),斬下之後再多停一下。
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if node.has_method(&"apply_hitstop"):
			node.call(&"apply_hitstop", windup + feel.ultimate_freeze_after)
	_ult_overlay = CombatFx.tint(self, Color(0.03, 0.0, 0.1, feel.ultimate_dark_alpha),
			maxf(feel.ultimate_dark_time, windup + 0.2), 0.08, 0.35, ULT_Z - 1)
	if _ult_overlay != null:
		_ult_overlay.pillar = true
		_ult_overlay.pillar_at = global_position
		_ult_overlay.pillar_width = feel.ultimate_pillar_width
	z_index = ULT_Z
	# 舉劍:停在攻擊動畫的第一格,身體拉高。
	_play(&"attack", true)
	sprite.pause()
	sprite.scale = Vector2(0.85, 1.2)
	sprite.position = Vector2(0, -2)
	CombatFx.sfx(&"whoosh", &"swing")
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.5), false, true)
	_ult_left = windup
	_emit_loyalty()
	EventBus.ultimate_used.emit()
	if windup <= 0.0:
		_ultimate_strike()
	return true


## 必殺技還在蓄力(舉劍)中。
func is_ultimate_charging() -> bool:
	return _ult_left >= 0.0


func _tick_ultimate(delta: float) -> void:
	velocity = Vector2.ZERO
	_ult_left -= delta
	# 蓄力時越舉越高、微微發抖。
	var t := 1.0 - clampf(_ult_left / maxf(feel.ultimate_windup, 0.001), 0.0, 1.0)
	sprite.position = Vector2(roundf(sin(t * 60.0) * 0.5), -2.0 - roundf(2.0 * t))
	if _ult_left < 0.0:
		_ultimate_strike()


func _ultimate_strike() -> void:
	_ult_left = -1.0
	var damage := CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus,
			tuning.ultimate_damage_mult)
	var targets := _enemies_in_radius(tuning.ultimate_radius)
	Sfx.play(&"ultimate")
	CombatFx.haptic(feel.haptic_ultimate)
	CombatFx.trauma(self, feel.trauma_ultimate)
	var size := tuning.ultimate_radius * 2.0
	var fx_frames := CombatFx.frames(&"ultimate_slash")
	var fx_scale := 2.5
	if fx_frames != null and fx_frames.get_frame_count(&"default") > 0:
		fx_scale = size / maxf(1.0, fx_frames.get_frame_texture(&"default", 0).get_width())
	CombatFx.spawn(self, &"ultimate_slash", global_position, 0.0, Vector2.ONE * fx_scale)
	CombatFx.ring(self, global_position, 8.0, tuning.ultimate_radius, 0.4, Color(1.0, 0.86, 0.35, 0.95), 3.0)
	# 白色閃光與爆發的光點放在暗幕之上、金毛之下,不會蓋住金毛。
	var overlay_ok := _ult_overlay != null and is_instance_valid(_ult_overlay) and _ult_overlay.is_inside_tree()
	var flash := CombatFx.ring(self, global_position, 4.0, tuning.ultimate_radius * 0.8, 0.18, Color(1, 1, 1, 0.5), 1.0, false, true)
	if flash != null and overlay_ok:
		flash.reparent(_ult_overlay)
		flash.z_index = 0
	CombatFx.particles(self, &"ultimate_burst", global_position, not overlay_ok, true,
			_ult_overlay if overlay_ok else null)
	sprite.play()
	sprite.scale = Vector2(1.2, 0.85)
	sprite.position = Vector2.ZERO
	_play(&"attack", true)
	_attack_anim_left = 0.35
	var bursts := 0
	for enemy in targets:
		_strike(enemy, damage, tuning.ultimate_knockback_speed, DamageNumber.Style.ULTIMATE,
				bursts < feel.hit_bursts_per_swing)
		bursts += 1
		if enemy.has_method(&"apply_hitstop"):
			enemy.call(&"apply_hitstop", maxf(tuning.ultimate_hitstop_time, feel.ultimate_freeze_after))
	z_index = 0


func _on_ultimate_requested() -> void:
	use_ultimate()


# --- 能力把戲的宿主方法(A10,見 trick_ability.gd) ----------------------------------

func ability_targets(radius: float) -> Array[Node2D]:
	return _enemies_in_radius(radius)


func ability_base_damage(multiplier: float) -> int:
	return CombatMath.player_damage(GameState.player_stats, GameState.next_level_bonus, multiplier)


func ability_hit(target: Node2D, damage: int, knockback: float) -> void:
	if not _is_valid_target(target):
		return
	_strike(target, damage, knockback)
	add_loyalty(tuning.loyalty_per_hit)


func ability_stun(target: Node2D, duration: float) -> void:
	if _is_valid_target(target) and target.has_method(&"stun"):
		target.call(&"stun", duration)


func ability_visual(kind: StringName, radius: float) -> void:
	match kind:
		&"spin":
			_spin_left = SPIN_VISUAL_TIME
			CombatFx.ring(self, global_position, 6.0, radius, 0.25, Color(1, 1, 1, 0.9), 2.0)
			for i in 4:
				var dir := Vector2.from_angle(TAU * float(i) / 4.0 + PI / 4.0)
				CombatFx.spawn(self, &"slash", global_position + dir * radius * 0.6, dir.angle() + PI / 2.0)
			CombatFx.sfx(&"whoosh", &"swing")
		&"bark":
			_hop_left = HOP_TIME
			CombatFx.ring(self, global_position, 4.0, radius, 0.35, Color(1.0, 0.92, 0.45, 0.9), 2.0)
			CombatFx.ring(self, global_position, 2.0, radius * 0.6, 0.25, Color(1.0, 0.92, 0.45, 0.7), 1.0)


func _on_trick_chosen(trick_id: StringName) -> void:
	if abilities.add_trick(trick_id):
		CombatFx.ring(self, global_position, 2.0, 16.0, 0.3, Color(1.0, 0.95, 0.6, 0.9), 1.0)


# --- 慶祝與回饋 -------------------------------------------------------------------

## 過關(AP10):不再攻擊;停下時歡呼。
func celebrate() -> void:
	if _downed or celebrating:
		return
	celebrating = true
	_cancel_windup()
	_cheer_left = 0.0
	_cheer_count = 0
	CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6), false, true)


## 連擊里程碑(由 ComboTracker 呼叫):金毛身邊閃一下。
func celebrate_combo(_count: int) -> void:
	CombatFx.particles(self, &"sparkle", global_position + Vector2(0, -_frame_size.y * 0.3), false, true)
	CombatFx.ring(self, global_position, 4.0, 20.0, 0.3, Color(1.0, 0.92, 0.5, 0.8), 1.0)


func _on_level_completed(_level_id: StringName) -> void:
	celebrate()


func _on_leveled_up(_new_level: int) -> void:
	if not is_inside_tree() or _downed:
		return
	# 升級時腳下升起光柱。升級後流程會暫停遊戲讓玩家選把戲,這個特效在暫停時也繼續播。
	var fx := CombatFx.particles(self, &"level_up_pillar", global_position + Vector2(0, _frame_size.y * 0.4), false, true)
	if fx != null:
		fx.process_mode = Node.PROCESS_MODE_ALWAYS


func _on_exp_collected(_amount: int) -> void:
	# 拾取經驗珠:輕震動,但有最短間隔,不會一直嗡嗡響。
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_pickup_haptic >= feel.pickup_haptic_interval:
		_last_pickup_haptic = now
		CombatFx.haptic(feel.haptic_pickup)


# --- 找敵人 ---------------------------------------------------------------------

func _has_enemies() -> bool:
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if _is_valid_target(node as Node2D):
			return true
	return false


func _nearest_enemy(max_distance: float) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_target(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position) - _radius_of(enemy)
		if d <= max_distance and d < best_distance:
			best = enemy
			best_distance = d
	return best


func _enemies_in_radius(radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if _is_valid_target(enemy) and global_position.distance_to(enemy.global_position) - _radius_of(enemy) <= radius:
			result.append(enemy)
	return result


func _enemies_in_sector(attack_range: float, half_angle: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var dir := facing.normalized()
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if not _is_valid_target(enemy):
			continue
		var r := _radius_of(enemy)
		if CombatMath.in_sector(global_position, dir, enemy.global_position, attack_range + r, half_angle,
				tuning.close_hit_distance + r):
			result.append(enemy)
	return result


func _is_valid_target(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if not enemy.is_in_group(ENEMY_GROUP):
		return false
	return not enemy.has_method(&"is_targetable") or bool(enemy.call(&"is_targetable"))


static func _radius_of(node: Node) -> float:
	var r: Variant = node.get(&"body_radius")
	return float(r) if r != null else 6.0


func _face_toward(point: Vector2) -> void:
	var dir := point - global_position
	if dir.length() > 0.5:
		facing = dir.normalized()


# --- 表現 -----------------------------------------------------------------------

func _tick_feedback(delta: float) -> void:
	if invuln_left > 0.0:
		invuln_left = maxf(0.0, invuln_left - delta)
	if _blink_left > 0.0:
		_blink_left = maxf(0.0, _blink_left - delta)
		sprite.visible = _blink_left <= 0.0 or int(_blink_left / tuning.blink_interval) % 2 == 0
	elif not sprite.visible:
		sprite.visible = true


func _update_visuals(delta: float) -> void:
	_hurt_anim_left = maxf(0.0, _hurt_anim_left - delta)
	_attack_anim_left = maxf(0.0, _attack_anim_left - delta)
	if absf(facing.x) > 0.05:
		sprite.flip_h = facing.x < 0.0
	var running := velocity.length() > 4.0 and _hurt_anim_left <= 0.0 and _windup_left < 0.0 and _attack_anim_left <= 0.0
	# 蓄力時維持壓扁的姿勢,其他時候慢慢回復原狀。
	if _windup_left < 0.0:
		sprite.scale = sprite.scale.move_toward(Vector2.ONE, delta * 2.5)
		var offset := Vector2.ZERO
		if _hop_left > 0.0:
			_hop_left = maxf(0.0, _hop_left - delta)
			offset = Vector2(0, -3.0 * sin(PI * _hop_left / HOP_TIME))
		elif running:
			# 跑步時上下彈。
			_run_time += delta
			offset = Vector2(0, -roundf(absf(sin(_run_time * 12.0)) * feel.run_bob))
		if _hop_left > 0.0 or running:
			sprite.position = offset
		else:
			sprite.position = sprite.position.move_toward(offset, delta * 30.0)
	# 跑步時身體往前傾(斜切,像素圖不會變糊)。
	var lean := 0.0
	if running:
		lean = -feel.run_lean * signf(facing.x) if absf(facing.x) > 0.05 else 0.0
	sprite.skew = move_toward(sprite.skew, lean, delta * 3.0)
	if _spin_left > 0.0:
		_spin_left = maxf(0.0, _spin_left - delta)
		sprite.rotation = TAU * (1.0 - _spin_left / SPIN_VISUAL_TIME) * (-1.0 if sprite.flip_h else 1.0)
	elif sprite.rotation != 0.0:
		sprite.rotation = 0.0

	if _hurt_anim_left > 0.0:
		_play(&"hurt")
	elif _windup_left >= 0.0 or _attack_anim_left > 0.0:
		pass
	elif running:
		_play(&"run")
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = tuning.footstep_interval
			CombatFx.particles(self, &"footstep_dust", global_position + Vector2(-facing.x * 3.0, _frame_size.y * 0.4), true)
	elif celebrating:
		_cheer(delta)
	else:
		_run_time = 0.0
		_play(&"idle")


## 歡呼:有 victory 動畫就播;沒有的話原地跳一跳(每跳兩下停一下),偶爾冒愛心。
func _cheer(delta: float) -> void:
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(&"victory"):
		_play(&"victory")
		return
	_play(&"idle")
	_cheer_left -= delta
	if _cheer_left <= 0.0:
		_cheer_count += 1
		_cheer_left = CHEER_HOP_TIME * (1.0 if _cheer_count % 3 != 0 else 2.2)
		if _cheer_count % 3 != 0:
			_hop_left = HOP_TIME * 1.3
			sprite.scale = Vector2(0.9, 1.12)
			if _cheer_count % 3 == 1:
				CombatFx.particles(self, &"heart", global_position + Vector2(0, -_frame_size.y * 0.6))


func _go_down() -> void:
	_downed = true
	invuln_left = 0.0
	_blink_left = 0.0
	_windup_left = -1.0
	_ult_left = -1.0
	_hitstop_left = 0.0
	z_index = 0
	velocity = Vector2.ZERO
	sprite.visible = true
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.skew = 0.0
	sprite.speed_scale = 1.0
	if joystick != null:
		joystick.enabled = false
	_play(&"sleep")
	_dizzy = CombatFx.attach(self, &"dizzy_stars", Vector2(0, -_frame_size.y * 0.55))
	EventBus.player_downed.emit()


func _play(anim: StringName, restart: bool = false) -> void:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if sprite.animation != anim or restart:
		sprite.play(anim)
		if restart:
			sprite.set_frame_and_progress(0, 0.0)
	elif not sprite.is_playing() and frames.get_animation_loop(anim):
		sprite.play(anim)


func _sprite_size() -> Vector2:
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		return frames.get_frame_texture(&"idle", 0).get_size()
	return Vector2(24, 24)


func _emit_vigor() -> void:
	EventBus.vigor_changed.emit(GameState.vigor, GameState.player_stats.max_vigor)


func _emit_loyalty() -> void:
	EventBus.loyalty_changed.emit(loyalty, tuning.loyalty_max)


func _draw() -> void:
	# 腳下的影子,讓位置一眼看得清楚。
	var w := _frame_size.x * 0.32
	draw_set_transform(Vector2(0, _frame_size.y * 0.42), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
