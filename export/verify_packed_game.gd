extends SceneTree
## Run outside the source project with --main-pack pointing to the exported game.
## Validates the delivered pack with the matching Godot engine on the build host.
## Browser and native rendering are exercised separately.

func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var source := ConfigFile.new()
	var settings_path: String = get_script().resource_path.get_base_dir().get_base_dir().path_join("project.godot")
	if source.load(settings_path) != OK or ProjectSettings.get_setting("application/config/version") != source.get_value("application", "config/version"):
		push_error("Unexpected packed game version")
		quit(1)
		return
	for path: String in ["res://ui/hints/guard_coach.gd", "res://assets/illustrated/combat/guard_lesson_atlas.png", "res://game/equipment/equipment_inventory.gd"]:
		if load(path) == null:
			push_error("Missing current production feature: " + path)
			quit(1)
			return
	if load("res://game/combat/arena.tscn") == null:
		push_error("Missing production arena")
		quit(1)
		return
	var checked: int = 0
	for chapter: int in range(1, 7):
		var episode: Resource = load("res://data/levels/chapter_%d.tres" % chapter)
		if episode == null or episode.level_count() != 6 or episode.prologue == null or episode.teaser == null:
			push_error("Incomplete story chapter %d" % chapter)
			quit(1)
			return
		for level: int in range(1, 7):
			var resource: Resource = load("res://data/levels/level_%d_%d.tres" % [chapter, level])
			if resource == null or resource.get("background") == null or resource.story_before == null or resource.story_after == null or episode.get_level(level - 1) != resource:
				push_error("Missing level or background %d-%d" % [chapter, level])
				quit(1)
				return
			if chapter == 1 and level <= 2:
				var reserve_count := 0
				for wave in resource.get("waves"):
					for entry in wave.reinforcements:
						if entry.pattern == &"line_top":
							reserve_count += int(entry.count)
				if reserve_count != 4:
					push_error("Missing opening reinforcement groups")
					quit(1)
					return
			checked += 1
	for companion: String in ["bulldog", "lancelot", "tristan", "gawain", "shield_echo"]:
		var resource: Resource = load("res://data/companions/%s.tres" % companion)
		if resource == null or resource.get("scene") == null:
			push_error("Missing companion " + companion)
			quit(1)
			return
	var ending: Resource = load("res://data/story/c6_teaser.tres")
	var painting: Texture2D = load("res://assets/story/round_table_homecoming.webp")
	TranslationServer.set_locale("zh_TW")
	if tr("STORY_C6_TEASER_02") != "《黃金騎士》全劇終。謝謝你和金毛一起走到這裡。" or tr("UI_CAMPAIGN_REST") != "回標題":
		push_error("Missing final campaign translations")
		quit(1)
		return
	if painting == null or ending.lines.size() != 2 or ending.lines[0].illustration != painting or ending.lines[1].illustration != painting:
		push_error("Missing final illustrated homecoming")
		quit(1)
		return
	var art_count := 0
	for name: String in ["app_icon", "bosses_avalon", "bosses_royal", "camp_sheet", "chapter_1", "chapter_2", "chapter_3", "chapter_4", "chapter_5", "chapter_6", "extra_cast", "foes_elements", "foes_magic", "foes_meadow", "fx_sheet", "hero_sheet", "minigame_worlds", "party_sheet", "story_1", "story_2", "story_3", "story_4", "story_5", "story_6", "story_cast", "title_art", "trick_icons", "ui_icons", "combat/shield_echo"]:
		if load("res://assets/illustrated/%s.png" % name) == null:
			push_error("Missing illustrated asset: " + name)
			quit(1)
			return
		art_count += 1
	for motion: String in ["knight", "mage", "archer", "companion_guard", "scarecrow_swing", "archer_draw",
			"stride_knight", "stride_mage", "stride_archer", "vertical_knight", "vertical_mage", "vertical_archer",
			"settle_knight", "settle_mage", "settle_archer"]:
		if load("res://assets/illustrated/motion/%s.png" % motion) == null:
			push_error("Missing motion atlas " + motion)
			quit(1)
			return
	for asset: String in ["class_codex/knight.webp", "class_codex/mage.webp", "class_codex/archer.webp",
			"equipment/atelier_cabinets.webp", "equipment/atelier_emblems.webp", "equipment/worn_gear.png",
			"equipment/worn_blade.png", "equipment/worn_cape.png", "equipment/worn_rank.png"]:
		if not load("res://assets/illustrated/" + asset) is Texture2D:
			push_error("Missing class or workshop artwork: " + asset)
			quit(1)
			return
	for technique: String in ["arc_rune", "starfall", "gale_disc"]:
		var card: Resource = load("res://data/tricks/%s.tres" % technique)
		if card == null or card.icon == null or card.max_level != 3:
			push_error("Missing playable attack card: " + technique)
			quit(1)
			return
	var figures := load("res://assets/fonts/QuillFigures.ttf") as Font
	if figures == null or load("res://assets/fonts/StoryDisplay.tres") == null:
		push_error("Missing combat figures or display typeface")
		quit(1)
		return
	for glyph in "0123456789":
		if not figures.has_char(glyph.unicode_at(0)):
			push_error("Missing damage digit " + glyph)
			quit(1)
			return
	if ResourceLoader.exists("res://tests/framework/test_runner.tscn"):
		push_error("Test scene incorrectly included in playtest")
		quit(1)
		return
	var pause := (load("res://ui/pause/pause.tscn") as PackedScene).instantiate() as Control
	root.add_child(pause)
	pause.visible = true
	await process_frame
	await process_frame
	var panel := pause.get("_panel") as PanelContainer
	if panel.size.x > 180 or panel.size.y > 320:
		push_error("Desktop pause menu exceeds the base game viewport")
		quit(1)
		return
	print("PACK_OK: 6 chapters, %d levels with opening and aftermath, illustrated epilogue, 4 companions and shield echo, %d illustrated textures, production UI; tests excluded" % [checked, art_count])
	pause.queue_free()
	await process_frame
	quit(0)
