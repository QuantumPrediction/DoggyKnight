extends "res://tests/line_a/combat_test_base.gd"

var captain: CaptainBoss

func before_each() -> void:
	GameState.hero_class = &"knight"
	GameState.equipment = EquipmentInventory.defaults()
	GameState.meta_upgrades = {}
	GameState.chapter = 1
	GameState.level_index = 0
	GameState.difficulty = &"normal"
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(110, 180)
	captain = spawn(&"scarecrow_captain", Vector2(80, 180)) as CaptainBoss
	captain.set_physics_process(false)
	captain.target = player

func test_sweep_cannot_hit_a_body_fully_beyond_the_shown_warning() -> void:
	captain._start_sweep()
	var mark := captain._telegraph
	player.global_position = mark.global_position + mark.direction * (mark.radius + EnemyBase.radius_of(player) + 1.0)
	var vigor := GameState.vigor
	captain._sweep()
	assert_eq(GameState.vigor, vigor, "forward lunge must be included in the warning before impact")

func test_sweep_does_not_invent_an_unmarked_rear_contact_circle() -> void:
	captain._start_sweep()
	# Put the entire player body behind the actual impact point, outside the wedge.
	var impact := CombatMath.clamp_to_bounds(captain.global_position + captain._sweep_dir * captain.sweep_lunge, captain.arena_margin)
	player.global_position = impact - captain._sweep_dir * (EnemyBase.radius_of(player) + 2.0)
	var vigor := GameState.vigor
	captain._sweep()
	assert_eq(GameState.vigor, vigor, "dodging behind the entire warned shape is safe")

func test_sweep_checks_body_overlap_at_the_visible_side_edge() -> void:
	captain._start_sweep()
	var impact := CombatMath.clamp_to_bounds(captain.global_position + captain._sweep_dir * captain.sweep_lunge, captain.arena_margin)
	var edge := captain._sweep_dir.rotated(deg_to_rad(captain.sweep_half_angle_deg))
	player.global_position = impact + edge * 20.0 + edge.orthogonal() * (EnemyBase.radius_of(player) - 1.0)
	var vigor := GameState.vigor
	captain._sweep()
	assert_true(GameState.vigor < vigor, "a body still overlapping the visible wedge is hit")

func test_sweep_commits_direction_and_clamped_origin_before_player_moves() -> void:
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		captain.global_position = CombatMath.clamp_to_bounds(Vector2(90, 180) + direction * 100, captain.arena_margin)
		player.global_position = captain.global_position + direction * 30
		captain._start_sweep()
		var mark := captain._telegraph
		var shown := mark.global_position
		assert_eq(shown, CombatMath.clamp_to_bounds(captain.global_position + direction * captain.sweep_lunge, captain.arena_margin))
		# A chase-to-tell transition cannot leave a frame of old velocity.
		assert_eq(captain.desired_velocity, Vector2.ZERO)
		player.global_position = captain.global_position - direction * 20
		captain._sweep()
		assert_eq(captain.global_position, shown)
		assert_eq(captain._sweep_dir, direction, "no retarget after warning")

func test_sweep_is_cancelled_by_stun_and_cannot_resolve_twice() -> void:
	captain._start_sweep()
	var vigor := GameState.vigor
	captain.stun(1.0)
	captain._sweep()
	assert_eq(GameState.vigor, vigor)
	assert_null(captain._telegraph)
	captain._stun_left = 0
	captain._start_sweep()
	player.global_position = captain._telegraph.global_position + captain._sweep_dir * 20
	captain._sweep()
	assert_true(GameState.vigor < vigor)
	vigor = GameState.vigor
	player.invuln_left = 0
	captain._sweep()
	assert_eq(GameState.vigor, vigor, "one committed attack can hit only once")

func test_rally_respects_remaining_slots_and_warns_only_actual_summons() -> void:
	captain._start_rally()
	captain._rally()
	assert_eq(captain.alive_summons(), 3)
	for summon in captain._summons:
		summon.set_physics_process(false)
	captain._start_rally()
	assert_eq(captain._rally_marks.size(), 1, "only one of four slots remains")
	captain._rally()
	assert_eq(captain.alive_summons(), captain.max_summons_alive)
	captain._start_rally()
	assert_true(captain._rally_marks.is_empty(), "no fake summon warning at capacity")
	captain._rally()
	assert_eq(captain.alive_summons(), captain.max_summons_alive)

