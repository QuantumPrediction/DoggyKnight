extends Node
## 背景音樂(Autoload 名稱:Music)。DEV_PLAN 4.10。擁有者:C 線(整合工作階段放了這個初版)。
##
## 用法(任何線):Music.play(&"field")、Music.stop()、Music.set_ducked(true)
## 曲目檔:assets/music/<id>.wav 或 .ogg;找不到檔案時安靜略過,所以各線不必等 C 線。
## 遵守 GameState.music_on(切換後呼叫 Music.refresh())。暫停時繼續播放(可壓低音量)。
## 循環曲目:title、field、boss、camp。只播一次的短曲:victory、fail、chapter_clear。

const LOOPS: Array[StringName] = [&"title", &"field", &"boss", &"camp"]
const JINGLES: Array[StringName] = [&"victory", &"fail", &"chapter_clear"]
const VOLUME_DB: float = -8.0
const DUCK_DB: float = -10.0

var current: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _ducked: bool = false
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)


## 換曲(同一首正在播就不重來)。fade 是淡入淡出秒數。
func play(track: StringName, fade: float = 0.6) -> void:
	if track == current and _players[_active].playing:
		return
	current = track
	if not GameState.music_on:
		return
	var stream := _stream(track)
	var old := _players[_active]
	_fade(old, -80.0, fade, true)
	if stream == null:
		return
	_active = 1 - _active
	var player := _players[_active]
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	_fade(player, _target_db(), fade, false)


func stop(fade: float = 0.6) -> void:
	current = &""
	for player in _players:
		_fade(player, -80.0, fade, true)


## 暫停選單打開時壓低音量。
func set_ducked(on: bool) -> void:
	_ducked = on
	var player := _players[_active]
	if player.playing:
		_fade(player, _target_db(), 0.2, false)


## GameState.music_on 改變後呼叫:關掉就停,打開就重新播目前的曲目。
func refresh() -> void:
	if not GameState.music_on:
		for player in _players:
			player.stop()
		return
	var track := current
	current = &""
	if track != &"":
		play(track, 0.3)


func is_playing() -> bool:
	return _players[_active].playing


func _target_db() -> float:
	return VOLUME_DB + (DUCK_DB if _ducked else 0.0)


func _fade(player: AudioStreamPlayer, to_db: float, duration: float, stop_after: bool) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, maxf(duration, 0.01))
	if stop_after:
		tween.tween_callback(player.stop)


func _stream(track: StringName) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://assets/music/%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[track] = stream
	return stream
