extends TestCase
## 核對手機相關的專案設定(DEV_PLAN 2、4.5、4.8)沒有被改動。


func _setting(name: String) -> Variant:
	return ProjectSettings.get_setting(name)


func test_portrait_pixel_screen() -> void:
	assert_eq(_setting("display/window/size/viewport_width"), 180)
	assert_eq(_setting("display/window/size/viewport_height"), 320)
	assert_eq(_setting("display/window/stretch/mode"), "viewport")
	assert_eq(_setting("display/window/stretch/aspect"), "expand")
	assert_eq(_setting("display/window/stretch/scale_mode"), "integer")
	assert_eq(_setting("display/window/handheld/orientation"), 1, "直向")
	assert_eq(_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "像素不平滑")


func test_renderer_and_mobile_export_prerequisites() -> void:
	assert_eq(_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")
	assert_eq(_setting("rendering/textures/vram_compression/import_etc2_astc"), true, "Android 匯出需要")


func test_touch_input_and_back_key() -> void:
	assert_eq(_setting("input_devices/pointing/emulate_touch_from_mouse"), true, "桌面滑鼠等同觸控")
	assert_eq(_setting("application/config/quit_on_go_back"), false, "返回鍵不可直接退出")
	assert_true(InputMap.has_action(&"back"), "桌面用 Esc 模擬返回鍵")


func test_collision_layer_names() -> void:
	var names := ["arena", "player", "companion", "enemy", "player_attack", "enemy_attack", "pickup"]
	for i in names.size():
		assert_eq(_setting("layer_names/2d_physics/layer_%d" % (i + 1)), names[i], "圖層 %d" % (i + 1))
	assert_eq(Layers.ARENA, 1)
	assert_eq(Layers.PICKUP, 64)


func test_autoloads() -> void:
	for autoload in ["EventBus", "GameState", "AppLifecycle", "ScreenFit", "Sfx", "PlayLog", "Music"]:
		assert_true(ProjectSettings.has_setting("autoload/%s" % autoload), "Autoload %s" % autoload)
		assert_not_null(get_tree().root.get_node_or_null(autoload), "Autoload %s 已載入" % autoload)


func test_traditional_chinese_strings() -> void:
	assert_eq(TranslationServer.get_locale(), "zh_TW")
	assert_eq(tr("GAME_TITLE"), "金毛騎士", "i18n/strings.csv 已載入")
	assert_eq(tr("UI_WAVE") % [1, 3], "第 1/3 波", "格式字串")


func test_layout_constants() -> void:
	assert_eq(Layout.ARENA_RECT.size, Vector2(11 * Layout.TILE, 14 * Layout.TILE), "11×14 格")
	assert_true(Rect2(Vector2.ZERO, SafeArea.GAME_SIZE).encloses(Layout.ARENA_RECT), "場地在遊戲區內")
	assert_true(Layout.ARENA_RECT.has_point(Layout.PLAYER_START))


func test_mobile_power_and_ios_settings() -> void:
	assert_eq(_setting("application/run/max_fps"), 60, "高更新率手機鎖 60 FPS")
	assert_eq(_setting("display/window/ios/allow_high_refresh_rate"), false)
	assert_eq(_setting("audio/general/ios/session_category"), 0, "Ambient:靜音鍵打開時不發聲")
	assert_eq(_setting("display/window/ios/hide_status_bar"), true)
	assert_eq(_setting("display/window/ios/hide_home_indicator"), true)
	assert_eq(_setting("display/window/ios/suppress_ui_gesture"), true)


func test_boot_main_scene_splash_and_theme() -> void:
	assert_eq(_setting("application/run/main_scene"), "res://game/flow/main.tscn", "開機進入正式流程")
	assert_eq(_setting("application/boot_splash/image"), "res://assets/app_icon/splash.png")
	assert_eq(_setting("application/boot_splash/use_filter"), false, "啟動畫面像素不模糊")
	assert_eq(_setting("gui/theme/custom"), "res://ui/theme/main_theme.tres", "全域像素字主題")
	assert_true(ResourceLoader.exists("res://game/flow/main.tscn"))
	assert_true(ResourceLoader.exists("res://assets/app_icon/splash.png"))
	assert_true(ResourceLoader.exists("res://ui/theme/main_theme.tres"))
