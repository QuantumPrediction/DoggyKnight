extends Node
## 背景音樂(Autoload 名稱:Music)。DEV_PLAN 4.10、CP6。擁有者:C 線。
##
## 用法(任何線):Music.play(&"field")、Music.stop()、Music.set_ducked(true)、Music.refresh()
## 曲目檔:assets/music/<id>.ogg,由 tools/audio/compose_score.py 作曲與合成。
## 戰鬥另有等長的 <id>_pressure.ogg;舊 WAV 保留作相容後備與短曲。
## 找不到檔案時安靜略過,所以各線不必等 C 線。
##
## - 循環曲目(title、field、boss、camp,v2.3 加 story:開場繪本、結局與預告;v2.6 加第二章 field_2、boss_2,
##   第三章 field_3、boss_3;v2.7 加第四至六章 field_4 至 boss_6)無縫循環;換曲時交叉淡入淡出。
## - 短曲(victory、fail、chapter_clear)只播一次,播完就安靜(不會自己接回原本的曲子)。
## - 遵守 GameState.music_on(切換後呼叫 Music.refresh())。暫停時繼續播放,可以壓低音量。
## - 可調數值(音量、壓低幅度、淡入淡出秒數、個別曲目微調)在 ui/audio/music_config.tres。

const LOOPS: Array[StringName] = [&"title", &"field", &"boss", &"camp", &"story", &"field_2", &"boss_2",
		&"field_3", &"boss_3", &"field_4", &"boss_4", &"field_5", &"boss_5", &"field_6", &"boss_6"]
const JINGLES: Array[StringName] = [&"victory", &"fail", &"chapter_clear"]
const CONFIG_PATH: String = "res://ui/audio/music_config.tres"
const SILENT_DB: float = -60.0

## 預設值(設定檔不存在時使用)
var volume_db: float = -9.0
var duck_db: float = -10.0
var crossfade: float = 0.8
var jingle_fade_out: float = 0.25
var track_trim_db: Dictionary = {}

var current: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _rhythm: Array[AudioStreamPlayer] = []
var _pressure: float = 0.0
var _phase: int = 1
var _sense_timer: float = 0.0
var _pressure_fade: float = 1.8
var _crowd_full: float = 12.0
var _tweens: Array[Tween] = [null, null]
var _active: int = 0
var _ducked: bool = false
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Deck%d" % i
		player.volume_db = SILENT_DB
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)
		var rhythm := AudioStreamPlayer.new()
		rhythm.name = "Pressure%d" % i
		rhythm.volume_db = SILENT_DB
		add_child(rhythm)
		_rhythm.append(rhythm)
	EventBus.boss_phase_changed.connect(func(phase: int) -> void: _phase = phase)



## 換曲(同一首正在播就不重來)。fade < 0 時用設定檔的交叉淡入淡出秒數。
func play(track: StringName, fade: float = -1.0) -> void:
	if fade < 0.0:
		fade = jingle_fade_out if JINGLES.has(track) else crossfade
	if track == current and _players[_active].playing:
		return
	current = track
	_phase = 1
	_pressure = 0.0
	if not GameState.music_on:
		return
	var stream := _stream(track)
	_fade(_active, SILENT_DB, fade, true)
	if stream == null:
		return
	_active = 1 - _active
	var player := _players[_active]
	_kill_tween(_active)
	player.stream = stream
	if JINGLES.has(track):
		player.volume_db = _target_db(track)     # 短曲要有力地開始
	else:
		player.volume_db = SILENT_DB
		_fade(_active, _target_db(track), fade, false, true)
	player.play()
	# Matching-length stems are started together; a wave change never restarts them.
	var stem := _stream(StringName(String(track) + "_pressure")) if _is_battle(track) else null
	_rhythm[_active].stop()
	_rhythm[_active].stream = stem
	_rhythm[_active].volume_db = SILENT_DB
	if stem != null:
		_rhythm[_active].play()



func stop(fade: float = 0.6) -> void:
	current = &""
	for i in _players.size():
		_fade(i, SILENT_DB, fade, true)


