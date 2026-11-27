extends SceneTree
## In a second process, reopen the exact profile that just closed the campaign credits.
## Usage: godot --headless --path . --script res://tests/integration/check_six_episode_save.gd

const SAVE := "user://six_episode_campaign.json"

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	if not FileAccess.file_exists(SAVE):
		printerr("Missing earned campaign save")
		quit(2)
		return
	var before := FileAccess.get_sha256(SAVE)
	root.size = Vector2i(360, 640)
	var game = load("res://game/flow/main.tscn").instantiate()
	game.save_path = SAVE
	game.use_stand_ins = false
	root.add_child(game)
	for frame in 90:
		await process_frame
	var title = game.get_screen()
	var profile: Dictionary = game.save_store.read()
	var after := FileAccess.get_sha256(SAVE)
	var result := {
		"chapter": int(profile.chapter), "chapters_cleared": int(profile.chapters_cleared),
		"departure": int(profile.get("chapter_departure", 0)), "class": String(profile.hero_class),
		"selected": int(title.chosen_chapter()), "chapter_6_locked": bool(title.is_chapter_locked(6)),
		"continue_visible": bool(title.continue_button.is_visible_in_tree()), "credits_open": game.get_credits() != null,
		"before_sha256": before, "after_sha256": after}
	var passed: bool = result.chapter == 6 and result.chapters_cleared == 6 and result.departure == 0 and result.selected == 6
	passed = passed and not result.chapter_6_locked and not result.continue_visible and not result.credits_open and before == after
	result["passed"] = passed
	print("SAVED_CAMPAIGN ", JSON.stringify(result))
	quit(0 if passed else 1)
