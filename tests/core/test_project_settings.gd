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
	for autoload in ["EventBus", "GameState", "AppLifecycle", "ScreenFit"]:
		assert_true(ProjectSettings.has_setting("autoload/%s" % autoload), "Autoload %s" % autoload)
		assert_not_null(get_tree().root.get_node_or_null(autoload), "Autoload %s 已載入" % autoload)
