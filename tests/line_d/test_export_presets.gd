extends TestCase
## D6、D10:export_presets.cfg 的基本檢查(直接解析檔案)。

const PRESETS_PATH := "res://export_presets.cfg"
const PACKAGE := "com.doggyknight.prototype"

var _cfg: ConfigFile


func before_each() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(PRESETS_PATH)


func _section_of(preset_name: String) -> String:
	for section in _cfg.get_sections():
		if not section.ends_with(".options") and _cfg.get_value(section, "name", "") == preset_name:
			return section
	return ""


func _opt(preset_name: String, key: String) -> Variant:
	return _cfg.get_value(_section_of(preset_name) + ".options", key)


func test_file_parses_and_has_presets() -> void:
	assert_eq(_cfg.load(PRESETS_PATH), OK, "export_presets.cfg 可以解析")
	for preset_name in ["Android", "Android AAB", "Android Sandbox", "iOS"]:
		assert_ne(_section_of(preset_name), "", "有「%s」匯出設定" % preset_name)


func test_android_package_and_versions() -> void:
	for preset_name in ["Android", "Android AAB"]:
		assert_eq(_cfg.get_value(_section_of(preset_name), "platform"), "Android")
		assert_eq(_opt(preset_name, "package/unique_name"), PACKAGE, "%s 套件名稱" % preset_name)
		assert_eq(_opt(preset_name, "package/name"), "金毛騎士")
		assert_eq(_opt(preset_name, "version/name"), "0.1.0")
		assert_true(int(_opt(preset_name, "version/code")) >= 1)
		assert_eq(_opt(preset_name, "architectures/arm64-v8a"), true, "Google Play 要求 64 位元")
		assert_eq(_opt(preset_name, "screen/immersive_mode"), true, "全螢幕")
		assert_eq(_opt(preset_name, "user_data_backup/allow"), false)


func test_aab_uses_gradle_with_store_sdk_levels() -> void:
	assert_eq(_opt("Android AAB", "gradle_build/use_gradle_build"), true)
	assert_eq(_opt("Android AAB", "gradle_build/export_format"), 1, "AAB")
	assert_eq(_opt("Android AAB", "gradle_build/min_sdk"), "24", "min SDK 24")
	assert_eq(_opt("Android AAB", "gradle_build/target_sdk"), "36", "target SDK 36(Google Play 2026-08-31 起)")
	# 非 Gradle 的 APK 用匯出範本內建的 24 / 36,這兩欄必須留空,否則匯出會失敗。
	assert_eq(_opt("Android", "gradle_build/min_sdk"), "")
	assert_eq(_opt("Android", "gradle_build/target_sdk"), "")


func test_no_permissions_requested() -> void:
	for preset_name in ["Android", "Android AAB", "Android Sandbox"]:
		var section := _section_of(preset_name) + ".options"
		for key in _cfg.get_section_keys(section):
			if key.begins_with("permissions/") and key != "permissions/custom_permissions":
				assert_ne(_cfg.get_value(section, key), true, "%s 不需要權限 %s" % [preset_name, key])
		var custom: Variant = _cfg.get_value(section, "permissions/custom_permissions", PackedStringArray())
		assert_eq((custom as PackedStringArray).size(), 0, "沒有自訂權限")


func test_no_secrets_in_presets() -> void:
	for section in _cfg.get_sections():
		if not section.ends_with(".options"):
			continue
		for key in ["keystore/release", "keystore/release_password", "keystore/debug_password", "keystore/release_user"]:
			assert_eq(_cfg.get_value(section, key, ""), "", "%s 的 %s 必須留空(金鑰不進 repo)" % [section, key])


func test_portrait_only() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "直向(Android 與 iOS 都讀這個專案設定)")
	assert_eq(_opt("iOS", "application/targeted_device_family"), 0, "只支援 iPhone")


func test_ios_preset() -> void:
	assert_eq(_cfg.get_value(_section_of("iOS"), "platform"), "iOS")
	assert_eq(_opt("iOS", "application/bundle_identifier"), PACKAGE, "與 Android 用同一個識別碼")
	assert_eq(_opt("iOS", "application/app_store_team_id"), "", "Team ID 由擁有人在 Mac 上填")
	assert_eq(_opt("iOS", "application/short_version"), "0.1.0")


func test_icons_exist() -> void:
	for preset_name in ["Android", "Android AAB", "Android Sandbox"]:
		for key in ["launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432",
				"launcher_icons/adaptive_background_432x432", "launcher_icons/adaptive_monochrome_432x432"]:
			var path: String = _opt(preset_name, key)
			if not path.is_empty():
				assert_true(ResourceLoader.exists(path) or FileAccess.file_exists(path), "%s %s 指向存在的檔案" % [preset_name, path])
	var ios_icon: String = _opt("iOS", "icons/icon_1024x1024")
	if not ios_icon.is_empty():
		assert_true(ResourceLoader.exists(ios_icon), "iOS 圖示存在")


func test_store_builds_exclude_tests() -> void:
	for preset_name in ["Android", "Android AAB", "iOS"]:
		var exclude: String = _cfg.get_value(_section_of(preset_name), "exclude_filter", "")
		assert_true(exclude.contains("tests/line_d/*"), "%s 不打包測試場景" % preset_name)
		assert_true(exclude.contains("tools/*"))
	var sandbox_exclude: String = _cfg.get_value(_section_of("Android Sandbox"), "exclude_filter", "")
	assert_false(sandbox_exclude.contains("tests/line_d/*"), "沙盒 APK 要包含 D 線的測試場景")
	assert_eq(_opt("Android Sandbox", "command_line/extra_args"), "res://tests/line_d/camp_sandbox.tscn")
	assert_ne(_opt("Android Sandbox", "package/unique_name"), PACKAGE, "沙盒用不同的套件名稱,不會蓋掉正式的除錯版")