func test_rally_never_fills_newly_freed_slots_without_warning() -> void:
	captain._start_rally()
	captain._rally()
	captain._start_rally()
	assert_eq(captain._rally_marks.size(), 1)
	for summon in captain._summons:
		summon.remove_from_group(&"enemy")
	captain._rally()
	assert_eq(captain.alive_summons(), 1, "only the announced reinforcement arrives")
	captain._rally()
	assert_eq(captain.alive_summons(), 1, "duplicate release cannot summon twice")

func test_rally_rechecks_capacity_and_stun_cancels_pending_summons() -> void:
	captain._start_rally()
	for i in captain.max_summons_alive:
		captain._summons.append(spawn(&"scarecrow", Vector2(30 + i * 30, 130)))
	captain._rally()
	assert_eq(captain.alive_summons(), captain.max_summons_alive)
	for summon in captain._summons:
		summon.remove_from_group(&"enemy")
	captain._start_rally()
	captain.stun(1.0)
	captain._rally()
	assert_eq(captain.alive_summons(), 0)
	assert_true(captain._rally_marks.is_empty())

func test_regular_and_elite_soldiers_respect_the_warning_boundary() -> void:
	for id: StringName in [&"scarecrow", &"scarecrow_elite"]:
		var soldier := spawn(id, Vector2(70, 210)) as ScarecrowEnemy
		soldier.set_physics_process(false)
		soldier._start_telegraph(Vector2.RIGHT, false)
		var mark := soldier._telegraph
		player.global_position = mark.global_position + Vector2.RIGHT * (mark.radius + EnemyBase.radius_of(player) + 1)
		var vigor := GameState.vigor
		soldier._swing()
		assert_eq(GameState.vigor, vigor, "%s lunge stays inside its warning" % id)
		soldier._start_telegraph(Vector2.RIGHT, false)
		player.global_position = soldier._telegraph.global_position - Vector2.RIGHT * (EnemyBase.radius_of(player) + 2)
		soldier._swing()
		assert_eq(GameState.vigor, vigor, "%s rear dodge is safe" % id)
		soldier._start_telegraph(Vector2.RIGHT, false)
		player.global_position = soldier._telegraph.global_position + Vector2.RIGHT * 20
		soldier._swing()
		assert_true(GameState.vigor < vigor, "%s still hits inside the warning" % id)
		player.invuln_left = 0

func test_crowding_does_not_slide_a_committed_soldier_warning() -> void:
	var soldier := spawn(&"scarecrow", Vector2(70, 210)) as ScarecrowEnemy
	var neighbor := spawn(&"scarecrow", Vector2(90, 210)) as ScarecrowEnemy
	soldier.set_physics_process(false)
	neighbor.set_physics_process(false)
	neighbor.global_position = soldier.global_position + Vector2.LEFT * 4
	soldier._start_telegraph(Vector2.RIGHT, false)
	var shown := soldier._telegraph.global_position
	var start := soldier.global_position
	soldier._move(1.0 / 60.0)
	assert_eq(soldier.global_position, start)
	assert_eq(soldier._telegraph.global_position, shown)
	soldier.stun(1.0)
	assert_null(soldier._telegraph)
	var vigor := GameState.vigor
	soldier._swing()
	assert_eq(GameState.vigor, vigor, "cancelled attack cannot resolve later")

func test_on_hit_equipment_control_keeps_its_recovery_state() -> void:
	var soldier := spawn(&"scarecrow", Vector2(70, 210)) as ScarecrowEnemy
	soldier.set_physics_process(false)
	player.equipment_combat.effects["control"] = 1.0
	soldier._start_telegraph(Vector2.RIGHT, false)
	player.global_position = soldier._telegraph.global_position + Vector2.RIGHT * 8
	soldier._swing()
	assert_true(soldier._stun_left > 0, "the real equipment proc stuns the attacker")
	assert_eq(soldier.phase, ScarecrowEnemy.Phase.RECOVER, "attack resolution must not overwrite hit-triggered control")
	assert_null(soldier._telegraph)
	player.invuln_left = 0
	player.equipment_combat.control_left = 0
	player.global_position = captain.global_position + Vector2.RIGHT * 30
	captain._start_sweep()
	player.global_position = captain._telegraph.global_position + Vector2.RIGHT * 8
	captain._sweep()
	assert_true(captain._stun_left > 0)
	assert_eq(captain.phase, CaptainBoss.Phase.SWEEP_RECOVER, "the completed hit keeps normal recovery after the proc")
	assert_null(captain._telegraph)

func after_each() -> void:
	captain = null
	await super()
