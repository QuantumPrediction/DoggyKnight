extends Node
## A 線的頭目量度工具(v2.6,不是測試):金毛(加上該章的同伴)和每個頭目單挑,
## 用簡單的「看到預警就走出去」操作,量打倒頭目要多久、受到多少傷害。
## 用來比較各章頭目的相對難度(章倍率、每關遞增都照故事模式套用);金毛用第 1 級的數值,
## 所以時間比正式關卡長(正式關卡打到頭目時已經升級、有把戲)。
##
## 執行(headless,約 1 至 2 分鐘):
##   godot --headless --path . res://tests/line_a/tools/boss_duel.tscn -- --hard --speed=4 --power=1.6
## --power:金毛攻擊力倍數(模擬打到頭目時的等級與把戲,預設 1.6)。
## --from=N:只量第 N 章以後的頭目(例如 --from=4)。

const ARENA_SCENE: PackedScene = preload("res://game/combat/arena.tscn")
const TIMEOUT_SEC := 240.0

## [頭目, 章, 關卡編號(0 起算), 同伴, (選用)同時出場的第二個頭目]
## v2.7:加上第四至六章(雙龍一起出場;莫德雷德第一戰逃走就算結束)。
const DUELS: Array = [
	[&"scarecrow_captain", 1, 3, [&"bulldog"]],
	[&"black_knight", 1, 5, [&"bulldog"]],
	[&"gargoyle_elite", 2, 3, [&"bulldog", &"lancelot"]],
	[&"green_knight", 2, 5, [&"bulldog", &"lancelot"]],
	[&"phantom_knight", 3, 3, [&"bulldog", &"lancelot"]],
	[&"morgana", 3, 5, [&"bulldog", &"lancelot"]],
	[&"crab_elite", 4, 3, [&"bulldog", &"tristan"]],
	[&"kraken", 4, 5, [&"bulldog", &"tristan"]],
	[&"snowman_elite", 5, 3, [&"lancelot", &"gawain"]],
	[&"red_dragon", 5, 5, [&"lancelot", &"gawain"], &"white_dragon"],
	[&"mordred_duel", 6, 3, [&"bulldog", &"lancelot"]],
	[&"mordred", 6, 5, [&"bulldog", &"lancelot", &"tristan", &"gawain"]],
]

var speed: float = 4.0
var power: float = 1.6
var hard: bool = false
var from_chapter: int = 1
var _damage: int = 0
var _downs: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--hard":
			hard = true
		elif arg.begins_with("--speed="):
			speed = float(arg.get_slice("=", 1))
		elif arg.begins_with("--power="):
			power = float(arg.get_slice("=", 1))
		elif arg.begins_with("--from="):
			from_chapter = int(arg.get_slice("=", 1))
	EventBus.player_damaged.connect(func(amount: int) -> void: _damage += amount)
	EventBus.player_downed.connect(func() -> void: _downs += 1)
	_run.call_deferred()


func _run() -> void:
	var lines: PackedStringArray = []
	for duel: Array in DUELS:
		if int(duel[1]) < from_chapter:
			continue
		lines.append(await _duel(duel[0], duel[1], duel[2], duel[3], duel[4] if duel.size() > 4 else &""))
	Engine.time_scale = 1.0
	print("\n== 頭目量度(%s,金毛攻擊力 ×%.1f) ==" % ["困難" if hard else "一般", power])
	for line in lines:
		print(line)
	get_tree().quit(0)


