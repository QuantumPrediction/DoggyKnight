extends Node
## 音效播放(Autoload 名稱:Sfx)。DEV_PLAN 4.9。擁有者:C 線。
##
## 用法(任何線):Sfx.play(&"swing")、Sfx.play(&"hit", -6.0)、Sfx.play(&"star", 0.0, 1.12)(第三個參數:音高)
## 音效檔:assets/sfx/<id>.wav(由 tools/pixel/sfx_gen.py 生成)。找不到檔案時安靜略過。
## 遵守 GameState.sound_on。暫停時仍可播放(介面按鍵音)。
##
## 為了不吵:同一個音效在 MIN_INTERVAL 秒內只播一次,同時最多 MAX_SAME 個;
## 揮劍、命中等常重複的音效每次音高略有不同,聽起來比較自然。

const IDS: Array[StringName] = [
	&"swing", &"hit", &"hurt", &"enemy_down", &"pickup", &"level_up", &"bark",
	&"boss_warning", &"ultimate", &"clear", &"fail", &"ui_tap", &"scroll", &"ink",
	# v2.2(DEV_PLAN 4.10)
	&"crit", &"combo", &"boss_roar", &"star", &"whoosh", &"heal", &"pet", &"perfect", &"countdown",
]
const VOICES: int = 12
const MIN_INTERVAL: float = 0.04
const MAX_SAME: int = 3
## 每次播放時音高隨機變化的幅度(只套用在常重複的音效)。
const PITCH_JITTER: Dictionary = {
	&"swing": 0.06, &"hit": 0.08, &"enemy_down": 0.06, &"pickup": 0.04, &"scroll": 0.08, &"crit": 0.04,
	&"pet": 0.05,
}

var _players: Array[AudioStreamPlayer] = []
var _playing_id: Array[StringName] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 2026
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		_playing_id.append(&"")
	for id in IDS:
		_stream(id)       # 先載入,第一次播放時不會卡頓


func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not GameState.sound_on:
		return
	var stream := _stream(id)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -1.0)) < MIN_INTERVAL:
		return
	if _count_playing(id) >= MAX_SAME:
		return
	_last_played[id] = now
	var index := _free_voice()
	var player := _players[index]
	_playing_id[index] = id
	player.stream = stream
	player.volume_db = volume_db
	var jitter: float = PITCH_JITTER.get(id, 0.0)
	player.pitch_scale = maxf(0.25, pitch) * (1.0 + _rng.randf_range(-jitter, jitter))
	player.play()


## 立刻停止所有音效(例如關掉音效開關時)。
func stop_all() -> void:
	for p in _players:
		p.stop()


## 這個 id 有沒有對應的音效檔(測試用)。
func has_sound(id: StringName) -> bool:
	return _stream(id) != null


func _free_voice() -> int:
	for i in _players.size():
		var k := (_next + i) % _players.size()
		if not _players[k].playing:
			_next = (k + 1) % _players.size()
			return k
	var oldest := _next
	_next = (_next + 1) % _players.size()
	return oldest


func _count_playing(id: StringName) -> int:
	var n := 0
	for i in _players.size():
		if _players[i].playing and _playing_id[i] == id:
			n += 1
	return n


func _stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := "res://assets/sfx/%s.wav" % id
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = stream
	return stream
