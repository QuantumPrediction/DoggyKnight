extends TestCase
## 手機生命週期(DEV_PLAN 4.8):系統通知 → EventBus 訊號。


func before_each() -> void:
	AppLifecycle.simulate_foreground()


func after_each() -> void:
	AppLifecycle.simulate_foreground()


func test_backgrounding_emits_once_even_with_two_notifications() -> void:
	var backgrounded := watch_signal(EventBus.app_backgrounded)
	# 手機切到背景時,系統常先送「失去焦點」再送「暫停」。
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(backgrounded.count, 1)
	assert_true(AppLifecycle.is_in_background())


func test_returning_emits_foregrounded_once() -> void:
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var foregrounded := watch_signal(EventBus.app_foregrounded)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	AppLifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(foregrounded.count, 1)
	assert_false(AppLifecycle.is_in_background())


func test_android_back_request() -> void:
	var back := watch_signal(EventBus.back_requested)
	AppLifecycle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(back.count, 1)


func test_escape_key_simulates_back_on_desktop() -> void:
	var back := watch_signal(EventBus.back_requested)
	var press := InputEventAction.new()
	press.action = &"back"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)
	assert_eq(back.count, 1)


func test_simulation_helpers_for_sandboxes() -> void:
	var backgrounded := watch_signal(EventBus.app_backgrounded)
	var foregrounded := watch_signal(EventBus.app_foregrounded)
	var back := watch_signal(EventBus.back_requested)
	AppLifecycle.simulate_background()
	AppLifecycle.simulate_background()
	AppLifecycle.simulate_foreground()
	AppLifecycle.simulate_back()
	assert_eq(backgrounded.count, 1)
	assert_eq(foregrounded.count, 1)
	assert_eq(back.count, 1)
