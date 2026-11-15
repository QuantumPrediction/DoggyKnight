extends TestCase
## 畫面適配與安全區(DEV_PLAN 2、4.8)。數字取自常見手機的實體解析度。

## [視窗實體像素, 預期倍數, 預期畫面邏輯像素]
const PHONES: Array = [
	[Vector2i(540, 960), 3, Vector2i(180, 320)],      # 桌面測試視窗
	[Vector2i(1080, 1920), 6, Vector2i(180, 320)],    # 16:9
	[Vector2i(1080, 2340), 6, Vector2i(180, 390)],    # 19.5:9
	[Vector2i(1080, 2400), 6, Vector2i(180, 400)],    # 20:9
	[Vector2i(720, 1600), 4, Vector2i(180, 400)],     # 入門 Android 20:9
	[Vector2i(1440, 3200), 8, Vector2i(180, 400)],    # 高階 Android
	[Vector2i(1179, 2556), 6, Vector2i(196, 426)],    # iPhone 15 / 16
	[Vector2i(1290, 2796), 7, Vector2i(184, 399)],    # iPhone Pro Max
	[Vector2i(750, 1334), 4, Vector2i(187, 333)],     # iPhone SE
]


func after_each() -> void:
	SafeArea.simulate_notch = false


func test_integer_scale_and_viewport_size_for_common_phones() -> void:
	for phone: Array in PHONES:
		var window_px: Vector2i = phone[0]
		assert_eq(ScreenFit.compute_scale(window_px), phone[1], "%s 的倍數" % window_px)
		assert_eq(ScreenFit.compute_viewport_size(window_px), phone[2], "%s 的畫面大小" % window_px)


func test_black_border_is_less_than_one_logical_pixel() -> void:
	for phone: Array in PHONES:
		var window_px: Vector2i = phone[0]
		var scale := ScreenFit.compute_scale(window_px)
		var used := ScreenFit.compute_viewport_size(window_px) * scale
		assert_true(used.x <= window_px.x and used.y <= window_px.y, "%s 畫面不超出螢幕" % window_px)
		assert_true(window_px.x - used.x < scale and window_px.y - used.y < scale, "%s 黑邊少於一個邏輯像素" % window_px)


func test_viewport_never_smaller_than_game_area() -> void:
	assert_eq(ScreenFit.compute_viewport_size(Vector2i(100, 100)), Vector2i(180, 320))


func test_safe_area_conversion_android_punch_hole() -> void:
	# 1080×2400 手機,頂部挖孔 132 像素,底部手勢列 63 像素。
	var safe_px := Rect2(0, 132, 1080, 2400 - 132 - 63)
	var logical := SafeArea.screen_to_logical(safe_px, Vector2(1080, 2400), Vector2(180, 400))
	assert_almost_eq(logical.position.y, 22.0)
	assert_almost_eq(logical.end.y, 389.5)
	assert_almost_eq(logical.position.x, 0.0)
	assert_almost_eq(logical.size.x, 180.0)


func test_safe_area_conversion_iphone_with_tiny_margins() -> void:
	# iPhone 15:1179×2556,畫面 196×426,放大 6 倍,左右各 1.5 實體像素的邊,上下沒有邊。
	# 頂部動態島 177 像素,底部橫條 102 像素。
	var safe_px := Rect2(0, 177, 1179, 2556 - 177 - 102)
	var logical := SafeArea.screen_to_logical(safe_px, Vector2(1179, 2556), Vector2(196, 426))
	assert_almost_eq(logical.position.y, 29.5)
	assert_almost_eq(logical.end.y, 409.0)
	assert_almost_eq(logical.position.x, 0.0, 0.0001, "超出畫面的部分被裁掉")
	assert_almost_eq(logical.end.x, 196.0)


func test_game_rect_is_centered_game_size() -> void:
	var game := SafeArea.get_game_rect()
	var screen := SafeArea.get_screen_size()
	assert_eq(game.size, SafeArea.GAME_SIZE)
	assert_eq(game.position, ((screen - SafeArea.GAME_SIZE) * 0.5).floor())


func test_simulated_notch_on_desktop() -> void:
	var full := SafeArea.get_safe_rect()
	SafeArea.simulate_notch = true
	var notched := SafeArea.get_safe_rect()
	assert_almost_eq(notched.position.y, full.position.y + SafeArea.SIMULATED_TOP_INSET)
	assert_almost_eq(notched.end.y, full.end.y - SafeArea.SIMULATED_BOTTOM_INSET)


func test_refits_when_window_shrinks_without_size_changed() -> void:
	var root := get_tree().root
	var original := root.size
	root.size = Vector2i(392, 852)
	await wait_frames(2)
	assert_eq(SafeArea.get_screen_size(), Vector2(196, 426))
	root.size = Vector2i(368, 798)
	await wait_frames(2)
	assert_eq(SafeArea.get_screen_size(), Vector2(184, 399), "縮小後重新適配")
	root.size = original
	await wait_frames(2)
