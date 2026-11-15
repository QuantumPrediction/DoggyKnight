extends SceneTree
## 把 assets/app_icon/ 裡現有的圖示填進 export_presets.cfg(D6、D10)。
## C 線(C13)加入正式圖示後執行一次,再提交 export_presets.cfg:
##
##   godot --headless --path . --script res://export/tools/sync_icons.gd
##
## 每個欄位依序找下面列出的檔名,找到第一個存在的就用;都沒有就保留原值。
## 只改圖示欄位,其他設定不動。

const PRESETS_PATH := "res://export_presets.cfg"
const ICON_DIR := "res://assets/app_icon/"

const ANDROID_ICONS := {
	"launcher_icons/main_192x192": ["android_main_192.png", "android_icon_192.png", "icon_192.png", "icon.png"],
	"launcher_icons/adaptive_foreground_432x432": ["android_foreground.png", "android_adaptive_foreground.png", "adaptive_foreground.png"],
	"launcher_icons/adaptive_background_432x432": ["android_background.png", "android_adaptive_background.png", "adaptive_background.png"],
	"launcher_icons/adaptive_monochrome_432x432": ["android_monochrome.png", "android_adaptive_monochrome.png", "adaptive_monochrome.png"],
}
const IOS_ICONS := {
	"icons/icon_1024x1024": ["ios_1024.png", "icon_1024.png", "app_icon_1024.png", "icon.png"],
	"icons/app_store_1024x1024": ["app_store_1024.png", "ios_1024.png", "icon_1024.png"],
}


func _initialize() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS_PATH) != OK:
		push_error("cannot read " + PRESETS_PATH)
		quit(1)
		return
	var changed := 0
	for section in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		var platform: String = cfg.get_value(section, "platform", "")
		var table: Dictionary = ANDROID_ICONS if platform == "Android" else (IOS_ICONS if platform == "iOS" else {})
		for key: String in table:
			var found := _first_existing(table[key])
			var options := section + ".options"
			if found.is_empty() or cfg.get_value(options, key, "") == found:
				continue
			print("%s: %s = %s" % [cfg.get_value(section, "name", section), key, found])
			cfg.set_value(options, key, found)
			changed += 1
	if changed > 0:
		cfg.save(PRESETS_PATH)
	print("sync_icons: %d change(s)" % changed)
	quit(0)


static func _first_existing(names: Array) -> String:
	for file_name: String in names:
		var path := ICON_DIR + file_name
		if FileAccess.file_exists(path):
			return path
	return ""