func _duel(boss_id: StringName, chapter: int, level_index: int, companions: Array, second_id: StringName = &"") -> String:
	GameState.reset_run()
	GameState.mode = &"story"
	GameState.difficulty = &"hard" if hard else &"normal"
	GameState.chapter = chapter
	GameState.level_index = level_index
	GameState.player_stats.attack_damage = roundi(float(GameState.player_stats.attack_damage) * power)
	var arena := ARENA_SCENE.instantiate() as CombatArena
	add_child(arena)
	for id: StringName in companions:
		arena.spawn_companion(id)
	var top := Layout.ARENA_RECT.position.y + 50
	var bosses: Array = []
	if second_id == &"":
		bosses.append(arena.spawn_enemy(boss_id, Vector2(Layout.ARENA_RECT.get_center().x, top)) as BossBase)
	else:
		bosses.append(arena.spawn_enemy(boss_id, Vector2(Layout.ARENA_RECT.position.x + 40, top)) as BossBase)
		bosses.append(arena.spawn_enemy(second_id, Vector2(Layout.ARENA_RECT.end.x - 40, top)) as BossBase)
	var player := arena.get_player() as GoldiePlayer
	_damage = 0
	_downs = 0
	var max_hp := 0
	for b: Variant in bosses:
		max_hp += (b as BossBase).max_hp
	Engine.time_scale = speed
	var clock := 0.0
	var alive := func() -> bool:
		for b: Variant in bosses:
			if is_instance_valid(b) and (b as Node).is_in_group(&"enemy"):
				return true
		return false
	while clock < TIMEOUT_SEC and alive.call():
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		if player.is_downed():
			player.revive()
		_steer(arena, player)
	Engine.time_scale = 1.0
	var won := not alive.call()
	remove_child(arena)
	arena.queue_free()
	await get_tree().process_frame
	return "%-18s 第%d章 第%d關  生命 %4d  %s %5.1f 秒  受傷 %4d  倒下 %d" % [boss_id, chapter, level_index + 1,
			max_hp, "打倒" if won else "逾時", clock, _damage, _downs]


## 看到預警就走出去;沒有危險時走向最近的敵人(停下就會自動揮劍)。
func _steer(arena: CombatArena, player: GoldiePlayer) -> void:
	var me := player.global_position
	var escape := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"combat_fx"):
		if node is AttackTelegraph and is_instance_valid(node):
			escape += _escape_from(node as AttackTelegraph, me)
		elif node is MoonBeam:
			var beam := node as MoonBeam
			var a := beam.global_position
			var b := a + beam.direction * beam.length
			if EnemyProjectile.segment_distance(a, b, me) < beam.width + 14.0:
				escape += beam.direction.orthogonal() * signf(beam.direction.orthogonal().dot(me - a) + 0.01)
	for node in arena.get_projectiles():
		var p := node as EnemyProjectile
		if p == null or not p.is_flying():
			continue
		var to_me := me - p.global_position
		if to_me.length() < 40.0 and to_me.dot(p.direction) > 0.0:
			var side := p.direction.orthogonal()
			escape += side * signf(side.dot(to_me) + 0.01)
	var direction := Vector2.ZERO
	if escape.length() > 0.01:
		direction = escape.normalized()
		if not Layout.ARENA_RECT.grow(-14.0).has_point(me + direction * 14.0):
			direction = (direction + (Layout.ARENA_RECT.get_center() - me).normalized()).normalized()
	else:
		var nearest: Node2D = null
		var best := INF
		for node in arena.get_enemies():
			var enemy := node as Node2D
			if enemy == null or not (not enemy.has_method(&"is_targetable") or bool(enemy.call(&"is_targetable"))):
				continue
			var d := enemy.global_position.distance_to(me)
			if d < best:
				best = d
				nearest = enemy
		if nearest != null and best > 24.0:
			direction = (nearest.global_position - me).normalized()
	player.set_move_override(direction)


## 站在預警範圍內(加一點餘裕)時,走出去的方向;不在範圍內傳回 0。
func _escape_from(t: AttackTelegraph, me: Vector2) -> Vector2:
	if t.color == AttackTelegraph.MAGIC or t.color == AttackTelegraph.DUST:
		return Vector2.ZERO
	var origin := t.global_position
	var margin := 9.0
	match t.shape:
		AttackTelegraph.Shape.CIRCLE:
			var off := me - origin
			if off.length() < t.radius + margin:
				return off.normalized() if off.length() > 0.1 else Vector2.RIGHT
		AttackTelegraph.Shape.LINE:
			var end := origin + t.direction * t.length
			if EnemyProjectile.segment_distance(origin, end, me) < t.width * 0.5 + margin:
				var side := t.direction.orthogonal()
				return side * signf(side.dot(me - origin) + 0.01)
		AttackTelegraph.Shape.SECTOR:
			if CombatMath.in_sector(origin, t.direction, me, t.radius + margin, t.half_angle, margin):
				var off := me - origin
				var side := t.direction.orthogonal() * signf(t.direction.orthogonal().dot(off) + 0.01)
				return (off.normalized() + side).normalized()
	return Vector2.ZERO