## 暫停選單打開時壓低音量。
func set_ducked(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	if _players[_active].playing:
		_fade(_active, _target_db(current), 0.25, false)


## GameState.music_on 改變後呼叫:關掉就停,打開就重新播目前的曲目(短曲不重播)。
func refresh() -> void:
	if not GameState.music_on:
		for i in _players.size():
			_kill_tween(i)
			_players[i].stop()
			_rhythm[i].stop()
			_rhythm[i].volume_db = SILENT_DB
			_players[i].volume_db = SILENT_DB
		return
	var track := current
	current = &""
	if track != &"" and not JINGLES.has(track):
		play(track, 0.4)


func is_playing() -> bool:
	return _players[_active].playing


## 目前播放的曲目(沒有在播就傳回 &"")。
func playing_track() -> StringName:
	return current if is_playing() else &""


func is_ducked() -> bool:
	return _ducked


## 這首曲子有沒有音樂檔(測試用)。
func has_track(track: StringName) -> bool:
	return _stream(track) != null


func _target_db(track: StringName) -> float:
	return volume_db + float(track_trim_db.get(track, 0.0)) + (duck_db if _ducked else 0.0)


func _on_finished(index: int) -> void:
	# 只有短曲會播完(循環曲目不會觸發 finished):播完就安靜。
	if index == _active and JINGLES.has(current):
		current = &""


func _kill_tween(index: int) -> void:
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	_tweens[index] = null


func _fade(index: int, to_db: float, duration: float, stop_after: bool, force: bool = false) -> void:
	var player := _players[index]
	if not player.playing and not force:
		return
	_kill_tween(index)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "volume_db", to_db, maxf(duration, 0.01))
	if stop_after:
		tween.parallel().tween_property(_rhythm[index], "volume_db", SILENT_DB, maxf(duration, 0.01))
	if stop_after:
		tween.tween_callback(player.stop)
		tween.tween_callback(_rhythm[index].stop)
	_tweens[index] = tween


func _stream(track: StringName) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://assets/music/%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if LOOPS.has(track) or String(track).ends_with("_pressure"):
			# 匯入設定已是 Forward 循環;這裡再保險一次,整首無縫循環。
			if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = LOOPS.has(track) or String(track).ends_with("_pressure")
	_cache[track] = stream
	return stream


func _load_config() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		return
	var cfg := load(CONFIG_PATH)
	if cfg == null:
		return
	volume_db = float(cfg.get("volume_db"))
	duck_db = float(cfg.get("duck_db"))
	crossfade = float(cfg.get("crossfade"))
	jingle_fade_out = float(cfg.get("jingle_fade_out"))
	var trims: Variant = cfg.get("track_trim_db")
	if trims is Dictionary:
		track_trim_db = trims
	_pressure_fade = float(cfg.get("pressure_fade"))
	_crowd_full = float(cfg.get("crowd_full"))


func _is_battle(track: StringName) -> bool:
	return String(track).begins_with("field") or String(track).begins_with("boss")


func _process(delta: float) -> void:
	if _rhythm.is_empty() or not _rhythm[_active].playing or not _is_battle(current):
		return
	# Periodic sensing, not a per-frame scan of every combat node.
	_sense_timer -= delta
	if _sense_timer <= 0.0 and not get_tree().paused:
		_sense_timer = 0.3
		var count := get_tree().get_nodes_in_group(&"enemy").size()
		var ratio := float(GameState.vigor) / maxf(1.0, GameState.player_stats.max_vigor)
		set_pressure(pressure_for(count, ratio, String(current).begins_with("boss"), _phase))
	var target := SILENT_DB if _pressure < 0.03 else _target_db(current) - 12.0 + 9.0 * _pressure
	_rhythm[_active].volume_db = move_toward(_rhythm[_active].volume_db, target, delta * 36.0 / maxf(_pressure_fade, 0.1))


func pressure_for(enemies: int, vigor_ratio: float, boss: bool, phase: int) -> float:
	var crowd := clampf(float(enemies) / maxf(1.0, _crowd_full), 0.0, 1.0)
	var danger := 0.25 if vigor_ratio < 0.35 and enemies > 0 else 0.0
	return clampf(maxf(crowd, 0.6 if boss and enemies > 0 else 0.0) + danger + (0.2 if boss and phase > 1 else 0.0), 0.0, 1.0)


func set_pressure(value: float) -> void:
	_pressure = clampf(value, 0.0, 1.0)


func pressure_level() -> float:
	return _pressure
