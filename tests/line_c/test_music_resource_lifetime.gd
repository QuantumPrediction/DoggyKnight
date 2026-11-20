extends TestCase

var previous_music: bool

func before_each() -> void:
	previous_music = GameState.music_on
	GameState.music_on = false
	Music.refresh()
	Music.set_ducked(false)
	Music.stop(0.0)
	GameState.music_on = true

func after_each() -> void:
	GameState.music_on = false
	Music.refresh()
	Music.set_ducked(false)
	Music.stop(0.0)
	GameState.music_on = previous_music

func test_looking_up_a_track_does_not_keep_unplayed_chapter_music_resident() -> void:
	var path := "res://assets/music/boss_6_pressure.ogg"
	assert_true(Music.has_track(&"boss_6_pressure"))
	assert_false(ResourceLoader.has_cached(path), "a track lookup must release the unplayed score")
	assert_false(Music.has_track(&"no_such_track"))

func test_crossfade_keeps_both_layers_until_the_outgoing_deck_releases_them() -> void:
	Music.play(&"field_2", 0.0)
	var old := Music._active
	Music.play(&"title", 0.08)
	assert_true(Music._players[old].playing)
	assert_true(Music._rhythm[old].playing)
	await get_tree().create_timer(0.15).timeout
	assert_null(Music._players[old].stream, "faded-out chapter melody")
	assert_null(Music._rhythm[old].stream, "faded-out pressure track")
	assert_eq(Music.playing_track(), &"title")

func test_stop_finishes_while_ducking_and_a_fast_deck_reuse_keeps_the_new_track() -> void:
	Music.play(&"field", 0.0)
	Music.play(&"boss", 0.08)
	Music.play(&"field_3", 0.08)
	await get_tree().create_timer(0.15).timeout
	assert_eq(Music.playing_track(), &"field_3")
	assert_true(Music._rhythm[Music._active].playing)
	Music.stop(0.08)
	Music.set_ducked(true)
	await get_tree().create_timer(0.15).timeout
	for player: AudioStreamPlayer in Music._players + Music._rhythm:
		assert_false(player.playing, "changing pause volume during stop must still finish the fade")
		assert_null(player.stream, "stopped decks release the score")

func test_muting_a_crossfade_releases_both_decks_and_resumes_the_selected_battle() -> void:
	Music.play(&"field", 0.0)
	Music.play(&"boss_2", 0.5)
	GameState.music_on = false
	Music.refresh()
	for player: AudioStreamPlayer in Music._players + Music._rhythm:
		assert_null(player.stream, "muted deck must relinquish each stream")
	GameState.music_on = true
	Music.refresh()
	assert_eq(Music.playing_track(), &"boss_2")
	assert_true(Music._rhythm[Music._active].playing)

func test_finished_victory_cue_releases_its_deck() -> void:
	Music.play(&"victory", 0.0)
	var deck: AudioStreamPlayer = Music._players[Music._active]
	deck.seek(maxf(0.0, deck.stream.get_length() - 0.05))
	await get_tree().create_timer(0.4).timeout
	assert_false(deck.playing)
	assert_eq(Music.current, &"")
	assert_null(deck.stream, "completed one-shot cue")

func test_returning_to_title_releases_scores_played_across_six_chapters() -> void:
	var score_paths := PackedStringArray()
	for chapter in range(1, 7):
		var suffix := "" if chapter == 1 else "_%d" % chapter
		for kind: String in ["field", "boss"]:
			var track := kind + suffix
			Music.play(StringName(track), 0.02)
			score_paths.append("res://assets/music/%s.ogg" % track)
			score_paths.append("res://assets/music/%s_pressure.ogg" % track)
			await get_tree().create_timer(0.05).timeout
	Music.play(&"title", 0.02)
	# Let the outgoing fade and the audio thread's queued playback finish.
	await get_tree().create_timer(0.5).timeout
	var retained := PackedStringArray()
	for path in score_paths:
		if ResourceLoader.has_cached(path):
			retained.append(path.get_file())
	print("Chapter score resources resident at title: %d/%d %s" % [retained.size(), score_paths.size(), retained])
	assert_true(retained.is_empty(), "unused chapter music still resident at title")
	assert_eq(Music.playing_track(), &"title")
