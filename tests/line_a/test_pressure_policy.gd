extends "res://tests/line_a/combat_test_base.gd"

const Visible = preload("res://tests/integration/visible_pressure.gd")
const Escape = preload("res://tests/integration/escape_policy.gd")

func test_visible_sector_uses_the_actual_transformed_warning() -> void:
	var mark := AttackTelegraph.make_sector(20.0, Vector2.RIGHT, PI / 4.0)
	add_child(mark)
	mark.position = Vector2(80, 160)
	mark.rotation = PI / 2.0
	assert_true(Visible.covers(mark, Vector2(80, 175), 2.0))
	assert_false(Visible.covers(mark, Vector2(95, 160), 2.0))
	assert_false(Visible.covers(mark, Vector2(80, 185), 2.0))

func test_hidden_warning_does_not_invent_visible_danger() -> void:
	var mark := AttackTelegraph.make_circle(20.0)
	add_child(mark)
	mark.hide()
	assert_false(Visible.warnings(get_tree()).has(mark))
	mark.show()
	assert_true(Visible.warnings(get_tree()).has(mark))

func test_escape_policy_keeps_a_wall_escape_inside_without_mutating_actors() -> void:
	GameState.reset_run()
	make_arena()
	player.set_physics_process(false)
	player.global_position = Vector2(17, 180)
	var enemy := spawn(&"scarecrow", Vector2(42, 180))
	enemy.set_physics_process(false)
	var old_position := enemy.global_position
	var old_hp := enemy.hp
	var old_rng := enemy.rng.state
	var chosen := Escape.choose(get_tree(), player.global_position, &"archer", 80.0, Vector2.ZERO)
	assert_true(Layout.ARENA_RECT.grow(-14.0).has_point(player.global_position + chosen * 18.0))
	assert_ne(chosen, Vector2.LEFT)
	assert_eq(enemy.global_position, old_position)
	assert_eq(enemy.hp, old_hp)
	assert_eq(enemy.rng.state, old_rng)
