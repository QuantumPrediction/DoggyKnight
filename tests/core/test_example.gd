extends TestCase
## 示範測試:給各線參考的寫法。複製這個檔案到 tests/line_x/test_<主題>.gd 再修改。


func test_basic_assertions() -> void:
	assert_eq(1 + 1, 2)
	assert_true("金毛".length() == 2, "中文字串長度")
	assert_almost_eq(0.1 + 0.2, 0.3)
	assert_ne(&"goldie", &"bulldog")


func test_watching_a_signal() -> void:
	var watcher := watch_signal(EventBus.enemy_died)
	EventBus.enemy_died.emit(&"scarecrow", Vector2(10, 20), 1)
	assert_eq(watcher.count, 1, "enemy_died 發出次數")
	assert_eq(watcher.last_args()[0], &"scarecrow")
	assert_eq(watcher.last_args()[2], 1)


func test_waiting_for_frames() -> void:
	var start := Engine.get_process_frames()
	await wait_frames(2)
	assert_true(Engine.get_process_frames() >= start + 2, "至少過了兩格")
