extends Node
## 音效播放(Autoload 名稱:Sfx)。DEV_PLAN 4.9。擁有者:C 線(整合工作階段放了這個初版)。
##
## 用法(任何線):Sfx.play(&"swing")
## 音效檔:assets/sfx/<id>.wav。找不到檔案時安靜略過,所以各線不必等 C 線。
## 遵守 GameState.sound_on。暫停時仍可播放(介面按鍵音)。

const IDS: Array[StringName] = [
	&"swing", &"hit", &"hurt", &"enemy_down", &"pickup", &"level_up", &"bark",
	&"boss_warning", &"ultimate", &"clear", &"fail", &"ui_tap", &"scroll", &"ink",
]
const VOICES: int = 8

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(id: StringName, volume_db: float = 0.0) -> void:
	if not GameState.sound_on:
		return
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := "res://assets/sfx/%s.wav" % id
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = stream
	return stream
