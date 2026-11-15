extends TestCase
## D7 平台介面:原型的廣告、內購、分析都是空實作,只回報「沒有」。


func test_services_are_disabled() -> void:
	assert_false(PlatformAds.ENABLED)
	assert_false(PlatformIap.ENABLED)
	assert_false(PlatformAnalytics.ENABLED)


func test_rewarded_ad_never_rewards() -> void:
	var ads := PlatformAds.new()
	add_child(ads)
	var finished := watch_signal(ads.rewarded_finished)
	assert_false(ads.is_available())
	ads.show_rewarded(&"continue")
	await wait_frames(1)
	assert_eq(finished.count, 1)
	assert_eq(finished.last_args(), [&"continue", false])
	ads.queue_free()


func test_purchase_always_fails() -> void:
	var iap := PlatformIap.new()
	add_child(iap)
	var finished := watch_signal(iap.purchase_finished)
	assert_eq(iap.get_products([&"snack_pack"]).size(), 0)
	iap.purchase(&"snack_pack")
	await wait_frames(1)
	assert_eq(finished.last_args(), [&"snack_pack", false])
	iap.queue_free()


func test_analytics_only_logs() -> void:
	var analytics := PlatformAnalytics.new()
	add_child(analytics)
	analytics.log_event(&"level_start", {"level": "1_1"})
	assert_true(PlatformLog.recent[PlatformLog.recent.size() - 1].contains("level_start"), "只記錄")
	analytics.queue_free()
