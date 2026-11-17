extends RefCounted
## 給 B 線測試用的假音樂播放器:方法與 Music Autoload 相同(play / stop / set_ducked / refresh),
## 只把每次呼叫記下來,例如 ["play:title", "play:field", "duck:true", "duck:false", "play:victory"]。
## v2.6:has_track(track) 讓 FlowMain 知道曲子在不在(預設全部都在;放進 missing 的就當作沒有檔案)。

var calls: PackedStringArray = []
var missing: PackedStringArray = []


func has_track(track: StringName) -> bool:
	return not missing.has(String(track))


func play(track: StringName, _fade: float = 0.6) -> void:
	calls.append("play:%s" % track)


func stop(_fade: float = 0.6) -> void:
	calls.append("stop")


func set_ducked(on: bool) -> void:
	calls.append("duck:%s" % on)


func refresh() -> void:
	calls.append("refresh")


## 只取「play:...」的曲目次序。
func tracks() -> PackedStringArray:
	var result: PackedStringArray = []
	for call_text in calls:
		if call_text.begins_with("play:"):
			result.append(call_text.trim_prefix("play:"))
	return result


func clear() -> void:
	calls.clear()
