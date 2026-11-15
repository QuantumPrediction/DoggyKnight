class_name PlatformLog
extends RefCounted
## platform/ 的空實作共用的記錄工具:只在除錯版印到主控台,正式版完全安靜。

## 測試用:記下最後幾筆訊息。
static var recent: PackedStringArray = []


static func note(service: String, message: String) -> void:
	var line := "[platform/%s] %s" % [service, message]
	recent.append(line)
	if recent.size() > 20:
		recent = recent.slice(recent.size() - 20)
	if OS.is_debug_build():
		print(line)
