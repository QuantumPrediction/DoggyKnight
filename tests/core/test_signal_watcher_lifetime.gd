extends TestCase

func test_watcher_can_stop_after_its_emitter_is_freed() -> void:
	var emitter := Node.new()
	var watcher := SignalWatcher.new(emitter.renamed)
	emitter.free()
	watcher.stop()
	watcher.stop()
	assert_true(watcher._signal.is_null())
	assert_false(watcher._callable.is_valid())

func test_stopping_a_live_watcher_disconnects_without_losing_evidence() -> void:
	var emitter := Node.new()
	var watcher := SignalWatcher.new(emitter.renamed)
	emitter.renamed.emit()
	watcher.stop()
	emitter.renamed.emit()
	assert_eq(watcher.count, 1)
	assert_eq(watcher.calls.size(), 1)
	emitter.free()
