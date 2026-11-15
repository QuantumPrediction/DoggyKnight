extends TestCase
## 文字與音效(C10、C11、C12):介面用到的每個 tr() 鍵都有翻譯;每個 Sfx id 都有音效檔。

const SFX_IDS: Array[StringName] = [   # DEV_PLAN 4.9 的固定 id
	&"swing", &"hit", &"hurt", &"enemy_down", &"pickup", &"level_up", &"bark",
	&"boss_warning", &"ultimate", &"clear", &"fail", &"ui_tap", &"scroll", &"ink",
]

var _sound_before: bool


func before_each() -> void:
	_sound_before = GameState.sound_on


func after_each() -> void:
	GameState.sound_on = _sound_before


func _scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_scripts(dir_path.path_join(sub)))
	for f in dir.get_files():
		if f.ends_with(".gd"):
			found.append(dir_path.path_join(f))
	return found


func test_every_tr_key_used_by_the_ui_exists() -> void:
	var re := RegEx.create_from_string("tr\\(\"([A-Za-z0-9_]+)\"\\)")
	var keys := {}
	for path in _scripts("res://ui"):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			keys[m.get_string(1)] = path
	assert_true(keys.size() >= 20, "掃描到介面用的翻譯鍵(%d 個)" % keys.size())
	for key: String in keys:
		assert_ne(tr(key), key, "%s 用到的 %s 沒有翻譯" % [keys[key], key])


func test_ui_keys_use_the_ui_prefix_or_shared_keys() -> void:
	var re := RegEx.create_from_string("tr\\(\"([A-Za-z0-9_]+)\"\\)")
	for path in _scripts("res://ui"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var key := m.get_string(1)
			assert_true(key.begins_with("UI_") or key == "CHAPTER_1" or key == "GAME_TITLE",
					"%s:C 線新增的鍵要用 UI_ 前綴(%s)" % [path, key])


func test_trick_and_level_keys_exist_for_dynamic_lookups() -> void:
	for id in ["SIT", "WAG", "FETCH", "SHAKE", "SPIN", "BARK"]:
		assert_ne(tr("TRICK_%s_NAME" % id), "TRICK_%s_NAME" % id)
		assert_ne(tr("TRICK_%s_DESC" % id), "TRICK_%s_DESC" % id)
	for i in range(1, 7):
		assert_ne(tr("LEVEL_1_%d" % i), "LEVEL_1_%d" % i)


func test_every_sfx_id_has_a_sound_file() -> void:
	assert_eq(Sfx.IDS.size(), SFX_IDS.size(), "Sfx.IDS 與 DEV_PLAN 4.9 一致")
	for id in SFX_IDS:
		var path := "res://assets/sfx/%s.wav" % id
		assert_true(ResourceLoader.exists(path), path)
		var stream := load(path) as AudioStreamWAV
		assert_not_null(stream, "%s 可以載入" % path)
		if stream != null:
			assert_true(stream.get_length() > 0.02 and stream.get_length() < 2.0, "%s 是短音效(%.2f 秒)" % [id, stream.get_length()])
		assert_true(Sfx.has_sound(id))


func test_sfx_respects_sound_switch() -> void:
	Sfx.stop_all()
	GameState.sound_on = false
	Sfx.play(&"hit")
	var playing := 0
	for p in Sfx.get_children():
		if p is AudioStreamPlayer and (p as AudioStreamPlayer).playing:
			playing += 1
	assert_eq(playing, 0, "音效關閉時不播放")
	GameState.sound_on = true
	Sfx.play(&"not_a_sound")      # 找不到檔案時安靜略過
	Sfx.play(&"ui_tap", -6.0)     # API 不變:play(id, volume_db)
	Sfx.stop_all()
